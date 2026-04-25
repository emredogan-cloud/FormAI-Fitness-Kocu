import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/legal_urls.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../providers/wizard_provider.dart';
import 'widgets/illusion_step.dart';
import 'widgets/photo_option_card.dart';
import 'widgets/wheel_column.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
// Phase 46 · shortened wizard.
//
// 9 pages total: 2 hook screens + 6 body/fitness questions + 1
// illusion/finish screen. The four nutrition questions
// (`_DietPreferenceStep`, `_AllergiesStep`, `_MealFrequencyStep`,
// `_PrepTimeStep`) were lifted into `NutritionOnboardingSheet` so
// the critical path to the /prediction payoff is 4 taps shorter.
const int _totalSteps = 9;
const int _hookSteps = 2;

/// Phase 42 · analytics labels per onboarding page. Index-aligned with
/// the `PageView.children` list below so the funnel reads the same
/// names the code uses. Phase 46 drops the four `nutrition_*` entries
/// — they live in `nutrition_onboarding_step_completed` now.
const List<String> _stepNames = [
  'welcome',
  'coach_intro',
  'gender',
  'age',
  'body_metrics',
  'current_physique',
  'target_physique',
  'activity',
  'illusion',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _totalSteps - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
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
    // the prompt from getting eaten by the prediction route's push.
    await AnalyticsService.instance.requestAttIfNeeded();
    if (!mounted) return;
    context.go(AppRoutes.prediction);
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
                  _GenderStep(onSelected: _next),
                  _AgeStep(onContinue: _next),
                  _BodyMetricsStep(onContinue: _next),
                  _CurrentPhysiqueStep(onSelected: _next),
                  _TargetPhysiqueStep(onSelected: _next),
                  _ActivityStep(onSelected: _next),
                  IllusionStep(onComplete: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Full-bleed background shot + dark gradient overlay so the neon copy
    // stays readable against whatever photo ships in photos/. The overlay
    // is stronger at the bottom so the CTA sits on a solid patch.
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
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.9),
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
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_neon, _neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Vücudunu Yapay Zeka İle Şekillendir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(blurRadius: 24, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Telefonunun kamerası ile her tekrarını izleyen, '
                  'formunu düzelten ve seni gerçek bir koç gibi motive '
                  'eden kişisel yapay zeka asistanın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black87)],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
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
                      onPressed: onStart,
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
                const SizedBox(height: 12),
                const _WelcomeLegalLine(),
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

class _CoachIntroStep extends StatelessWidget {
  const _CoachIntroStep({required this.onContinue});
  final VoidCallback onContinue;

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
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _PulsingCoachAvatar(),
                const SizedBox(height: 28),
                const Text(
                  'Merhaba 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 20, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Ben senin kişisel yapay zeka koçunum. '
                    'Şimdi sana birkaç hızlı soru soracağım ve '
                    'tamamen sana özel bir program çıkaracağım.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.55,
                      shadows: [Shadow(blurRadius: 16, color: Colors.black87)],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('DEVAM ET'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _neon,
                      foregroundColor: Colors.white,
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
              ],
            ),
          ),
        ),
      ],
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
  const _StepTitle({
    required this.title,
    this.subtitle,
    this.whyAskTitle,
    this.whyAskExplanation,
  });
  final String title;
  final String? subtitle;

  /// Phase 46 · optional "Neden soruyoruz?" tooltip. When
  /// [whyAskExplanation] is non-null, a subtle `Icons.info_outline`
  /// button renders flush-right of the title; tapping it surfaces
  /// [_showWhyAskSheet]. Left null on non-sensitive questions
  /// (gender, activity, current physique) so the chrome stays quiet
  /// everywhere it doesn't need to reassure the user.
  final String? whyAskTitle;
  final String? whyAskExplanation;

  @override
  Widget build(BuildContext context) {
    final showInfoButton = whyAskExplanation != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              if (showInfoButton) ...[
                const SizedBox(width: 8),
                _WhyAskButton(
                  title: whyAskTitle ?? 'Neden soruyoruz?',
                  explanation: whyAskExplanation!,
                ),
              ],
            ],
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

