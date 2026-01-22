import 'dart:async';

import '../../llm/llm_prefs.dart';
import '../../llm/local_llm_service.dart';
import '../models/chat_message.dart';
import '../models/chat_reply.dart';
import '../models/chat_session.dart';
import 'chat_provider.dart';

class LocalProvider extends IChatProvider {
  LocalProvider(this._service, this._prefs);

  final LocalLlmService _service;
  final LlmPrefsController _prefs;

  @override
  String get providerId => 'local';

  @override
  String get displayName => 'Local LLM';

  @override
  List<String> get supportedModels => const [];

  @override
  Future<ChatReply> sendMessage(ChatSession session, String userText) async {
    final buffer = StringBuffer();
    await for (final chunk in streamMessage(session, userText)) {
      buffer.write(chunk);
    }
    final updated = _appendMessages(session, userText, buffer.toString());
    return ChatReply(text: buffer.toString(), updatedSession: updated);
  }

  @override
  Stream<String> streamMessage(ChatSession session, String userText) {
    final controller = StreamController<String>();
    late final StreamSubscription sub;
    String? requestId;
    _service
        .generate(userText, _prefs.state.toGenerationParams())
        .then((id) {
      requestId = id;
      if (requestId == null) {
        controller.addError('Falha ao iniciar geracao.');
        controller.close();
        return;
      }
      sub = _service.events.listen((event) {
        final type = event['type'];
        final req = event['requestId']?.toString();
        if (req != requestId) {
          return;
        }
        if (type == 'token') {
          final chunk = event['textChunk']?.toString() ?? '';
          controller.add(chunk);
        } else if (type == 'done') {
          controller.close();
        } else if (type == 'error') {
          controller.addError(event['message']?.toString() ?? 'Erro');
          controller.close();
        }
      });
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });
    controller.onCancel = () async {
      if (requestId != null) {
        await _service.stopGeneration(requestId!);
      }
      await sub.cancel();
    };
    return controller.stream;
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
