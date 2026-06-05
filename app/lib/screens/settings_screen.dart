import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId ?? '';
    final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                child: const Icon(Icons.person_outline, color: AppTheme.accentOrange),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SelectableText('あなた', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                SelectableText('ID: $shortId', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          _tile(context, Icons.notifications_outlined, '通知設定', 'フォローアップのタイミング', () {}),
          _tile(context, Icons.info_outline, 'RegretLensについて', 'v1.0.0', () {
            showAboutDialog(context: context, applicationName: 'RegretLens', applicationVersion: '1.0.0');
          }),
          const SizedBox(height: 12),
          _tile(context, Icons.delete_outline, 'データをリセット', '記録を全て消して新しいIDを発行', () async {
            await AuthService.reset();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('リセットしました。アプリを再起動してください')),
              );
            }
          }, danger: true),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String? subtitle, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? AppTheme.dangerColor : AppTheme.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(),
      child: ListTile(
        leading: Icon(icon, color: danger ? AppTheme.dangerColor : AppTheme.accentOrange),
        title: SelectableText(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? SelectableText(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)) : null,
        trailing: danger ? null : Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}
