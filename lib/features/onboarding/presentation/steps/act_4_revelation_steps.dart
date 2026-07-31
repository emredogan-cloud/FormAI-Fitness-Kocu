import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/morphing_number.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/ai_personalization_engine.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';
import '../../../../l10n/app_localizations.dart';

/// Act 4 · Revelation.
///
/// Two screens — the labor-illusion that builds anticipation, and the
/// dynamic AI report that lands the personalised insight. The pair is
/// the emotional climax of the data-collection arc; the user should
/// finish reading the report feeling *understood*, not *measured*.
///
/// Cinematic layering (Phase 100):
///   • Both screens get an [AmbientParticles] layer — slow drifting
///     motes that say "the AI is computing through atmosphere," not
///     "a loader is spinning."
///   • Analysis core wraps in [GlowPulse] and the central icon in
///     [BreathingBox] — the rotation stays, but the core now reads as
///     alive instead of mechanical.
///   • Report metric cards (BMI, daily kcal) animate in via
///     [MorphingNumber] from 0 to target with [MotionTokens.revealEase]
///     for slight overshoot — numbers *land* on their values.
///   • A new [_TransformationProjection] block sits between the metric
///     cards and the assessment paragraph — a 12-week timeline visual
///     drawing in left-to-right, with the engine's existing
///     `estimatedResults` outcome as the right-hand label. This is the
///     "future self emerging" moment.
///   • Confidence bar uses easeOutBack (via [MotionTokens.revealEase])
///     so the % land overshoots ~3 % then settles at the target —
///     reads as a number landing into place rather than filling
///     linearly.

// ─────────────────────────── analysis-illusion ──────────────────────────────

class AnalysisIllusionStep extends StatefulWidget {
  const AnalysisIllusionStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<AnalysisIllusionStep> createState() => _AnalysisIllusionStepState();
}

