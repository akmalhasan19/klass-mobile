enum ChatMessageRole { user, system }

class ChatMessage {
  final String id;
  final String content;
  final ChatMessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == ChatMessageRole.user;
  bool get isSystem => role == ChatMessageRole.system;

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: ChatMessageRole.user,
    );
  }

  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: ChatMessageRole.system,
    );
  }
}
