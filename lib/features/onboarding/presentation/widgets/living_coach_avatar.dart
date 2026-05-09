import 'package:flutter/material.dart';

import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import 'coach_mood.dart';

/// Form's avatar — outer radial halo on [BreathingBox] + inner photo
/// on [GlowPulse]. Two breathing layers, intentionally out of phase
/// so the avatar reads as alive rather than pulsing on a metronome.
///
/// Phase 105 · the avatar now reads a [CoachMood] and behaves
/// differently per mood: halo color, breathing speed, glow
/// intensity, and perceived posture (scale) all shift. The
/// transition between moods is a 500 ms `AnimatedSwitcher`
/// cross-fade so users see Form *change* — not a hard re-render.
/// `AnimatedScale` outside the switcher tweens scale smoothly
/// across mood changes (700 ms easeOutCubic).
///
/// Used wherever Form is "speaking" or "present":
///   • Coach intro (idle → listening when typewriter completes)
///   • Name capture (listening when asking → proud when
///     acknowledging)
///   • Interlude after goal (reassuring)
///   • Interlude before pain-point (reflective)
///
/// Defaults (220 outer / 140 inner) match the original Phase 60H
/// `_PulsingCoachAvatar`. Pass smaller sizes for the name capture
/// screen where the avatar shares vertical space with the prompt +
/// input field.
///
/// ## Rive swap-in protocol (Phase 103 deferral)
///
/// This widget is intentionally an *adapter*. The Phase 97 plan was
/// to back the avatar with a Rive state machine driving the same 8
/// facial states this enum already names — so the swap-in is a
/// 4-step in-place edit:
///
///   ```dart
///   // 1. Add `rive: ^0.14.x` back to pubspec, drop the .riv under
///   //    assets/rive/form_coach.riv with one trigger / state
///   //    input per CoachMood.
///   // 2. Branch the build:
///   //      if (kCoachUsesRive) RiveAnimation.asset(
///   //          'assets/rive/form_coach.riv',
///   //          stateMachines: ['Form'],
///   //          onInit: (artboard) {
///   //            _machine = StateMachineController.fromArtboard(
///   //                artboard, 'Form');
///   //            _machine?.findInput<bool>(mood.name)?.value = true;
///   //          },
///   //      )
///   //      else /* current BreathingBox + GlowPulse */
///   //    behind a top-of-file `kCoachUsesRive` const.
///   // 3. Watch `mood` in didUpdateWidget and toggle the Rive input.
///   // 4. Verify the call sites (CoachIntroStep, NameCaptureStep,
///   //    InterludeScene) still pass moods — no API change needed.
///   ```
///
/// Until Rive arrives, the parameter-driven mood system here is the
/// canonical Form-presence renderer. Visible character performance
/// without native dependencies.
class LivingCoachAvatar extends StatelessWidget {
  const LivingCoachAvatar({
    super.key,
    this.size = 220,
    this.innerSize = 140,
    this.assetPath = 'photos/kişiselyapayzekakoçfoto.webp',
    this.mood = CoachMood.idle,
  });

  /// Total side length (outer halo extends to this size).
  final double size;

  /// Side length of the inner photo circle.
  final double innerSize;

  /// Asset path for Form's portrait. Defaults to the Phase-60H webp.
  final String assetPath;

  /// Form's current emotional state. Drives every visual parameter
  /// via [kCoachMoodConfigs].
  final CoachMood mood;

  @override
  Widget build(BuildContext context) {
    final config = kCoachMoodConfigs[mood] ?? kCoachMoodConfigs[CoachMood.idle]!;
    return AnimatedScale(
      scale: config.scale,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          // Stack outgoing + incoming so the cross-fade reads as a
          // smooth transformation rather than a flicker.
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey<CoachMood>(mood),
          child: _AvatarLayers(
            config: config,
            size: size,
            innerSize: innerSize,
            assetPath: assetPath,
          ),
        ),
      ),
    );
  }
}

/// The two-layer avatar render for one mood. Stateless so each mood
/// transition just mounts a fresh instance — the BreathingBox /
/// GlowPulse inside have their own controllers and start fresh.
class _AvatarLayers extends StatelessWidget {
  const _AvatarLayers({
    required this.config,
    required this.size,
    required this.innerSize,
    required this.assetPath,
  });

  final CoachMoodConfig config;
  final double size;
  final double innerSize;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          BreathingBox(
            minAlpha: config.haloMinAlpha,
            maxAlpha: config.haloMaxAlpha,
            duration: config.haloDuration,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    config.haloPrimary.withValues(alpha: 0.55),
                    config.haloAccent.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          GlowPulse(
            color: config.glowColor,
            minAlpha: config.glowMinAlpha,
            maxAlpha: config.glowMaxAlpha,
            minBlur: config.glowMinBlur,
            maxBlur: config.glowMaxBlur,
            spread: -2,
            duration: config.glowDuration,
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: config.glowColor.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.neon, AppColors.neonAccent],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
