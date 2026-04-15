class SupabaseConfig {
  // Supabase プロジェクトのURLとAnon Keyを設定
  // TODO: 実際のSupabaseプロジェクト作成後に値を入れる
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );
}
