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
      if (_index >= _phrases.length - 1) {
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
        if (newIndex >= _phrases.length - 1) {
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
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  /// Set when the confidence bar finishes its land. Gates the CTA's
  /// ambient [GlowPulse] so it doesn't compete with the bar's filling.
  bool _confidenceLanded = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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
    // Confidence lands with easeOutBack — overshoots ~3 % past target
    // then settles. Reads as a number arriving at its place rather
    // than smoothly filling.
    _confidence = Tween<double>(begin: 0.0, end: _confidenceTarget).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_confidenceLanded) {
        setState(() => _confidenceLanded = true);
        // Soft success haptic when the % lands — the AI has finished
        // *delivering* the report.
        AppHaptics.success();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(wizardProvider);
    final report = AiPersonalizationEngine.generateReport(wizard);
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
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [AppColors.neon, AppColors.neonAccent],
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
                            morphingValue: bmi,
                            formatter: (v) => v.toStringAsFixed(1),
                            startDelay: const Duration(milliseconds: 200),
                            icon: Icons.monitor_weight_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ReportMetricCard(
                            label: 'GÜNLÜK KAL.',
                            morphingValue: calories.toDouble(),
                            formatter: (v) => v.round().toString(),
                            startDelay: const Duration(milliseconds: 350),
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TransformationProjection(outcome: report.estimatedResults),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: BreathingBox(
                          minAlpha: 0.96,
                          maxAlpha: 1.0,
                          duration: const Duration(milliseconds: 5200),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.neon.withValues(alpha: 0.35),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neon.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.psychology_outlined,
                                      color: AppColors.neonAccent,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'AI DEĞERLENDİRMESİ',
                                      style: TextStyle(
                                        color: AppColors.neonAccent,
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
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _confidence,
                      builder: (context, _) {
                        // Clamp display: easeOutBack overshoots, but we
                        // don't want to show 95 % en route to 92 %.
                        final shown = _confidence.value.clamp(0.0, 1.0);
                        final pct = (shown * 100).round();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
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
                                    color: AppColors.neon,
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
                                value: shown,
                                minHeight: 6,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.neon,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    GlowPulse(
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
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            AppHaptics.secondaryTap();
                            widget.onComplete();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.neon,
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
        ],
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.morphingValue,
    required this.formatter,
    required this.icon,
    required this.startDelay,
  });

  final String label;
  final double morphingValue;
  final String Function(double) formatter;
  final IconData icon;
  final Duration startDelay;

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
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neon.withValues(alpha: 0.18),
              border: Border.all(
                color: AppColors.neon.withValues(alpha: 0.5),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "12 haftalık yolculuk" — a draw-in timeline visual: BUGÜN dot on
/// the left, neon line drawing in 0 → 1 over 1.4 s, 12 HAFTA glow dot
/// on the right, with the engine's [AiReport.estimatedResults] string
/// rendered below as the right-hand outcome label.
///
/// Deliberately avoids invented kg numbers — the engine's
/// estimatedResults strings are the only outcome data we can claim,
/// so the timeline visualises a *journey*, not a *measurement*.
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
      duration: const Duration(milliseconds: 1400),
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
            children: const [
              Icon(
                Icons.timeline_rounded,
                color: AppColors.neonAccent,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                '12 HAFTALIK YOLCULUK',
                style: TextStyle(
                  color: AppColors.neonAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                const _TimelineDot(label: 'BUGÜN', highlighted: false),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _draw,
                    builder: (context, _) =>
                        _TimelineLine(progress: _draw.value),
                  ),
                ),
                const _TimelineDot(label: '12 HAFTA', highlighted: true),
              ],
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

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.label, required this.highlighted});
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted
                  ? AppColors.neon
                  : AppColors.neon.withValues(alpha: 0.4),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: AppColors.neon.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _TimelinePainter(progress: progress),
        size: const Size(double.infinity, 14),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    // Dotted background line — full width, dim.
    final dim = Paint()..color = AppColors.neon.withValues(alpha: 0.25);
    const dotSpacing = 6.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, cy), 0.9, dim);
      x += dotSpacing;
    }
    // Solid neon line up to current progress.
    final lit = Paint()
      ..color = AppColors.neon
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final endX = size.width * progress;
    if (endX > 0) {
      canvas.drawLine(Offset(0, cy), Offset(endX, cy), lit);
    }
    // Glow at the leading edge while drawing.
    if (progress > 0 && progress < 1) {
      final glow = Paint()
        ..color = AppColors.neon.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(endX, cy), 3, glow);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.progress != progress;
}
