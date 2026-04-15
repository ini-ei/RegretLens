import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final prediction = message.regretPrediction;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 60 : 8,
          right: isUser ? 8 : 60,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildContent(context, isUser),
            ),
            if (prediction != null) _buildPredictionBadge(prediction),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    final text = message.content;

    // URLを検出してリンク化
    final urlRegex = RegExp(
      r'https?://[^\s\)]+',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }

    // URLを含むテキストをリッチテキストで表示
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
        ));
      }
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Text(
            url.length > 40 ? '${url.substring(0, 40)}...' : url,
            style: TextStyle(
              color: isUser ? Colors.white70 : AppTheme.primaryColor,
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildPredictionBadge(Map<String, dynamic> prediction) {
    final score = (prediction['regret_score'] as num?)?.toDouble() ?? 0;
    final riskLevel = prediction['risk_level'] as String? ?? '低';
    final warnings = List<String>.from(prediction['warnings'] ?? []);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.riskColor(riskLevel).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.riskColor(riskLevel).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                riskLevel == '高'
                    ? Icons.warning_amber
                    : riskLevel == '中'
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                size: 16,
                color: AppTheme.riskColor(riskLevel),
              ),
              const SizedBox(width: 4),
              Text(
                '後悔リスク: ${(score * 100).toInt()}% ($riskLevel)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.riskColor(riskLevel),
                ),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...warnings.take(2).map((w) => Text(
                  w,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
