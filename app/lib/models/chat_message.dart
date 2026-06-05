class ChatMessage {
  final String id;
  final String userId;
  final String role; // 'user', 'assistant'
  final String content;
  final Map<String, dynamic>? decisionContext;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    this.decisionContext,
    this.metadata,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      decisionContext: json['decision_context'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'role': role,
        'content': content,
        'decision_context': decisionContext,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic>? get regretPrediction =>
      metadata?['regret_prediction'] as Map<String, dynamic>?;

  Map<String, dynamic>? get mapData =>
      metadata?['map'] as Map<String, dynamic>?;
}
