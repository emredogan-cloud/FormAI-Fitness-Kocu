import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';

/// Form's emotional state at any given moment in the wizard.
///
/// The character-performance system (Phase 105) reads this enum on
/// every render and looks up [CoachMoodConfig] to drive the
/// avatar's halo color, breathing speed, glow intensity, blur range,
/// and scale. Different moods make the avatar visibly behave
/// differently — without Rive, without artwork — using only the
/// existing `BreathingBox` + `GlowPulse` motion primitives.
///
/// Eight expressive states + an idle baseline cover every wizard
/// surface where Form is present:
///
///   • idle — default calm presence (coach intro, fillers)
///   • listening — attentive, slight forward lean (waiting for input)
///   • thinking — cool tone, faster pulse (AI computing)
///   • reassuring — warm, slow, deep breath (post-goal interlude)
///   • reflective — dim, slow, settled (pre-pain-point interlude)
///   • excited — bright, faster, slight forward (milestone reveal)
///   • concerned — slightly dimmer, slower (edge cases)
///   • proud — chest forward, brighter (acknowledgment, post-completion)
///   • celebratory — peak intensity (paywall purchase, future use)
///
/// Differentiation axes (deliberate Apple-subtle constraints):
///   • Color stays inside the neon palette (`neon` / `neonAccent` /
///     `neonDeep`) — brand consistency, no orange/red detours.
///   • Speed delta — halo cycle 1.8 s (excited) … 5.2 s (reflective).
///   • Scale delta — 0.97 (reflective) … 1.07 (celebratory) for
///     perceived posture.
///   • Alpha intensity for both halo + glow.
///
/// No mascot energy. Each mood is a parameter set, not an
/// illustration.
enum CoachMood {
  idle,
  listening,
  thinking,
  reassuring,
  reflective,
  excited,
  concerned,
  proud,
  celebratory,
}

/// Parameter set that drives [LivingCoachAvatar] for one mood.
///
/// Immutable; the lookup table [kCoachMoodConfigs] holds one instance
/// per [CoachMood]. Callers don't construct this directly — they pass
/// a [CoachMood] to the avatar and the lookup happens inside.
@immutable
class CoachMoodConfig {
  const CoachMoodConfig({
    required this.haloPrimary,
    required this.haloAccent,
    required this.haloDuration,
    required this.haloMinAlpha,
    required this.haloMaxAlpha,
    required this.glowColor,
    required this.glowDuration,
    required this.glowMinAlpha,
    required this.glowMaxAlpha,
    required this.glowMinBlur,
    required this.glowMaxBlur,
    required this.scale,
  });

  final Color haloPrimary;
  final Color haloAccent;
  final Duration haloDuration;
  final double haloMinAlpha;
  final double haloMaxAlpha;

  final Color glowColor;
  final Duration glowDuration;
  final double glowMinAlpha;
  final double glowMaxAlpha;
  final double glowMinBlur;
  final double glowMaxBlur;

  /// Perceived posture. 1.0 is neutral. <1.0 reads as "settling
  /// inward / inward-focused." >1.0 reads as "leaning forward /
  /// engaged / proud." Kept inside [0.97, 1.07] so the avatar never
  /// looks distorted, just intentionally sized.
  final double scale;
}

const CoachMoodConfig _idleConfig = CoachMoodConfig(
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 3600),
  haloMinAlpha: 0.55,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 2400),
  glowMinAlpha: 0.30,
  glowMaxAlpha: 0.55,
  glowMinBlur: 22,
  glowMaxBlur: 30,
  scale: 1.0,
);

const CoachMoodConfig _listeningConfig = CoachMoodConfig(
  // Faster pulse than idle — attentive, slight forward lean.
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 2800),
  haloMinAlpha: 0.60,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 1800),
  glowMinAlpha: 0.35,
  glowMaxAlpha: 0.60,
  glowMinBlur: 22,
  glowMaxBlur: 28,
  scale: 1.02,
);

const CoachMoodConfig _thinkingConfig = CoachMoodConfig(
  // Cool tone (accent-blue dominant), faster pulse — "computing."
  haloPrimary: AppColors.neonAccent,
  haloAccent: AppColors.neon,
  haloDuration: Duration(milliseconds: 2000),
  haloMinAlpha: 0.45,
  haloMaxAlpha: 0.95,
  glowColor: AppColors.neonAccent,
  glowDuration: Duration(milliseconds: 1400),
  glowMinAlpha: 0.40,
  glowMaxAlpha: 0.65,
  glowMinBlur: 24,
  glowMaxBlur: 36,
  scale: 1.0,
);

