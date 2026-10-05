import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (credential == null) return;
      await SyncService.instance.syncOnSignIn();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithoutAccount() async {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryEmerald, Color(0xFF064E3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + MediaQuery.of(context).padding.bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Icon(Icons.auto_stories_rounded, size: 64, color: AppColors.goldAccent),
                    const SizedBox(height: 12),
                    Text(l.appTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(l.authWelcomeBack, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 36),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    _Soc(
                      label: l.authSignInWithGoogle,
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: _loading ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Expanded(child: Divider(color: Colors.white30)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.authOrContinueWith, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                      const Expanded(child: Divider(color: Colors.white30)),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _loading ? null : _continueWithoutAccount,
                      child: Text(l.authSkipForNow, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 20),
                      const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Soc extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback? onPressed;
  const _Soc({required this.label, required this.icon, this.onPressed});
  @override Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    onPressed: onPressed, icon: Icon(icon, size: 22), label: Text(label, style: const TextStyle(fontSize: 15)));
}
