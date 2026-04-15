import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/decision.dart';
import '../models/chat_message.dart';

class SupabaseService {
  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => isInitialized ? client.auth.currentUser : null;

  // 匿名サインイン
  static Future<void> signInAnonymously() async {
    if (currentUser != null) return;
    await client.auth.signInAnonymously();
  }

  // メールサインイン
  static Future<void> signInWithEmail(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  // サインアップ
  static Future<void> signUp(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  // サインアウト
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // 意思決定一覧取得
  static Future<List<Decision>> getDecisions({int limit = 20, int offset = 0}) async {
    final res = await client
        .from('decisions')
        .select('*, feedbacks(*)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List).map((d) => Decision.fromJson(d)).toList();
  }

  // 意思決定を1件取得
  static Future<Decision> getDecision(String id) async {
    final res = await client
        .from('decisions')
        .select('*, feedbacks(*)')
        .eq('id', id)
        .single();

    return Decision.fromJson(res);
  }

  // チャット履歴取得
  static Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    final res = await client
        .from('chat_messages')
        .select()
        .order('created_at', ascending: true)
        .limit(limit);

    return (res as List).map((m) => ChatMessage.fromJson(m)).toList();
  }

  // 後悔パターン取得
  static Future<List<Map<String, dynamic>>> getRegretPatterns() async {
    final res = await client
        .from('regret_patterns')
        .select()
        .order('occurrence_count', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  // カテゴリ別統計
  static Future<Map<String, double>> getCategoryStats() async {
    final res = await client
        .from('decisions')
        .select('category, feedbacks(regret_score)')
        .not('feedbacks', 'is', null);

    final stats = <String, List<int>>{};
    for (final d in res) {
      final category = d['category'] as String;
      final feedbacks = d['feedbacks'] as List;
      for (final f in feedbacks) {
        stats.putIfAbsent(category, () => []);
        stats[category]!.add(f['regret_score'] as int);
      }
    }

    return stats.map((k, v) =>
        MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  // 統計データ取得
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final decisions = await client
        .from('decisions')
        .select('id')
        .count(CountOption.exact);

    final feedbacks = await client
        .from('feedbacks')
        .select('id')
        .count(CountOption.exact);

    return {
      'total_decisions': decisions.count,
      'total_feedbacks': feedbacks.count,
    };
  }

  // 保留中の通知取得
  static Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    final now = DateTime.now().toIso8601String();
    final res = await client
        .from('scheduled_notifications')
        .select('*, decisions(decision_text, category)')
        .eq('is_sent', false)
        .lte('notify_at', now)
        .order('notify_at');

    return List<Map<String, dynamic>>.from(res);
  }

  // 通知を送信済みにマーク
  static Future<void> markNotificationSent(String notificationId) async {
    await client
        .from('scheduled_notifications')
        .update({'is_sent': true})
        .eq('id', notificationId);
  }
}
