import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/ai_config_store.dart';
import '../models/chat_message.dart';
import '../models/chat_reply.dart';
import '../models/chat_session.dart';
import 'chat_provider.dart';

class OpenAiProvider extends IChatProvider {
  OpenAiProvider(this._config);

  final AiConfigStore _config;

  static const _endpoint = 'https://api.openai.com/v1/responses';
  static const _timeout = Duration(seconds: 30);

  @override
  String get providerId => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  List<String> get supportedModels => const [
        'gpt-5.2',
        'gpt-5.2-pro',
        'gpt-5.1',
        'gpt-5',
        'gpt-5-mini',
        'gpt-5-nano',
        'gpt-4.1',
        'gpt-4.1-mini',
        'gpt-4.1-nano',
        'o3',
        'o4-mini',
        'o1',
        'o1-pro',
      ];

  @override
  Future<ChatReply> sendMessage(ChatSession session, String userText) async {
    final key = await _config.getOpenAiKey();
    if (key == null || key.isEmpty) {
      throw Exception('API key nao configurada.');
    }
    final model = _config.state.activeModels[AiProviderId.openai] ??
        supportedModels.first;
    final params = _config.state.openAiParams;
    final input = _buildPrompt(session, userText);
    final payload = <String, dynamic>{
      'model': model,
      'input': input,
      'temperature': params.temperature,
      'max_output_tokens': params.maxOutputTokens,
    };
    if (session.previousResponseId != null) {
      payload['previous_response_id'] = session.previousResponseId;
    }
    if (params.reasoningEffort != null &&
        params.reasoningEffort!.isNotEmpty) {
      payload['reasoning'] = {'effort': params.reasoningEffort};
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout ao chamar OpenAI.');
    }

    if (response.statusCode == 401) {
      throw Exception('API key invalida.');
    }
    if (response.statusCode == 429) {
      throw Exception('Rate limit da OpenAI.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro OpenAI: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final outputText = _extractOutputText(decoded);
    final responseId = decoded['id'] as String?;

    final updated = _appendMessages(session, userText, outputText)
        .copyWith(modelId: model, previousResponseId: responseId);
    return ChatReply(text: outputText, updatedSession: updated);
  }

  Future<bool> testConnection() async {
    final key = await _config.getOpenAiKey();
    if (key == null || key.isEmpty) {
      return false;
    }
    final model = _config.state.activeModels[AiProviderId.openai] ??
        supportedModels.first;
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'input': 'ping',
              'max_output_tokens': 16,
            }),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  String _buildPrompt(ChatSession session, String userText) {
    final buffer = StringBuffer();
    final history = session.messages.take(8).toList();
    for (final msg in history) {
      if (msg.role == ChatRole.user) {
        buffer.writeln('User: ${msg.text}');
      } else {
        buffer.writeln('Assistant: ${msg.text}');
      }
    }
    buffer.writeln('User: $userText');
    buffer.write('Assistant:');
    return buffer.toString();
  }

  String _extractOutputText(Map<String, dynamic> json) {
    final outputText = json['output_text'];
    if (outputText is String && outputText.isNotEmpty) {
      return outputText;
    }
    final output = json['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map && item['content'] is List) {
          final parts = item['content'] as List;
          final text = parts
              .whereType<Map>()
              .map((part) => part['text'])
              .whereType<String>()
              .join();
          if (text.isNotEmpty) {
            return text;
          }
        }
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
