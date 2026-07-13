import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Character-by-character reveal of a string, with an optional blinking
/// neon caret while typing is in flight.
///
/// Replaces the hand-rolled controller in the original
/// `_TerminalBubble` of the onboarding monolith. Pass [onComplete] to
/// be notified when the reveal finishes (e.g. to enable a CTA). Pass a
/// [RevealController] to short-circuit the animation from outside —
/// e.g. when the user taps anywhere on the surrounding screen.
class KineticTextReveal extends StatefulWidget {
  const KineticTextReveal({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.charDuration = MotionTokens.typewriterChar,
    this.caret = true,
    this.caretColor,
    this.onComplete,
    this.controller,
    this.startDelay = Duration.zero,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration charDuration;
  final bool caret;
  final Color? caretColor;
  final VoidCallback? onComplete;
  final RevealController? controller;

  /// Optional delay before the typewriter starts. Used by
  /// CoachIntroStep (Phase 108) to wait for Form's arrival
  /// choreography (avatar fade + scale-up + ArrivalPulse ring) to
  /// settle before the line begins typing — so the user reads
  /// "Form arrived → Form started speaking", not both at once.
  final Duration startDelay;

  @override
  State<KineticTextReveal> createState() => _KineticTextRevealState();
}

class _KineticTextRevealState extends State<KineticTextReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _typer = AnimationController(
      vsync: this,
      duration: widget.charDuration * widget.text.length,
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && !_done) {
          setState(() => _done = true);
          widget.onComplete?.call();
        }
      });
    widget.controller?._attach(this);
    if (widget.startDelay == Duration.zero) {
      _typer.forward();
    } else {
      Future<void>.delayed(widget.startDelay, () {
        if (mounted) _typer.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion (store-submission U4): render the full line at once.
    // Routed through [_skip] so the status listener still fires
    // [onComplete] and CTA gating keeps working.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _skip();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _typer.dispose();
    super.dispose();
  }

  void _skip() {
    if (_done) return;
    _typer.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final caret =
        widget.caretColor ?? widget.style?.color ?? const Color(0xFF8E5BFF);
    return AnimatedBuilder(
      animation: _typer,
      builder: (context, _) {
        final chars = (_typer.value * widget.text.length)
            .round()
            .clamp(0, widget.text.length);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: widget.text.substring(0, chars)),
              if (widget.caret && !_done)
                TextSpan(text: '▍', style: TextStyle(color: caret)),
            ],
            style: widget.style,
          ),
          textAlign: widget.textAlign,
        );
      },
    );
  }
}

/// External handle for skipping a [KineticTextReveal] — typically wired
/// to a `GestureDetector` wrapping the surrounding screen.
class RevealController {
  _KineticTextRevealState? _state;
  void _attach(_KineticTextRevealState s) => _state = s;
  void _detach() => _state = null;

  void skip() => _state?._skip();
  bool get isDone => _state?._done ?? false;
}
