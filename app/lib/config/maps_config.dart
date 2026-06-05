class MapsConfig {
  // Google Maps Embed API キー
  // ビルド時に --dart-define=MAPS_EMBED_KEY=xxx で渡す
  // ※コードに直書きしない（漏洩防止）。Embed API専用 + HTTPリファラ制限を必須にする
  static const String embedApiKey = String.fromEnvironment(
    'MAPS_EMBED_KEY',
    defaultValue: '',
  );
}
