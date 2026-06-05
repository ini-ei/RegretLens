import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/theme.dart';

/// 店舗の周辺地図 + 店舗リスト
/// 地図はサーバーの /map プロキシ経由（APIキーはサーバー内に隠蔽）
class StoreMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final List<Map<String, dynamic>> places;

  const StoreMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    required this.places,
  });

  @override
  State<StoreMapWidget> createState() => _StoreMapWidgetState();
}

class _StoreMapWidgetState extends State<StoreMapWidget> {
  late final String _viewType;
  static int _counter = 0;

  @override
  void initState() {
    super.initState();
    _viewType = 'map-${_counter++}';
    if (kIsWeb) _registerView();
  }

  void _registerView() {
    final names = widget.places.map((p) => p['name'] as String).take(1).join();
    final query = Uri.encodeComponent(names.isNotEmpty ? names : '飲食店');
    // サーバーの地図プロキシを指す（キーはクライアントに出ない）
    final src = '${ApiConfig.baseUrl}/map'
        '?q=$query'
        '&center=${widget.centerLat},${widget.centerLng}'
        '&zoom=15';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = src;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.setAttribute('loading', 'lazy');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 48, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kIsWeb)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          const SizedBox(height: 8),
          ...widget.places.take(5).map((p) => _buildPlaceCard(p)),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> p) {
    final name = p['name'] as String? ?? '';
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final mapUrl = p['map_url'] as String?;
    final description = p['description'] as String? ?? '';
    final price = p['price'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: mapUrl != null
              ? () => launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppTheme.accentOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rating > 0) ...[
                      const Icon(Icons.star, size: 14, color: AppTheme.warningColor),
                      const SizedBox(width: 2),
                      Text('$rating', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    if (price.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(price, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 13, color: Colors.grey.shade400),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      description,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
