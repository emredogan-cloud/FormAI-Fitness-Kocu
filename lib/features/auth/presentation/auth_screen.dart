import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/connectivity_service.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { signIn, signUp }

enum _SocialProvider { google, apple }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const Color _neon = Color(0xFF00F0FF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  // Tracks which OAuth flow (if any) is currently in flight so we can show a
  // spinner on the right button and block re-entrancy on the other.
  _SocialProvider? _social;

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

  /// Phase 140 · post-auth navigation hand-off.
  ///
  /// Existing-Pro users (CASE B: same account, new device) should
  /// land on the dashboard with Pro features unlocked, NOT on the
  /// paywall — re-presenting the paywall to someone who's already
  /// paying reads as broken. Free users land on the paywall, but
  /// the [authGateClearedProvider] latch is already flipped by every
  /// auth-success path so the gate doesn't re-fire.
  ///
  /// `subscriptionProvider.refresh()` is awaited so RevenueCat's
  /// fresh customerInfo is loaded before we read `isPro`. RC's
  /// `Purchases.logIn` was just called (inside
  /// `aliasRevenueCatWithCurrentUser`) so this refresh hits the
  /// network for the real Supabase-aliased entitlement set, not the
  /// pre-login anonymous cache.
  Future<void> _routePostAuth() async {
    if (!mounted) return;
    try {
      await ref.read(subscriptionProvider.notifier).refresh();
    } catch (_) {
      // Falls back to free routing — the paywall will re-attempt
      // refresh on mount and the user can still see / use Restore.
    }
    if (!mounted) return;
    final isPro = ref.read(isProProvider);
    if (isPro) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.paywall);
    }
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
        // Mirror the social path's RC alias step. Without this, an email
        // login lands the user on the paywall with the RC SDK still
        // pointing at the anonymous app-user-ID — a subsequent purchase
        // would be lost on the next sign-in.
        await ref.read(authControllerProvider).aliasRevenueCatWithCurrentUser();
        // Phase 140 · latch the paywall gate cleared so its remount
        // after pushReplacement / context.go doesn't re-fire.
        ref.read(authGateClearedProvider.notifier).markCleared();
        await _routePostAuth();
      } else {
        // If the user came in as a guest (signInAnonymously from the
        // onboarding flow), upgrade that same identity via updateUser
        // instead of creating a new account. This preserves user_id, so
        // any user_progress rows + queued offline syncs stay attributed
        // to the same person after they register.
        final currentUser = _client.auth.currentUser;
        final isAnon = currentUser?.isAnonymous ?? false;
        if (isAnon) {
          await _client.auth.updateUser(
            UserAttributes(email: email, password: password),
          );
          await _persistWizardMetrics();
          await ref
              .read(authControllerProvider)
              .aliasRevenueCatWithCurrentUser();
          ref.read(authGateClearedProvider.notifier).markCleared();
          if (mounted) {
            _toast(
              'E-posta adresine doğrulama bağlantısı gönderildi. '
              'Hesabın yükseltildi, ilerlemen korundu.',
            );
          }
          await _routePostAuth();
        } else {
          final res =
              await _client.auth.signUp(email: email, password: password);
          await _persistWizardMetrics();
          if (res.session == null && mounted) {
            _toast('E-posta adresine doğrulama bağlantısı gönderildi.');
          } else {
            await ref
                .read(authControllerProvider)
                .aliasRevenueCatWithCurrentUser();
            ref.read(authGateClearedProvider.notifier).markCleared();
            await _routePostAuth();
          }
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
      // Guests must still see the paywall's auth gate — they have not
      // authenticated; the latch stays false on purpose so the gate
      // can fire when they next reach /paywall.
      if (mounted) context.pushReplacement(AppRoutes.paywall);
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Misafir girişi başarısız: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() => _runSocial(
        _SocialProvider.google,
        () => ref.read(authControllerProvider).signInWithGoogle(),
        errorMessage: 'Google ile giriş başarısız oldu. Lütfen tekrar dene.',
        offlineMessage:
            'Google ile giriş yapmak için internet bağlantısı gereklidir.',
      );

  Future<void> _signInWithApple() => _runSocial(
        _SocialProvider.apple,
        () => ref.read(authControllerProvider).signInWithApple(),
        errorMessage: 'Apple ile giriş başarısız oldu. Lütfen tekrar dene.',
        offlineMessage:
            'Apple ile giriş yapmak için internet bağlantısı gereklidir.',
      );

  Future<void> _runSocial(
    _SocialProvider provider,
    Future<SocialAuthResult> Function() run, {
    required String errorMessage,
    required String offlineMessage,
  }) async {
    if (_busy || _social != null) return;
    // Phase 89 · OAuth flows make multiple network round-trips (id-token
    // exchange + Supabase signInWithIdToken). Without a connection the
    // native sheet may still appear but the final exchange hangs for
    // the HTTP timeout (~30 s) before the error toast lands. Pre-check
    // so the user sees a clear "İnternet gerekli" message instantly.
    final online = await ref.read(connectivityServiceProvider).isOnline();
    if (!online) {
      if (!mounted) return;
      _toast(offlineMessage);
      return;
    }
    setState(() => _social = provider);
    try {
      final result = await run();
      if (!mounted) return;
      switch (result.outcome) {
        case SocialAuthOutcome.success:
          await _persistWizardMetrics();
          // The AuthController already flipped authGateClearedProvider
          // on success — just route to the right destination.
          await _routePostAuth();
        case SocialAuthOutcome.cancelled:
          // Silent — user bailed out of the native sheet.
          break;
        case SocialAuthOutcome.error:
          // Phase 88 · prefer the controller's specific message (e.g. an
          // AuthException from Supabase rejecting the id token) so the
          // user sees the actual cause rather than the generic "tekrar
          // dene" copy. The fallback handles the legacy enum-only paths.
          _toast(result.errorMessage ?? errorMessage);
      }
    } finally {
      if (mounted) setState(() => _social = null);
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
                    onPressed: (_busy || _social != null) ? null : _submit,
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
                    onPressed:
                        (_busy || _social != null) ? null : _continueAsGuest,
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
                  const SizedBox(height: 24),
                  const _Divider(label: 'Veya şununla giriş yap'),
                  const SizedBox(height: 18),
                  _GoogleButton(
                    busy: _social == _SocialProvider.google,
                    enabled: !_busy && _social == null,
                    onPressed: _signInWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  _AppleButton(
                    busy: _social == _SocialProvider.apple,
                    enabled: !_busy && _social == null,
                    onPressed: _signInWithApple,
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

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled && !busy ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
      ),
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black54,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _GoogleLogo(size: 18),
                SizedBox(width: 10),
                Text('Google ile Devam Et'),
              ],
            ),
    );
  }
}

/// Official Google "G" rendered with the brand's four colours. Kept inline
/// (no asset / SVG dep) so the button stays self-contained.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    // Four arcs, one per Google colour, in the conventional order.
    canvas.drawArc(
        rect.deflate(stroke / 2), -0.5, 1.8, false, paint..color = _blue);
    canvas.drawArc(
        rect.deflate(stroke / 2), 1.3, 1.4, false, paint..color = _green);
    canvas.drawArc(
        rect.deflate(stroke / 2), 2.7, 1.4, false, paint..color = _yellow);
    canvas.drawArc(
        rect.deflate(stroke / 2), 4.1, 1.7, false, paint..color = _red);
    // Inner horizontal bar of the "G".
    final barPaint = Paint()..color = _blue;
    final barRect = Rect.fromLTWH(
      size.width * 0.5,
      size.height * 0.42,
      size.width * 0.5 - stroke * 0.5,
      size.height * 0.16,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled && !busy ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white10,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Colors.white24, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
      ),
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.apple, size: 22, color: Colors.white),
                SizedBox(width: 8),
                Text('Apple ile Devam Et'),
              ],
            ),
    );
  }
}
