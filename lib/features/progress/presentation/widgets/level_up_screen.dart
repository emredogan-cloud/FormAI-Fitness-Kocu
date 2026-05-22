import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/level_titles.dart';

const Color _gold = Color(0xFFE0B547);
const Color _goldDeep = Color(0xFFC18D2A);
const Color _amber = Color(0xFFF59E0B);

/// Progress redesign Phase 3.E · level-up celebration.
///
/// Same choreography skeleton as `BadgeCelebrationScreen` but distinct
/// visual register: **gold/amber palette** (not neon purple), **chevron
/// sigil** (not a medallion + emoji), **30 quieter particles** (not
/// 40), **YENİ SEVİYE eyebrow** (not YENİ ROZET AÇILDI). The point is
/// that level-up is a *consequence* of badges + workouts, not its own
/// "earning" moment — the visual language reflects that.
///
/// Public API mirrors `BadgeCelebrationScreen.push` so the
/// dashboard's celebration queue stays uniform.
class LevelUpScreen extends StatefulWidget {
  const LevelUpScreen({
    super.key,
    required this.level,
    required this.tier,
  });

  final int level;
  final LevelTier tier;

  static Future<void> push(
    BuildContext context, {
    required int level,
    required LevelTier tier,
  }) {
    HapticFeedback.heavyImpact();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => LevelUpScreen(level: level, tier: tier),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen>
    with TickerProviderStateMixin {
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  late final List<_GoldParticle> _particles = _GoldParticle.spawn(30);

  bool _firedClick = false;
  bool _firedMedium = false;

  @override
  void initState() {
    super.initState();
    _timeline.addListener(_maybeFireHaptics);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _timeline.forward();
    });
  }

  void _maybeFireHaptics() {
    final t = _timeline.value;
    if (!_firedClick && t >= 0.14) {
      HapticFeedback.selectionClick();
      _firedClick = true;
    }
    if (!_firedMedium && t >= 0.39) {
      HapticFeedback.mediumImpact();
      _firedMedium = true;
    }
  }

  @override
  void dispose() {
    _timeline
      ..removeListener(_maybeFireHaptics)
      ..dispose();
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_timeline, _breathing]),
          builder: (context, _) {
            final t = _timeline.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: t > 0.6 ? () => Navigator.of(context).pop() : null,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _eyebrow(t),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (t >= 0.39)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GoldParticlesPainter(
                                    progress:
                                        ((t - 0.39) / 0.50).clamp(0.0, 1.0),
                                    particles: _particles,
                                  ),
                                ),
                              ),
                            _sigil(t),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      _label(t),
                      const SizedBox(height: 10),
                      _subtitle(t),
                      const SizedBox(height: 34),
                      _cta(t),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _eyebrow(double t) {
    final segT = ((t - 0.05) / 0.20).clamp(0.0, 1.0);
    return Opacity(
      opacity: segT,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - segT)),
        child: const Text(
          'YENİ SEVİYE',
          style: TextStyle(
            color: _amber,
            fontSize: 12,
            letterSpacing: 5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _sigil(double t) {
    double scale;
    if (t <= 0.14) {
      scale = 0.0;
    } else if (t <= 0.50) {
      final s = (t - 0.14) / 0.36;
      scale = Curves.elasticOut.transform(s);
    } else {
      final breathe = 1.0 + (_breathing.value - 0.5) * 0.04;
      scale = breathe;
    }
    final glow = 0.45 + _breathing.value * 0.4;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_gold, _goldDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: glow),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        // Chevron sigil — three stacked carets reading "ascent" without
        // any character or mascot.
        child: const Icon(
          Icons.keyboard_double_arrow_up_rounded,
          color: Colors.white,
          size: 84,
        ),
      ),
    );
  }

  Widget _label(double t) {
    final segT = ((t - 0.61) / 0.18).clamp(0.0, 1.0);
    return Opacity(
      opacity: segT,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - segT)),
        child: Text(
          'Lv ${widget.level} · ${widget.tier.title}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _subtitle(double t) {
    final segT = ((t - 0.72) / 0.18).clamp(0.0, 1.0);
    return Opacity(
      opacity: segT,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Text(
          _subtitleFor(widget.tier),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14.5,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _cta(double t) {
    final segT = ((t - 0.83) / 0.17).clamp(0.0, 1.0);
    return Opacity(
      opacity: segT,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                fontSize: 14.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('DEVAM'),
          ),
        ),
      ),
    );
  }
}

/// Tiny corpus of dignified one-liners. Kept short on purpose — a
/// level-up is rare enough that even 5 strings feel fresh, and a long
/// corpus would push toward gamer-toned territory the user explicitly
/// ruled out.
String _subtitleFor(LevelTier tier) {
  if (tier.minLevel >= 30) {
    return 'Az insan buraya gelir. Sen geldin.';
  }
  if (tier.minLevel >= 20) {
    return 'Disiplin sonuç vermeye başladı. Aynen böyle devam.';
  }
  if (tier.minLevel >= 10) {
    return 'Tutarlılık karakter haline geldi.';
  }
  return 'Bir sonraki seviyeye doğru.';
}

class _GoldParticle {
  _GoldParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.lifetime,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double lifetime;

  static List<_GoldParticle> spawn(int count) {
    final rng = math.Random();
    return List.generate(count, (i) {
      final theta = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.5;
      final speed = 70.0 + rng.nextDouble() * 110.0;
      final size = 3.0 + rng.nextDouble() * 3.5;
      final color = _palette[rng.nextInt(_palette.length)];
      final lifetime = 0.65 + rng.nextDouble() * 0.35;
      return _GoldParticle(
        angle: theta,
        speed: speed,
        size: size,
        color: color,
        lifetime: lifetime,
      );
    });
  }

  // Gold-only palette — quieter than the badge celebration's rainbow.
  static const List<Color> _palette = [
    _gold,
    _goldDeep,
    _amber,
    Color(0xFFFFE9A0),
  ];
}

class _GoldParticlesPainter extends CustomPainter {
  _GoldParticlesPainter({required this.progress, required this.particles});

  final double progress;
  final List<_GoldParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const gravity = 200.0;

    for (final p in particles) {
      final t = (progress / p.lifetime).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final dx = math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(centerX + dx, centerY + dy);
      canvas.rotate(p.angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size * 1.5,
        height: p.size,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(p.size * 0.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GoldParticlesPainter old) =>
      old.progress != progress || old.particles != particles;
}
