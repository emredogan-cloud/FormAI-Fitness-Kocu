import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/connectivity_service.dart';
import '../providers/auth_provider.dart';

/// Phase 94 · forced-auth gate that prevents anonymous purchases on
/// the paywall.
///
/// **Why this exists:** an anonymous user buying via RevenueCat creates
/// purchases bound to a throwaway RC app-user-ID. When that user later
/// signs in with Google/Apple, RC sees a *different* app-user-ID and
/// the purchase isn't carried over (the RC aliasing window only applies
/// when `Purchases.logIn` is called BEFORE the purchase, while the
/// anonymous ID is still active). The simplest way to avoid the entire
/// class of bug is to force sign-in BEFORE the purchase action — so the
/// Supabase UUID is already aliased onto the RC SDK by the time the
/// user taps a plan card.
///
/// **Why not `showModalBottomSheet`:** the spec asks for a
/// `BackdropFilter` on the area BEHIND the sheet (the visible top half
/// of the paywall). `showModalBottomSheet`'s `barrierColor` is a flat
/// `Color` only — there's no public hook to substitute a
/// `BackdropFilter`. We use a custom `PageRouteBuilder` with
/// `barrierColor: Colors.transparent` and render the blur ourselves
/// inside the route's `pageBuilder`, while preserving the spec'd
/// behavioural contract:
///
///   • non-dismissible (system back, tap-outside, swipe-down all
///     no-op) — enforced by `PopScope(canPop: false)` and
///     `barrierDismissible: false`.
///   • bottom 50% only — the modal is `Align`ed to bottomCenter
///     inside a `SizedBox(height: screenHeight * 0.5)`.
///   • slide-up entry — wired via the route's animation.
///
/// **Behavioural contract:** the future returned by [showAuthGate]
/// resolves only when the gate is dismissed, which can happen in
/// exactly three ways:
///
///   1. Successful Google or Apple sign-in (the controller has
///      already aliased RC to the new Supabase UUID via
///      `_aliasRevenueCatToSupabaseUser`); modal `pop`s itself; the
///      user is back on the paywall, now authenticated, ready to
///      purchase.
///   2. The "Go to email login" link — pops the modal AND routes to
///      `/auth`. Email sign-in there will `pushReplacement` back to
///      the paywall on success, by which point RC is also aliased
///      (via the same controller path on email-sign-in submit, see
///      AuthScreen._submit).
///   3. (Defensive only — not part of the supported flow) the route
///      is removed by another navigator action. Callers that rely on
///      the gate being mandatory must not pop it from outside.
Future<void> showAuthGate(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Auth gate',
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: _AuthGateScaffold(animation: animation),
        );
      },
      // Slide / fade are driven inside the scaffold so the blur layer
      // and the sheet body can ride independent curves.
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ),
  );
}

