import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The consumed-versus-target ring on the calorie dashboard.
///
/// A `CustomPainter` rather than a `CircularProgressIndicator` because
/// the ring has to do three things that widget cannot: overshoot past
/// 100% without clamping (going over your target is information, not an
/// error), carry a gradient sweep, and mark the current position with a
/// knob.
///
/// RTL note: this paints from a fixed angle in a fixed direction and does
/// NOT mirror. That is deliberate — a clock face and a progress dial read
/// the same way in every locale, and mirroring one makes it read as
/// counting down. `tool/check_directional_layout.dart` flags directional
/// painters, and this is the case where the flag is answered rather than
/// obeyed.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 168,
    this.centerLabel,
    this.centerSublabel,
  });

  final int consumed;
  final int target;
  final double size;
  final String? centerLabel;
  final String? centerSublabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A zero target would divide by zero and, worse, render as a full
    // ring — which would tell a user with no target set that they had
    // finished their day.
    final ratio = target <= 0 ? 0.0 : consumed / target;
    final over = ratio > 1.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              ratio: ratio,
              trackColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              // Over target switches to the warning colour rather than
              // just continuing round: the ring's own geometry cannot
              // express "past 100%" a second time.
              gradient: over
                  ? const [AppColors.orange, AppColors.danger]
                  : const [AppColors.neonDeep, AppColors.neon],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerSublabel != null)
                Text(
                  centerSublabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                centerLabel ?? '$consumed',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.trackColor,
    required this.gradient,
  });

  final double ratio;
  final Color trackColor;
  final List<Color> gradient;

  static const _stroke = 12.0;
  static const _start = -math.pi / 2; // 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(_stroke / 2, _stroke / 2) &
        Size(size.width - _stroke, size.height - _stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (ratio <= 0) return;

    // Cap the drawn sweep at one full turn. The colour already carries
    // "over target"; a second lap would paint over the first and read as
    // less progress rather than more.
    final sweep = math.min(ratio, 1.0) * math.pi * 2;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: gradient,
        transform: const GradientRotation(_start),
      ).createShader(rect);
    canvas.drawArc(rect, _start, sweep, false, arc);

    // Knob at the leading edge, so the exact position is readable at a
    // glance even when the arc's ends are near each other.
    final angle = _start + sweep;
    final centre = rect.center;
    final radius = rect.width / 2;
    final knob = Offset(
      centre.dx + radius * math.cos(angle),
      centre.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(knob, _stroke / 2 + 1.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio ||
      old.trackColor != trackColor ||
      old.gradient != gradient;
}
