import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ai_config_store.dart';
import '../models/chat_message.dart';
import '../models/chat_reply.dart';
import '../models/chat_session.dart';
import 'chat_provider.dart';

class GeminiProvider extends IChatProvider {
  GeminiProvider(this._config);

  final AiConfigStore _config;

  @override
  String get providerId => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  List<String> get supportedModels => const [
        'gemini-3-pro-preview',
        'gemini-3-flash-preview',
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
        'gemini-2.0-flash',
        'gemini-2.0-flash-lite',
      ];
  static const _timeout = Duration(seconds: 30);

  @override
  Future<ChatReply> sendMessage(ChatSession session, String userText) async {
    final key = await _config.getGeminiKey();
    if (key == null || key.isEmpty) {
      throw Exception('API key nao configurada.');
    }
    final model = _config.state.activeModels[AiProviderId.gemini] ??
        supportedModels.first;
    final params = _config.state.geminiParams;
    final payload = {
      'contents': _buildContents(session, userText),
      'generationConfig': {
        'temperature': params.temperature,
        'maxOutputTokens': params.maxOutputTokens,
      },
    };

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout ao chamar Gemini.');
    }

    if (response.statusCode == 401) {
      throw Exception('API key invalida.');
    }
    if (response.statusCode == 429) {
      throw Exception('Rate limit do Gemini.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro Gemini: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(decoded);
    final updated = _appendMessages(session, userText, text)
        .copyWith(modelId: model);
    return ChatReply(text: text, updatedSession: updated);
  }

  Future<bool> testConnection() async {
    final key = await _config.getGeminiKey();
    if (key == null || key.isEmpty) {
      return false;
    }
    final model = _config.state.activeModels[AiProviderId.gemini] ??
        supportedModels.first;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'ping'}
                  ],
                }
              ],
              'generationConfig': {'maxOutputTokens': 16},
            }),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _buildContents(
    ChatSession session,
    String userText,
  ) {
    final contents = <Map<String, dynamic>>[];
    for (final message in session.messages.take(8)) {
      contents.add({
        'role': message.role == ChatRole.user ? 'user' : 'model',
        'parts': [
          {'text': message.text}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userText}
      ],
    });
    return contents;
  }

  String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = candidates.first['content'];
      if (content is Map && content['parts'] is List) {
        return (content['parts'] as List)
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join();
      }
    }
    return '';
  }

  ChatSession _appendMessages(ChatSession session, String userText, String reply) {
    final user = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      text: userText,
      createdAt: DateTime.now(),
    );
    final assistant = ChatMessage(
      id: '${user.id}_assistant',
      role: ChatRole.assistant,
      text: reply,
      createdAt: DateTime.now(),
    );
    return session.copyWith(messages: [...session.messages, user, assistant]);
  }
}
