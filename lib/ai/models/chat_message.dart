enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.streaming = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool streaming;

  ChatMessage copyWith({String? text, bool? streaming}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      streaming: streaming ?? this.streaming,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      role: ChatRole.values.firstWhere(
        (role) => role.name == map['role'],
        orElse: () => ChatRole.user,
      ),
      text: map['text'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
