import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';

/// Roadmap Phase 2 (C27) · the reusable coach-mark / spotlight system.
///
/// One step = "dim everything, cut a hole around this rect, and put a
/// sentence beside it". That is the whole vocabulary, and it is enough
/// to build every tour in the roadmap (dashboard tour here, the
/// in-workout tutorial layer in Phase 3, feature-unlock reveals in
/// Phase 4).
///
/// Deliberate constraints, each learned from how coach-mark systems
/// usually fail:
///
///   * **Skip is on every step, including the first.** A tour the user
///     can't escape is a tour that earns a 1-star review.
///   * **A missing target skips its step instead of crashing.** Targets
///     are resolved at present time from GlobalKeys; if a widget moved,
///     unmounted, or scrolled away, [SpotlightStep.rect] returns null and
///     the step is dropped. A tour must never be able to break the app.
///   * **Bubble placement is computed, not configured.** The card goes
///     below the hole when there's room and above otherwise, clamped to
///     the safe area. Hardcoded offsets break on the first phone with a
///     different aspect ratio — this app has already been bitten twice
///     by fixed-height layout (RC-17 paywall, RC-18 Başla).
///   * **Reduce-motion aware.** With `disableAnimations` the hole and
///     bubble jump between steps instead of animating. The tour still
///     completes and still teaches.
///   * **Presented as a transparent route**, so the real UI stays
///     mounted and genuinely visible through the hole — no screenshots,
///     no fake reproductions of the target widget.
class SpotlightStep {
  const SpotlightStep({
    required this.title,
    required this.body,
    required this.rect,
    this.radius = 16,
    this.padding = 8,
  });

  final String title;
  final String body;

  /// Resolved lazily at present time so a step reflects the *current*
  /// layout, not the layout when the tour was declared.
  final Rect? Function() rect;

  /// Corner radius of the punched hole.
  final double radius;

  /// Breathing room between the target's bounds and the hole edge.
  final double padding;
}

/// Presents [steps] in order. Returns `true` when the user reached the
/// end, `false` when they skipped. Steps whose target can't be resolved
/// are dropped; if that leaves nothing, the tour returns `false`
/// immediately without showing anything.
Future<bool> showSpotlightTour(
  BuildContext context, {
  required List<SpotlightStep> steps,
  String nextLabel = 'Devam',
  String? finishLabel,
  String skipLabel = 'Atla',
  ValueChanged<int>? onStepShown,
}) async {
  final resolvable =
      steps.where((s) => s.rect() != null).toList(growable: false);
  if (resolvable.isEmpty) return false;

  // Roadmap Phase 5 · the default finish label is localized, but the
  // parameter stays overridable so a tour can say something specific.
  final resolvedFinish =
      finishLabel ?? AppLocalizations.of(context).commonUnderstood;

  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    PageRouteBuilder<bool>(
      // Transparent so the live UI shows through the punched hole.
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _SpotlightOverlay(
        steps: resolvable,
        nextLabel: nextLabel,
        finishLabel: resolvedFinish,
        skipLabel: skipLabel,
        onStepShown: onStepShown,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
  return result ?? false;
}

class _SpotlightOverlay extends StatefulWidget {
  const _SpotlightOverlay({
    required this.steps,
    required this.nextLabel,
    required this.finishLabel,
    required this.skipLabel,
    this.onStepShown,
  });

  final List<SpotlightStep> steps;
  final String nextLabel;
  final String finishLabel;
  final String skipLabel;
  final ValueChanged<int>? onStepShown;

  @override
  State<_SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<_SpotlightOverlay> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.onStepShown?.call(0);
  }

  void _next() {
    AppHaptics.secondaryTap();
    if (_index >= widget.steps.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _index++);
    widget.onStepShown?.call(_index);
  }

  void _skip() {
    AppHaptics.secondaryTap();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    // Re-resolve every build: an interceding rebuild of the host tree
    // (a provider tick, a rotation) can move the target.
    final target = step.rect();
    if (target == null) {
      // The target vanished mid-tour. Advance rather than showing a hole
      // in the wrong place — a post-frame callback so we don't setState
      // during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next();
      });
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final hole = Rect.fromLTRB(
      target.left - step.padding,
      target.top - step.padding,
      target.right + step.padding,
      target.bottom + step.padding,
    );
    final isLast = _index == widget.steps.length - 1;

    return Semantics(
      container: true,
      // The scrim is explanatory chrome, not content — but the copy on
      // it is the whole point, so it must reach a screen reader.
      label: '${step.title}. ${step.body}',
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Scrim + hole. Absorbs taps everywhere so a stray tap can't
            // trigger the very control we're pointing at mid-explanation.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: _AnimatedHole(
                  hole: hole,
                  radius: step.radius,
                  animate: !reduceMotion,
                ),
              ),
            ),
            _StepCard(
              hole: hole,
              media: media,
              step: step,
              stepIndex: _index,
              stepCount: widget.steps.length,
              actionLabel: isLast ? widget.finishLabel : widget.nextLabel,
              skipLabel: widget.skipLabel,
              onAction: _next,
              onSkip: _skip,
              animate: !reduceMotion,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tweens the hole between steps so the eye follows it, unless the user
/// asked for reduced motion.
class _AnimatedHole extends StatelessWidget {
  const _AnimatedHole({
    required this.hole,
    required this.radius,
    required this.animate,
  });

  final Rect hole;
  final double radius;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return CustomPaint(
        painter: _ScrimPainter(hole: hole, radius: radius),
        child: const SizedBox.expand(),
      );
    }
    // `end` only — TweenAnimationBuilder animates from whatever it last
    // rendered to the new end value, which is exactly the step-to-step
    // slide we want. Supplying `begin` too would pin every step to the
    // same start and kill the animation.
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: hole),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        painter: _ScrimPainter(hole: value ?? hole, radius: radius),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints the dim layer with a rounded-rect hole, plus a neon ring so
/// the hole reads as deliberate emphasis rather than a rendering gap.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.radius});

  final Rect hole;
  final double radius;

  static const double _scrimOpacity = 0.78;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    final scrim = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addRRect(rrect);

    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, cutout),
      Paint()..color = Colors.black.withValues(alpha: _scrimOpacity),
    );

    // Ring: a soft outer glow then a crisp inner stroke.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.neon.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.neon.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius;
}