/// Lays out the blurred top half + the bottom-50% sheet. Owns the
/// route's master animation; the inner [AuthModalBottomSheet] owns
/// the looping neon-glow animation independently.
class _AuthGateScaffold extends StatelessWidget {
  const _AuthGateScaffold({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // 0.56 (was 0.5) so the "Şimdilik değil" dashboard-escape link clears
    // the system nav bar; the blurred paywall behind still reads clearly.
    final modalHeight = screenHeight * 0.56;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // BLUR + DIM · top half of screen
          //
          // BackdropFilter is sigma-animated so the blur eases in with
          // the modal slide rather than snapping to full strength.
          // The `ColoredBox` adds a subtle scrim so the paywall plan
          // cards still read as a backdrop, not as foreground content
          // competing with the modal copy.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: modalHeight,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value.clamp(0.0, 1.0);
                return BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 14 * t,
                    sigmaY: 14 * t,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45 * t),
                  ),
                );
              },
            ),
          ),
          // MODAL · bottom 50%, slides up from below
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
              child: SizedBox(
                height: modalHeight,
                child: const AuthModalBottomSheet(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet body. Public on purpose so it can be reused (preview
/// route, integration test harness) without going through
/// [showAuthGate].
class AuthModalBottomSheet extends ConsumerStatefulWidget {
  const AuthModalBottomSheet({super.key});

  @override
  ConsumerState<AuthModalBottomSheet> createState() =>
      _AuthModalBottomSheetState();
}

enum _Provider { google, apple }

class _AuthModalBottomSheetState extends ConsumerState<AuthModalBottomSheet>
    with SingleTickerProviderStateMixin {
  static const Color _neonCyan = Color(0xFF00F0FF);

  /// Drives the looping neon-glow drift in [_AnimatedNeonBackground].
  /// Long period (5 s) keeps the motion subtle — it's mood, not
  /// attention-grabbing.
  late final AnimationController _glow;

  /// Which OAuth flow is currently in flight, or null. Used to disable
  /// the other button + the email-login link while a sign-in is
  /// running, mirroring the same re-entrancy guard the standalone
  /// /auth screen uses.
  _Provider? _busy;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          _AnimatedNeonBackground(controller: _glow),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHandle(),
                  const SizedBox(height: 18),
                  _buildLogoBadge(),
                  const SizedBox(height: 14),
                  _buildTitle(),
                  const SizedBox(height: 8),
                  _buildSubtitle(),
                  const Spacer(),
                  _buildGoogleButton(),
                  // Apple Sign-In is iOS-only (see auth_screen.dart) —
                  // on Android the native flow throws into an error
                  // toast, so the button never renders there.
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    _buildAppleButton(),
                  ],
                  const SizedBox(height: 14),
                  _buildEmailLoginLink(),
                  _buildDismissLink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  /// Decorative grab-handle. Non-functional (the sheet is
  /// non-dismissible) — kept purely so the surface reads as a
  /// bottom sheet to the user's eye.
  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _neonCyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _neonCyan.withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: const Text(
          'FormAI',
          style: TextStyle(
            color: _neonCyan,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 14, color: _neonCyan)],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Planını kaydetmek için ücretsiz hesabını oluştur.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w900,
        height: 1.25,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Hesap olmadan satın alımın yeni cihazda kaybolabilir.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.66),
        fontSize: 13,
        height: 1.4,
      ),
    );
  }

  Widget _buildGoogleButton() {
    final isBusy = _busy == _Provider.google;
    final disabled = _busy != null && !isBusy;
    return FilledButton(
      onPressed: disabled ? null : _onGooglePressed,
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
          letterSpacing: 0.4,
          fontSize: 14,
        ),
      ),
      child: isBusy
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

  Widget _buildAppleButton() {
    final isBusy = _busy == _Provider.apple;
    final disabled = _busy != null && !isBusy;
    return FilledButton(
      onPressed: disabled ? null : _onApplePressed,
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
          letterSpacing: 0.4,
          fontSize: 14,
        ),
      ),
      child: isBusy
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

  /// Escape hatch so the gate is never a trap. Anonymous users (guests,
  /// and store reviewers who pick "guest") can leave the gate to the
  /// dashboard and keep using the free tier. This does NOT weaken the
  /// no-anonymous-purchase guarantee: the gate re-fires on every fresh
  /// paywall mount for an anonymous user, so the purchase button stays
  /// unreachable while anonymous — dismissing only returns to the
  /// dashboard, never to the paywall's plan cards.
  Widget _buildDismissLink() {
    final disabled = _busy != null;
    return Center(
      child: TextButton(
        onPressed: disabled ? null : _onDismissPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        child: const Text('Şimdilik değil'),
      ),
    );
  }

  Widget _buildEmailLoginLink() {
    final disabled = _busy != null;
    return Center(
      child: TextButton(
        onPressed: disabled ? null : _onEmailLoginPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.78),
          disabledForegroundColor: Colors.white24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            decoration: TextDecoration.underline,
          ),
        ),
        child: const Text('E-posta ile Giriş Sayfasına Git'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onGooglePressed() => _runOAuth(
        _Provider.google,
        () => ref.read(authControllerProvider).signInWithGoogle(),
        offlineMessage:
            'Google ile giriş yapmak için internet bağlantısı gereklidir.',
        fallbackError: 'Google ile giriş başarısız oldu. Lütfen tekrar dene.',
      );

  Future<void> _onApplePressed() => _runOAuth(
        _Provider.apple,
        () => ref.read(authControllerProvider).signInWithApple(),
        offlineMessage:
            'Apple ile giriş yapmak için internet bağlantısı gereklidir.',
        fallbackError: 'Apple ile giriş başarısız oldu. Lütfen tekrar dene.',
      );

  Future<void> _runOAuth(
    _Provider provider,
    Future<SocialAuthResult> Function() run, {
    required String offlineMessage,
    required String fallbackError,
  }) async {
    if (_busy != null) return;
    // Pre-flight connectivity check — same pattern as AuthScreen so
    // the user sees a clear message instantly instead of waiting on
    // the ~30 s HTTP timeout from a doomed OAuth round-trip.
    final online = await ref.read(connectivityServiceProvider).isOnline();
    if (!online) {
      if (!mounted) return;
      _toast(offlineMessage);
      return;
    }
    setState(() => _busy = provider);
    try {
      final result = await run();
      if (!mounted) return;
      switch (result.outcome) {
        case SocialAuthOutcome.success:
          // RevenueCat aliasing has already happened inside
          // `AuthController.signIn{Google,Apple}` via
          // `_aliasRevenueCatToSupabaseUser`. We just close the gate;
          // the user lands back on the paywall, now authenticated.
          Navigator.of(context, rootNavigator: true).pop();
        case SocialAuthOutcome.cancelled:
          // User bailed out of the native sheet — stay on the gate.
          break;
        case SocialAuthOutcome.error:
          _toast(result.errorMessage ?? fallbackError);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Closes the gate and navigates the user to the standalone email
  /// login screen. After they sign in there, AuthScreen's own
  /// `_goToPaywall` `pushReplacement`s them back to /paywall — and by
  /// that point AuthController has already aliased RC, so the gate
  /// won't re-trigger.
  void _onEmailLoginPressed() {
    Navigator.of(context, rootNavigator: true).pop();
    context.go(AppRoutes.auth);
  }

  /// Pops the gate AND leaves the paywall for the dashboard, so an
  /// anonymous user is returned to the free tier rather than to the
  /// paywall's (now gate-free) plan cards — keeping anonymous purchases
  /// impossible while never trapping the user.
  void _onDismissPressed() {
    Navigator.of(context, rootNavigator: true).pop();
    context.go(AppRoutes.dashboard);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2A1B5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Animated dark gradient + drifting neon orbs that give the sheet
/// its "premium" feel. Uses a single AnimationController + cheap
/// `Align` arithmetic instead of a CustomPainter — 60 fps on the
/// Redmi Note 11R baseline, no shader compilation.
class _AnimatedNeonBackground extends StatelessWidget {
  const _AnimatedNeonBackground({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // `t` is the looping 0→1 phase; `s` is a phase-shifted sine
        // [-1, 1] used to drive the orb x-positions back and forth so
        // they're not a constant linear drift across the screen.
        final t = controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient — same palette family as the paywall hero
            // so the sheet reads as a continuation of the screen
            // behind the blur, not a foreign element.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0B3D),
                    Color(0xFF0B0B12),
                  ],
                  stops: [0.0, 0.85],
                ),
              ),
            ),
            // Cyan orb — drifts left↔right across the upper region
            _Orb(
              alignmentX: -0.6 + 1.2 * t,
              alignmentY: -0.5,
              size: 220,
              colorInner: const Color(0x6600F0FF),
              colorOuter: const Color(0x0000F0FF),
            ),
            // Purple orb — counter-drifts in the lower region
            _Orb(
              alignmentX: 0.6 - 1.2 * t,
              alignmentY: 0.55,
              size: 280,
              colorInner: const Color(0x668E5BFF),
              colorOuter: const Color(0x008E5BFF),
            ),
            // Top-edge neon line. Brightness pulses on `t` to suggest
            // a subtle electric current — this is the "neon background
            // effect" the spec calls out.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0x0000F0FF),
                      Color.lerp(
                        const Color(0xFF00F0FF),
                        const Color(0xFF8E5BFF),
                        t,
                      )!,
                      const Color(0x0000F0FF),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.alignmentX,
    required this.alignmentY,
    required this.size,
    required this.colorInner,
    required this.colorOuter,
  });

  final double alignmentX;
  final double alignmentY;
  final double size;
  final Color colorInner;
  final Color colorOuter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(alignmentX, alignmentY),
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [colorInner, colorOuter],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline four-colour Google "G" so the sheet stays self-contained.
/// Mirrors the [_GoogleLogoPainter] shipped with the standalone /auth
/// screen — duplicated rather than extracted to a shared widget per
/// CLAUDE.md's "don't refactor adjacent code" rule. ~40 lines, no
/// runtime cost beyond the four arcs.
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
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -0.5,
      1.8,
      false,
      paint..color = _blue,
    );
    canvas.drawArc(
      rect.deflate(stroke / 2),
      1.3,
      1.4,
      false,
      paint..color = _green,
    );
    canvas.drawArc(
      rect.deflate(stroke / 2),
      2.7,
      1.4,
      false,
      paint..color = _yellow,
    );
    canvas.drawArc(
      rect.deflate(stroke / 2),
      4.1,
      1.7,
      false,
      paint..color = _red,
    );
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
