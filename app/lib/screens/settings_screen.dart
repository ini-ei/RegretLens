import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

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
                child: Icon(isAnonymous ? Icons.person_outline : Icons.person, color: AppTheme.accentOrange),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(isAnonymous ? 'ゲストユーザー' : (user?.email ?? ''), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                SelectableText(isAnonymous ? 'ログインでデータを保護' : 'ログイン済み', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          _tile(context, Icons.notifications_outlined, '通知設定', 'フォローアップのタイミング', () {}),
          _tile(context, Icons.info_outline, 'RegretLensについて', 'v1.0.0', () {
            showAboutDialog(context: context, applicationName: 'RegretLens', applicationVersion: '1.0.0');
          }),
          const SizedBox(height: 12),
          _tile(context, Icons.logout, 'サインアウト', null, () async {
            await SupabaseService.signOut();
            if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
