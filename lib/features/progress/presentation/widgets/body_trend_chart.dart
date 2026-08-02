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
/// ---
///
/// **Pre-Phase-10 polish · the founder's "Your body" reference.** The
/// stroke now runs the brand gradient along the time axis, the plot
/// carries its own value and date axes, and the newest reading is a lit
/// white dot. Three notes on what did *not* change with the look:
///
///   * **The gradient is along X, not by value.** Purple at the oldest
///     reading, lime at the newest. It reads as "then → now", which is
///     information. A gradient keyed to the value would be valence
///     colouring by the back door.
///   * **The axes are drawn, not laid out.** A painter is the only place
///     the labels can be positioned against the same scale as the line
///     without measuring the plot twice.
///   * **[axisColor] and friends are handed in.** This widget is used on
///     a hardcoded dark surface today, and it must not start assuming
///     that.
class BodyTrendChart extends StatelessWidget {
  const BodyTrendChart({
    super.key,
    required this.points,
    required this.targetValue,
    required this.targetLabel,
    this.height = 180,
    this.strokeGradient,
    this.axisColor,
    this.gridColor,
    this.endDotColor,
    this.valueLabel,
    this.dateLabel,
  });

  final List<TrendPoint> points;

  /// The user's own stated target, in the same unit as [points]. Null
  /// means no line — which is a valid permanent state, not a gap.
  final double? targetValue;

  /// Localized caption for the target line, painted at its right end.
  final String targetLabel;

  final double height;

  /// Oldest-to-newest stroke colours. Null falls back to the theme's
  /// primary as a flat stroke, which is what the Progress tab wants.
  final List<Color>? strokeGradient;

  final Color? axisColor;
  final Color? gridColor;
  final Color? endDotColor;

  /// Formats a plotted value for the right-hand axis. Null hides the
  /// axis — a caller that has not thought about units should not get a
  /// bare number.
  final String Function(double value)? valueLabel;

