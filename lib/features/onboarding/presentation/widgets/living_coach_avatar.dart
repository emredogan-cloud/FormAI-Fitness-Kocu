import 'package:flutter/material.dart';

import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';

/// Form's avatar — outer radial halo on [BreathingBox] + inner photo
/// on [GlowPulse]. Two breathing layers, intentionally out of phase so
/// the avatar reads as alive rather than pulsing on a metronome.
///
/// Shared between every screen where Form is "speaking" (coach intro,
/// name capture, future name-callback moments) so the user sees the
/// same identity across scenes — cross-scene presence continuity.
///
/// Defaults match the original `_PulsingCoachAvatar` from the
/// coach-intro screen (220 outer / 140 inner, 3.6 s halo / 2.4 s
/// inner). Pass smaller sizes for the name capture screen where the
/// avatar shares vertical space with the prompt + input field.
class LivingCoachAvatar extends StatelessWidget {
  const LivingCoachAvatar({
    super.key,
    this.size = 220,
    this.innerSize = 140,
    this.outerHaloDuration = const Duration(milliseconds: 3600),
    this.innerGlowDuration = const Duration(milliseconds: 2400),
    this.assetPath = 'photos/kişiselyapayzekakoçfoto.webp',
  });

  /// Total side length of the avatar (outer halo extends to this size).
  final double size;

  /// Side length of the inner photo circle.
  final double innerSize;

  /// Period of the outer halo's breathing cycle.
  final Duration outerHaloDuration;

  /// Period of the inner photo's glow pulse.
  final Duration innerGlowDuration;

  /// Asset path for Form's portrait. Defaults to the Phase-60H webp.
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
            minAlpha: 0.55,
            maxAlpha: 1.0,
            duration: outerHaloDuration,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neon.withValues(alpha: 0.55),
                    AppColors.neonAccent.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          GlowPulse(
            color: AppColors.neon,
            minAlpha: 0.30,
            maxAlpha: 0.55,
            minBlur: 22,
            maxBlur: 30,
            spread: -2,
            duration: innerGlowDuration,
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.7),
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
