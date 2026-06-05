import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/decision.dart';
import '../services/api_service.dart';
import 'feedback_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await ApiService.getNotifications();
      setState(() {
        _notifications = n;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFeedback(Map<String, dynamic> notif) async {
    // 通知から意思決定を取得してフィードバック画面へ
    final decisions = await ApiService.getDecisions(limit: 100);
    final decisionId = notif['decision_id'] as String;
    final match = decisions.where((d) => d.id == decisionId).firstOrNull;

    await ApiService.markNotificationRead(notif['id'] as String);

    if (match != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FeedbackScreen(decision: match)),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('お知らせ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    SelectableText('お知らせはありません', style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _card(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> notif) {
    final message = notif['message'] as String? ?? '';
    final category = notif['category'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openFeedback(notif),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rate_review, color: AppTheme.accentOrange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category.isNotEmpty)
                        Text(category, style: TextStyle(fontSize: 11, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(message, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('タップしてフィードバック', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