/// The coach bubble. Placement is computed from available space, never
/// configured — see the class doc on [SpotlightStep].
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.hole,
    required this.media,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.actionLabel,
    required this.skipLabel,
    required this.onAction,
    required this.onSkip,
    required this.animate,
  });

  final Rect hole;
  final MediaQueryData media;
  final SpotlightStep step;
  final int stepIndex;
  final int stepCount;
  final String actionLabel;
  final String skipLabel;
  final VoidCallback onAction;
  final VoidCallback onSkip;
  final bool animate;

  static const double _gap = 16;
  static const double _sideInset = 20;

  @override
  Widget build(BuildContext context) {
    final screen = media.size;
    final safeTop = media.padding.top + 8;
    final safeBottom = media.padding.bottom + 8;
    final maxWidth = screen.width - _sideInset * 2;

    // Space on each side of the hole decides where the card goes. No
    // magic numbers: whichever side has more room wins.
    final spaceBelow = screen.height - safeBottom - hole.bottom - _gap;
    final spaceAbove = hole.top - safeTop - _gap;
    final placeBelow = spaceBelow >= spaceAbove;

    final card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _CardBody(
        step: step,
        stepIndex: stepIndex,
        stepCount: stepCount,
        actionLabel: actionLabel,
        skipLabel: skipLabel,
        onAction: onAction,
        onSkip: onSkip,
      ),
    );

    // Keyed on the step index so each step gets its own element and
    // fades in independently rather than mutating the previous card's
    // text in place.
    return Positioned(
      key: animate ? ValueKey(stepIndex) : null,
      left: _sideInset,
      right: _sideInset,
      top: placeBelow ? hole.bottom + _gap : null,
      bottom: placeBelow ? null : screen.height - hole.top + _gap,
      child: card,
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.actionLabel,
    required this.skipLabel,
    required this.onAction,
    required this.onSkip,
  });

  final SpotlightStep step;
  final int stepIndex;
  final int stepCount;
  final String actionLabel;
  final String skipLabel;
  final VoidCallback onAction;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF160C26),
      borderRadius: BorderRadius.circular(18),
      elevation: 12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.neon.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const _CoachAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13.5,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StepDots(index: stepIndex, count: stepCount),
                const Spacer(),
                // Skip is present on EVERY step, first included.
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.55),
                    minimumSize: const Size(64, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    skipLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(88, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.6)),
      ),
      child: ClipOval(
        child: Image.asset(
          'photos/PT_FORM.png',
          fit: BoxFit.cover,
          // The avatar is decoration; a missing asset must not blank the
          // card that carries the actual explanation.
          errorBuilder: (_, __, ___) => const Icon(
            Icons.auto_awesome,
            size: 16,
            color: AppColors.neon,
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == index;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Container(
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: active
                    ? AppColors.neon
                    : Colors.white.withValues(alpha: 0.28),
              ),
            ),
          );
        }),
      ),
    );
  }
}
