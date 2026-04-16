class SupabaseConfig {
  static const String supabaseUrl = 'https://zkzpaqqwsqulxhgyazyo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprenBhcXF3c3F1bHhoZ3lhenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNDEyMDYsImV4cCI6MjA5MTgxNzIwNn0.MSaXRk7PW2cJTdLnxoiR58GMY6Y1kE9kJGEvSzFrlRE';

  // Google OAuth
  // Supabase Dashboard → Authentication → Providers → Google で設定後に入れる
  // Google Cloud Console → APIs & Services → Credentials で取得
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
