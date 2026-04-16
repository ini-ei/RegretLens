import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const AuthScreen({super.key, required this.onSignedIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        widget.onSignedIn();
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        // OAuthリダイレクトなのでここでは戻らない
        return;
      }

      // ネイティブ (iOS/Android)
      final gsi = GoogleSignIn.instance;
      await gsi.initialize();
      final account = await gsi.authenticate();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }
      final auth = await account.authentication;
      if (auth.idToken == null) {
        setState(() => _isLoading = false);
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
      );
      widget.onSignedIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      widget.onSignedIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentOrange, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'RegretLens',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '迷ったら、まず話してみよう',
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Googleでサインイン'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                child: Text(
                  'ログインせずに使う',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
