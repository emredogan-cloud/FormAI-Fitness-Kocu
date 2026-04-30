import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/legal_urls.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../domain/ai_personalization_engine.dart';
import '../providers/wizard_provider.dart';
import 'widgets/interactive_question_step.dart';
import 'widgets/onboarding_image.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
// Phase 60E · 12 pages total.
//
//   • 2 hook screens (welcome, coach_intro)
//   • 1 gender screen (Phase 60E) — the missing demographic input that
//     feeds the macro calculator's sex correction
//   • 4 interactive AI-styled questions (goal, experience_level,
//     daily_minutes, activity) — the "premium" Phase-60B surface,
//     refreshed in 60E with image-tile cards on goal + helper
//     subtexts on experience_level
//   • 1 physical-data screen (CupertinoPicker wheels for age, height,
//     weight) feeding BMR/TDEE downstream
//   • 1 pain-point screen (interactive) — surfaces the user's blocker
//   • 1 analysis-illusion screen — labor illusion that cycles AI
//     "thinking" phrases for ~6 s before the reveal
//   • 1 dynamic-report screen — qualitative "AI Assessment" with
//     BMI/calorie cards + 92% confidence bar
//   • 1 pre-paywall summary screen (Phase 60D) — concrete plan card
//     before the paywall route
//
// Nutrition steps live in `NutritionOnboardingSheet` and are surfaced
// on first Beslenme-tab view (Phase 46).
const int _totalSteps = 12;
const int _hookSteps = 2;

