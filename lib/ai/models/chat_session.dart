import 'chat_message.dart';

class ChatSession {
  ChatSession({
    required this.id,
    required this.providerId,
    required this.modelId,
    required this.messages,
    this.previousResponseId,
  });

  final String id;
  final String providerId;
  final String modelId;
  final List<ChatMessage> messages;
  final String? previousResponseId;

  ChatSession copyWith({
    String? providerId,
    String? modelId,
    List<ChatMessage>? messages,
    String? previousResponseId,
  }) {
    return ChatSession(
      id: id,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      messages: messages ?? this.messages,
      previousResponseId: previousResponseId ?? this.previousResponseId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'providerId': providerId,
      'modelId': modelId,
      'previousResponseId': previousResponseId,
      'messages': messages.map((message) => message.toMap()).toList(),
    };
  }

  static ChatSession fromMap(Map<String, dynamic> map) {
    final rawMessages = map['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: map['id'] as String,
      providerId: map['providerId'] as String? ?? 'local',
      modelId: map['modelId'] as String? ?? '',
      previousResponseId: map['previousResponseId'] as String?,
      messages: rawMessages
          .whereType<Map>()
          .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
