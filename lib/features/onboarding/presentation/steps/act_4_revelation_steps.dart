import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/ai_personalization_engine.dart';
import '../../providers/wizard_provider.dart';

/// Act 4 · Revelation.
///
/// Two screens: the labor-illusion (cycles five "AI thinking" phrases
/// over a rotating neon core) and the dynamic AI report (BMI + calorie
/// cards + personalised assessment + animated 92% confidence bar). The
/// confidence bar is currently a fixed target — moving to per-user
/// dynamic confidence is a Phase 1 audit item still pending.

// ─────────────────────────── analysis-illusion ──────────────────────────────

class AnalysisIllusionStep extends StatefulWidget {
  const AnalysisIllusionStep({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<AnalysisIllusionStep> createState() => _AnalysisIllusionStepState();
}

class _AnalysisIllusionStepState extends State<AnalysisIllusionStep>
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
                      AppColors.neon.withValues(alpha: 0.25),
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
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: AppColors.neon, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neon.withValues(alpha: 0.55),
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
                    color: AppColors.neon,
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
                            value: _confidence.value,
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
