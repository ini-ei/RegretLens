class MapsConfig {
  // Google Maps Embed API キー（リファラ制限推奨）
  // Places APIとは別キーを推奨だが、同じキーでも可
  static const String embedApiKey = String.fromEnvironment(
    'MAPS_EMBED_KEY',
    defaultValue: 'REMOVED_API_KEY',
  );
}
