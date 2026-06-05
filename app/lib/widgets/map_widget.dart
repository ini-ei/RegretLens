import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'package:url_launcher/url_launcher.dart';
import '../config/maps_config.dart';
import '../config/theme.dart';

/// 店舗の周辺地図を表示するウィジェット（Web: Embed API iframe）
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
    if (kIsWeb && MapsConfig.embedApiKey.isNotEmpty) _registerView();
  }

  void _registerView() {
    // 検索クエリ: 中心座標周辺の店舗
    // Embed APIのsearchモードで周辺の該当店を地図表示
    final names = widget.places.map((p) => p['name'] as String).take(1).join();
    final query = Uri.encodeComponent(names.isNotEmpty ? names : '飲食店');
    final src =
        'https://www.google.com/maps/embed/v1/search'
        '?key=${MapsConfig.embedApiKey}'
        '&q=$query'
        '&center=${widget.centerLat},${widget.centerLng}'
        '&zoom=15';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = src;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
      return iframe;
    });
  }

  bool get _hasKey => MapsConfig.embedApiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 48, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // キーがある時だけ地図iframeを表示（無ければ店舗リストのみ）
          if (kIsWeb && _hasKey)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          if (kIsWeb && _hasKey) const SizedBox(height: 6),
          ...widget.places.take(5).map((p) => _buildPlaceRow(p)),
        ],
      ),
    );
  }

  Widget _buildPlaceRow(Map<String, dynamic> p) {
    final name = p['name'] as String? ?? '';
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final mapUrl = p['map_url'] as String?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: mapUrl != null
            ? () => launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.place, size: 16, color: AppTheme.accentOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rating > 0) ...[
                const Icon(Icons.star, size: 13, color: AppTheme.warningColor),
                const SizedBox(width: 2),
                Text('$rating', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
              const SizedBox(width: 4),
              Icon(Icons.open_in_new, size: 13, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
