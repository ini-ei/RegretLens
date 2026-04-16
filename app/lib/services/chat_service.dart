import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ChatService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<ChatResponse> sendMessage(
    String message,
    List<ChatMessage> conversationHistory, {
    double? lat,
    double? lng,
  }) async {
    final historyForApi = conversationHistory
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final body = <String, dynamic>{
      'message': message,
      'conversation_history': historyForApi,
      'user_id': _client.auth.currentUser?.id,
    };
    if (lat != null && lng != null) {
      body['lat'] = lat;
      body['lng'] = lng;
    }

    final res = await _client.functions.invoke('chat', body: body);

    Map<String, dynamic> data;
    if (res.data is Map<String, dynamic>) {
      data = res.data as Map<String, dynamic>;
    } else if (res.data is String) {
      data = json.decode(res.data as String) as Map<String, dynamic>;
    } else {
      throw Exception('予期しないレスポンス形式');
    }

    if (data.containsKey('error')) {
      throw Exception(data['error']);
    }

    return ChatResponse(
      message: data['message'] as String? ?? '',
      decision: data['decision'] as Map<String, dynamic>?,
      regretPrediction: data['regret_prediction'] as Map<String, dynamic>?,
      quickReplies: data['quick_replies'] != null
          ? List<String>.from(data['quick_replies'] as List)
          : [],
    );
  }
}

class ChatResponse {
  final String message;
  final Map<String, dynamic>? decision;
  final Map<String, dynamic>? regretPrediction;
  final List<String> quickReplies;

  ChatResponse({
    required this.message,
    this.decision,
    this.regretPrediction,
    this.quickReplies = const [],
  });

  bool get hasDecision => decision != null;
  bool get hasPrediction => regretPrediction != null;
  double? get regretScore => (regretPrediction?['regret_score'] as num?)?.toDouble();
  String? get riskLevel => regretPrediction?['risk_level'] as String?;
  List<String> get warnings => List<String>.from(regretPrediction?['warnings'] ?? []);
}
