import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:web/web.dart' as web;

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class PlacesService {
  static Future<LatLng?> getCurrentLocation() async {
    if (kIsWeb) return _getWebLocation();
    return null; // ネイティブは後で
  }

  static Future<LatLng?> _getWebLocation() async {
    final completer = Completer<LatLng?>();
    final geo = web.window.navigator.geolocation;

    geo.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        final c = pos.coords;
        debugPrint('位置情報取得: ${c.latitude}, ${c.longitude}');
        completer.complete(LatLng(c.latitude, c.longitude));
      }).toJS,
      ((web.GeolocationPositionError err) {
        debugPrint('位置情報エラー: ${err.code} ${err.message}');
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
}
