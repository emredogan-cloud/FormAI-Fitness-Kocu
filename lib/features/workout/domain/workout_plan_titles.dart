import '../../../l10n/app_localizations.dart';

/// Difficulty of a [WorkoutPlan], as a token rather than a label.
///
/// The templates used to carry the label itself — `level: 'Orta düzey'`
/// — which is why an English reader saw Turkish difficulty text on every
/// plan card. A token cannot be rendered by accident.
enum WorkoutLevel {
  beginner,
  intermediate,
  advanced;

  /// Reuses the difficulty labels the rest of the app already ships.
  /// `difficultyIntermediateLong` and not `difficultyIntermediate`
  /// because the Turkish of the two differs — "Orta düzey" against
  /// "Orta Seviye" — and "Orta düzey" is what this catalogue has always
  /// said.
  String label(AppLocalizations l10n) => switch (this) {
        WorkoutLevel.beginner => l10n.difficultyBeginner,
        WorkoutLevel.intermediate => l10n.difficultyIntermediateLong,
        WorkoutLevel.advanced => l10n.difficultyAdvanced,
      };

  /// The level a set of exercises actually adds up to: whichever
  /// difficulty appears most often, beginner when there is nothing to
  /// count.
  ///
  /// Exists because the plan-detail hero used to print
  /// `difficultyIntermediateLong` as a **literal** — every program, every
  /// user, "Intermediate", including for somebody who had just told the
  /// wizard they had never trained. It sat under the line "Built
  /// specifically for your goal and level", which is what made it worth
  /// fixing rather than leaving as decoration.
  ///
  /// The rule is the one `today_task_card` already used; both now call
  /// this, so the two surfaces cannot disagree about the same day.
  static WorkoutLevel dominantOf(Iterable<String> difficulties) {
    final counts = <String, int>{};
    for (final d in difficulties) {
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return WorkoutLevel.beginner;
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return switch (dominant) {
      'advanced' => WorkoutLevel.advanced,
      'intermediate' => WorkoutLevel.intermediate,
      _ => WorkoutLevel.beginner,
    };
  }
}

/// Plan id → its localized card title.
///
/// A map rather than 52 `switch` arms so the table reads as data, and
/// keyed by the template's own `id` so there is no second identifier to
/// keep in step. Every id in `workout_repository.dart`'s templates
/// appears here exactly once and a test asserts that both ways — a plan
/// added without a title would otherwise render its raw id.
String? workoutPlanTitle(AppLocalizations l10n, String planId) =>
    _titles[planId]?.call(l10n);

const int kWorkoutPlanTitleCount = 52;

final Map<String, String Function(AppLocalizations)> _titles = {
  'equipment_chest_strength': (l) => l.planTitleEquipmentChestStrength,
  'equipment_back_width': (l) => l.planTitleEquipmentBackWidth,
  'equipment_shoulders_round': (l) => l.planTitleEquipmentShouldersRound,
  'equipment_arms_biceps': (l) => l.planTitleEquipmentArmsBiceps,
  'equipment_arms_triceps': (l) => l.planTitleEquipmentArmsTriceps,
  'equipment_legs_power': (l) => l.planTitleEquipmentLegsPower,
  'equipment_core_loaded': (l) => l.planTitleEquipmentCoreLoaded,
  'core_steel_abs': (l) => l.planTitleCoreSteelAbs,
  'core_athletic': (l) => l.planTitleCoreAthletic,
  'chest_dumbbell_fast': (l) => l.planTitleChestDumbbellFast,
  'chest_activation_growth': (l) => l.planTitleChestActivationGrowth,
  'chest_full_growth_burst': (l) => l.planTitleChestFullGrowthBurst,
  'chest_fat_burn_basic': (l) => l.planTitleChestFatBurnBasic,
  'back_v_taper': (l) => l.planTitleBackVTaper,
  'back_posture_basic': (l) => l.planTitleBackPostureBasic,
  'shoulders_giant': (l) => l.planTitleShouldersGiant,
  'shoulders_v_taper': (l) => l.planTitleShouldersVTaper,
  'shoulders_power_burst': (l) => l.planTitleShouldersPowerBurst,
  'arms_steel': (l) => l.planTitleArmsSteel,
  'arms_explosive_super': (l) => l.planTitleArmsExplosiveSuper,
  'arms_quick_tone': (l) => l.planTitleArmsQuickTone,
  'legs_quad_strength': (l) => l.planTitleLegsQuadStrength,
  'legs_power_day': (l) => l.planTitleLegsPowerDay,
  'legs_cardio_strength': (l) => l.planTitleLegsCardioStrength,
  'legs_elite_sculpt': (l) => l.planTitleLegsEliteSculpt,
  'cardio_fat_burn': (l) => l.planTitleCardioFatBurn,
  'cardio_full_body_burst': (l) => l.planTitleCardioFullBodyBurst,
  'cardio_morning_quick': (l) => l.planTitleCardioMorningQuick,
  'core_static_resistance': (l) => l.planTitleCoreStaticResistance,
  'core_lower_abs': (l) => l.planTitleCoreLowerAbs,
  'core_oblique_burner': (l) => l.planTitleCoreObliqueBurner,
  'core_mobility_flow': (l) => l.planTitleCoreMobilityFlow,
  'chest_bodyweight_burst': (l) => l.planTitleChestBodyweightBurst,
  'chest_plyo_explosive': (l) => l.planTitleChestPlyoExplosive,
  'chest_beginner_flow': (l) => l.planTitleChestBeginnerFlow,
  'back_bodyweight_activation': (l) => l.planTitleBackBodyweightActivation,
  'back_postural_corrective': (l) => l.planTitleBackPosturalCorrective,
  'back_hanging_workout': (l) => l.planTitleBackHangingWorkout,
  'shoulders_advanced_bodyweight': (l) =>
      l.planTitleShouldersAdvancedBodyweight,
  'shoulders_mobility_opening': (l) => l.planTitleShouldersMobilityOpening,
  'shoulders_scapular_stability': (l) => l.planTitleShouldersScapularStability,
  'arms_bodyweight_burst': (l) => l.planTitleArmsBodyweightBurst,
  'arms_triceps_bodyweight': (l) => l.planTitleArmsTricepsBodyweight,
  'arms_hanging_grip': (l) => l.planTitleArmsHangingGrip,
  'legs_glute_activation': (l) => l.planTitleLegsGluteActivation,
  'legs_single_leg_bodyweight': (l) => l.planTitleLegsSingleLegBodyweight,
  'legs_plyometric_burst': (l) => l.planTitleLegsPlyometricBurst,
  'legs_sumo_adductor': (l) => l.planTitleLegsSumoAdductor,
  'cardio_hiit_burst': (l) => l.planTitleCardioHiitBurst,
  'cardio_mobility_stretch': (l) => l.planTitleCardioMobilityStretch,
  'cardio_shadow_box': (l) => l.planTitleCardioShadowBox,
  'cardio_full_body_flow': (l) => l.planTitleCardioFullBodyFlow,
};
