import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/decision.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class ApiService {
  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  // 意思決定一覧
  static Future<List<Decision>> getDecisions({int limit = 20, int offset = 0}) async {
    final uid = await AuthService.getUserId();
    final res = await http.get(_uri('/decisions', {
      'user_id': uid,
      'limit': '$limit',
      'offset': '$offset',
    }));
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['decisions'] as List).map((d) => Decision.fromJson(d)).toList();
  }

  // チャット履歴
  static Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    final uid = await AuthService.getUserId();
    final res = await http.get(_uri('/chat_history', {
      'user_id': uid,
      'limit': '$limit',
    }));
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  // 後悔パターン
  static Future<List<Map<String, dynamic>>> getRegretPatterns() async {
    final uid = await AuthService.getUserId();
    final res = await http.get(_uri('/patterns', {'user_id': uid}));
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['patterns'] ?? []);
  }

  // ダッシュボード統計
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final uid = await AuthService.getUserId();
    final res = await http.get(_uri('/stats', {'user_id': uid}));
    if (res.statusCode != 200) return {'total_decisions': 0, 'total_feedbacks': 0};
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // カテゴリ別統計
  static Future<Map<String, double>> getCategoryStats() async {
    final uid = await AuthService.getUserId();
    final res = await http.get(_uri('/stats', {'user_id': uid}));
    if (res.statusCode != 200) return {};
    final data = json.decode(res.body) as Map<String, dynamic>;
    final cats = data['category_stats'] as Map<String, dynamic>? ?? {};
    return cats.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  // フィードバック送信
  static Future<void> submitFeedback(Map<String, dynamic> body) async {
    final uid = await AuthService.getUserId();
    final res = await http.post(
      _uri('/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({...body, 'user_id': uid}),
    );
    if (res.statusCode != 200) {
      throw Exception('フィードバック送信失敗: ${res.statusCode}');
    }
  }
}
