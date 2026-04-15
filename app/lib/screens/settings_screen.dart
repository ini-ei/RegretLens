import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              child: Icon(isAnonymous ? Icons.person_outline : Icons.person),
            ),
            title: Text(isAnonymous ? '匿名ユーザー' : (user?.email ?? '')),
            subtitle: Text(isAnonymous ? 'メール登録でデータを保護' : 'ログイン済み'),
          ),
          const Divider(),
          if (isAnonymous)
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('メールアドレスで登録'),
              subtitle: const Text('データをバックアップ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 登録画面に遷移
              },
            ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知設定'),
            subtitle: const Text('フォローアップ通知のタイミング'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 通知設定画面
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('RegretLensについて'),
            subtitle: const Text('後悔予測AIアプリ v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'RegretLens',
                applicationVersion: '1.0.0',
                children: [
                  const Text('後悔しない選択をAIがサポートするアプリです。'),
                ],
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('サインアウト', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await SupabaseService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
