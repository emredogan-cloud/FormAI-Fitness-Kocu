import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../providers/wizard_provider.dart';

/// Post-onboarding "future self" hook. Dark neon palette, evolved to the
/// Phase-23 reference shape: hero card with the coach illustration + plan
/// facts, a pair of stat pills, a plan-features checklist, and a pulsing
/// "Planımı Göster" CTA that pushes the paywall.
class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen>
    with SingleTickerProviderStateMixin {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);
  static const Color _surface = Color(0xFF141028);

  static const List<String> _trMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const List<String> _planFeatures = [
    'AI destekli egzersiz kılavuzları',
    'Gerçek zamanlı form analizi',
    'Sesli koç motivasyonu',
    'İnteraktif 30 günlük takvim',
    'Kişisel kalori ve ağırlık takibi',
  ];

  late final AnimationController _pulse;
  late final DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _targetDate = DateTime.now().add(const Duration(days: 84));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    final month = _trMonths[(d.month - 1).clamp(0, 11)];
    return '${d.day} $month ${d.year}';
  }

  String _goalLabel(GoalPhysique? goal) {
    switch (goal) {
      case GoalPhysique.tone:
        return 'Sıkılaşmak';
      case GoalPhysique.bulk:
        return 'Hacim Kazanmak';
      case GoalPhysique.sixpack:
        return 'Six-Pack';
      case null:
        return 'Kişisel Hedef';
    }
  }

  String _difficultyLabel(ActivityLevel? level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Yeni Başlayan';
      case ActivityLevel.light:
        return 'Orta Düzey';
      case ActivityLevel.active:
        return 'İleri';
      case null:
        return 'Kişiye Özel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(wizardProvider);
    final goal = _goalLabel(wizard.targetPhysique);
    final difficulty = _difficultyLabel(wizard.activityLevel);

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.3,
            colors: [Color(0xFF1A0B3D), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () {
                if (context.canPop()) context.pop();
              }),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCard(
                        title: 'FormAI için Özel Plan',
                        goal: goal,
                        durationWeeks: 12,
                        difficulty: difficulty,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: _StatPill(
                              value: '25-40',
                              label: 'Egzersiz başına dakika',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _WeeklyTargetPill(checks: const [
                              false,
                              true,
                              false,
                              true,
                              false,
                              true,
                              true,
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _DateCard(
                        date: _formatDate(_targetDate),
                        pulse: _pulse,
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel(label: 'Plan'),
                      const SizedBox(height: 10),
                      _PlanChecklist(items: _planFeatures),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  children: [
                    _PulsingCta(
                      pulse: _pulse,
                      onTap: () => context.go(AppRoutes.paywall),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Planın seni bekliyor — kaçırma.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Planın hazır',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.goal,
    required this.durationWeeks,
    required this.difficulty,
  });

  final String title;
  final String goal;
  final int durationWeeks;
  final String difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        color: _PredictionScreenState._surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _PredictionScreenState._neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _PredictionScreenState._neon.withValues(alpha: 0.25),
            blurRadius: 26,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [
                      _PredictionScreenState._neon,
                      _PredictionScreenState._neonAccent,
                    ],
                  ).createShader(rect),
                  child: Text(
                    title,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _HeroFactRow(
                  icon: Icons.track_changes,
                  label: 'Hedef',
                  value: goal,
                ),
                const SizedBox(height: 10),
                _HeroFactRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Süre',
                  value: '$durationWeeks hafta',
                ),
                const SizedBox(height: 10),
                _HeroFactRow(
                  icon: Icons.bolt_outlined,
                  label: 'Zorluk',
                  value: difficulty,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: AspectRatio(
              aspectRatio: 0.85,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'photos/kişiselyapayzekakoçfoto.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _PredictionScreenState._neon,
                          _PredictionScreenState._neonAccent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
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

class _HeroFactRow extends StatelessWidget {
  const _HeroFactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _PredictionScreenState._neonAccent,
          size: 18,
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
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: _PredictionScreenState._surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _PredictionScreenState._neonAccent, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _PredictionScreenState._neonAccent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyTargetPill extends StatelessWidget {
  const _WeeklyTargetPill({required this.checks});
  final List<bool> checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: _PredictionScreenState._surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4 Egzersiz',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Hafta başına',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final done in checks)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    done ? Icons.check_circle : Icons.cancel,
                    color: done
                        ? _PredictionScreenState._neonAccent
                        : Colors.white24,
                    size: 14,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.date, required this.pulse});
  final String date;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.45 + pulse.value * 0.4;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF22115C), Color(0xFF0E0729)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _PredictionScreenState._neon.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _PredictionScreenState._neon.withValues(alpha: glow),
                blurRadius: 30,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                color: _PredictionScreenState._neonAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HEDEF TARİHİN',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(
                              blurRadius: 20,
                              color: _PredictionScreenState._neon,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '12 hafta',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _PlanChecklist extends StatelessWidget {
  const _PlanChecklist({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PredictionScreenState._surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _PredictionScreenState._neon.withValues(alpha: 0.22),
                    border: Border.all(
                      color:
                          _PredictionScreenState._neon.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (i < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PulsingCta extends StatelessWidget {
  const _PulsingCta({required this.pulse, required this.onTap});
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = 1.0 + pulse.value * 0.03;
        return Transform.scale(scale: scale, child: child);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _PredictionScreenState._neon.withValues(alpha: 0.65),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  _PredictionScreenState._neon,
                  _PredictionScreenState._neonAccent,
                ],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Planımı Göster',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