const CoachMoodConfig _reassuringConfig = CoachMoodConfig(
  // Slower, warmer (deeper purple), gentle breath. Empathy moments.
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonDeep,
  haloDuration: Duration(milliseconds: 4400),
  haloMinAlpha: 0.50,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 3000),
  glowMinAlpha: 0.30,
  glowMaxAlpha: 0.55,
  glowMinBlur: 26,
  glowMaxBlur: 36,
  scale: 0.99,
);

const CoachMoodConfig _reflectiveConfig = CoachMoodConfig(
  // Dim, slow, deep — preparing the user for vulnerability.
  haloPrimary: AppColors.neonDeep,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 5200),
  haloMinAlpha: 0.40,
  haloMaxAlpha: 0.85,
  glowColor: AppColors.neonDeep,
  glowDuration: Duration(milliseconds: 3600),
  glowMinAlpha: 0.20,
  glowMaxAlpha: 0.45,
  glowMinBlur: 28,
  glowMaxBlur: 38,
  scale: 0.97,
);

const CoachMoodConfig _excitedConfig = CoachMoodConfig(
  // Faster, brighter, leans forward — milestone reveals.
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 1800),
  haloMinAlpha: 0.65,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 1200),
  glowMinAlpha: 0.45,
  glowMaxAlpha: 0.75,
  glowMinBlur: 22,
  glowMaxBlur: 32,
  scale: 1.04,
);

const CoachMoodConfig _concernedConfig = CoachMoodConfig(
  // Slightly dimmer + slower than idle. Doesn't break the palette;
  // reads as "Form noticed something." Deep purple plus muted
  // amplitude.
  haloPrimary: AppColors.neonDeep,
  haloAccent: AppColors.neon,
  haloDuration: Duration(milliseconds: 4000),
  haloMinAlpha: 0.40,
  haloMaxAlpha: 0.80,
  glowColor: AppColors.neonDeep,
  glowDuration: Duration(milliseconds: 2800),
  glowMinAlpha: 0.25,
  glowMaxAlpha: 0.50,
  glowMinBlur: 26,
  glowMaxBlur: 34,
  scale: 0.98,
);

const CoachMoodConfig _proudConfig = CoachMoodConfig(
  // Chest forward, brighter halo, faster glow — "Form is satisfied
  // with what it just heard." Lands on name capture acknowledgment
  // and the pre-paywall coach panel.
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 3000),
  haloMinAlpha: 0.65,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 2000),
  glowMinAlpha: 0.40,
  glowMaxAlpha: 0.70,
  glowMinBlur: 22,
  glowMaxBlur: 32,
  scale: 1.05,
);

const CoachMoodConfig _celebratoryConfig = CoachMoodConfig(
  // Peak intensity — bright, fast, larger. Reserved for major
  // milestones (paywall purchase, future first-workout completion).
  haloPrimary: AppColors.neon,
  haloAccent: AppColors.neonAccent,
  haloDuration: Duration(milliseconds: 1500),
  haloMinAlpha: 0.70,
  haloMaxAlpha: 1.0,
  glowColor: AppColors.neon,
  glowDuration: Duration(milliseconds: 1100),
  glowMinAlpha: 0.55,
  glowMaxAlpha: 0.85,
  glowMinBlur: 24,
  glowMaxBlur: 36,
  scale: 1.07,
);

/// Lookup table — exactly one config per [CoachMood]. Const map so
/// callers can resolve the config without allocation.
const Map<CoachMood, CoachMoodConfig> kCoachMoodConfigs = {
  CoachMood.idle: _idleConfig,
  CoachMood.listening: _listeningConfig,
  CoachMood.thinking: _thinkingConfig,
  CoachMood.reassuring: _reassuringConfig,
  CoachMood.reflective: _reflectiveConfig,
  CoachMood.excited: _excitedConfig,
  CoachMood.concerned: _concernedConfig,
  CoachMood.proud: _proudConfig,
  CoachMood.celebratory: _celebratoryConfig,
};
