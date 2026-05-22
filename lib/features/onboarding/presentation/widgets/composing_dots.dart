import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';

/// Three pulsing dots — the universal "the other side is composing"
/// signal. Used inside a Form chat bubble during Phase 110's thinking
/// moment to read as "Form is preparing something for you", not as
/// "a loader is spinning."
///
/// Each dot pulses on its own phase offset (0.0 / 0.33 / 0.66) so
/// the wave reads as a left-to-right ripple. Dots brighten + scale
/// at their peak (intensity 0.35 → 1.0 alpha, 0.70 → 1.0 scale)
/// then dim back. Single shared [AnimationController] drives all
/// three — one ticker, three [AnimatedBuilder]s reading off the
/// same value.
///
/// Restraint matters: this is meant to read as a *quiet* signal.
/// Don't pump amplitude or speed up the cycle — the goal is "Form
/// is thoughtfully composing", not "loading bar."
class ComposingDots extends StatefulWidget {
  const ComposingDots({
    super.key,
    this.color = AppColors.neon,
    this.dotSize = 8,
    this.spacing = 7,
    this.cycle = const Duration(milliseconds: 1500),
  });

  final Color color;
  final double dotSize;
  final double spacing;
  final Duration cycle;

  @override
  State<ComposingDots> createState() => _ComposingDotsState();
}

class _ComposingDotsState extends State<ComposingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycle)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.dotSize + 4,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dot(0.0),
              SizedBox(width: widget.spacing),
              _dot(0.33),
              SizedBox(width: widget.spacing),
              _dot(0.66),
            ],
          );
        },
      ),
    );
  }

  Widget _dot(double phaseOffset) {
    final t = (_ctrl.value + phaseOffset) % 1.0;
    // Bell-shape via sine — peak at t=0.5, low at edges.
    final intensity = (math.sin(t * math.pi * 2 - math.pi / 2) + 1) / 2;
    final alpha = 0.35 + (0.65 * intensity);
    final scale = 0.70 + (0.30 * intensity);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: alpha),
        ),
      ),
    );
  }
}
