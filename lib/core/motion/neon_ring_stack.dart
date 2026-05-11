import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Concentric neon-ring system that wraps a centered subject (typically
/// the coach avatar) on cinematic AI-presence scenes.
///
/// Visual structure, outer → inner:
///
///   1. **Segmented arc ring** — 8 short arcs evenly spaced on the
///      outer perimeter, rotating clockwise slowly. The gaps between
///      arcs are what makes the ring read as "high-tech computing
///      indicator" rather than a generic loading spinner.
///   2. **Solid thin ring** — a single circle just inside the
///      segmented ring, alpha breathing on a sine wave. The contrast
///      between rotating-segmented (energetic) and static-breathing
///      (calm) is what produces the "intelligent processing" feel.
///   3. **Orbit dots** — N small dots travelling counterclockwise on
///      a circle slightly outside the segmented ring. Counter-
///      rotation against the arcs reads as orbital depth, not a
///      uniform spin.
///   4. **Inner glow** — a soft blurred halo just behind the subject,
///      pulsing in sync with the breathing ring.
///
/// All four layers are painted in a single [CustomPainter] driven by
/// one [AnimationController] (modular phase math). Wrapped in
/// [RepaintBoundary] at the root so this widget's 60 Hz repaint never
/// bubbles into the parent or sibling layers — critical because the
/// subject inside has its own breathing/glow animation that must stay
/// isolated.
///
/// Restraint: stroke widths + alpha values are deliberately low. The
/// goal is "calm intelligent processing", not "flashy loader".
class NeonRingStack extends StatefulWidget {
  const NeonRingStack({
    super.key,
    required this.child,
    this.size = 220,
    this.primaryColor = const Color(0xFF4DA6FF),
    this.accentColor = const Color(0xFF8E5BFF),
    this.outerSegmentCount = 8,
    this.outerArcSweepDegrees = 16,
    this.outerRotationPeriod = const Duration(seconds: 14),
    this.solidRingBreathPeriod = const Duration(milliseconds: 4200),
    this.orbitDotCount = 5,
    this.orbitRotationPeriod = const Duration(seconds: 22),
  })  : assert(size > 0),
        assert(outerSegmentCount > 0),
        assert(outerArcSweepDegrees > 0 && outerArcSweepDegrees < 360),
        assert(orbitDotCount >= 0);

  /// What sits inside the ring stack — typically the avatar.
  final Widget child;

  /// Total outer diameter of the ring system (the outermost orbit dot
  /// path will fit within this; the segmented ring is slightly inside).
  final double size;

  /// Color for segmented arcs, inner glow, and orbit dots.
  final Color primaryColor;

  /// Color for the solid breathing ring. The visual interplay between
  /// the two colors gives the stack its depth.
  final Color accentColor;

  final int outerSegmentCount;
  final double outerArcSweepDegrees;
  final Duration outerRotationPeriod;
  final Duration solidRingBreathPeriod;

  final int orbitDotCount;
  final Duration orbitRotationPeriod;

  @override
  State<NeonRingStack> createState() => _NeonRingStackState();
}

class _NeonRingStackState extends State<NeonRingStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Reference master period. The controller runs on this exact
  /// duration, then individual ring/orbit phases are derived via
  /// modular math against their own periods. One controller is
  /// strictly cheaper than three, and the modular derivation is
  /// pixel-stable.
  static const Duration _master = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _master)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                painter: _RingStackPainter(
                  t: _ctrl.value,
                  masterMs: _master.inMilliseconds,
                  primary: widget.primaryColor,
                  accent: widget.accentColor,
                  outerSegmentCount: widget.outerSegmentCount,
                  outerArcSweepDegrees: widget.outerArcSweepDegrees,
                  outerRotationMs: widget.outerRotationPeriod.inMilliseconds,
                  solidBreathMs: widget.solidRingBreathPeriod.inMilliseconds,
                  orbitDotCount: widget.orbitDotCount,
                  orbitRotationMs: widget.orbitRotationPeriod.inMilliseconds,
                ),
                size: Size(widget.size, widget.size),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _RingStackPainter extends CustomPainter {
  _RingStackPainter({
    required this.t,
    required this.masterMs,
    required this.primary,
    required this.accent,
    required this.outerSegmentCount,
    required this.outerArcSweepDegrees,
    required this.outerRotationMs,
    required this.solidBreathMs,
    required this.orbitDotCount,
    required this.orbitRotationMs,
  });

  final double t;
  final int masterMs;
  final Color primary;
  final Color accent;
  final int outerSegmentCount;
  final double outerArcSweepDegrees;
  final int outerRotationMs;
  final int solidBreathMs;
  final int orbitDotCount;
  final int orbitRotationMs;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Orbital dots sit on the outermost path so they're the visual
    // boundary. Pull the segmented ring 6 px inside, then the solid
    // ring 8 px inside that.
    final orbitRadius = maxRadius - 4;
    final segmentRadius = orbitRadius - 8;
    final solidRadius = segmentRadius - 10;
    final glowRadius = solidRadius - 8;

    _paintGlow(canvas, center, glowRadius);
    _paintSolidRing(canvas, center, solidRadius);
    _paintSegmentedRing(canvas, center, segmentRadius);
    _paintOrbitDots(canvas, center, orbitRadius);
  }

  void _paintGlow(Canvas canvas, Offset center, double radius) {
    final breathPhase = _modPhase(solidBreathMs);
    // Soft bell: 0 at edges of cycle, 1 mid-cycle. Slight floor so the
    // glow never fully disappears.
    final breath = 0.55 + 0.45 * (1.0 - math.cos(breathPhase * math.pi * 2)) / 2.0;
    final paint = Paint()
      ..color = primary.withValues(alpha: 0.30 * breath)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintSolidRing(Canvas canvas, Offset center, double radius) {
    final breathPhase = _modPhase(solidBreathMs);
    final alpha = 0.55 + 0.30 * (1.0 - math.cos(breathPhase * math.pi * 2)) / 2.0;
    final paint = Paint()
      ..color = accent.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, paint);

    // Subtle inner halo on the same ring — gives the line a faint
    // bloom without needing a separate composited shader.
    final bloomPaint = Paint()
      ..color = accent.withValues(alpha: alpha * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, radius, bloomPaint);
  }

  void _paintSegmentedRing(Canvas canvas, Offset center, double radius) {
    final rotPhase = _modPhase(outerRotationMs); // 0..1 progress
    final rotation = rotPhase * math.pi * 2;
    final arcSweep = outerArcSweepDegrees * math.pi / 180;
    final segmentStride = (math.pi * 2) / outerSegmentCount;

    final paint = Paint()
      ..color = primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < outerSegmentCount; i++) {
      final start = rotation + i * segmentStride;
      canvas.drawArc(rect, start, arcSweep, false, paint);
    }

    // Bright "leading" arc — same length but brighter + slightly
    // thicker. Acts as the comet head; rest of the segments are the
    // trail. Direction matches rotation.
    final leadPaint = Paint()
      ..color = primary.withValues(alpha: 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, rotation, arcSweep, false, leadPaint);
  }

  void _paintOrbitDots(Canvas canvas, Offset center, double radius) {
    if (orbitDotCount == 0) return;
    // Counter-rotation against the segmented ring — orbital depth.
    final rotPhase = _modPhase(orbitRotationMs);
    final rotation = -rotPhase * math.pi * 2;
    final stride = (math.pi * 2) / orbitDotCount;
    final dotPaint = Paint()..color = primary.withValues(alpha: 0.9);
    final glowDotPaint = Paint()
      ..color = primary.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (int i = 0; i < orbitDotCount; i++) {
      final angle = rotation + i * stride;
      final pos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(pos, 2.2, glowDotPaint);
      canvas.drawCircle(pos, 1.6, dotPaint);
    }
  }

  /// Returns the local phase [0,1) for a layer with its own period,
  /// computed against the master controller's `t` (also [0,1)). The
  /// modular math means each layer cycles at its true period
  /// regardless of the master period being arbitrary.
  double _modPhase(int periodMs) {
    final masterT = t * masterMs;
    final localT = masterT % periodMs;
    return localT / periodMs;
  }

  @override
  bool shouldRepaint(_RingStackPainter old) =>
      old.t != t ||
      old.primary != primary ||
      old.accent != accent ||
      old.outerSegmentCount != outerSegmentCount;
}
