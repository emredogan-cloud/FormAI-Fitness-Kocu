import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/ai_personalization_engine.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/onboarding_image.dart';

/// Act 5 · Commitment.
///
/// Pre-paywall summary screen. Pulls the AI report from the engine and
/// renders the plan as a side-image card (left = stat rows, right =
/// coach face panel). A trust-booster confidence bar fills 0 → 92 %
/// just before the CTA so the % land is the last thing the user sees.

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
                      color: AppColors.neon.withValues(alpha: 0.55),
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
        final pct = (fill.value * 100).round();
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
                  value: fill.value,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.neon),
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
/// left, the AI coach face panel anchors the right ~45 %. Neon BoxShadow
/// behind the entire card to make it feel "alive" and high-value.
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
            border:
                Border.all(color: AppColors.neon.withValues(alpha: 0.5)),
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