  /// Formats a day for the bottom axis. The last tick is handed
  /// [points]`.last.day` and may return "Today".
  final String Function(DateTime day, {required bool isLast})? dateLabel;

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
          strokeGradient: strokeGradient,
          dotColor: scheme.onSurface.withValues(alpha: 0.32),
          gridColor: gridColor ?? scheme.onSurface.withValues(alpha: 0.10),
          targetColor: scheme.onSurface.withValues(alpha: 0.45),
          axisColor: axisColor ?? scheme.onSurface.withValues(alpha: 0.45),
          endDotColor: endDotColor,
          valueLabel: valueLabel,
          dateLabel: dateLabel,
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
    required this.strokeGradient,
    required this.dotColor,
    required this.gridColor,
    required this.targetColor,
    required this.axisColor,
    required this.endDotColor,
    required this.valueLabel,
    required this.dateLabel,
    required this.textDirection,
  });

  final List<TrendPoint> points;
  final double? targetValue;
  final String targetLabel;
  final Color lineColor;
  final List<Color>? strokeGradient;
  final Color dotColor;
  final Color gridColor;
  final Color targetColor;
  final Color axisColor;
  final Color? endDotColor;
  final String Function(double value)? valueLabel;
  final String Function(DateTime day, {required bool isLast})? dateLabel;

  /// Handed in rather than read, because a painter has no
  /// `BuildContext`. Used for the label only — see the class doc for
  /// why the plot itself never mirrors.
  final TextDirection textDirection;

  static const double _topPad = 14;
  static const double _bottomPad = 10;

  /// Gutter reserved for the right-hand value axis, and the strip under
  /// the plot for the date axis. Both are zero when the caller did not
  /// ask for that axis, so the Progress tab's chart is unchanged.
  static const double _valueAxisWidth = 34;
  static const double _dateAxisHeight = 20;
  static const double _axisFontSize = 10.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Everything below plots into `size`; carve the axis gutters off
    // first so the line never runs under its own labels.
    final plotSize = Size(
      size.width - (valueLabel == null ? 0 : _valueAxisWidth),
      size.height - (dateLabel == null ? 0 : _dateAxisHeight),
    );
    if (plotSize.width <= 1 || plotSize.height <= 1) return;
    _paintPlot(canvas, plotSize);
    if (dateLabel != null) _paintDateAxis(canvas, size, plotSize);
  }

  void _paintPlot(Canvas canvas, Size size) {
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
    if (valueLabel != null) {
      _paintValueAxis(canvas, size, minValue, span);
    }

    // The smoothed line, as a cubic through the midpoints.
    final path = Path()..moveTo(x(points.first.day), y(points.first.smoothed));
    for (var i = 1; i < points.length; i++) {
      final prev = Offset(x(points[i - 1].day), y(points[i - 1].smoothed));
      final curr = Offset(x(points[i].day), y(points[i].smoothed));
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final plotRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = strokeGradient;

    final fill = Path.from(path)
      ..lineTo(size.width, size.height - _bottomPad)
      ..lineTo(0, size.height - _bottomPad)
      ..close();
    if (gradient == null) {
      // Flat stroke: a single vertical fade, as the Progress tab has
      // always drawn it.
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
          ).createShader(plotRect),
      );
    } else {
      _paintGradientFill(canvas, fill, plotRect, gradient);
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient == null
            ? null
            : LinearGradient(colors: gradient).createShader(plotRect)
        ..color = lineColor
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The raw readings, small and quiet, under the trend. Suppressed
    // once the stroke carries a gradient: on the dark surface the dots
    // read as a second, noisier series rather than as the source of the
    // first.
    if (gradient == null) {
      final dotPaint = Paint()..color = dotColor;
      for (final point in points) {
        canvas.drawCircle(Offset(x(point.day), y(point.value)), 2.5, dotPaint);
      }
    }

    // The latest smoothed value, anchored — and lit, when the caller
    // asked for it. This is the one point on the chart that is "now".
    final last = Offset(x(points.last.day), y(points.last.smoothed));
    final endColor = endDotColor ?? lineColor;
    if (endDotColor != null) {
      canvas.drawCircle(
        last,
        11,
        Paint()
          ..color = (gradient?.last ?? lineColor).withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawCircle(last, 4.5, Paint()..color = endColor);
    canvas.drawCircle(
      last,
      7.5,
      Paint()..color = endColor.withValues(alpha: 0.22),
    );

    if (target != null) _paintTarget(canvas, size, y(target));
  }

  /// The area under a gradient stroke, faded along X *and* down Y.
  ///
  /// One `Paint` carries one shader, so the two ramps cannot be
  /// combined in a single draw: the horizontal hue is painted into its
  /// own layer, then a vertical alpha ramp is composited over it with
  /// [BlendMode.dstIn], which multiplies the layer's alpha rather than
  /// drawing anything of its own.
  ///
  /// Without the vertical half, the area under the oldest reading is a
  /// solid purple slab that reads as part of the chart rather than as
  /// the space beneath it.
  void _paintGradientFill(
    Canvas canvas,
    Path fill,
    Rect rect,
    List<Color> gradient,
  ) {
    canvas.saveLayer(rect, Paint());
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [for (final color in gradient) color.withValues(alpha: 0.34)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [0.0, 0.92],
        ).createShader(rect),
    );
    canvas.restore();
  }

  /// Four rules across the plot. Dashed when the chart carries a value
  /// axis, because a solid rule beside a number reads as a threshold the
  /// user set rather than as a gridline.
  void _paintGrid(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final plotHeight = size.height - _topPad - _bottomPad;
    for (var i = 0; i <= 3; i++) {
      final lineY = _topPad + plotHeight * (i / 3);
      if (valueLabel == null) {
        canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), paint);
      } else {
        _dashedLine(canvas, lineY, size.width, paint);
      }
    }
  }

  void _dashedLine(Canvas canvas, double lineY, double width, Paint paint) {
    const dash = 4.0;
    const gap = 6.0;
    for (var startX = 0.0; startX < width; startX += dash + gap) {
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(_min(startX + dash, width), lineY),
        paint,
      );
    }
  }

  /// The value axis, in the gutter to the right of the plot. One label
  /// per gridline, so a reader can put a number on any rule without
  /// interpolating.
  void _paintValueAxis(Canvas canvas, Size size, double minValue, double span) {
    final format = valueLabel;
    if (format == null) return;
    final plotHeight = size.height - _topPad - _bottomPad;
    for (var i = 0; i <= 3; i++) {
      final lineY = _topPad + plotHeight * (i / 3);
      // i == 0 is the TOP rule, which is the largest value.
      final value = minValue + span * (1 - i / 3);
      final painter = _label(format(value));
      painter.paint(
        canvas,
        Offset(size.width + 8, lineY - painter.height / 2),
      );
    }
  }

  /// The date axis, under the plot. Five ticks evenly spaced across the
  /// *time* window, matching the x() mapping — not across the point
  /// list, which would bunch the labels wherever logging was dense.
  void _paintDateAxis(Canvas canvas, Size size, Size plotSize) {
    final format = dateLabel;
    if (format == null) return;
    final firstDay = points.first.day;
    final lastDay = points.last.day;
    final totalDays = lastDay.difference(firstDay).inDays;
    const ticks = 5;
    final top = plotSize.height + 2;

    for (var i = 0; i < ticks; i++) {
      final fraction = i / (ticks - 1);
      final isLast = i == ticks - 1;
      final day = isLast
          ? lastDay
          : firstDay.add(Duration(days: (totalDays * fraction).round()));
      final painter = _label(format(day, isLast: isLast));
      // The first and last labels are anchored to the plot edges rather
      // than centred on their tick, so neither hangs off the canvas.
      final centre = plotSize.width * fraction;
      var left = centre - painter.width / 2;
      if (i == 0) left = 0;
      if (isLast) left = plotSize.width - painter.width;
      painter.paint(canvas, Offset(left, top));
    }
  }

  TextPainter _label(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: axisColor,
            fontSize: _axisFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: textDirection,
      )..layout();

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
      old.strokeGradient != strokeGradient ||
      old.axisColor != axisColor ||
      old.endDotColor != endDotColor ||
      old.valueLabel != valueLabel ||
      old.dateLabel != dateLabel ||
      old.textDirection != textDirection;
}
