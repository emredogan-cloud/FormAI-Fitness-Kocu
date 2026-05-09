import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Wraps any subtree in an ambient breathing pulse — a slow opacity
/// wave from [minAlpha] to [maxAlpha] and back.
///
/// Used for: coach avatar halo, premium CTA buttons (the breath says
/// "I'm waiting for you" without competing for attention), and idle
/// illustrations during analysis-illusion screens.
///
/// Symmetric easing ([Curves.easeInOutSine]) so the chest "rests"
/// between cycles rather than bouncing. The child sits inside a
/// [RepaintBoundary] so a parent rebuild does not trigger a full
/// repaint of the breathing subtree.
class BreathingBox extends StatefulWidget {
  const BreathingBox({
    super.key,
    required this.child,
    this.minAlpha = 0.6,
    this.maxAlpha = 1.0,
    this.duration = MotionTokens.breath,
    this.enabled = true,
  })  : assert(minAlpha >= 0.0 && minAlpha <= 1.0),
        assert(maxAlpha >= 0.0 && maxAlpha <= 1.0),
        assert(minAlpha <= maxAlpha);

  final Widget child;
  final double minAlpha;
  final double maxAlpha;
  final Duration duration;

  /// When false, the controller pauses at full opacity. Use on screens
  /// where the user is reading dense copy and motion would compete.
  final bool enabled;

  @override
  State<BreathingBox> createState() => _BreathingBoxState();
}

class _BreathingBoxState extends State<BreathingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _alpha;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _alpha = Tween<double>(begin: widget.minAlpha, end: widget.maxAlpha)
        .chain(CurveTween(curve: MotionTokens.breathEase))
        .animate(_controller);
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BreathingBox old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _alpha,
        builder: (context, child) =>
            Opacity(opacity: _alpha.value, child: child),
        child: widget.child,
      ),
    );
  }
}
