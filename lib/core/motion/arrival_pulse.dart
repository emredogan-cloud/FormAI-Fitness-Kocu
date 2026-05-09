import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// One-shot scanning ring that expands outward from a centered child
/// — used as Form's "arrival" gesture on screens where the coach
/// enters the scene for the first time (coach intro, future
/// celebratory moments).
///
/// Reverse-engineered from Unrot's character-arrival energy (ref
/// video 0:00–0:06) but stripped of cartoon waving — a calm
/// premium AI acknowledgment instead. Reads as "the AI scanned and
/// locked focus on you." The ring expands once, fades as it grows,
/// then stops painting — a single deliberate gesture, not an
/// ambient loop.
///
/// Pair with a fade + scale-up entry on the wrapped child for the
/// full arrival choreography (CoachIntroStep does this — see the
/// ScaleTransition + FadeTransition wrapping the avatar).
///
/// Performance: the painter is `RepaintBoundary`-isolated and
/// stops invalidating once the ring completes. No long-lived
/// repaint cost.
class ArrivalPulse extends StatefulWidget {
  const ArrivalPulse({
    super.key,
    required this.child,
    this.color = const Color(0xFF8E5BFF),
    this.maxRadius = 240,
    this.duration = const Duration(milliseconds: 1100),
    this.startDelay = const Duration(milliseconds: 180),
    this.curve = MotionTokens.enterEase,
    this.ringWidth = 1.8,
    this.peakAlpha = 0.65,
    this.onComplete,
  });

  /// The thing the ring expands around — typically a coach avatar.
  final Widget child;

  final Color color;

  /// Where the ring stops expanding. Should comfortably exceed the
  /// child's visible radius so the ring doesn't read as a halo —
  /// 240 px against a 220 px avatar gives a clean "outside the
  /// avatar" perception.
  final double maxRadius;

  final Duration duration;

  /// Time to wait before the ring starts. Lets the wrapped child's
  /// own entry choreography (fade + scale) start first, so the user
  /// sees "Form arrives → ring radiates from Form" rather than the
  /// reverse.
  final Duration startDelay;

  final Curve curve;
  final double ringWidth;

  /// Peak alpha at progress 0; fades linearly to 0 as the ring
  /// expands. 0.65 gives a clearly visible ring that doesn't
  /// dominate the surrounding atmosphere.
  final double peakAlpha;

  /// Fires once when the ring completes. Useful for triggering a
  /// follow-up beat (e.g., starting the coach's typewriter).
  final VoidCallback? onComplete;

  @override
  State<ArrivalPulse> createState() => _ArrivalPulseState();
}

class _ArrivalPulseState extends State<ArrivalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        widget.onComplete?.call();
        // Trigger one more rebuild so the painter stops requesting
        // frames; this leaves the wrapped child as the only paying
        // surface in the steady state.
        if (mounted) setState(() {});
      }
    });
    if (widget.startDelay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(widget.startDelay, () {
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (!_done)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _curve,
                builder: (context, _) => CustomPaint(
                  painter: _ArrivalRingPainter(
                    progress: _curve.value,
                    color: widget.color,
                    maxRadius: widget.maxRadius,
                    ringWidth: widget.ringWidth,
                    peakAlpha: widget.peakAlpha,
                  ),
                  size: Size(widget.maxRadius * 2, widget.maxRadius * 2),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _ArrivalRingPainter extends CustomPainter {
  _ArrivalRingPainter({
    required this.progress,
    required this.color,
    required this.maxRadius,
    required this.ringWidth,
    required this.peakAlpha,
  });

  final double progress;
  final Color color;
  final double maxRadius;
  final double ringWidth;
  final double peakAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = maxRadius * progress;
    // Linear alpha fade as the ring expands — the ring is brightest
    // at the start (small + clearly visible) and dimmest at the end
    // (large + already dissolving). Reads as "energy radiating
    // outward and dissipating."
    final alpha = peakAlpha * (1.0 - progress);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_ArrivalRingPainter old) => old.progress != progress;
}
