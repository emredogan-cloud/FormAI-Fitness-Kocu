import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extension.dart';
import '../../domain/trend_calculator.dart';

/// Roadmap Phase 9 (C1) · the weight / measurement chart.
///
/// Extends the `_AreaLinePainter` approach the Progress tab already uses
/// — a cubic-bezier stroke over a bottom-anchored gradient — rather than
/// adding a charting dependency. Keeps the bundle flat and the visual
/// language consistent, which the roadmap asked for explicitly.
///
/// What is different from that painter, and why:
///
///   * **It draws two series.** The raw observations as faint dots, the
///     smoothed line as the stroke. A weight chart that plots only raw
///     readings tells a user their body gained a kilo overnight; one
///     that plots only the trend hides the readings they typed. Both,
///     with the trend dominant, is the honest arrangement.
///   * **It has a target line**, when and only when the user set one.
///   * **It carries a direction.** A painter cannot read the ambient
///     `Directionality`, so it is handed one — the Phase 8 rule, learned
///     from two painters that laid out localized copy left-to-right
///     forever. The time axis itself deliberately does NOT mirror: weeks
///     run earlier-to-later, and flipping that would say the user's
///     history ran backwards.
class BodyTrendChart extends StatelessWidget {
  const BodyTrendChart({
    super.key,
    required this.points,
    required this.targetValue,
    required this.targetLabel,
    this.height = 180,
  });

  final List<TrendPoint> points;

  /// The user's own stated target, in the same unit as [points]. Null
  /// means no line — which is a valid permanent state, not a gap.
  final double? targetValue;

  /// Localized caption for the target line, painted at its right end.
  final String targetLabel;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BodyTrendPainter(
          points: points,
          targetValue: targetValue,
          targetLabel: targetLabel,
          lineColor: scheme.primary,
          dotColor: scheme.onSurface.withValues(alpha: 0.32),
          gridColor: scheme.onSurface.withValues(alpha: 0.10),
          targetColor: scheme.onSurface.withValues(alpha: 0.45),
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _BodyTrendPainter extends CustomPainter {
  _BodyTrendPainter({
    required this.points,
    required this.targetValue,
    required this.targetLabel,
    required this.lineColor,
    required this.dotColor,
    required this.gridColor,
    required this.targetColor,
    required this.textDirection,
  });

  final List<TrendPoint> points;
  final double? targetValue;
  final String targetLabel;
  final Color lineColor;
  final Color dotColor;
  final Color gridColor;
  final Color targetColor;

  /// Handed in rather than read, because a painter has no
  /// `BuildContext`. Used for the label only — see the class doc for
  /// why the plot itself never mirrors.
  final TextDirection textDirection;

  static const double _topPad = 14;
  static const double _bottomPad = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // The value window includes the target when there is one, so a
    // target below everything logged is still on screen — otherwise the
    // line the user set would be the one thing they could not see.
    var minValue = points.first.value;
    var maxValue = points.first.value;
    for (final point in points) {
      minValue = _min(minValue, _min(point.value, point.smoothed));
      maxValue = _max(maxValue, _max(point.value, point.smoothed));
    }
    final target = targetValue;
    if (target != null) {
      minValue = _min(minValue, target);
      maxValue = _max(maxValue, target);
    }

    // A flat series has zero span, which would divide by zero and paint
    // every point at the same y. Give it a nominal window so it renders
    // as the horizontal line it actually is.
    var span = maxValue - minValue;
    if (span < 0.001) {
      minValue -= 0.5;
      maxValue += 0.5;
      span = maxValue - minValue;
    } else {
      // A tenth of headroom top and bottom so the extremes are not
      // painted onto the frame's own edge.
      final margin = span * 0.1;
      minValue -= margin;
      maxValue += margin;
      span = maxValue - minValue;
    }

    final plotHeight = size.height - _topPad - _bottomPad;
    double y(double value) =>
        _topPad + plotHeight * (1 - (value - minValue) / span);

    // X is time, not index: three readings a day apart and then one a
    // month later must not be evenly spaced, or the chart flattens a
    // holiday into a step.
    final firstDay = points.first.day;
    final totalDays = points.last.day.difference(firstDay).inDays.toDouble();
    double x(DateTime day) {
      if (totalDays <= 0) return 0;
      return size.width * (day.difference(firstDay).inDays / totalDays);
    }

    _paintGrid(canvas, size, gridColor);

    // The smoothed line, as a cubic through the midpoints.
    final path = Path()..moveTo(x(points.first.day), y(points.first.smoothed));
    for (var i = 1; i < points.length; i++) {
      final prev = Offset(x(points[i - 1].day), y(points[i - 1].smoothed));
      final curr = Offset(x(points[i].day), y(points[i].smoothed));
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height - _bottomPad)
      ..lineTo(0, size.height - _bottomPad)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The raw readings, small and quiet, under the trend.
    final dotPaint = Paint()..color = dotColor;
    for (final point in points) {
      canvas.drawCircle(Offset(x(point.day), y(point.value)), 2.5, dotPaint);
    }

    // The latest smoothed value, anchored.
    final last = Offset(x(points.last.day), y(points.last.smoothed));
    canvas.drawCircle(last, 4, Paint()..color = lineColor);
    canvas.drawCircle(
      last,
      7,
      Paint()..color = lineColor.withValues(alpha: 0.22),
    );

    if (target != null) _paintTarget(canvas, size, y(target));
  }

  void _paintGrid(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final plotHeight = size.height - _topPad - _bottomPad;
    for (var i = 0; i <= 3; i++) {
      final lineY = _topPad + plotHeight * (i / 3);
      canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);
    }
  }

  /// A dashed horizontal rule with its caption at the reading-end.
  ///
  /// The label is the only thing on this canvas that flips with
  /// direction: in Arabic it belongs at the left, where a reader's eye
  /// finishes. The rule and the plot do not flip, because time does not.
  void _paintTarget(Canvas canvas, Size size, double lineY) {
    final paint = Paint()
      ..color = targetColor
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 5.0;
    for (var startX = 0.0; startX < size.width; startX += dash + gap) {
      final endX = _min(startX + dash, size.width);
      canvas.drawLine(Offset(startX, lineY), Offset(endX, lineY), paint);
    }

    final painter = TextPainter(
      text: TextSpan(
        text: targetLabel,
        style: TextStyle(
          color: targetColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: textDirection,
    )..layout(maxWidth: size.width);

    final labelX = textDirection == TextDirection.rtl
        ? 2.0
        : size.width - painter.width - 2;
    // Above the rule normally; below it when the rule is near the top
    // and the caption would be clipped off the canvas.
    final labelY =
        lineY - painter.height - 2 < 0 ? lineY + 2 : lineY - painter.height - 2;
    painter.paint(canvas, Offset(labelX, labelY));
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant _BodyTrendPainter old) =>
      old.points != points ||
      old.targetValue != targetValue ||
      old.targetLabel != targetLabel ||
      old.lineColor != lineColor ||
      old.textDirection != textDirection;
}
