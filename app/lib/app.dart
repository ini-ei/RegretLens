import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/supabase_service.dart';

class RegretLensApp extends StatelessWidget {
  const RegretLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RegretLens',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isInitialized) {
      return const MainScreen();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const MainScreen();
    }

    return AuthScreen(
      onSignedIn: () => setState(() {}),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    ChatScreen(),
    DashboardScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.message_outlined),
              selectedIcon: Icon(Icons.message),
              label: 'トーク',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: '分析',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: '記録',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'マイページ',
            ),
          ],
        ),
      ),
    );
  }
}
