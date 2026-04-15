import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ChatService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// チャットメッセージを送信し、AI応答を取得
  static Future<ChatResponse> sendMessage(
    String message,
    List<ChatMessage> conversationHistory,
  ) async {
    final historyForApi = conversationHistory
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final res = await _client.functions.invoke(
      'chat',
      body: {
        'message': message,
        'conversation_history': historyForApi,
      },
    );

    if (res.status != 200) {
      throw Exception('チャットエラー: ${res.status}');
    }

    final data = res.data as Map<String, dynamic>;

    return ChatResponse(
      message: data['message'] as String? ?? '',
      decision: data['decision'] as Map<String, dynamic>?,
      regretPrediction: data['regret_prediction'] as Map<String, dynamic>?,
    );
  }
}

class ChatResponse {
  final String message;
  final Map<String, dynamic>? decision;
  final Map<String, dynamic>? regretPrediction;

  ChatResponse({
    required this.message,
    this.decision,
    this.regretPrediction,
  });

  bool get hasDecision => decision != null && (decision!['decision_detected'] == true);
  bool get hasPrediction => regretPrediction != null;

  double? get regretScore => (regretPrediction?['regret_score'] as num?)?.toDouble();
  String? get riskLevel => regretPrediction?['risk_level'] as String?;
  List<String> get warnings =>
      List<String>.from(regretPrediction?['warnings'] ?? []);
}
