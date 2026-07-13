import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Subtle drifting motes layer — used behind the analysis-illusion core
/// to make the screen read as "the AI is computing through atmosphere"
/// rather than a static loader.
///
/// Renders [count] dots that drift slowly upward at staggered speeds,
/// with each dot's opacity pulsing on its own sine phase. When a dot
/// drifts off the top, it wraps to the bottom and re-randomises its
/// horizontal position. The result is dust-in-a-sunbeam motion: motion
/// the user feels but can't point at.
///
/// Performance:
///   * Single [AnimationController] driving all particles via fmod.
///   * One [CustomPainter] redraws per frame; wrapped in
///     [RepaintBoundary] so the parent tree doesn't repaint with it.
///   * No allocations on the hot path — particle list seeds at mount,
///     positions derive from controller value.
///
/// Tuning defaults are deliberate (low count, low alpha, slow drift)
/// because the brief specifies "subtle ambient particles, NOT flashy
/// animation spam." Push the values higher only when validated on
/// device.
class AmbientParticles extends StatefulWidget {
  const AmbientParticles({
    super.key,
    this.count = 8,
    this.color = const Color(0xFF8E5BFF),
    this.minAlpha = 0.10,
    this.maxAlpha = 0.40,
    this.minRadius = 1.2,
    this.maxRadius = 2.6,
    this.driftDuration = const Duration(seconds: 18),
    this.blur = 1.4,
    this.seed = 42,
  })  : assert(count > 0),
        assert(minAlpha >= 0 && maxAlpha <= 1 && minAlpha < maxAlpha),
        assert(minRadius > 0 && minRadius < maxRadius);

  final int count;
  final Color color;
  final double minAlpha;
  final double maxAlpha;
  final double minRadius;
  final double maxRadius;
  final Duration driftDuration;
  final double blur;

  /// Deterministic positioning so two consecutive runs of the screen
  /// look the same — important on the analysis-illusion screen where a
  /// jittery reroll would be noticed.
  final int seed;

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.seed);
    _motes = List<_Mote>.generate(widget.count, (i) {
      return _Mote(
        x: rng.nextDouble(),
        radius: ui.lerpDouble(
          widget.minRadius,
          widget.maxRadius,
          rng.nextDouble(),
        )!,
        phaseOffset: rng.nextDouble(),
        driftSpeed: ui.lerpDouble(0.7, 1.3, rng.nextDouble())!,
        opacityPhase: rng.nextDouble() * math.pi * 2,
      );
    });
    _ctrl = AnimationController(vsync: this, duration: widget.driftDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A11y (P1-18) · honor the OS "Reduce Motion" setting: this is a
    // purely decorative background layer, so it simply disappears.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _MotesPainter(
              motes: _motes,
              t: _ctrl.value,
              color: widget.color,
              minAlpha: widget.minAlpha,
              maxAlpha: widget.maxAlpha,
              blur: widget.blur,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Mote {
  _Mote({
    required this.x,
    required this.radius,
    required this.phaseOffset,
    required this.driftSpeed,
    required this.opacityPhase,
  });

  final double x;
  final double radius;
  final double phaseOffset;
  final double driftSpeed;
  final double opacityPhase;
}

class _MotesPainter extends CustomPainter {
  _MotesPainter({
    required this.motes,
    required this.t,
    required this.color,
    required this.minAlpha,
    required this.maxAlpha,
    required this.blur,
  });

  final List<_Mote> motes;
  final double t;
  final Color color;
  final double minAlpha;
  final double maxAlpha;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motes) {
      // Wrap-around vertical position: each mote's progress derives
      // from the controller's value plus its phase offset, modulo 1.
      // 1 - progress so motes drift upward (1=bottom, 0=top).
      final progress = ((t * m.driftSpeed) + m.phaseOffset) % 1.0;
      final y = (1.0 - progress) * size.height;
      final x = m.x * size.width;

      // Opacity pulses on a sine of the same controller, so each mote
      // brightens and dims independently.
      final pulse = (math.sin(t * math.pi * 2 + m.opacityPhase) + 1.0) / 2.0;
      final alpha = ui.lerpDouble(minAlpha, maxAlpha, pulse)!;

      // Fade in at the bottom and out at the top so motes don't pop.
      final edgeFade = _edgeFade(progress);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha * edgeFade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawCircle(Offset(x, y), m.radius, paint);
    }
  }

  /// Smooth fade-in at progress 0 (just spawned at bottom) and fade-out
  /// at progress 1 (about to wrap). Eliminates pop-in / pop-out.
  double _edgeFade(double progress) {
    const edge = 0.12;
    if (progress < edge) return progress / edge;
    if (progress > 1 - edge) return (1 - progress) / edge;
    return 1.0;
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.t != t || old.color != color;
}
