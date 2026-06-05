class ApiConfig {
  // Deno DeployのエンドポイントURL
  // デプロイ後に実際のURLに差し替える
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
