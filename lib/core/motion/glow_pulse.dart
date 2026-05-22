import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Ambient radial glow — used as the halo around the coach avatar, the
/// emphasis ring on identity-declaration cards, and the "this matters"
/// outline on milestone CTAs.
///
/// Replaces the hand-rolled radial-gradient pulse in the original
/// `_PulsingCoachAvatar`. The implementation here uses a single
/// [BoxShadow] (one repaint cost) instead of a stacked radial-gradient
/// overlay (composition cost), so wrapping a heavy subtree stays cheap.
class GlowPulse extends StatefulWidget {
  const GlowPulse({
    super.key,
    required this.child,
    this.color,
    this.minAlpha = 0.25,
    this.maxAlpha = 0.55,
    this.minBlur = 18,
    this.maxBlur = 32,
    this.spread = 1,
    this.duration = MotionTokens.breath,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.enabled = true,
  })  : assert(minAlpha >= 0.0 && minAlpha <= 1.0),
        assert(maxAlpha >= 0.0 && maxAlpha <= 1.0),
        assert(minAlpha <= maxAlpha),
        assert(minBlur <= maxBlur);

  final Widget child;
  final Color? color;
  final double minAlpha;
  final double maxAlpha;
  final double minBlur;
  final double maxBlur;
  final double spread;
  final Duration duration;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: MotionTokens.breathEase,
    );
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GlowPulse old) {
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
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? const Color(0xFF8E5BFF);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius:
                  widget.shape == BoxShape.circle ? null : widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  color: base.withValues(
                    alpha: widget.minAlpha +
                        (widget.maxAlpha - widget.minAlpha) * t,
                  ),
                  blurRadius:
                      widget.minBlur + (widget.maxBlur - widget.minBlur) * t,
                  spreadRadius: widget.spread,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
