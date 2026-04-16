import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          margin: EdgeInsets.only(
            top: 3,
            bottom: 3,
            left: isUser ? 48 : 8,
            right: isUser ? 8 : 48,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.accentOrange : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
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
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    final text = message.content;

    if (isUser) {
      return SelectableText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      );
    }

    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) _launchUrl(href);
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        strong: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        em: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
        listBullet: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
        ),
        code: TextStyle(
          color: AppTheme.accentOrange,
          fontSize: 13,
          backgroundColor: Colors.grey.shade100,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        a: const TextStyle(
          color: AppTheme.accentBlue,
          decoration: TextDecoration.underline,
        ),
        h1: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h3: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.accentOrange, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionBadge(Map<String, dynamic> prediction) {
    final score = (prediction['regret_score'] as num?)?.toDouble() ?? 0;
    final riskLevel = prediction['risk_level'] as String? ?? '低';
    final warnings = List<String>.from(prediction['warnings'] ?? []);
    final color = AppTheme.riskColor(riskLevel);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              SelectableText(
                '後悔リスク ${(score * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 2),
            ...warnings.take(2).map((w) => SelectableText(
                  w,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                )),
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コピーしました'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
