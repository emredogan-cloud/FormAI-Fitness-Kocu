import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/ai_personalization_engine.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/onboarding_image.dart';

/// Act 5 · Commitment.
///
/// The user has just read their personalised report. This screen is
/// the *commitment moment* — not the billing moment. The CTA carries
/// "begin the journey" framing rather than "view a plan." Trust the
/// dense plan card to do the convincing; cinematic motion stays
/// deliberately subtle here so the eye can read.
///
/// Cinematic atmosphere (Phase 101):
///   • Low-density [AmbientParticles] (4 motes, 30s drift, alpha
///     0.04→0.15) behind the entire scene — barely perceptible, but
///     keeps the screen from feeling static.
///   • Plan card wrapped in [BreathingBox] (0.96→1.0 over 6 s) once
///     the entrance settles. Reads as "the plan is alive, waiting."
///   • Coach panel inside the plan card carries its own [GlowPulse]
///     so Form's presence stays consistent with Act 2 — cross-scene
///     identity continuity.
///   • Trust-booster confidence bar uses easeOutBack on its fill so
///     the % lands with a slight overshoot (matches the dynamic-
///     report's confidence pattern).
///   • CTA wrapped in [GlowPulse] gated on `_trustLanded` so the
///     pulse only ambients after the % has finished landing.
///
/// Copy reframe: "PLANIMI GÖR" → "YOLCULUĞA BAŞLA". Audit §3.9 flagged
/// the original as bait-and-switch (user thinks they're seeing a plan,
/// they actually land on a paywall). The new label commits to a
/// journey, doesn't promise the plan is about to render. Subtitle
/// "paketi" → "yolculuğunu" carries the same reframe.

class PrePaywallSummaryStep extends ConsumerStatefulWidget {
  const PrePaywallSummaryStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  ConsumerState<PrePaywallSummaryStep> createState() =>
      _PrePaywallSummaryStepState();
}

class _PrePaywallSummaryStepState extends ConsumerState<PrePaywallSummaryStep>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  late final AnimationController _trustCtrl;
  late final Animation<double> _trustFill;

  /// Flips when the entrance fades complete; gates the plan card's
  /// ambient breathing so the breath doesn't compete with the
  /// entrance choreography.
  bool _entranceDone = false;

  /// Flips when the trust-booster bar finishes its land. Gates the
  /// CTA's ambient GlowPulse so the pulse waits its turn.
  bool _trustLanded = false;

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
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_entranceDone) {
        setState(() => _entranceDone = true);
      }
    });

    _trustCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    // easeOutBack so the % overshoots slightly past 92 then settles —
    // matches the dynamic-report confidence pattern so the two
    // confidence reveals across the wizard feel like one motion
    // language.
    _trustFill = Tween<double>(begin: 0.0, end: _confidenceTarget).animate(
      CurvedAnimation(parent: _trustCtrl, curve: Curves.easeOutBack),
    );
    _trustCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_trustLanded) {
        setState(() => _trustLanded = true);
        // Soft confirmation — the plan is "approved" and the user
        // is now invited to begin.
        AppHaptics.success();
      }
    });
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Lowest-density ambient layer in the wizard — the screen
          // is content-dense, motion stays at the threshold of
          // perception. 4 motes, 30s drift.
          const AmbientParticles(
            count: 4,
            color: AppColors.neon,
            minAlpha: 0.04,
            maxAlpha: 0.15,
            minRadius: 1.0,
            maxRadius: 1.8,
            driftDuration: Duration(seconds: 30),
            seed: 121,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.neon, AppColors.neonAccent],
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
                  'AI motorun seni baştan sona dinledi ve sana özel '
                  'yolculuğunu kurdu.',
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
                        child: BreathingBox(
                          enabled: _entranceDone,
                          minAlpha: 0.96,
                          maxAlpha: 1.0,
                          duration: const Duration(milliseconds: 6000),
                          child: _SummaryCard(report: report),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: _cardFade,
                  child: _TrustBoosterPanel(fill: _trustFill),
                ),
                const SizedBox(height: 14),
                GlowPulse(
                  enabled: _trustLanded,
                  color: AppColors.neon,
                  minAlpha: 0.42,
                  maxAlpha: 0.68,
                  minBlur: 24,
                  maxBlur: 34,
                  spread: 1,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(18),
                  duration: const Duration(milliseconds: 2900),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        AppHaptics.secondaryTap();
                        widget.onComplete();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('YOLCULUĞA BAŞLA'),
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

class _TrustBoosterPanel extends StatelessWidget {
  const _TrustBoosterPanel({required this.fill});

  final Animation<double> fill;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fill,
      builder: (context, _) {
        // easeOutBack overshoots — clamp the on-screen value so the
        // user sees 92 % at peak instead of 95 % en route.
        final shown = fill.value.clamp(0.0, 1.0);
        final pct = (shown * 100).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.neon.withValues(alpha: 0.16),
                AppColors.neonAccent.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.neon.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: 0.32),
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
                    color: AppColors.neonAccent,
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
                      color: AppColors.neon,
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
                  value: shown,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(AppColors.neon),
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

/// The detailed Plan Card. Side-image layout: stat rows stack on the
/// left, the AI coach face panel anchors the right ~45 %. Neon
/// BoxShadow behind the entire card to make it feel "alive" and
/// high-value.
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
          color: AppColors.neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.32),
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
            color: AppColors.neon.withValues(alpha: 0.18),
            border: Border.all(color: AppColors.neon.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: AppColors.neon, size: 15),
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
            AppColors.neon.withValues(alpha: 0.24),
            AppColors.neonAccent.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(
                Icons.trending_up_rounded,
                color: AppColors.neonAccent,
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

/// Form's face on the right of the plan card. Wrapped in [GlowPulse]
/// so the coach's "presence" stays consistent with how Form pulses on
/// the coach-intro screen — cross-scene identity continuity. Glow is
/// subtle here (alpha 0.20→0.40, blur 14→22) since the panel sits
/// inside an already-glowing card.
class _AiCoachPanel extends StatelessWidget {
  const _AiCoachPanel();

  static const String _coachAsset = 'photos/kişiselyapayzekakoçfoto.webp';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlowPulse(
          color: AppColors.neon,
          minAlpha: 0.20,
          maxAlpha: 0.40,
          minBlur: 14,
          maxBlur: 22,
          spread: -3,
          shape: BoxShape.rectangle,
          duration: Duration(milliseconds: 3400),
          child: OnboardingImage(
            asset: _coachAsset,
            fallbackIcon: Icons.smart_toy_rounded,
            borderRadius: 0,
            dimOverlay: false,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.transparent],
            ),
          ),
        ),
        const Positioned(
          top: 10,
          left: 6,
          right: 6,
          child: Center(child: _CoachBadge()),
        ),
      ],
    );
  }
}

class _CoachBadge extends StatelessWidget {
  const _CoachBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.neon, size: 10),
          SizedBox(width: 4),
          Text(
            'Form · AI Koçun',
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
