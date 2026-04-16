import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class PlacesService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<LatLng?> getCurrentLocation() async {
    if (kIsWeb) {
      return _getWebLocation();
    }
    // ネイティブ版は後で実装
    return null;
  }

  static Future<LatLng?> _getWebLocation() async {
    final completer = Completer<LatLng?>();

    final geo = web.window.navigator.geolocation;

    geo.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        final coords = pos.coords;
        debugPrint('Web位置情報取得: ${coords.latitude}, ${coords.longitude}');
        completer.complete(LatLng(coords.latitude, coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError err) {
        debugPrint('Web位置情報エラー: ${err.code} ${err.message}');
        completer.complete(null);
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 60000,
      ),
    );

    return completer.future;
  }

  static Future<List<Map<String, dynamic>>> searchNearby({
    required double lat,
    required double lng,
    String? query,
    String? type,
  }) async {
    final res = await _client.functions.invoke('places', body: {
      'lat': lat,
      'lng': lng,
      'query': query,
      'type': type ?? 'restaurant',
    });

    if (res.status != 200) return [];

    final data = res.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['places'] ?? []);
  }
}
