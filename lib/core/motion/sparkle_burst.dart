import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Continuous neon-particle activity around a center. Used to wrap a
/// celebratory subject (typically the coach avatar on the social-proof
/// scene) and surround it with a soft, ambient sparkle field.
///
/// Each particle has its own staggered start time, random angular
/// direction, and individual lifespan. The result reads as "this thing
/// is alive and being celebrated" — not as a one-shot burst, not as a
/// confetti shower. The reference video's social-proof beat
/// (~0:59-1:01) shows the mascot with similar dynamic-sparkle energy;
/// this primitive is the FormAI-palette adaptation.
///
/// Performance: single shared [AnimationController] drives all
/// particles via modular phase math. One [CustomPainter] repaint per
/// frame, RepaintBoundary-isolated at the root.
///
/// Restraint: opacity and radius defaults are deliberately low. The
/// goal is "subtly alive", not "visual noise."
class SparkleBurst extends StatefulWidget {
  const SparkleBurst({
    super.key,
    required this.child,
    this.color = const Color(0xFF8E5BFF),
    this.particleCount = 8,
    this.maxRadius = 90,
    this.minLifetime = const Duration(milliseconds: 1100),
    this.maxLifetime = const Duration(milliseconds: 1700),
    this.minSize = 1.5,
    this.maxSize = 3.5,
    this.peakAlpha = 0.7,
    this.seed = 23,
  })  : assert(particleCount > 0),
        assert(peakAlpha > 0 && peakAlpha <= 1),
        assert(minSize > 0 && minSize <= maxSize);

  /// What the sparkles surround.
  final Widget child;

  final Color color;

  /// How many particles are alive in the field. Each has independent
  /// phase + direction. 8 is a comfortable "alive but not noisy"
  /// default; bump to 10-12 for stronger celebration energy.
  final int particleCount;

  /// How far from center each particle drifts at the end of its life.
  final double maxRadius;

  /// Lifespan range — each particle picks a deterministic-random
  /// duration in this range, so particles don't synchronise into a
  /// pulsing wave.
  final Duration minLifetime;
  final Duration maxLifetime;

  /// Visual size range. Sparkles start small, grow to max during
  /// flight, fade as they reach the outer edge.
  final double minSize;
  final double maxSize;

  /// Peak alpha during each particle's bright phase. Linearly fades
  /// in / out from this.
  final double peakAlpha;

  /// Deterministic random seed so the sparkle pattern is stable
  /// across rebuilds and test runs.
  final int seed;

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.seed);
    final minLifetimeMs = widget.minLifetime.inMilliseconds;
    final maxLifetimeMs = widget.maxLifetime.inMilliseconds;
    _sparks = List<_Spark>.generate(widget.particleCount, (i) {
      return _Spark(
        angle: rng.nextDouble() * math.pi * 2,
        lifetimeMs: minLifetimeMs +
            (rng.nextDouble() * (maxLifetimeMs - minLifetimeMs)).round(),
        size: widget.minSize +
            rng.nextDouble() * (widget.maxSize - widget.minSize),
        phaseOffset: rng.nextDouble(),
        radiusMult: 0.55 + 0.45 * rng.nextDouble(),
      );
    });
    // Master controller runs on the longest particle's lifetime so
    // the modular phase math wraps cleanly.
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: maxLifetimeMs),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A11y (P1-18) · honor the OS "Reduce Motion" setting: render the
    // resting frame instead of the continuous animation.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              painter: _SparklePainter(
                sparks: _sparks,
                t: _ctrl.value,
                masterDurationMs: _ctrl.duration!.inMilliseconds,
                color: widget.color,
                maxRadius: widget.maxRadius,
                peakAlpha: widget.peakAlpha,
              ),
              size: Size(widget.maxRadius * 2, widget.maxRadius * 2),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Spark {
  _Spark({
    required this.angle,
    required this.lifetimeMs,
    required this.size,
    required this.phaseOffset,
    required this.radiusMult,
  });

  /// Outward direction from center (radians).
  final double angle;

  /// How long this particle's full birth → fade cycle takes.
  final int lifetimeMs;

  /// Visual diameter at peak.
  final double size;

  /// Phase offset into the master cycle [0,1] so particles don't sync.
  final double phaseOffset;

  /// Multiplier on [maxRadius] for this particle's specific outer
  /// reach. 0.55-1.0 range gives natural variety — not every particle
  /// goes the same distance.
  final double radiusMult;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.sparks,
    required this.t,
    required this.masterDurationMs,
    required this.color,
    required this.maxRadius,
    required this.peakAlpha,
  });

  final List<_Spark> sparks;
  final double t;
  final int masterDurationMs;
  final Color color;
  final double maxRadius;
  final double peakAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final s in sparks) {
      // Each particle's local progress in its own lifetime,
      // independent of the others. Modular math means it wraps
      // continuously — there's never a "no sparkles" moment.
      final localCycle = s.lifetimeMs / masterDurationMs;
      final localT = ((t + s.phaseOffset) % localCycle) / localCycle;

      // Radius curve: starts at 0, grows to maxRadius * radiusMult,
      // with a slight ease-out so particles slow as they reach the
      // outer edge (more graceful than linear flight).
      final eased = 1.0 - math.pow(1.0 - localT, 2).toDouble();
      final radius = maxRadius * s.radiusMult * eased;

      // Alpha curve: bell — fades in over first 30%, plateaus 30-70%,
      // fades out over 70-100%. Reads as "particle exists, lives,
      // disappears" rather than "linearly fading throughout."
      final alphaCurve = _bellCurve(localT);
      final alpha = peakAlpha * alphaCurve;
      if (alpha < 0.01) continue;

      // Size also lifts and settles to give particles weight.
      final sizeCurve = 0.4 + 0.6 * alphaCurve;
      final spriteRadius = s.size * sizeCurve;

      final px = center.dx + math.cos(s.angle) * radius;
      final py = center.dy + math.sin(s.angle) * radius;

      // Soft glow under the dot, then a brighter core.
      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(px, py), spriteRadius * 1.6, glowPaint);

      final corePaint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), spriteRadius, corePaint);
    }
  }

  /// Symmetric bell — 0 at edges, 1 at center. Used for alpha + size.
  double _bellCurve(double x) {
    if (x <= 0 || x >= 1) return 0;
    // Smooth bell: 1 - cos(2πx) gives a soft hump.
    return (1.0 - math.cos(x * math.pi * 2)) / 2.0;
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t || old.color != color;
}
