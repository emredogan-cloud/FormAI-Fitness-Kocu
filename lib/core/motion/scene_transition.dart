import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// Replaces a `PageView` snap with a cinematic crossfade-and-rise.
///
/// Wrap the wizard's current scene in [SceneTransition] keyed by the
/// step index. When the key changes, the previous scene fades out
/// while drifting +8 px down and scaling 1.0 → 0.98 (recedes); the
/// incoming scene rises from +8 px to its resting position, scales
/// 0.98 → 1.0, and fades 0 → 1. Both share the same easing curve so
/// they feel choreographed rather than competing.
///
/// The kinematics are:
///   • opacity = animation.value
///   • translateY = (1 - animation.value) × [rise]
///   • scale     = 0.98 + 0.02 × animation.value
///
/// `AnimatedSwitcher` calls `transitionBuilder` once per child — the
/// outgoing child sees its animation reverse 1 → 0, the incoming sees
/// it forward 0 → 1, so both follow the same formulae and the user
/// reads the result as "the previous scene receded as the next scene
/// emerged" rather than "two screens slid past each other."
///
/// Stays at 480 ms by default ([MotionTokens.sceneCrossfade]) — long
/// enough that the user *feels* the transition, short enough that
/// taps still feel responsive. Cinematic > snappy is the right
/// direction for the onboarding rebuild.
class SceneTransition extends StatelessWidget {
  const SceneTransition({
    super.key,
    required this.scene,
    required this.sceneKey,
    this.duration = MotionTokens.sceneCrossfade,
    this.curve = MotionTokens.enterEase,
    this.rise = 8.0,
  });

  /// The current scene's content.
  final Widget scene;

  /// Identity for the scene. Changing this triggers the transition.
  /// Use `ValueKey(_index)` from the orchestrator.
  final ValueKey<Object> sceneKey;

  final Duration duration;
  final Curve curve;

  /// How far the incoming scene rises (and the outgoing scene drifts
  /// down). 8 px gives a felt-but-not-snappy lift.
  final double rise;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, builderChild) {
            final t = animation.value;
            return Transform.translate(
              offset: Offset(0, (1.0 - t) * rise),
              child: Transform.scale(
                scale: 0.98 + (0.02 * t),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: t,
                  child: builderChild,
                ),
              ),
            );
          },
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        // Stack so outgoing + incoming overlap during the crossfade.
        return Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(key: sceneKey, child: scene),
    );
  }
}
