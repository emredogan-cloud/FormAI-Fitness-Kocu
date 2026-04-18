import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';

/// Post-onboarding "future self" hook. Shows a dynamically computed date
/// 12 weeks out plus a pulsing CTA into the paywall — adapted from the
/// proven Cal AI / Noom-style commitment funnel.
class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  static const Color _neon = Color(0xFF8E5BFF);
  static const Color _neonAccent = Color(0xFF4DA6FF);

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

  late final AnimationController _pulse;
  late final DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    // 12-week horizon — far enough to feel transformative, close enough
    // to feel reachable on day one. Recomputed from the device clock so
    // returning visitors always see a fresh "today + 12w" date.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [Color(0xFF1A0B3D), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(child: _AiBadge()),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_neon, _neonAccent],
                  ).createShader(rect),
                  child: const Text(
                    'Özel Planın Hazır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _DateCard(date: _formatDate(_targetDate), pulse: _pulse),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Bu plana uyarsan tam olarak bu tarihte hayalindeki '
                    'fiziğe ulaşacaksın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _PulsingCta(
                  pulse: _pulse,
                  onTap: () => context.go(AppRoutes.paywall),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Planın seni bekliyor — kaçırma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _PredictionScreenState._neon.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _PredictionScreenState._neon.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: const Text(
        'AI HESAPLAMA TAMAMLANDI',
        style: TextStyle(
          color: _PredictionScreenState._neon,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF22115C), Color(0xFF0E0729)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _PredictionScreenState._neon.withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: _PredictionScreenState._neon.withValues(alpha: glow),
                blurRadius: 32,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'HEDEF TARİHİN',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  date,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        blurRadius: 24,
                        color: _PredictionScreenState._neon,
                      ),
                      Shadow(
                        blurRadius: 48,
                        color: _PredictionScreenState._neon,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '12 hafta sonra',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
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
                padding: EdgeInsets.symmetric(vertical: 22),
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