/// Phase 42 · analytics labels per onboarding page. Index-aligned with
/// the `PageView.children` list below so the funnel reads the same
/// names the code uses. Phase 60E re-adds `gender` at slot 2.
const List<String> _stepNames = [
  'welcome',
  'coach_intro',
  'gender',
  'goal',
  'experience_level',
  'daily_minutes',
  'activity',
  'physical_data',
  'pain_point',
  'analysis_illusion',
  'dynamic_report',
  'pre_paywall_summary',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _didPrecacheAssets = false;

  /// Phase 60G · the photos rendered by gender / goal / activity tiles
  /// plus the pre-paywall plan card. We push them through
  /// `precacheImage` once at mount so the user never sees a
  /// placeholder flash when they swipe into the relevant page — and
  /// so the PM can swap any of these assets for a higher-res
  /// AI-generated version later without the user catching a decode
  /// hitch.
  ///
  /// Phase 60H swaps the pre-paywall hero from the generic
  /// "plan-creation" art to the AI coach face so the screen mirrors
  /// the coach-intro identity right before the paywall.
  static const List<String> _precacheImagePaths = [
    'photos/cinsiyetseçimikadın.webp',
    'photos/cinsiyetseçimierkek.webp',
    'photos/hedefinneSıkılaşmak.webp',
    'photos/hedefinneHacimKazanmak.webp',
    'photos/hedefinneSadeceSix-Pack.webp',
    // Phase 64 · `hedef_guclenmek.webp` is the PM-shipped art for the
    // strength goal option (was text-only pre-Phase 64). Listed here
    // so the asset is warmed before the user lands on the goal step.
    'photos/hedef_guclenmek.webp',
    'photos/günlükaktivitenmasabaşı.webp',
    'photos/günlükaktivitenhafifhareketli.webp',
    'photos/günlükaktivitenneÇokAktif.webp',
    'photos/kişiselyapayzekakoçfoto.webp',
  ];

  @override
  void initState() {
    super.initState();
    // Phase 46 · capture step_index=0 so the funnel has an "entered
    // onboarding" event. `PageView.onPageChanged` never emits for the
    // initial page, so without this the welcome impression is
    // invisible to the drop-off dashboard.
    AnalyticsService.instance.onboardingStepCompleted(
      stepIndex: 0,
      stepName: _stepNames.first,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;
    // Fire-and-forget — `OnboardingImage`'s placeholder layer covers
    // the case where any of these decode slowly or are missing on
    // disk. The `.catchError` swallows the "asset not found" exception
    // that `precacheImage` throws so a missing path doesn't break the
    // wizard.
    for (final path in _precacheImagePaths) {
      unawaited(
        precacheImage(AssetImage(path), context).catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _totalSteps - 1) return;
    // Phase 60D · UX rule §4: every forward step transition fires a
    // medium impact so the user feels the wizard *progressing* rather
    // than just sliding silently. Light impact on the tap that
    // initiated the transition is fired by the calling widget.
    AppHaptics.primaryCta();
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    AppHaptics.secondaryTap();
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    // Phase 60D · the wizard's exit transition is also a "step
    // transition" per the UX rules — medium impact on the way out.
    AppHaptics.primaryCta();
    final wizard = ref.read(wizardProvider);
    final prefs = ref.read(appPreferencesProvider);
    // Persist the full wizard payload BEFORE flipping the firstTime flag
    // so the workout generator (which reads `userMetrics['targetPhysique']`
    // and `userMetrics['activityLevel']`) has everything it needs on the
    // very first /prediction render — without this save, guests complete
    // onboarding with an empty `user_metrics` and the generator silently
    // falls back to sixpack + beginner.
    await prefs.saveUserMetrics(wizard.toJson());
    await prefs.completeOnboarding(goal: wizard.targetPhysique?.name);
    // Phase 48 · the user just committed to the program; the paywall is
    // the next major surface they may see (post-prediction). Kick off
    // RevenueCat configuration now so the platform channel handshake
    // overlaps the prediction render instead of stalling the paywall
    // open. `configureRevenueCat` is idempotent — calling it again
    // from sign-in is a no-op.
    unawaited(configureRevenueCat());
    if (!mounted) return;

    // Frictionless auth: silently create an anonymous Supabase session so
    // the user can preview their personalized prediction without being
    // shoved into a sign-up form. If anon auth is disabled in the project
    // (or the network is offline), fall back to the explicit /auth screen.
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e, st) {
      AppLogger.error(
        'Anonymous sign-in failed, falling back to /auth',
        e,
        stackTrace: st,
        category: 'onboarding',
      );
      if (!mounted) return;
      context.go(AppRoutes.auth);
      return;
    }
    // Phase 42: now that the user has a session, raise the iOS ATT
    // prompt BEFORE navigating. The ~400 ms internal debounce keeps
    // the prompt from getting eaten by the next route's push.
    await AnalyticsService.instance.requestAttIfNeeded();
    if (!mounted) return;
    // Phase 60C · the dynamic report screen is now the on-wizard hook
    // that the prediction screen used to be, so the wizard exits
    // straight to /paywall instead of stopping over at /prediction.
    // Anonymous users are allowed at /paywall (the redirect rule only
    // bounces *registered* users away from /auth back to it), so this
    // is safe without any router change.
    context.go(AppRoutes.paywall);
  }

  @override
  Widget build(BuildContext context) {
    final showHeader = _index >= _hookSteps;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (showHeader)
              _WizardHeader(
                step: _index - _hookSteps + 1,
                total: _totalSteps - _hookSteps,
                onBack: _index == 0 ? null : _back,
              ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _index = i);
                  // Funnel event — drop-off per step is the most actionable
                  // metric for onboarding optimisation (Phase 46 plans an
                  // A/B on the 13→9 step squeeze).
                  AnalyticsService.instance.onboardingStepCompleted(
                    stepIndex: i,
                    stepName:
                        i < _stepNames.length ? _stepNames[i] : 'unknown_$i',
                  );
                },
                children: [
                  _WelcomeStep(onStart: _next),
                  _CoachIntroStep(onContinue: _next),
                  _GenderStep(onCommitted: _next),
                  _GoalStep(onCommitted: _next),
                  _ExperienceStep(onCommitted: _next),
                  _DailyMinutesStep(onCommitted: _next),
                  _ActivityStep(onCommitted: _next),
                  _PhysicalDataStep(onContinue: _next),
                  _PainPointStep(onCommitted: _next),
                  _AnalysisIllusionStep(onComplete: _next),
                  _DynamicReportStep(onComplete: _next),
                  _PrePaywallSummaryStep(onComplete: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phase 60A · immersive hero hook.
///
/// Title / subtitle / CTA stagger in via a shared [AnimationController]
/// so the screen feels composed when the wizard mounts. The background
/// asset stays static behind a transparent → near-black gradient so the
/// neon copy remains readable against any frame of the photo.
class _WelcomeStep extends StatefulWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    Animation<double> fade(double a, double b) => CurvedAnimation(
          parent: _intro,
          curve: Interval(a, b, curve: Curves.easeOutCubic),
        );
    Animation<Offset> slide(double a, double b) =>
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _intro,
            curve: Interval(a, b, curve: Curves.easeOutCubic),
          ),
        );

    _titleFade = fade(0.0, 0.55);
    _titleSlide = slide(0.0, 0.55);
    _subtitleFade = fade(0.2, 0.75);
    _subtitleSlide = slide(0.2, 0.75);
    _ctaFade = fade(0.45, 1.0);
    _ctaSlide = slide(0.45, 1.0);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _appear({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'photos/ilkkarşılamaanaekranarkaplanı.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [Color(0xFF1A0B3D), Colors.black],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                _appear(
                  fade: _titleFade,
                  slide: _titleSlide,
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [_neon, _neonAccent],
                    ).createShader(rect),
                    child: const Text(
                      'Vücudunu Yapay Zeka ile Şekillendir',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: 0.4,
                        shadows: [
                          Shadow(blurRadius: 24, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _appear(
                  fade: _subtitleFade,
                  slide: _subtitleSlide,
                  child: const Text(
                    'Sana özel antrenman ve beslenme planıyla 30 günde '
                    'hedefine ulaş.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                      shadows: [Shadow(blurRadius: 18, color: Colors.black87)],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _appear(
                  fade: _ctaFade,
                  slide: _ctaSlide,
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _neon.withValues(alpha: 0.55),
                            blurRadius: 28,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () {
                          AppHaptics.secondaryTap();
                          widget.onStart();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _neon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontSize: 18,
                          ),
                        ),
                        child: const Text('BAŞLA'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _appear(
                  fade: _ctaFade,
                  slide: _ctaSlide,
                  child: const _WelcomeLegalLine(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeLegalLine extends StatefulWidget {
  const _WelcomeLegalLine();

  @override
  State<_WelcomeLegalLine> createState() => _WelcomeLegalLineState();
}

class _WelcomeLegalLineState extends State<_WelcomeLegalLine> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.terms);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => openLegalUrl(LegalUrls.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white70,
      fontSize: 11,
      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
    );
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF00F0FF),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF00F0FF).withValues(alpha: 0.8),
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Devam ederek '),
          TextSpan(
            text: 'Kullanım Şartları',
            style: linkStyle,
            recognizer: _termsTap,
          ),
          const TextSpan(text: ' ve '),
          TextSpan(
            text: 'Gizlilik Politikası',
            style: linkStyle,
            recognizer: _privacyTap,
          ),
          const TextSpan(text: '’nı kabul edersin.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Phase 60A · the AI coach's first words.
///
/// Drives the copy through a [_TypewriterText] so the coach feels like
/// it's "speaking" in real time. The CTA stays disabled until the line
/// is fully revealed; tapping the bubble area before then short-circuits
/// the animation. The visual frame is a chat-bubble + neon halo so the
/// surface reads as a conversation with the agent, not a static blurb.
class _CoachIntroStep extends StatefulWidget {
  const _CoachIntroStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<_CoachIntroStep> createState() => _CoachIntroStepState();
}

class _CoachIntroStepState extends State<_CoachIntroStep>
    with SingleTickerProviderStateMixin {
  static const String _coachLine =
      'Merhaba! Ben senin kişisel yapay zeka koçunum. '
      'Şimdi sana birkaç soru soracağım ve tamamen senin '
      'hedeflerine, vücuduna özel bir plan oluşturacağım.';
  // ~28ms/char keeps the line under ~4s — long enough to feel deliberate,
  // short enough that nobody waits long for the CTA to enable.
  static const Duration _perChar = Duration(milliseconds: 28);

  late final AnimationController _typer;
  bool _typingDone = false;

  @override
  void initState() {
    super.initState();
    _typer = AnimationController(
      vsync: this,
      duration: _perChar * _coachLine.length,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _typingDone = true);
        }
      });
    _typer.forward();
  }

  @override
  void dispose() {
    _typer.dispose();
    super.dispose();
  }

  void _skipTyping() {
    if (_typingDone) return;
    _typer.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0E0729)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                Expanded(
                  // GestureDetector wraps only the avatar + bubble area so
                  // taps here skip the typewriter while the CTA below
                  // still owns its own onPressed when enabled.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skipTyping,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _PulsingCoachAvatar(),
                        const SizedBox(height: 28),
                        _TerminalBubble(
                          typer: _typer,
                          fullText: _coachLine,
                          isTypingDone: _typingDone,
                        ),
                        const SizedBox(height: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: _typingDone ? 0.0 : 1.0,
                          child: const Text(
                            'Geçmek için ekrana dokun',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: _typingDone ? 1.0 : 0.45,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _typingDone
                          ? () {
                              AppHaptics.secondaryTap();
                              widget.onContinue();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('DEVAM ET'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _neon.withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chat-bubble container that progressively reveals the coach's line as
/// [typer] advances 0→1. A blinking neon caret trails the cursor while
/// typing is in flight; it disappears the moment the line is complete.
class _TerminalBubble extends StatelessWidget {
  const _TerminalBubble({
    required this.typer,
    required this.fullText,
    required this.isTypingDone,
  });
  final Animation<double> typer;
  final String fullText;
  final bool isTypingDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: _neon.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: typer,
        builder: (context, _) {
          final int chars =
              (typer.value * fullText.length).round().clamp(0, fullText.length);
          final String visible = fullText.substring(0, chars);
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: visible),
                if (!isTypingDone)
                  const TextSpan(
                    text: '▍',
                    style: TextStyle(color: _neon),
                  ),
              ],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.55,
                shadows: [Shadow(blurRadius: 16, color: Colors.black87)],
              ),
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    );
  }
}

class _PulsingCoachAvatar extends StatefulWidget {
  const _PulsingCoachAvatar();

  @override
  State<_PulsingCoachAvatar> createState() => _PulsingCoachAvatarState();
}

class _PulsingCoachAvatarState extends State<_PulsingCoachAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 0.35 + _c.value * 0.4;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _neon.withValues(alpha: glow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _neon, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.6),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'photos/kişiselyapayzekakoçfoto.webp',
                  fit: BoxFit.cover,
                  // Center-fit the face and lean into the dark halo when the
                  // webp can't be decoded so we don't flash a grey circle.
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_neon, _neonAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 56,
                    ),
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

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.total,
    required this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  /// Phase 46 · psychological motivator on the progress rail.
  ///
  /// Replaces the bare "4/7" counter with commitment-style copy:
  ///   • steps 1..total-2 → "N soru kaldı" (N questions left)
  ///   • steps total-1, total → "Neredeyse bitti!" (Almost done!)
  ///
  /// The two-step tail is deliberate — the user on the very last
  /// body-metric question should feel the finish line, not another
  /// abstract countdown.
  String _progressCopy() {
    final remaining = total - step;
    if (remaining <= 1) return 'Neredeyse bitti!';
    return '$remaining soru kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final progress = step / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: onBack == null
                    ? null
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onBack,
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
              ),
              const Text(
                'FormAI',
                style: TextStyle(
                  color: _neon,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$step/$total',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_neon),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _progressCopy(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          // Phase 60D · UX rule §4: light haptic on the *tap* moment
          // (the user committing to advance); the wizard's `_next()`
          // fires the medium "transition" haptic when the page
          // actually slides.
          onPressed: onPressed == null
              ? null
              : () {
                  AppHaptics.secondaryTap();
                  onPressed!();
                },
          style: FilledButton.styleFrom(
            backgroundColor: _neon,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              fontSize: 14,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ─────────────────────── Phase 60C reveal-flow steps ────────────────────────
//
// Phase 60C closes the wizard with four screens:
//   • _PhysicalDataStep — three Cupertino scroll wheels (age / height /
//     weight) with click-haptics, then a 1.5 s "Metabolizmanı
//     hesaplıyorum…" overlay before advancing.
//   • _PainPointStep — interactive pain-point question (delegates to
//     [InteractiveQuestionStep]).
//   • _AnalysisIllusionStep — labor-illusion screen that cycles five
//     "AI thinking" phrases at 1.2 s each over a rotating neon core.
//   • _DynamicReportStep — final reveal with BMI + maintenance-calorie
//     cards, a personalised "AI assessment" paragraph, and a 92%
//     confidence bar. Its CTA fires `_finish`, which routes the user
//     straight to /paywall.

class _PhysicalDataStep extends ConsumerStatefulWidget {
  const _PhysicalDataStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<_PhysicalDataStep> createState() => _PhysicalDataStepState();
}

class _PhysicalDataStepState extends ConsumerState<_PhysicalDataStep>
    with SingleTickerProviderStateMixin {
  static const int _minAge = 18;
  static const int _maxAge = 80;
  static const int _minHeight = 120;
  static const int _maxHeight = 220;
  static const int _minWeight = 30;
  static const int _maxWeight = 200;

  late final FixedExtentScrollController _ageCtrl;
  late final FixedExtentScrollController _heightCtrl;
  late final FixedExtentScrollController _weightCtrl;

  late final AnimationController _feedbackCtrl;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    final w = ref.read(wizardProvider);
    final initialAge = (w.age ?? 25).clamp(_minAge, _maxAge) - _minAge;
    final initialHeight =
        (w.heightCm ?? 170).clamp(_minHeight, _maxHeight) - _minHeight;
    final initialWeight =
        (w.weightKg ?? 70).clamp(_minWeight, _maxWeight) - _minWeight;
    _ageCtrl = FixedExtentScrollController(initialItem: initialAge);
    _heightCtrl = FixedExtentScrollController(initialItem: initialHeight);
    _weightCtrl = FixedExtentScrollController(initialItem: initialWeight);
    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Pre-populate state with the initial pickers so a user who taps
    // DEVAM without scrolling still gets a well-formed wizard payload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(wizardProvider.notifier);
      notifier.setAge(_minAge + initialAge);
      notifier.setHeight(_minHeight + initialHeight);
      notifier.setWeight(_minWeight + initialWeight);
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (_calculating) return;
    // Light tap-feedback only — the medium "transition" thump is fired
    // by the wizard's _next() when it advances 1.5 s later.
    AppHaptics.secondaryTap();
    setState(() => _calculating = true);
    _feedbackCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StepTitle(
          title: 'Vücut bilgilerin',
          subtitle: 'Tam kişiselleştirme için kısa bir veri girişi.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _CupertinoWheel(
                    label: 'YAŞ',
                    controller: _ageCtrl,
                    min: _minAge,
                    max: _maxAge,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setAge(v),
                  ),
                ),
                Expanded(
                  child: _CupertinoWheel(
                    label: 'BOY',
                    suffix: 'cm',
                    controller: _heightCtrl,
                    min: _minHeight,
                    max: _maxHeight,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setHeight(v),
                  ),
                ),
                Expanded(
                  child: _CupertinoWheel(
                    label: 'KİLO',
                    suffix: 'kg',
                    controller: _weightCtrl,
                    min: _minWeight,
                    max: _maxWeight,
                    onChanged: (v) =>
                        ref.read(wizardProvider.notifier).setWeight(v),
                  ),
                ),
              ],
            ),
          ),
        ),
        FadeTransition(
          opacity: _feedbackCtrl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(_neon),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Metabolizmanı hesaplıyorum…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        _PrimaryButton(
          label: _calculating ? 'HESAPLANIYOR…' : 'DEVAM',
          onPressed: _calculating ? null : _commit,
        ),
      ],
    );
  }
}

/// A single column of [CupertinoPicker] tuned to the onboarding's
/// dark/neon palette. Fires [HapticFeedback.selectionClick] on every
/// scroll tick so picking a number feels physical on Android (the
/// iOS-side click is handled natively by the picker).
class _CupertinoWheel extends StatelessWidget {
  const _CupertinoWheel({
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final String? suffix;
  final FixedExtentScrollController controller;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 44,
            squeeze: 1.1,
            diameterRatio: 1.5,
            magnification: 1.08,
            useMagnifier: true,
            backgroundColor: Colors.transparent,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _neon.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  bottom: BorderSide(
                    color: _neon.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              onChanged(min + i);
            },
            children: [
              for (int v = min; v <= max; v++)
                Center(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(text: '$v'),
                        if (suffix != null)
                          TextSpan(
                            text: ' $suffix',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Phase 63A · hybrid pain-point step.
///
/// Tap a preset card and the wizard auto-advances; or type a more
/// specific obstacle in your own words and the DEVAM ET button writes
/// the trimmed string to [WizardState.painPointDescription] before
/// advancing. Identical machinery to the experience step — both flow
/// through [_HybridQuestionStep].
class _PainPointStep extends ConsumerWidget {
  const _PainPointStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    return _HybridQuestionStep(
      title: 'Seni en çok zorlayan ne?',
      subtitle: 'Programın bu noktayı çözecek şekilde kurulacak.',
      feedbackText: 'Bunu çözmek için planını optimize edeceğim.',
      initialCardValue: wizard.painPoint,
      initialDescription: wizard.painPointDescription,
      options: const [
        InteractiveOption(
          value: 'motivation',
          label: 'Motivasyon',
          icon: Icons.local_fire_department_outlined,
        ),
        InteractiveOption(
          value: 'consistency',
          label: 'Süreklilik',
          icon: Icons.repeat_rounded,
        ),
        InteractiveOption(
          value: 'no_idea',
          label: 'Ne yapacağımı bilmiyorum',
          icon: Icons.help_outline_rounded,
        ),
        InteractiveOption(
          value: 'diet',
          label: 'Diyet',
          icon: Icons.restaurant_menu_rounded,
        ),
      ],
      inputLabel: 'Seni tam olarak neyin zorladığını detaylandırabilirsin',
      inputHint: 'Örn: Akşamları çok yorgun oluyorum ve diyeti '
          'bozuyorum...',
      onCardCommitted: (value) {
        ref.read(wizardProvider.notifier).setPainPoint(value);
        onCommitted();
      },
      onTextCommitted: (text) {
        ref.read(wizardProvider.notifier).setPainPointDescription(text);
        onCommitted();
      },
    );
  }
}

/// Phase 60C · the "labor illusion" screen that sits between the
/// pain-point answer and the dynamic report. Cycles through five AI
/// "thinking" phrases at a fixed 1.2 s cadence over a rotating neon
/// core graphic, then auto-advances. Total dwell ≈ 6 s so the user
/// believes the system is doing serious work before the reveal.
class _AnalysisIllusionStep extends StatefulWidget {
  const _AnalysisIllusionStep({required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<_AnalysisIllusionStep> createState() => _AnalysisIllusionStepState();
}

class _AnalysisIllusionStepState extends State<_AnalysisIllusionStep>
    with SingleTickerProviderStateMixin {
  static const List<String> _phrases = [
    'Vücudun analiz ediliyor…',
    'Metabolizma hesaplanıyor…',
    'Kas potansiyelin değerlendiriliyor…',
    'Yağ oranı tahmin ediliyor…',
    'Sana özel plan oluşturuluyor…',
  ];
  static const Duration _phraseDuration = Duration(milliseconds: 1200);

  Timer? _timer;
  int _index = 0;
  late final AnimationController _coreCtrl;

  @override
  void initState() {
    super.initState();
    _coreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _timer = Timer.periodic(_phraseDuration, (timer) {
      if (!mounted) return;
      if (_index >= _phrases.length - 1) {
        timer.cancel();
        // One last phrase-length beat so the user actually sees the
        // closing "Sana özel plan…" line before we punt them to the
        // report.
        Future<void>.delayed(_phraseDuration, () {
          if (mounted) widget.onComplete();
        });
      } else {
        setState(() => _index += 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _coreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            _AnalysisCore(progress: _coreCtrl),
            const SizedBox(height: 36),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
                _phrases[_index],
                key: ValueKey<int>(_index),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${_index + 1} / ${_phrases.length}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

/// Centered animated AI core: a sweep-gradient ring rotates around an
/// inner neon-bordered disc with a glowing sparkle icon. Pure CPU
/// drawing — no images required.
class _AnalysisCore extends StatelessWidget {
  const _AnalysisCore({required this.progress});
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _neon.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: t * 2 * math.pi,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _neon.withValues(alpha: 0),
                        _neonAccent,
                        _neon,
                        _neon.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: _neon, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.55),
                      blurRadius: 28,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: -t * math.pi,
                  child: const Icon(
                    Icons.auto_awesome,
                    color: _neon,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Phase 60C · the final pre-paywall reveal.
///
/// Pulls the wizard payload, renders BMI + maintenance-calorie cards,
/// a generated "AI Assessment" paragraph that branches on
/// activityLevel/goal/experienceLevel/painPoint, and a fake 92%
/// confidence bar. The CTA wires straight into [_finish], which
/// persists the wizard, signs the user in anonymously, and routes to
/// /paywall.
class _DynamicReportStep extends ConsumerStatefulWidget {
  const _DynamicReportStep({required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<_DynamicReportStep> createState() => _DynamicReportStepState();
}

class _DynamicReportStepState extends ConsumerState<_DynamicReportStep>
    with SingleTickerProviderStateMixin {
  static const double _confidenceTarget = 0.92;

  late final AnimationController _intro;
  late final Animation<double> _confidence;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _contentFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));
    _confidence = Tween<double>(begin: 0.0, end: _confidenceTarget).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 60D · all derivation lives in [AiPersonalizationEngine] now —
    // both this screen and the pre-paywall summary read the same
    // structured report so the two surfaces stay coherent.
    final report =
        AiPersonalizationEngine.generateReport(ref.watch(wizardProvider));
    final bmi = report.bmi;
    final calories = report.maintenanceCalories;
    final assessment = report.assessment;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FadeTransition(
          opacity: _contentFade,
          child: SlideTransition(
            position: _contentSlide,
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_neon, _neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Kişisel AI Raporun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI değerlendirmen hazır',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ReportMetricCard(
                        label: 'BMI',
                        value: bmi.toStringAsFixed(1),
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReportMetricCard(
                        label: 'GÜNLÜK KAL.',
                        value: '$calories',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _neon.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _neon.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.psychology_outlined,
                                color: _neonAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI DEĞERLENDİRMESİ',
                                style: TextStyle(
                                  color: _neonAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            assessment,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _confidence,
                  builder: (context, _) {
                    final pct = (_confidence.value * 100).round();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Başarı olasılığı',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '%$pct',
                              style: const TextStyle(
                                color: _neon,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _confidence.value,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(_neon),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _neon.withValues(alpha: 0.55),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () {
                        AppHaptics.secondaryTap();
                        widget.onComplete();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          fontSize: 15,
                        ),
                      ),
                      child: const Text('KİŞİSEL PLANIMI AL'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: _neon.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neon.withValues(alpha: 0.18),
              border: Border.all(
                color: _neon.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── Phase 60D pre-paywall summary ─────────────────────
//
// _PrePaywallSummaryStep sits between the dynamic AI report and the
// paywall. Where the report screen sells the *insight* the AI gathered,
// this screen sells the *plan* itself: goal, duration, difficulty,
// weekly cadence, projected results — pulled out of the same engine.
// The CTA fires `_finish`, which is the only path out of the wizard
// and routes the user straight to /paywall.

class _PrePaywallSummaryStep extends ConsumerStatefulWidget {
  const _PrePaywallSummaryStep({required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<_PrePaywallSummaryStep> createState() =>
      _PrePaywallSummaryStepState();
}

class _PrePaywallSummaryStepState extends ConsumerState<_PrePaywallSummaryStep>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  // Phase 63A · the trust-booster confidence bar fills from 0 → 92 %
  // on entry. Driven by its own short controller (separate from
  // [_intro]) so the bar fill lands a beat after the summary card has
  // settled, drawing the eye down toward the CTA.
  late final AnimationController _trustCtrl;
  late final Animation<double> _trustFill;

  static const double _confidenceTarget = 0.92;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _cardFade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

    _trustCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _trustFill = Tween<double>(begin: 0.0, end: _confidenceTarget).animate(
      CurvedAnimation(parent: _trustCtrl, curve: Curves.easeOutCubic),
    );
    // Start the bar a touch after the summary card lands so the user
    // sees the % climb rather than it being already-filled when the
    // page mounts.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _trustCtrl.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _trustCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report =
        AiPersonalizationEngine.generateReport(ref.watch(wizardProvider));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [_neon, _neonAccent],
              ).createShader(rect),
              child: const Text(
                'Bu plan sana özel oluşturuldu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI motorun seni baştan sona dinledi ve aşağıdaki paketi '
              'senin için kurdu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _cardFade,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: _SummaryCard(report: report),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Phase 63A · trust-booster sits between the AI summary
            // card and the CTA so the high-conversion "92 %" lands on
            // the user right before they tap "Planımı Gör".
            FadeTransition(
              opacity: _cardFade,
              child: _TrustBoosterPanel(fill: _trustFill),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.55),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: () {
                    AppHaptics.secondaryTap();
                    widget.onComplete();
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('PLANIMI GÖR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _neon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phase 63A · pre-paywall trust booster.
///
/// Glowing container with a neon-bordered confidence bar that fills
/// 0 → 92 % once the page settles, paired with a coach-voice line
/// that reads as the AI vouching for its own work. Lives between the
/// summary card and the "Planımı Gör" CTA so the % climb is the last
/// thing the user sees before tapping through.
class _TrustBoosterPanel extends StatelessWidget {
  const _TrustBoosterPanel({required this.fill});

  final Animation<double> fill;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fill,
      builder: (context, _) {
        final pct = (fill.value * 100).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _neon.withValues(alpha: 0.16),
                _neonAccent.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _neon.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.32),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: _neonAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Başarı Olasılığı',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Text(
                    '%$pct',
                    style: const TextStyle(
                      color: _neon,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: fill.value,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(_neon),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bu program, girdiğin veriler çaprazlanarak tamamen sana özel '
                'milimetrik olarak hesaplandı.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Phase 60G · the detailed Plan Card. Top half is a full-bleed hero
/// image (with `AI KİŞİSEL PLAN` chip + `12 HAFTA` badge floated
/// over it and a bottom dim-gradient for legibility); bottom half is
/// the structured detail block — a 2x2 stat grid plus a full-width
/// projected-results highlight tile. The previous Phase-60D version
/// rendered a 96 px placeholder and 5 stacked rows; this richer card
/// is what the PM is reverting toward in their "Image + Details"
/// brief.
/// Phase 60H · the AI plan card.
///
/// Side-image layout matching the option cards: stat rows stack on
/// the left, the AI coach face panel anchors the right ~45% of the
/// card. A neon `BoxShadow` sits behind the entire card to make it
/// feel "alive" and high-value.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final AiReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          // Phase 60H · "premium accent" glow per PM brief — low alpha,
          // high blur so the card breathes neon without taking on a
          // hard outline.
          BoxShadow(
            color: _neon.withValues(alpha: 0.32),
            blurRadius: 38,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlanStatRow(
                        label: 'HEDEF',
                        value: report.goalLabel,
                        icon: Icons.flag_rounded,
                      ),
                      const SizedBox(height: 10),
                      _PlanStatRow(
                        label: 'SÜRE',
                        value: report.durationLabel,
                        icon: Icons.calendar_month_rounded,
                      ),
                      const SizedBox(height: 10),
                      _PlanStatRow(
                        label: 'ZORLUK',
                        value: report.difficultyLabel,
                        icon: Icons.bolt_rounded,
                      ),
                      const SizedBox(height: 10),
                      _PlanStatRow(
                        label: 'HAFTALIK',
                        value: '${report.weeklyWorkoutCount} gün',
                        icon: Icons.fitness_center_rounded,
                      ),
                      const SizedBox(height: 12),
                      _PlanResultTile(text: report.estimatedResults),
                    ],
                  ),
                ),
              ),
              const Expanded(
                flex: 9,
                child: _AiCoachPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon + label/value row sized for the plan card's narrow
/// (~55%) left column. Smaller icon-bubble + tighter type than the
/// older 2x2 [_SummaryStatTile] grid so the four stats + the result
/// callout fit alongside the AI coach image.
class _PlanStatRow extends StatelessWidget {
  const _PlanStatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neon.withValues(alpha: 0.18),
            border: Border.all(color: _neon.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: _neon, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "TAHMİNİ SONUÇ" callout — slimmed down for the narrow left column
/// of the side-image plan card. Smaller icon, tighter padding, but
/// preserves the neon-tinted background that makes it the visual
/// climax of the card.
class _PlanResultTile extends StatelessWidget {
  const _PlanResultTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.24),
            _neonAccent.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neon.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: _neonAccent,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'TAHMİNİ SONUÇ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 60H · the right-hand AI coach panel for the plan card.
/// Same flush-mounted, gradient-blended layout as the option cards'
/// `_SideImagePanel`, plus a "Senin AI Koçun" badge floated near the
/// top to reinforce the AI persona on the screen the user sees right
/// before the paywall.
class _AiCoachPanel extends StatelessWidget {
  const _AiCoachPanel();

  static const String _coachAsset = 'photos/kişiselyapayzekakoçfoto.webp';

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        OnboardingImage(
          asset: _coachAsset,
          fallbackIcon: Icons.smart_toy_rounded,
          borderRadius: 0,
          dimOverlay: false,
        ),
        // Same dark-to-transparent left blend the option cards use, so
        // the coach feels visually continuous with the dark left half
        // of the card.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.transparent],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 6,
          right: 6,
          child: Center(child: _SeninAiKocunBadge()),
        ),
      ],
    );
  }
}

class _SeninAiKocunBadge extends StatelessWidget {
  const _SeninAiKocunBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: _neon, size: 10),
          SizedBox(width: 4),
          Text(
            'Senin AI Koçun',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Phase 60B interactive steps ──────────────────────
//
// The screens below are the "AI coaching" surface introduced by
// Phase 60B (refreshed in 60E with image-tile cards on goal + helper
// subtexts on experience_level + a re-introduced gender screen). They
// all delegate to [InteractiveQuestionStep] — selecting a card
// highlights it, dims its peers, fades in a micro-feedback line, then
// auto-advances ~1.5 s later.

/// Phase 60E · gender as the first demographic input. Stores the
/// existing [Gender] enum (preserved in `WizardState` for the profile
/// editor) — the wizard's `toJson` already serialises it as the
/// enum's name, which is the string token downstream services expect.
class _GenderStep extends ConsumerWidget {
  const _GenderStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).gender;
    return InteractiveQuestionStep(
      title: 'Cinsiyetin?',
      subtitle: 'Programını sana göre kalibre edelim.',
      initialValue: current?.name,
      feedbackText: 'Programını sana özel kalibre ediyorum.',
      options: const [
        InteractiveOption(
          value: 'female',
          label: 'Kadın',
          icon: Icons.female_rounded,
          imageAsset: 'photos/cinsiyetseçimikadın.webp',
        ),
        InteractiveOption(
          value: 'male',
          label: 'Erkek',
          icon: Icons.male_rounded,
          imageAsset: 'photos/cinsiyetseçimierkek.webp',
        ),
        InteractiveOption(
          value: 'other',
          label: 'Diğer',
          icon: Icons.transgender_rounded,
        ),
      ],
      // Phase 63A · sleek AI insight beneath the three cards. Fills
      // the empty space without bloating the cards themselves and
      // keeps the page reading as the AI explaining its reasoning.
      bottomSlot: const _AiInsightCard(
        headline: '💡 Yapay Zeka Notu',
        body: 'Fiziksel özelliklerine ve biyomekaniğine en uygun '
            'antrenman iskeletini kurabilmek için cinsiyet verini '
            'analiz ediyoruz.',
      ),
      onCommitted: (value) {
        final picked = Gender.values.firstWhere(
          (g) => g.name == value,
          orElse: () => Gender.other,
        );
        ref.read(wizardProvider.notifier).setGender(picked);
        onCommitted();
      },
    );
  }
}

class _GoalStep extends ConsumerWidget {
  const _GoalStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).goal;
    return InteractiveQuestionStep(
      title: 'Hedefin ne?',
      subtitle: 'Sana en uygun planı bunun üzerine inşa edeceğim.',
      initialValue: current,
      feedbackText:
          '🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde '
          'fark görüyor.',
      // Phase 60E · transformation thumbnails on the right of each
      // card. Where a bundled asset isn't a perfect match (`strength`)
      // we omit the path and let the icon stay as the visual anchor.
      options: const [
        InteractiveOption(
          value: 'belly_burn',
          label: 'Göbek eritmek',
          icon: Icons.local_fire_department_rounded,
          imageAsset: 'photos/hedefinneSıkılaşmak.webp',
        ),
        InteractiveOption(
          value: 'muscle_gain',
          label: 'Kas yapmak',
          icon: Icons.fitness_center_rounded,
          imageAsset: 'photos/hedefinneHacimKazanmak.webp',
        ),
        InteractiveOption(
          value: 'fitness_look',
          label: 'Daha fit görünmek',
          icon: Icons.auto_awesome_rounded,
          imageAsset: 'photos/hedefinneSadeceSix-Pack.webp',
        ),
        InteractiveOption(
          value: 'strength',
          label: 'Güçlenmek',
          icon: Icons.bolt_rounded,
          // Phase 64 · the PM-shipped `hedef_guclenmek.webp` (chalked-
          // hand-on-barbell shot generated from the Phase 63B prompt
          // brief) lands the strength option on the same Fitify side-
          // image layout the other three goal cards already use.
          imageAsset: 'photos/hedef_guclenmek.webp',
        ),
      ],
      onCommitted: (value) {
        ref.read(wizardProvider.notifier).setGoal(value);
        onCommitted();
      },
    );
  }
}

/// Phase 63A · hybrid experience step.
///
/// Same shape as [_ActivityStep]: tap a preset card and the wizard
/// auto-advances with the existing 1.5 s commit window, OR type a
/// free-text training history and an animated DEVAM ET button writes
/// the trimmed string to [WizardState.experienceDescription] before
/// advancing. Built on top of the shared [_HybridQuestionStep] so the
/// pain-point step + any future hybrid use the exact same machinery.
class _ExperienceStep extends ConsumerWidget {
  const _ExperienceStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    return _HybridQuestionStep(
      title: 'Daha önce spor yaptın mı?',
      subtitle: 'Programın zorluğunu seviyene göre kalibre edeceğim.',
      feedbackText: 'Tamam, programını buna göre ayarlıyorum.',
      initialCardValue: wizard.experienceLevel,
      initialDescription: wizard.experienceDescription,
      // Phase 60E · motivational subtext under each option per PM
      // mapping. Reads as supportive ("hiç sorun değil") rather than
      // judgemental.
      options: const [
        InteractiveOption(
          value: 'none',
          label: 'Hiç yapmadım',
          icon: Icons.spa_rounded,
          helper:
              'Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız.',
        ),
        InteractiveOption(
          value: 'occasional',
          label: 'Ara sıra yaptım',
          icon: Icons.directions_walk_rounded,
          helper: 'Harika, temelini güçlendirip daha iyi sonuç alacağız.',
        ),
        InteractiveOption(
          value: 'regular',
          label: 'Düzenli yapıyorum',
          icon: Icons.fitness_center_rounded,
          helper: 'Seviyeni bir üst noktaya taşıyacağız.',
        ),
      ],
      inputLabel: 'Spor geçmişinizi anlatırsanız daha iyi yardımcı oluruz',
      inputHint: 'Örn: Lisede basketbol oynardım ama 2 yıldır spor '
          'yapmıyorum...',
      onCardCommitted: (value) {
        ref.read(wizardProvider.notifier).setExperienceLevel(value);
        onCommitted();
      },
      onTextCommitted: (text) {
        ref.read(wizardProvider.notifier).setExperienceDescription(text);
        onCommitted();
      },
    );
  }
}

class _DailyMinutesStep extends ConsumerWidget {
  const _DailyMinutesStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(wizardProvider).dailyMinutes;
    return InteractiveQuestionStep(
      title: 'Günde ne kadar zaman ayırabilirsin?',
      subtitle: 'Antrenman uzunluğunu buna göre planlayacağım.',
      initialValue: current,
      feedbackText: 'Bu süreyle bile ciddi sonuç alabilirsin.',
      // Phase 60F · motivational subtexts under each option per PM
      // mapping. Reads as a coach validating the user's choice rather
      // than a neutral specification.
      options: const [
        InteractiveOption(
          value: '10_15',
          label: '10–15 dakika',
          icon: Icons.timer_outlined,
          helper: 'Kısa sürede maksimum verim alacağız.',
        ),
        InteractiveOption(
          value: '20_30',
          label: '20–30 dakika',
          icon: Icons.access_time_rounded,
          helper: 'En ideal aralık. Hızlı gelişim mümkün.',
        ),
        InteractiveOption(
          value: '45_plus',
          label: '45+ dakika',
          icon: Icons.local_fire_department_outlined,
          helper: 'Daha agresif ilerleyebiliriz.',
        ),
      ],
      // Phase 63A · motivational AI Coach insight that fills the dead
      // space below the three cards. Reinforces the consistency-over-
      // duration framing the rest of the wizard already leans on.
      bottomSlot: const _AiInsightCard(
        headline: '💡 AI Koçun Diyor ki:',
        body: 'Günde sadece 15 dakika bile, hiç yapmamaktan %100 daha '
            'etkilidir. İstikrar, süreden çok daha önemlidir.',
      ),
      onCommitted: (value) {
        ref.read(wizardProvider.notifier).setDailyMinutes(value);
        onCommitted();
      },
    );
  }
}

/// Phase 60F · hybrid activity step.
///
/// Two paths to advance the wizard:
///   • Tap one of the three preset cards (`Masa başı` / `Hafif
///     hareketli` / `Çok aktif`) → mirrors the Phase 60B card flow:
///     selection light haptic, feedback banner fades in, 1.5 s commit
///     window, then `onCommitted` advances. Writes to the existing
///     [ActivityLevel] enum that the BMR/TDEE calculator consumes.
///   • Or focus the free-text input below the cards and describe the
///     day in their own words → an animated DEVAM ET button appears.
///     Tapping it writes the trimmed string to
///     [WizardState.activityDescription] and advances. Stays disabled
///     while the field is empty.
///
/// Cards and feedback banner are reused via the public [OptionCard] /
/// [FeedbackBanner] widgets so the visual language matches the rest
/// of the interactive steps exactly.
class _ActivityStep extends ConsumerStatefulWidget {
  const _ActivityStep({required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  ConsumerState<_ActivityStep> createState() => _ActivityStepState();
}

class _ActivityStepState extends ConsumerState<_ActivityStep>
    with TickerProviderStateMixin {
  static const List<InteractiveOption> _options = [
    InteractiveOption(
      value: 'sedentary',
      label: 'Masa başı',
      icon: Icons.chair_outlined,
      imageAsset: 'photos/günlükaktivitenmasabaşı.webp',
    ),
    InteractiveOption(
      value: 'light',
      label: 'Hafif hareketli',
      icon: Icons.directions_walk_rounded,
      imageAsset: 'photos/günlükaktivitenhafifhareketli.webp',
    ),
    InteractiveOption(
      value: 'active',
      label: 'Çok aktif',
      icon: Icons.directions_run_rounded,
      imageAsset: 'photos/günlükaktivitenneÇokAktif.webp',
    ),
  ];
  static const String _feedbackText =
      'Kişisel kalori ve program yoğunluğunu buna göre ayarlıyorum.';

  String? _selectedCardValue;
  bool _committingCard = false;

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  // Once the user enters at least one character we keep the DEVAM ET
  // button mounted; the disabled state takes over if they later clear
  // the field. Matches the PM rule "disabled if empty, enabled if
  // there is text" — the button doesn't disappear once the user has
  // engaged with the field.
  bool _hasStartedTyping = false;

  late final AnimationController _feedbackCtrl;
  late final Animation<double> _feedbackFade;
  late final Animation<Offset> _feedbackSlide;

  late final AnimationController _ctaCtrl;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    final w = ref.read(wizardProvider);
    _selectedCardValue = w.activityLevel?.name;
    _textCtrl = TextEditingController(text: w.activityDescription ?? '');
    _focusNode = FocusNode();
    _hasStartedTyping = _textCtrl.text.isNotEmpty;
    _textCtrl.addListener(_onTextChange);

    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _feedbackFade =
        CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic);
    _feedbackSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic),
    );

    _ctaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _ctaFade = CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic);
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic),
    );
    if (_hasStartedTyping) {
      _ctaCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChange);
    _textCtrl.dispose();
    _focusNode.dispose();
    _feedbackCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  void _onTextChange() {
    final hasText = _textCtrl.text.isNotEmpty;
    if (!_hasStartedTyping && hasText) {
      setState(() => _hasStartedTyping = true);
      _ctaCtrl.forward();
    } else {
      // Re-evaluate the disabled/enabled state on every keystroke even
      // when the visibility flag hasn't flipped.
      setState(() {});
    }
  }

  Future<void> _pickCard(String value) async {
    if (_committingCard) return;
    AppHaptics.secondaryTap();
    _focusNode.unfocus();
    setState(() {
      _selectedCardValue = value;
      _committingCard = true;
    });
    _feedbackCtrl.forward();
    final level = ActivityLevel.values.firstWhere(
      (a) => a.name == value,
      orElse: () => ActivityLevel.light,
    );
    ref.read(wizardProvider.notifier).setActivityLevel(level);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onCommitted();
  }

  void _commitCustom() {
    if (_committingCard) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    AppHaptics.secondaryTap();
    ref.read(wizardProvider.notifier).setActivityDescription(text);
    widget.onCommitted();
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Column(
      children: [
        const _StepTitle(
          title: 'Günlük aktiviten?',
          subtitle: 'Kalori ihtiyacını buna göre hesaplıyorum.',
        ),
        // Phase 68 · header→cards 20 → 14 to absorb the card-height bump
        // (88 → 102) without re-introducing scroll on the hybrid step.
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            // Keyboard-aware: `resizeToAvoidBottomInset` (default true)
            // shrinks our Expanded when the IME opens, the
            // SingleChildScrollView keeps the input + CTA reachable.
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in _options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selectedCardValue == opt.value,
                    dimmed: _committingCard && _selectedCardValue != opt.value,
                    onTap: () => _pickCard(opt.value),
                  ),
                  // Phase 68 · 12 → 8 between cards.
                  if (opt != _options.last) const SizedBox(height: 8),
                ],
                // Phase 68 · 16 → 12 cards→banner.
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: _feedbackText,
                ),
                // Phase 68 · banner→input tightened 22 → 14 per PM brief
                // ("reduce the margins around the text input"). Keeps
                // the input reachable above the keyboard fold without
                // squashing the visual rhythm.
                const SizedBox(height: 14),
                _CustomActivityInput(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  enabled: !_committingCard,
                ),
                // Phase 68 · input→CTA 14 → 10.
                const SizedBox(height: 10),
                if (_hasStartedTyping)
                  FadeTransition(
                    opacity: _ctaFade,
                    child: SlideTransition(
                      position: _ctaSlide,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ctaEnabled ? _commitCustom : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _neon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _neon.withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              fontSize: 14,
                            ),
                          ),
                          child: const Text('DEVAM ET'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Phase 60F · the free-text "describe your day" input. A label sits
/// above the [TextField] explaining what to write; the placeholder is
/// the example day-in-the-life sentence the PM provided. The [enabled]
/// flag mirrors the parent's commit state so a card-driven advance
/// can't be raced by a late keystroke.
class _CustomActivityInput extends StatelessWidget {
  const _CustomActivityInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: _neonAccent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Gününü açıklarsan daha iyi yardımcı olabiliriz',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: 3,
          minLines: 3,
          maxLength: 280,
          textInputAction: TextInputAction.done,
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          cursorColor: _neon,
          decoration: InputDecoration(
            hintText: 'Günüm genelde masa başında geçiyor ama akşam yürüyüş '
                'yapıyorum...',
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.4,
            ),
            // The PM brief calls out hint disappearing once the user
            // types — that's Flutter's default TextField behaviour, so
            // no extra wiring is needed.
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _neon, width: 1.4),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Phase 63A · generic hybrid question step.
//
// Mirrors [_ActivityStep] for any wizard question that wants a "tap a
// card OR type a longer answer" hybrid. Used by [_ExperienceStep] and
// [_PainPointStep] so all hybrid screens share identical animation
// timings, focus management, and DEVAM ET visibility logic.
//
// The activity step is intentionally NOT migrated onto this widget:
// [ActivityLevel] is an enum (not a string) and that step has its own
// integration with the BMR/TDEE calculator. Future cleanup can fold
// it in if the enum gets relaxed; for now the two coexist.
// ============================================================================

class _HybridQuestionStep extends StatefulWidget {
  const _HybridQuestionStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.feedbackText,
    required this.initialCardValue,
    required this.initialDescription,
    required this.onCardCommitted,
    required this.onTextCommitted,
    required this.inputLabel,
    required this.inputHint,
  });

  final String title;
  final String? subtitle;
  final List<InteractiveOption> options;
  final String feedbackText;
  final String? initialCardValue;
  final String? initialDescription;

  /// Fired when the user taps one of the [options]. The string is the
  /// `value` of the picked option — the caller writes it into
  /// whichever wizard slot owns this step.
  final ValueChanged<String> onCardCommitted;

  /// Fired when the user types into the free-text field and taps
  /// DEVAM ET. The string is the trimmed text the caller writes into
  /// the matching `*Description` slot.
  final ValueChanged<String> onTextCommitted;

  final String inputLabel;
  final String inputHint;

  @override
  State<_HybridQuestionStep> createState() => _HybridQuestionStepState();
}

class _HybridQuestionStepState extends State<_HybridQuestionStep>
    with TickerProviderStateMixin {
  String? _selectedCardValue;
  bool _committingCard = false;

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  // Once the user enters at least one character we keep DEVAM ET
  // mounted; the disabled state takes over if they later clear the
  // field. Same UX rule the activity step follows.
  bool _hasStartedTyping = false;

  late final AnimationController _feedbackCtrl;
  late final Animation<double> _feedbackFade;
  late final Animation<Offset> _feedbackSlide;

  late final AnimationController _ctaCtrl;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _selectedCardValue = widget.initialCardValue;
    _textCtrl = TextEditingController(text: widget.initialDescription ?? '');
    _focusNode = FocusNode();
    _hasStartedTyping = _textCtrl.text.isNotEmpty;
    _textCtrl.addListener(_onTextChange);

    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _feedbackFade =
        CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic);
    _feedbackSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic),
    );

    _ctaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _ctaFade = CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic);
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctaCtrl, curve: Curves.easeOutCubic),
    );
    if (_hasStartedTyping) {
      _ctaCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChange);
    _textCtrl.dispose();
    _focusNode.dispose();
    _feedbackCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  void _onTextChange() {
    final hasText = _textCtrl.text.isNotEmpty;
    if (!_hasStartedTyping && hasText) {
      setState(() => _hasStartedTyping = true);
      _ctaCtrl.forward();
    } else {
      setState(() {});
    }
  }

  Future<void> _pickCard(String value) async {
    if (_committingCard) return;
    AppHaptics.secondaryTap();
    _focusNode.unfocus();
    setState(() {
      _selectedCardValue = value;
      _committingCard = true;
    });
    _feedbackCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    widget.onCardCommitted(value);
  }

  void _commitCustom() {
    if (_committingCard) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    AppHaptics.secondaryTap();
    widget.onTextCommitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Column(
      children: [
        _StepTitle(
          title: widget.title,
          subtitle: widget.subtitle,
        ),
        // Phase 68 · header→cards 20 → 14, mirroring the activity step.
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in widget.options) ...[
                  OptionCard(
                    option: opt,
                    selected: _selectedCardValue == opt.value,
                    dimmed: _committingCard && _selectedCardValue != opt.value,
                    onTap: () => _pickCard(opt.value),
                  ),
                  // Phase 68 · 12 → 8 between cards.
                  if (opt != widget.options.last) const SizedBox(height: 8),
                ],
                // Phase 68 · 16 → 12 cards→banner.
                const SizedBox(height: 12),
                FeedbackBanner(
                  fade: _feedbackFade,
                  slide: _feedbackSlide,
                  text: widget.feedbackText,
                ),
                // Phase 68 · banner→input 22 → 14 per PM brief.
                const SizedBox(height: 14),
                _CustomDescriptionInput(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  enabled: !_committingCard,
                  label: widget.inputLabel,
                  hint: widget.inputHint,
                ),
                // Phase 68 · input→CTA 14 → 10.
                const SizedBox(height: 10),
                if (_hasStartedTyping)
                  FadeTransition(
                    opacity: _ctaFade,
                    child: SlideTransition(
                      position: _ctaSlide,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ctaEnabled ? _commitCustom : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _neon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _neon.withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              fontSize: 14,
                            ),
                          ),
                          child: const Text('DEVAM ET'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Phase 63A · parameterised free-text input shared by every hybrid
/// step. Same chrome as [_CustomActivityInput] (which kept its
/// hardcoded copy because the activity step still uses it directly),
/// but takes [label] and [hint] so the experience and pain-point
/// steps can supply their own coach-voice copy.
class _CustomDescriptionInput extends StatelessWidget {
  const _CustomDescriptionInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: _neonAccent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          maxLines: 3,
          minLines: 3,
          maxLength: 280,
          textInputAction: TextInputAction.done,
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          cursorColor: _neon,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.4,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _neon, width: 1.4),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Phase 63A · "AI Insight" card.
//
// Glassmorphism-style block dropped into the dead space below the cards
// on the gender + daily-minutes steps. The lead emoji + headline fix
// the card as the AI coach speaking; the body explains why the answer
// matters or reinforces a motivational beat. Visually consistent with
// the rest of the dark/neon onboarding palette so it never reads as a
// disclaimer or a footnote.
// ============================================================================
class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.headline, required this.body});

  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.10),
            _neonAccent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _neon.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: _neonAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// Nutrition wizard steps moved to
// `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart`
// in Phase 46. Surfaced on first Beslenme-tab view instead of inside
// primary onboarding so the path to /prediction stays short.
