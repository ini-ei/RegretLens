import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 端末UUIDベースの簡易認証。サーバー不要・クレカ不要。
class AuthService {
  static const _key = 'regretlens_user_id';
  static String? _cachedUserId;

  /// 端末固有のユーザーIDを取得（無ければ生成して保存）
  static Future<String> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cachedUserId = id;
    return id;
  }

  /// 同期的に取得（事前にgetUserIdが呼ばれている前提）
  static String? get currentUserId => _cachedUserId;

  /// データをリセット（新しいIDを発行）
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cachedUserId = null;
  }
}
