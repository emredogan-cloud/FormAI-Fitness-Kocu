import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Plays a fade-and-rise entrance for each child along a single shared
/// controller. Children appear in sequence with overlapping windows so
/// the row feels like a "ripple" rather than a sharp one-after-another.
///
/// Used by the welcome screen (title / subtitle / CTA / legal line),
/// the dynamic-report screen (assessment paragraph / cards / confidence
/// bar / footer), and any other multi-element entrance.
///
/// Window math: with `n` children and `overlap` of 0.35 (default), the
/// window size is `1 / (1 + (n - 1) * (1 - 0.35))`. Each child's
/// window starts `winSize * (1 - overlap) * i` into the controller, so
/// the last child's window ends exactly at 1.0.
class StaggerColumn extends StatefulWidget {
  const StaggerColumn({
    super.key,
    required this.children,
    this.span = MotionTokens.staggerSpan,
    this.overlap = 0.35,
    this.riseFrom = const Offset(0, 0.4),
    this.curve = MotionTokens.enterEase,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.startDelay = Duration.zero,
  }) : assert(overlap >= 0.0 && overlap < 1.0);

  final List<Widget> children;
  final Duration span;
  final double overlap;
  final Offset riseFrom;
  final Curve curve;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final Duration startDelay;

  @override
  State<StaggerColumn> createState() => _StaggerColumnState();
}

class _StaggerColumnState extends State<StaggerColumn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.span);
    if (widget.startDelay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.startDelay).then((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    if (n == 0) {
      return Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisAlignment: widget.mainAxisAlignment,
      );
    }
    // Reduce-motion (store-submission U4): skip the entrance ripple and
    // present all children settled.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisAlignment: widget.mainAxisAlignment,
        children: widget.children,
      );
    }
    final winSize = 1.0 / (1.0 + (n - 1) * (1.0 - widget.overlap));
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisAlignment: widget.mainAxisAlignment,
      children: [
        for (var i = 0; i < n; i++) _entry(i, winSize, widget.children[i]),
      ],
    );
  }

  Widget _entry(int i, double winSize, Widget child) {
    final start = (i * winSize * (1.0 - widget.overlap)).clamp(0.0, 1.0);
    final end = (start + winSize).clamp(0.0, 1.0);
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: widget.curve),
    );
    final slide =
        Tween<Offset>(begin: widget.riseFrom, end: Offset.zero).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
