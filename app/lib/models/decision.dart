class Decision {
  final String id;
  final String userId;
  final String category;
  final String decisionText;
  final List<String> alternatives;
  final Map<String, dynamic> context;
  final Map<String, dynamic> decisionFactors;
  final double? predictedRegretScore;
  final String? riskLevel;
  final List<String> warnings;
  final String? sourceUrl;
  final String? sourceType;
  final DateTime createdAt;
  final List<Feedback>? feedbacks;

  Decision({
    required this.id,
    required this.userId,
    required this.category,
    required this.decisionText,
    this.alternatives = const [],
    this.context = const {},
    this.decisionFactors = const {},
    this.predictedRegretScore,
    this.riskLevel,
    this.warnings = const [],
    this.sourceUrl,
    this.sourceType,
    required this.createdAt,
    this.feedbacks,
  });

  factory Decision.fromJson(Map<String, dynamic> json) {
    return Decision(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      category: json['category'] ?? '',
      decisionText: json['decision_text'] ?? '',
      alternatives: List<String>.from(json['alternatives'] ?? []),
      context: Map<String, dynamic>.from(json['context'] ?? {}),
      decisionFactors: Map<String, dynamic>.from(json['decision_factors'] ?? {}),
      predictedRegretScore: (json['predicted_regret_score'] as num?)?.toDouble(),
      riskLevel: json['risk_level'],
      warnings: List<String>.from(json['warnings'] ?? []),
      sourceUrl: json['source_url'],
      sourceType: json['source_type'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      feedbacks: json['feedbacks'] != null
          ? (json['feedbacks'] as List)
              .map((f) => Feedback.fromJson(f))
              .toList()
          : null,
    );
  }

  bool get hasFeedback => feedbacks != null && feedbacks!.isNotEmpty;
  bool get hasUrl => sourceUrl != null && sourceUrl!.isNotEmpty;

  String get riskEmoji {
    switch (riskLevel) {
      case '高':
        return '🔴';
      case '中':
        return '🟡';
      case '低':
        return '🟢';
      default:
        return '⚪';
    }
  }
}

class Feedback {
  final String id;
  final String decisionId;
  final int regretScore;
  final int satisfactionScore;
  final List<String> regretReasons;
  final bool wouldChange;
  final String? feedbackTiming;
  final String? feedbackText;
  final DateTime createdAt;

  Feedback({
    required this.id,
    required this.decisionId,
    required this.regretScore,
    required this.satisfactionScore,
    this.regretReasons = const [],
    this.wouldChange = false,
    this.feedbackTiming,
    this.feedbackText,
    required this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] ?? '',
      decisionId: json['decision_id'] ?? '',
      regretScore: json['regret_score'] ?? 3,
      satisfactionScore: json['satisfaction_score'] ?? 3,
      regretReasons: List<String>.from(json['regret_reasons'] ?? []),
      wouldChange: json['would_change'] ?? false,
      feedbackTiming: json['feedback_timing'],
      feedbackText: json['feedback_text'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