class _AnalysisIllusionStepState extends State<AnalysisIllusionStep>
    with TickerProviderStateMixin {
  static List<String> _phrasesFor(AppLocalizations l10n) => [
        l10n.analysisPhraseBody,
        l10n.analysisPhraseMetabolism,
        l10n.analysisPhraseMuscle,
        l10n.analysisPhraseFat,
        l10n.analysisPhrasePlan,
      ];

  /// The rotation timer starts in `initState`, before there is a
  /// `BuildContext` to resolve copy against, so the count it paces
  /// against is a constant. The assert in `build` keeps the two from
  /// drifting apart.
  static const int _phraseCount = 5;
  static const Duration _phraseDuration = Duration(milliseconds: 1200);

  Timer? _timer;
  int _index = 0;
  late final AnimationController _coreCtrl;

  /// Atmospheric breath cycle behind the rotating core. Slow (4.8 s)
  /// so the atmosphere feels patient even though the rotating core
  /// runs faster. Out-of-phase from the core ring on purpose — the
  /// scene shouldn't feel metronomic.
  late final AnimationController _atmosphereCtrl;

  @override
  void initState() {
    super.initState();
    _coreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _atmosphereCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat(reverse: true);
    _timer = Timer.periodic(_phraseDuration, (timer) {
      if (!mounted) return;
      if (_index >= _phraseCount - 1) {
        timer.cancel();
        // Final beat: heavy haptic so the user feels the illusion *land*
        // before the dynamic-report rises. This is the emotional pivot
        // from "AI is working" to "AI is showing you what it found."
        AppHaptics.milestone();
        Future<void>.delayed(_phraseDuration, () {
          if (mounted) widget.onComplete();
        });
      } else {
        final newIndex = _index + 1;
        // Subtle crescendo: light per intermediate phrase, medium on
        // the penultimate. The final-phrase milestone fires on
        // completion above.
        if (newIndex >= _phraseCount - 1) {
          AppHaptics.primaryCta();
        } else {
          AppHaptics.secondaryTap();
        }
        setState(() => _index = newIndex);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _coreCtrl.dispose();
    _atmosphereCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrases = _phrasesFor(AppLocalizations.of(context));
    assert(phrases.length == _phraseCount);
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Atmospheric breath — radial gradient that subtly inhales /
          // exhales behind the core, giving the scene depth without
          // adding any moving element the eye can lock onto.
          AnimatedBuilder(
            animation: _atmosphereCtrl,
            builder: (context, _) {
              final t =
                  MotionTokens.breathEase.transform(_atmosphereCtrl.value);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      AppColors.neon.withValues(alpha: 0.06 + 0.05 * t),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),
          const AmbientParticles(
            count: 10,
            color: AppColors.neon,
            minAlpha: 0.08,
            maxAlpha: 0.32,
            minRadius: 1.0,
            maxRadius: 2.4,
            driftDuration: Duration(seconds: 22),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Phase 106 · Form is visibly present during the
                // labor illusion — not just an abstract atmosphere.
                // `thinking` mood cools the halo to neonAccent and
                // speeds up the pulse to 2.0 s, so the user reads
                // "Form is computing." Smaller than the bonding-zone
                // avatar (90 / 60) so it sits above the rotating
                // core without competing for focus.
                const LivingCoachAvatar(
                  size: 90,
                  innerSize: 60,
                  mood: CoachMood.thinking,
                ),
                const SizedBox(height: 24),
                _AnalysisCore(progress: _coreCtrl),
                const SizedBox(height: 36),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: MotionTokens.reflectionEase,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: MotionTokens.reflectionEase,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    phrases[_index],
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
                  '${_index + 1} / ${phrases.length}',
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
        ],
      ),
    );
  }
}

/// The animated AI core. Outer halo + rotating sweep ring + inner
/// core. The rotating ring carries the "computing" motion; the inner
/// core breathes on its own slower cycle ([GlowPulse] 2.2 s) so the
/// two layers visibly drift in and out of phase. The icon inside the
/// core counter-rotates and breathes ([BreathingBox] 2.4 s).
class _AnalysisCore extends StatelessWidget {
  const _AnalysisCore({required this.progress});
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outermost soft halo — static radial gradient.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.neon.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Rotating sweep ring (only this rebuilds per frame).
          AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return Transform.rotate(
                angle: progress.value * 2 * math.pi,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.neon.withValues(alpha: 0),
                        AppColors.neonAccent,
                        AppColors.neon,
                        AppColors.neon.withValues(alpha: 0),
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
              );
            },
          ),
          // Inner core with its own breathing glow + counter-rotating
          // icon. The two breath cycles (2.2 s glow, 2.4 s icon) drift
          // out of phase on purpose.
          GlowPulse(
            color: AppColors.neon,
            minAlpha: 0.40,
            maxAlpha: 0.65,
            minBlur: 22,
            maxBlur: 32,
            spread: -2,
            duration: const Duration(milliseconds: 2200),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: AppColors.neon, width: 1.4),
              ),
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: progress,
                builder: (context, child) => Transform.rotate(
                  angle: -progress.value * math.pi,
                  child: child,
                ),
                child: const BreathingBox(
                  minAlpha: 0.78,
                  maxAlpha: 1.0,
                  duration: Duration(milliseconds: 2400),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.neon,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── dynamic-report ─────────────────────────────────

/// Per-element reveal record. Holds a [fade] (opacity 0 → 1 across a
/// sub-interval of the parent controller) plus a matching [slide]
/// (offset y +0.18 → 0). Constructed via [_DynamicReportStepState._makeReveal].
class _RevealAnim {
  const _RevealAnim({required this.fade, required this.slide});
  final Animation<double> fade;
  final Animation<Offset> slide;
}

class DynamicReportStep extends ConsumerStatefulWidget {
  const DynamicReportStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<DynamicReportStep> createState() => _DynamicReportStepState();
}

class _DynamicReportStepState extends ConsumerState<DynamicReportStep>
    with SingleTickerProviderStateMixin {
  static const double _confidenceTarget = 0.92;

  late final AnimationController _intro;
  late final Animation<double> _confidence;

  // Phase 106 · staggered scene composition. The single content
  // FadeTransition + SlideTransition wrapping the whole Column has
  // been replaced with seven per-element reveals so the eye is
  // guided sequentially through the report — Form first, then
  // title, then subtitle cascading down to the CTA. Reads as a
  // *directed* reveal rather than one synchronous block.
  // RC-1 P9 · the avatar/title/subtitle trio collapsed into one hero CARD
  // (reference: photos/kişisel_aı_raporun.png) so the reveal list shrank.
  late final _RevealAnim _heroReveal;
  late final _RevealAnim _metricsReveal;
  late final _RevealAnim _projectionReveal;
  late final _RevealAnim _assessmentReveal;
  late final _RevealAnim _ctaReveal;

  /// Set when the confidence bar finishes its land. Gates the CTA's
  /// ambient [GlowPulse] so it doesn't compete with the bar's filling.
  bool _confidenceLanded = false;

  @override
  void initState() {
    super.initState();
    // Phase 106 · scene span bumped 1600 → 1800 ms so the staggered
    // entrances breathe a little. Each element claims a window
    // inside this single controller; later elements peak after the
    // earlier ones have settled, so the eye is led from Form down
    // to the CTA in one continuous arc.
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _heroReveal = _makeReveal(0.00, 0.35);
    _metricsReveal = _makeReveal(0.25, 0.55);
    _projectionReveal = _makeReveal(0.30, 0.60);
    _assessmentReveal = _makeReveal(0.40, 0.70);
    _ctaReveal = _makeReveal(0.55, 1.00);

    // Confidence lands with easeOutBack — overshoots ~3 % past
    // target then settles. Reads as a number arriving at its place
    // rather than smoothly filling.
    _confidence = Tween<double>(begin: 0.0, end: _confidenceTarget).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_confidenceLanded) {
        setState(() => _confidenceLanded = true);
        AppHaptics.success();
      }
    });
  }

  /// Build a per-element fade + rise pair from a sub-interval of
  /// [_intro]. Both share the same easeOutCubic curve so adjacent
  /// reveals read as one motion language.
  _RevealAnim _makeReveal(double start, double end) {
    final fade = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(fade);
    return _RevealAnim(fade: fade, slide: slide);
  }

  Widget _staggered({required _RevealAnim reveal, required Widget child}) {
    return FadeTransition(
      opacity: reveal.fade,
      child: SlideTransition(position: reveal.slide, child: child),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(wizardProvider);
    final l10n = AppLocalizations.of(context);
    final report = AiPersonalizationEngine.generateReport(l10n, wizard);
    final bmi = report.bmi;
    final calories = report.maintenanceCalories;
    final assessment = report.assessment;

    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle ambient atmosphere behind the report — fewer / dimmer
          // motes than the analysis screen since the report is a
          // reading surface, not a pure-atmosphere moment.
          const AmbientParticles(
            count: 6,
            color: AppColors.neon,
            minAlpha: 0.05,
            maxAlpha: 0.18,
            minRadius: 1.0,
            maxRadius: 2.0,
            driftDuration: Duration(seconds: 28),
            seed: 73,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                // Everything above the CTA scrolls; the CTA itself is
                // pinned below it.
                //
                // Device QA (Huawei ANE-LX1, 1080×2280) found the report's
                // fixed-height children overflowing a shorter viewport,
                // which clipped "KİŞİSEL PLANIMI AL" and left it
                // untappable — onboarding could not be finished at all on
                // that phone. This is the third time a fixed-height
                // onboarding layout has pushed its primary CTA out of
                // reach (RC-17 paywall, RC-18 Başla), and it is fixed the
                // same proven way: a scroll area that can absorb any
                // shortfall, and a CTA that is structurally outside it so
                // no screen size can ever hide it.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _staggered(
                          reveal: _heroReveal,
                          child: const _ReportHeroCard(),
                        ),
                        const SizedBox(height: 14),
                        _staggered(
                          reveal: _metricsReveal,
                          child: Row(
                            children: [
                              Expanded(
                                child: _ReportMetricCard(
                                  label: 'BMI',
                                  morphingValue: bmi,
                                  formatter: (v) => v.toStringAsFixed(1),
                                  startDelay: const Duration(milliseconds: 200),
                                  icon: Icons.monitor_weight_outlined,
                                  gaugeFraction:
                                      ((bmi - 14.0) / 22.0).clamp(0.05, 1.0),
                                  statusLabel: _bmiCategory(l10n, bmi),
                                  statusColor: _bmiTint(bmi),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ReportMetricCard(
                                  label: l10n.reportMetricDailyCalories,
                                  morphingValue: calories.toDouble(),
                                  formatter: (v) => v.round().toString(),
                                  startDelay: const Duration(milliseconds: 350),
                                  icon: Icons.local_fire_department_rounded,
                                  gaugeFraction:
                                      (calories / 3200.0).clamp(0.05, 1.0),
                                  statusLabel: 'kcal',
                                  statusColor: AppColors.neonAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _staggered(
                          reveal: _projectionReveal,
                          child: _TransformationProjection(
                            outcome: report.estimatedResults,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _staggered(
                          reveal: _assessmentReveal,
                          child: BreathingBox(
                            minAlpha: 0.96,
                            maxAlpha: 1.0,
                            duration: const Duration(milliseconds: 5200),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.neon.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.neon.withValues(alpha: 0.15),
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
                                      Icon(
                                        Icons.psychology_outlined,
                                        color: AppColors.neonAccent,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      // Same reason as the CTA row: a
                                      // fixed Text in a Row has no give,
                                      // and this eyebrow is long enough
                                      // to overflow a narrow phone at an
                                      // accessibility text scale.
                                      Flexible(
                                          child: Text(
                                        l10n.reportAiAssessmentEyebrow,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.neonAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.6,
                                        ),
                                      )),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // RC-1 P9 · success probability as a RING + copy row
                // (reference layout) instead of a bare linear bar.
                AnimatedBuilder(
                  animation: _confidence,
                  builder: (context, _) {
                    // Clamp display: easeOutBack overshoots, but we
                    // don't want to show 95 % en route to 92 %.
                    final shown = _confidence.value.clamp(0.0, 1.0);
                    return Row(
                      children: [
                        _SuccessRing(fraction: shown),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.reportSuccessProbability,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.reportSuccessNearGoal,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: shown,
                                  minHeight: 5,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.neon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Pinned footer — structurally outside the scroll area,
                // so it is on screen at every viewport height.
                _staggered(
                  reveal: _ctaReveal,
                  child: GlowPulse(
                    enabled: _confidenceLanded,
                    color: AppColors.neon,
                    minAlpha: 0.40,
                    maxAlpha: 0.65,
                    minBlur: 24,
                    maxBlur: 34,
                    spread: 1,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(18),
                    duration: const Duration(milliseconds: 2900),
                    // RC-1 P9 · gradient two-line CTA per the reference:
                    // sparkle + 'KİŞİSEL PLANIMI AL' with the mission
                    // subline. Material+InkWell keeps the ripple.
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.neon, AppColors.neonAccent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            AppHaptics.secondaryTap();
                            widget.onComplete();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    // Scales down rather than ellipsising:
                                    // a primary CTA reading "KİŞİSEL PLA…"
                                    // is worse than one a point smaller.
                                    // Wide letter-spacing plus a 1.3 text
                                    // scale overflows a 360dp phone
                                    // otherwise.
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          l10n.reportPrimaryCta,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2.2,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.reportCtaSubtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

/// RC-1 P9 · BMI category label/tint for the metric card status line
/// (reference shows "24.2 / Normal" in green). Standard WHO bands; the
/// wording stays descriptive, not diagnostic.
String _bmiCategory(AppLocalizations l10n, double bmi) {
  if (bmi < 18.5) return l10n.bmiLow;
  if (bmi < 25.0) return l10n.bmiNormal;
  if (bmi < 30.0) return l10n.bmiHigh;
  return l10n.bmiVeryHigh;
}

Color _bmiTint(double bmi) {
  if (bmi >= 18.5 && bmi < 25.0) return AppColors.neonGreen;
  if (bmi < 18.5 || bmi < 30.0) return const Color(0xFFEAFF00);
  return const Color(0xFFFF5577);
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.morphingValue,
    required this.formatter,
    required this.icon,
    required this.startDelay,
    required this.gaugeFraction,
    required this.statusLabel,
    required this.statusColor,
  });

  final String label;
  final double morphingValue;
  final String Function(double) formatter;
  final IconData icon;
  final Duration startDelay;

  /// 0..1 sweep of the gauge arc around the icon (reference: circular
  /// gauges on the BMI + calorie cards).
  final double gaugeFraction;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon wrapped in an animated gauge arc — reads as a measured
          // value, not a decoration. Sweep tweens in with the card.
          SizedBox(
            width: 44,
            height: 44,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: gaugeFraction),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => CustomPaint(
                painter: _GaugeArcPainter(fraction: v, color: statusColor),
                child: child,
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                MorphingNumber(
                  value: morphingValue,
                  formatter: formatter,
                  startDelay: startDelay,
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

/// Partial ring around the metric icon — a ~270° gauge whose sweep maps
/// the metric onto its plausible range.
class _GaugeArcPainter extends CustomPainter {
  const _GaugeArcPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(2.5);
    const start = 2.2; // radians — opens bottom-left like the reference
    const maxSweep = 5.0;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(inset, start, maxSweep, false, track);
    canvas.drawArc(
        inset, start, maxSweep * fraction.clamp(0.0, 1.0), false, value);
  }

  @override
  bool shouldRepaint(_GaugeArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// RC-1 P9 · hero card per photos/kişisel_aı_raporun.png — Form's portrait
/// left; "AI HAZIR" chip, the two-line gradient title, and the ready-line
/// right. Replaces the plain centered avatar + title.
class _ReportHeroCard extends StatelessWidget {
  const _ReportHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neon.withValues(alpha: 0.14),
            Colors.black.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neon.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neon.withValues(alpha: 0.4),
                  blurRadius: 22,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/PT_FORM.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.smart_toy,
                  color: AppColors.neon,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.neonGreen.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _PulsingDot(),
                      SizedBox(width: 5),
                      Text(
                        'AI HAZIR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.white, AppColors.neon],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(rect),
                  child: Text(
                    AppLocalizations.of(context).reportHeaderTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context).reportReadySubtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live-status dot inside the AI HAZIR chip.
class _PulsingDot extends StatelessWidget {
  const _PulsingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.neonGreen,
        boxShadow: [
          BoxShadow(
            color: AppColors.neonGreen.withValues(alpha: 0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// RC-1 P9 · circular %92 ring for the success-probability row.
class _SuccessRing extends StatelessWidget {
  const _SuccessRing({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: fraction,
            strokeWidth: 5,
            strokeCap: StrokeCap.round,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(AppColors.neon),
          ),
          Center(
            child: Text(
              '%$pct',
              style: const TextStyle(
                color: AppColors.neon,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 112 · transformation graph (replaces the old horizontal
/// timeline). A diagonal trajectory line drawn over a faint grid,
/// with a dim BUGÜN dot at the bottom-left, a glowing 12 HAFTA dot
/// at the upper-right, and a soft gradient area-fill under the
/// curve. Reads as "future-self projection" — premium, serious,
/// emotionally grounded — not as "startup analytics chart."
///
/// Reference timestamp: ~0:57 (Unrot's "Day 1 → Day 30" two-point
/// comparison line). Mechanic adapted; aesthetic kept FormAI-dark
/// premium. The line draws in over 1.6 s (slightly longer than the
/// previous 1.4 s — gives the trajectory a more deliberate cinematic
/// dwell) and lands the endpoint glow as the line completes.
///
/// Still avoids invented kg numbers — the engine's `estimatedResults`
/// strings are the only outcome data we can claim. The graph shows
/// *direction*; the outcome text below carries the goal-specific
/// promise.
class _TransformationProjection extends StatefulWidget {
  const _TransformationProjection({required this.outcome});
  final String outcome;

  @override
  State<_TransformationProjection> createState() =>
      _TransformationProjectionState();
}

class _TransformationProjectionState extends State<_TransformationProjection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Lands a beat after the metric cards' MorphingNumbers settle so
    // the eye reads the row as a sequence (numbers → projection)
    // rather than two simultaneous reveals competing.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _draw.forward();
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.neon.withValues(alpha: 0.10),
            AppColors.neonAccent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.16),
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
              Icon(
                Icons.show_chart_rounded,
                color: AppColors.neonAccent,
                size: 14,
              ),
              SizedBox(width: 6),
              // Third fixed-Text-in-a-Row on this screen; same give.
              Flexible(
                child: Text(
                  l10n.reportProjectionEyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neonAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _draw,
            builder: (context, _) => SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _TrajectoryPainter(
                  progress: _draw.value,
                  startLabel: l10n.reportTrajectoryStart,
                  endLabel: l10n.reportTrajectoryEnd,
                ),
                size: const Size(double.infinity, 110),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              widget.outcome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.3,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trajectory canvas — bottom-left BUGÜN dot, upper-right 12
/// HAFTA dot, diagonal neon line drawn from start to current
/// progress, faint horizontal gridlines, and a gradient area-fill
/// under the line. Endpoint glow + label appear in the last 15 % of
/// the draw so the user reads the line *landing* on its destination.
class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({
    required this.progress,
    required this.startLabel,
    required this.endLabel,
  });

  final double progress;

  /// Drawn straight onto the canvas, so the copy has to be resolved by
  /// the widget above and handed down — a painter has no context.
  final String startLabel;
  final String endLabel;

  static const double _padX = 28;
  static const double _padTop = 16;
  static const double _padBottom = 26;
  static const int _gridLines = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(_padX, size.height - _padBottom);
    final end = Offset(size.width - _padX, _padTop);

    _drawGrid(canvas, size);

    // Current end of the in-progress line.
    final currentEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy + (end.dy - start.dy) * progress,
    );

    if (progress > 0) {
      _drawAreaFill(canvas, size, start, currentEnd);
      _drawLineWithGlow(canvas, start, currentEnd);
    }

    _drawStartDot(canvas, start);
    if (progress > 0.85) {
      final reveal = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
      _drawEndDot(canvas, end, reveal);
    }

    _drawLabel(canvas, startLabel, Offset(start.dx - 2, start.dy + 8),
        AppColors.neon.withValues(alpha: 0.70),
        align: _LabelAlign.left);
    if (progress > 0.92) {
      _drawLabel(
          canvas, endLabel, Offset(end.dx + 2, end.dy - 16), AppColors.neon,
          align: _LabelAlign.right);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neon.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final innerHeight = size.height - _padTop - _padBottom;
    for (var i = 0; i <= _gridLines; i++) {
      final y = _padTop + innerHeight * (i / _gridLines);
      canvas.drawLine(
        Offset(_padX, y),
        Offset(size.width - _padX, y),
        paint,
      );
    }
  }

  void _drawAreaFill(Canvas canvas, Size size, Offset start, Offset end) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(end.dx, size.height - _padBottom)
      ..lineTo(start.dx, size.height - _padBottom)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.neon.withValues(alpha: 0.30),
          AppColors.neon.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
  }

  void _drawLineWithGlow(Canvas canvas, Offset start, Offset end) {
    final glow = Paint()
      ..color = AppColors.neon.withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawLine(start, end, glow);

    final stroke = Paint()
      ..color = AppColors.neon
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, stroke);
  }

  void _drawStartDot(Canvas canvas, Offset start) {
    final fill = Paint()..color = AppColors.neon.withValues(alpha: 0.55);
    canvas.drawCircle(start, 4.5, fill);
    final ring = Paint()
      ..color = AppColors.neon
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(start, 4.5, ring);
  }

  void _drawEndDot(Canvas canvas, Offset end, double reveal) {
    final glow = Paint()
      ..color = AppColors.neon.withValues(alpha: reveal * 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(end, 14, glow);
    final fill = Paint()..color = AppColors.neon.withValues(alpha: reveal);
    canvas.drawCircle(end, 6.5, fill);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    required _LabelAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == _LabelAlign.right ? anchor.dx - tp.width : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) =>
      old.progress != progress ||
      old.startLabel != startLabel ||
      old.endLabel != endLabel;
}

enum _LabelAlign { left, right }
