import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Animates a numeric value from 0 to [value] using a configurable
/// curve — used by the dynamic-report metric cards (BMI, daily kcal)
/// and the pre-paywall plan card so numbers *land* on their values
/// instead of appearing already-filled.
///
/// Pair with [MotionTokens.revealEase] (defaults) for a slight
/// overshoot at the end (`Curves.easeOutBack`) — the number momentarily
/// passes its target by ~3% and settles. The micro-overshoot is the
/// difference between "the number rolled to its place" and "the
/// number was assigned a value."
///
/// Pass [formatter] to control display (e.g. `(v) => v.toStringAsFixed(1)`
/// for BMI, `(v) => v.round().toString()` for kcal).
class MorphingNumber extends StatefulWidget {
  const MorphingNumber({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 900),
    this.curve = MotionTokens.revealEase,
    this.startDelay = Duration.zero,
    this.style,
    this.textAlign,
  });

  /// Target value the animation lands on.
  final double value;

  /// How to render the current animated value as a string.
  final String Function(double) formatter;

  final Duration duration;
  final Curve curve;
  final Duration startDelay;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<MorphingNumber> createState() => _MorphingNumberState();
}

class _MorphingNumberState extends State<MorphingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value)
        .chain(CurveTween(curve: widget.curve))
        .animate(_ctrl);
    if (widget.startDelay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(widget.startDelay).then((_) {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Text(
        widget.formatter(_animation.value),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}