/// Subtle info button that sits flush-right of a step title and opens
/// a `_showWhyAskSheet` on tap. Surface rendering is deliberately
/// low-contrast so it doesn't compete with the primary answer options
/// — users who don't need reassurance never see it.
class _WhyAskButton extends StatelessWidget {
  const _WhyAskButton({required this.title, required this.explanation});
  final String title;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showWhyAskSheet(
          context,
          title: title,
          explanation: explanation,
        ),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: _neon.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.info_outline,
            color: _neon,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Phase 46 · "Neden soruyoruz?" reassurance sheet.
///
/// Called from the info buttons on sensitive wizard steps (Age,
/// Body Metrics, Target Physique). Keeps the explanation contained
/// in a modal so the user can dismiss it without losing their
/// place in the wizard. Background matches the onboarding purple
/// gradient so it reads as part of the same flow.
Future<void> _showWhyAskSheet(
  BuildContext context, {
  required String title,
  required String explanation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF221145), Color(0xFF0D0622)],
          ),
          border: Border.all(
            color: _neon.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: _neonAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _neon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                child: const Text('ANLADIM'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
          onPressed: onPressed,
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

class _GenderStep extends ConsumerWidget {
  const _GenderStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).gender;

    void pick(Gender g) {
      ref.read(wizardProvider.notifier).setGender(g);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Cinsiyetin?',
          subtitle: 'Programını sana göre kalibre edelim.',
        ),
        const SizedBox(height: 16),
        // Fills the full remaining step height: three Expanded cards
        // share the column evenly so there's no dead space at the bottom.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.female,
                    title: 'Kadın',
                    subtitle: 'Kadın için optimize edilmiş plan.',
                    selected: selected == Gender.female,
                    onTap: () => pick(Gender.female),
                    image: 'photos/cinsiyetseçimikadın.webp',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.male,
                    title: 'Erkek',
                    subtitle: 'Erkek için optimize edilmiş plan.',
                    selected: selected == Gender.male,
                    onTap: () => pick(Gender.male),
                    image: 'photos/cinsiyetseçimierkek.webp',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    fallbackIcon: Icons.transgender,
                    title: 'Diğer',
                    subtitle: 'Tarafsız bir plan oluşturalım.',
                    selected: selected == Gender.other,
                    onTap: () => pick(Gender.other),
                    // No bespoke artwork shipped for "Diğer" — text only.
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

class _AgeStep extends ConsumerStatefulWidget {
  const _AgeStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends ConsumerState<_AgeStep> {
  static const int _minAge = 18;
  static const int _maxAge = 80;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = (ref.read(wizardProvider).age ?? 25) - _minAge;
    _controller = FixedExtentScrollController(initialItem: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wizardProvider.notifier).setAge(_minAge + initial);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final age = ref.watch(wizardProvider).age ?? 25;
    return Column(
      children: [
        const _StepTitle(
          title: 'Yaşın kaç?',
          subtitle: 'Metabolizmana göre yoğunluğu ayarlayalım.',
          whyAskTitle: 'Yaşı neden soruyoruz?',
          whyAskExplanation: 'Bazal metabolizma hızı yaşla birlikte değişir. '
              'Günlük kalori ihtiyacını ve antrenman yoğunluğunu doğru '
              'hesaplamak için yaşına ihtiyacımız var. Veriler sadece '
              'senin hesabında tutulur, üçüncü taraflarla paylaşılmaz.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 48),
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
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 60,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  ref.read(wizardProvider.notifier).setAge(_minAge + i);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _maxAge - _minAge + 1,
                  builder: (context, i) {
                    final value = _minAge + i;
                    final selected = value == age;
                    return Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: selected ? _neon : Colors.white54,
                          fontSize: selected ? 42 : 28,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w500,
                          shadows: selected
                              ? [Shadow(blurRadius: 18, color: _neon)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Positioned(
                right: 32,
                child: Text(
                  'YAŞ',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        _PrimaryButton(label: 'DEVAM', onPressed: widget.onContinue),
      ],
    );
  }
}

class _BodyMetricsStep extends ConsumerStatefulWidget {
  const _BodyMetricsStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<_BodyMetricsStep> createState() => _BodyMetricsStepState();
}

class _BodyMetricsStepState extends ConsumerState<_BodyMetricsStep> {
  static const int _minHeight = 120;
  static const int _maxHeight = 220;
  static const int _minWeight = 30;
  static const int _maxWeight = 200;

  late final FixedExtentScrollController _heightController;
  late final FixedExtentScrollController _weightController;

  @override
  void initState() {
    super.initState();
    final initialHeight =
        (ref.read(wizardProvider).heightCm ?? 170) - _minHeight;
    final initialWeight =
        (ref.read(wizardProvider).weightKg ?? 70) - _minWeight;
    _heightController = FixedExtentScrollController(initialItem: initialHeight);
    _weightController = FixedExtentScrollController(initialItem: initialWeight);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wizardProvider.notifier).setHeight(_minHeight + initialHeight);
      ref.read(wizardProvider.notifier).setWeight(_minWeight + initialWeight);
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardProvider);
    return Column(
      children: [
        const _StepTitle(
          title: 'Boy & Kilo',
          subtitle: 'Kalori ve set hesaplarını buna göre yapacağız.',
          whyAskTitle: 'Boy ve kiloyu neden soruyoruz?',
          whyAskExplanation:
              'Kalori ihtiyacını ve günlük makro dağılımını (protein, '
              'karbonhidrat, yağ) doğru hesaplamak için fiziksel '
              'metriklerine ihtiyacımız var. Ayrıca antrenman şiddetini '
              've set sayısını sana göre ayarlayabilmemiz için önemli. '
              'Tüm bilgiler güvenli bir şekilde saklanır.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: WheelColumn(
                  label: 'BOY (cm)',
                  controller: _heightController,
                  min: _minHeight,
                  max: _maxHeight,
                  current: state.heightCm ?? 170,
                  onChanged: (v) =>
                      ref.read(wizardProvider.notifier).setHeight(v),
                ),
              ),
              Container(width: 1, color: Colors.white12),
              Expanded(
                child: WheelColumn(
                  label: 'KİLO (kg)',
                  controller: _weightController,
                  min: _minWeight,
                  max: _maxWeight,
                  current: state.weightKg ?? 70,
                  onChanged: (v) =>
                      ref.read(wizardProvider.notifier).setWeight(v),
                ),
              ),
            ],
          ),
        ),
        _PrimaryButton(label: 'DEVAM', onPressed: widget.onContinue),
      ],
    );
  }
}

class _CurrentPhysiqueStep extends ConsumerWidget {
  const _CurrentPhysiqueStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).currentPhysique;

    void pick(Physique p) {
      ref.read(wizardProvider.notifier).setCurrentPhysique(p);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Şu anki vücudun?',
          subtitle: 'Sana en yakın olanı seç.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/vücutseçimiZayıf.webp',
                    fallbackIcon: Icons.accessibility,
                    title: 'Zayıf',
                    subtitle: 'Düşük yağ, ince yapı.',
                    selected: selected == Physique.slim,
                    onTap: () => pick(Physique.slim),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    // Filename carries a "vucüt" typo that ships from the
                    // user's asset export; keep the path verbatim so the
                    // manifest lookup actually matches.
                    image: 'photos/vucütseçimiNormal.webp',
                    fallbackIcon: Icons.accessibility_new,
                    title: 'Normal',
                    subtitle: 'Ortalama yapı.',
                    selected: selected == Physique.normal,
                    onTap: () => pick(Physique.normal),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/vücutseçimikiloluhacimli.webp',
                    fallbackIcon: Icons.airline_seat_recline_extra,
                    title: 'Kilolu / Hacimli',
                    subtitle: 'Fazla yağ veya hacimli yapı.',
                    selected: selected == Physique.heavy,
                    onTap: () => pick(Physique.heavy),
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

class _TargetPhysiqueStep extends ConsumerWidget {
  const _TargetPhysiqueStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).targetPhysique;

    void pick(GoalPhysique g) {
      ref.read(wizardProvider.notifier).setTargetPhysique(g);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Hedefin ne?',
          subtitle: '30 gün sonra nereye varmak istersin?',
          whyAskTitle: 'Hedefini neden soruyoruz?',
          whyAskExplanation:
              '30 günlük programının tamamı hedefine göre kalibre '
              'edilir. Sıkılaşmak için kardiyo + full-body ağırlıklı '
              'bir plan, hacim kazanmak için güç antrenmanları, '
              'six-pack için ise core + stabilite çalışmaları '
              'öne çıkar. Bu tercih programının ilk günden doğru '
              'yönde ilerlemesini sağlar.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneSıkılaşmak.webp',
                    fallbackIcon: Icons.local_fire_department,
                    title: 'Sıkılaşmak',
                    subtitle: 'Yağ yak, kasları sıkılaştır.',
                    selected: selected == GoalPhysique.tone,
                    onTap: () => pick(GoalPhysique.tone),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneHacimKazanmak.webp',
                    fallbackIcon: Icons.fitness_center,
                    title: 'Hacim Kazanmak',
                    subtitle: 'Daha kalın, daha güçlü.',
                    selected: selected == GoalPhysique.bulk,
                    onTap: () => pick(GoalPhysique.bulk),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/hedefinneSadeceSix-Pack.webp',
                    fallbackIcon: Icons.bolt,
                    title: 'Sadece Six-Pack',
                    subtitle: 'Net çizgiler, belirgin karın.',
                    selected: selected == GoalPhysique.sixpack,
                    onTap: () => pick(GoalPhysique.sixpack),
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

class _ActivityStep extends ConsumerWidget {
  const _ActivityStep({required this.onSelected});
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wizardProvider).activityLevel;

    void pick(ActivityLevel a) {
      ref.read(wizardProvider.notifier).setActivityLevel(a);
      Future<void>.delayed(const Duration(milliseconds: 220), onSelected);
    }

    return Column(
      children: [
        const _StepTitle(
          title: 'Günlük aktiviten?',
          subtitle: 'Programın yoğunluğunu buna göre dengeleyeceğiz.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenmasabaşı.webp',
                    fallbackIcon: Icons.chair,
                    title: 'Masa Başı',
                    subtitle: 'Çoğunlukla otururum, az hareket ederim.',
                    selected: selected == ActivityLevel.sedentary,
                    onTap: () => pick(ActivityLevel.sedentary),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenhafifhareketli.webp',
                    fallbackIcon: Icons.directions_walk,
                    title: 'Hafif Hareketli',
                    subtitle: 'Düzenli yürüyüş, hafif egzersiz.',
                    selected: selected == ActivityLevel.light,
                    onTap: () => pick(ActivityLevel.light),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PhotoOptionCard(
                    image: 'photos/günlükaktivitenneÇokAktif.webp',
                    fallbackIcon: Icons.directions_run,
                    title: 'Çok Aktif',
                    subtitle: 'Düzenli antrenman, yüksek tempo.',
                    selected: selected == ActivityLevel.active,
                    onTap: () => pick(ActivityLevel.active),
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

// Nutrition wizard steps moved to
// `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart`
// in Phase 46. Surfaced on first Beslenme-tab view instead of inside
// primary onboarding so the path to /prediction stays short.
