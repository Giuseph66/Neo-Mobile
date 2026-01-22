import 'chat_session.dart';

class ChatReply {
  ChatReply({
    required this.text,
    required this.updatedSession,
  });

  final String text;
  final ChatSession updatedSession;
}
