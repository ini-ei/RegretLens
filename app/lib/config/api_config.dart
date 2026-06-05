class ApiConfig {
  // Deno DeployのエンドポイントURL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://regretlens.ini-ei.deno.net',
  );
}
