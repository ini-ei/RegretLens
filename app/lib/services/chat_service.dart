import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class ChatService {
  static Future<ChatResponse> sendMessage(
    String message,
    List<ChatMessage> conversationHistory, {
    double? lat,
    double? lng,
  }) async {
    final uid = await AuthService.getUserId();
    final historyForApi = conversationHistory
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final body = <String, dynamic>{
      'message': message,
      'conversation_history': historyForApi,
      'user_id': uid,
    };
    if (lat != null && lng != null) {
      body['lat'] = lat;
      body['lng'] = lng;
    }

    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('チャットエラー: ${res.statusCode}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
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
