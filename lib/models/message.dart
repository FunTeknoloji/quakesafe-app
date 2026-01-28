enum MessagePriority {
  SOS,
  Voice,
  Location,
  Chat,
  System,
}

class Message {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String content;
  final MessagePriority priority;
  final DateTime timestamp;
  int ttl;

  Message({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.priority = MessagePriority.Chat,
    required this.timestamp,
    this.ttl = 2,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['messageId'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      content: json['content'],
      priority: MessagePriority.values[json['priority']],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      ttl: json['ttl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'priority': priority.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ttl': ttl,
    };
  }
}
