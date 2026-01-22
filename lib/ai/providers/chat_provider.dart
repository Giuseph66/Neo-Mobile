import '../models/chat_reply.dart';
import '../models/chat_session.dart';

abstract class IChatProvider {
  String get providerId;
  String get displayName;
  List<String> get supportedModels;

  Future<ChatReply> sendMessage(ChatSession session, String userText);

  Stream<String> streamMessage(ChatSession session, String userText) async* {
    final reply = await sendMessage(session, userText);
    yield reply.text;
  }
}
