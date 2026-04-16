import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../onboarding/providers/wizard_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signIn, signUp }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const Color _neon = Color(0xFF00F0FF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _persistWizardMetrics() async {
    final wizard = ref.read(wizardProvider);
    if (wizard.gender == null && wizard.age == null) return;
    await ref.read(appPreferencesProvider).saveUserMetrics(wizard.toJson());
  }

  void _goToPaywall() {
    if (!mounted) return;
    context.pushReplacement(AppRoutes.paywall);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _busy = true);
    try {
      if (_mode == _Mode.signIn) {
        await _client.auth.signInWithPassword(email: email, password: password);
        await _persistWizardMetrics();
        _goToPaywall();
      } else {
        final res = await _client.auth.signUp(email: email, password: password);
        await _persistWizardMetrics();
        if (res.session == null && mounted) {
          _toast('E-posta adresine doğrulama bağlantısı gönderildi.');
        } else {
          _goToPaywall();
        }
      }
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Beklenmedik hata: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _client.auth.signInAnonymously();
      await _persistWizardMetrics();
      _goToPaywall();
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Misafir girişi başarısız: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isSignIn = _mode == _Mode.signIn;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  Text(
                    isSignIn ? 'Tekrar hoşgeldin.' : 'Hesap Oluştur',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSignIn
                        ? 'İlerlemeni bulutta güvende tut.'
                        : 'Hesap aç, ilerlemen senden ayrılmasın.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _emailField(),
                  const SizedBox(height: 12),
                  _passwordField(),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _neon,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(isSignIn ? 'GİRİŞ YAP' : 'KAYIT OL'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(
                              () => _mode =
                                  isSignIn ? _Mode.signUp : _Mode.signIn,
                            ),
                    child: Text(
                      isSignIn
                          ? 'Hesabın yok mu? Kayıt ol'
                          : 'Zaten hesabın var mı? Giriş yap',
                      style: const TextStyle(color: _neon),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _Divider(label: 'ya da'),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _continueAsGuest,
                    icon: const Icon(Icons.person_outline, color: _neon),
                    label: const Text(
                      'Misafir Olarak Devam Et',
                      style: TextStyle(color: _neon),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _neon, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: const [
        Text(
          'FormAI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _neon,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [Shadow(blurRadius: 24, color: _neon)],
          ),
        ),
        SizedBox(height: 6),
        Text(
          'AI DESTEKLİ FORM KOÇU',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      enabled: !_busy,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'E-posta',
        icon: Icons.alternate_email,
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'E-posta gerekli';
        if (!v.contains('@') || !v.contains('.')) return 'Geçersiz e-posta';
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      enabled: !_busy,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label: 'Şifre', icon: Icons.lock_outline),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Şifre gerekli';
        if (value.length < 6) return 'En az 6 karakter';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: _neon),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _neon, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ],
    );
  }
}
