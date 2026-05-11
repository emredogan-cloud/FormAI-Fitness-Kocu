import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Gender { female, male, other }

enum Physique { slim, normal, heavy }

enum GoalPhysique { tone, bulk, sixpack }

enum ActivityLevel { sedentary, light, active }

/// Nutrition preference defaults. Kept as module-level constants so the
/// onboarding UI, the serialiser, and the macro engine can all reference
/// the same token if they need to treat the default specially.
const String kDefaultDietPreference = 'standart';
const String kDefaultAllergies = 'yok';
const String kDefaultMealFrequency = '3_ogun';
const String kDefaultPrepTime = 'hizli';
// Phase 62 · three additional nutrition fields surfaced by the V2
// nutrition onboarding sheet. Defaults match the most common answer
// so a user that skips the prompt still gets reasonable macro / recipe
// targeting downstream.
const String kDefaultNutritionGoal = 'dengeli';
const String kDefaultWaterIntake = 'orta';
const String kDefaultTastePreference = 'karisik';

class WizardState {
  const WizardState({
    this.name,
    this.coachingTone,
    this.motivationStyle,
    this.hasEquipment,
    this.bodyFeelings = const <String>{},
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.currentPhysique,
    this.targetPhysique,
    this.activityLevel,
    this.goal,
    this.experienceLevel,
    this.dailyMinutes,
    this.painPoint,
    this.activityDescription,
    this.experienceDescription,
    this.painPointDescription,
    this.dietPreference = kDefaultDietPreference,
    this.allergies = kDefaultAllergies,
    this.mealFrequency = kDefaultMealFrequency,
    this.prepTime = kDefaultPrepTime,
    this.nutritionGoal = kDefaultNutritionGoal,
    this.waterIntake = kDefaultWaterIntake,
    this.tastePreference = kDefaultTastePreference,
  });

  /// Cinematic rebuild · the name Form will use when speaking to the
  /// user. Captured by the dedicated `NameCaptureStep` between the
  /// coach intro and gender, used by the assessment engine's greeting
  /// line and (eventually) by push-notification copy.
  final String? name;

  /// Phase 131 · how the user wants Form to speak to them. Captured
  /// in the second beat of the chat-format name-capture step, right
  /// after the name. Three tokens: `cesaretlendirici` (encouraging),
  /// `direkt` (clear + direct), `sakin` (calm + reminder-style).
  /// Read by the assessment engine to colour coach copy across the
  /// rest of the wizard, and (eventually) by push-notification copy.
  final String? coachingTone;

  /// Phase 132 · what drives the user. Captured in the third beat of
  /// the chat-format name-capture step, after the coaching tone.
  /// Three tokens: `sonuc` (outcome-driven), `disiplin` (process-
  /// driven), `guc` (identity / strength-driven). Read by the
  /// assessment engine to colour the "why this plan suits you" pitch
  /// in the dynamic report, and by post-workout congrats copy.
  final String? motivationStyle;

  /// Phase 133 · whether the user has any training equipment at home
  /// or gym access. The first onboarding question that *directly*
  /// affects the generated 30-day workout plan. When `false`, the
  /// generator filters out equipment-only exercises (barbells,
  /// machines, cables, etc.) so the plan contains only bodyweight
  /// movements. When `true` (or null — legacy installs), the
  /// generator keeps its existing mixed-exercise behaviour.
  final bool? hasEquipment;

  /// Phase 111 · multi-select emotional self-recognition captured on
  /// the body-feelings step (between gender and goal). Tokens are
  /// emotional self-statements the user identifies with — `tired`,
  /// `lost_form`, `low_discipline`, `low_energy`, `mirror_avoid`,
  /// `dont_know_start`, `want_old_self`, `want_better`. Empty set is
  /// a valid answer (user skipped). The personalisation engine
  /// reads this set to weight assessment paragraph branches.
  final Set<String> bodyFeelings;

  final Gender? gender;
  final int? age;
  final int? heightCm;
  final int? weightKg;
  final Physique? currentPhysique;
  final GoalPhysique? targetPhysique;
  final ActivityLevel? activityLevel;

  /// Phase 60B · motivational driver captured by the interactive
  /// onboarding Goal step. Distinct from [targetPhysique] (the
  /// body-shape token consumed by the workout generator). Tokens:
  /// `belly_burn`, `muscle_gain`, `fitness_look`, `strength`.
  final String? goal;

  /// Phase 60B · self-reported training history.
  /// One of: `none`, `occasional`, `regular`.
  final String? experienceLevel;

  /// Phase 60B · daily time budget the user can commit to training.
  /// One of: `10_15`, `20_30`, `45_plus`.
  final String? dailyMinutes;

  /// Phase 60C · self-reported obstacle the user wants help with —
  /// surfaced on the Step-8 pain-point question. The downstream report
  /// generator branches its closing sentence on this token.
  /// One of: `motivation`, `consistency`, `no_idea`, `diet`.
  final String? painPoint;

  /// Phase 60F · free-text "describe your day" answer captured by the
  /// hybrid activity step. Set instead of (not in addition to)
  /// [activityLevel] when the user opts to write rather than tap a
  /// preset card. Stays null when the user picks a card.
  final String? activityDescription;

  /// Phase 63A · free-text "tell me about your training history" answer
  /// captured by the hybrid experience step. Set instead of (not in
  /// addition to) [experienceLevel] when the user types rather than
  /// tapping a card. Stays null when the user picks a card.
  final String? experienceDescription;

  /// Phase 63A · free-text "what specifically holds you back" answer
  /// captured by the hybrid pain-point step. Set instead of (not in
  /// addition to) [painPoint] when the user types rather than tapping
  /// a card. Stays null when the user picks a card.
  final String? painPointDescription;

  /// One of: `standart`, `vejetaryen`, `vegan`, `ketojenik`. Keyed in
  /// Turkish ASCII to match the rest of the wizard's persisted tokens.
  final String dietPreference;

  /// One of: `yok`, `kuruyemis`, `sut_urunleri`, `gluten`. Intentionally
  /// a single-select string for now — the recipe filter currently only
  /// needs one hot exclusion; multi-select can graduate to a list later.
  final String allergies;

  /// One of: `2_ogun`, `3_ogun`, `4_ogun`.
  final String mealFrequency;

  /// One of: `hizli` (10-15 min), `yavas` (30+ min).
  final String prepTime;

  /// Phase 62 · macro-targeting hint asked at the top of the deferred
  /// nutrition sheet ("Beslenme Hedefin Nedir?"). Distinct from
  /// [goal]/[targetPhysique] (which drive the workout side) so the
  /// nutrition engine can branch independently.
  /// One of: `yag_yakimi`, `kas_kazanimi`, `dengeli`.
  final String nutritionGoal;

  /// Phase 62 · self-reported daily water intake. Used by the
  /// nutrition coach to prompt hydration targets.
  /// One of: `cok_az` (0-1L), `orta` (1-2L), `iyi` (2L+).
  final String waterIntake;

  /// Phase 62 · taste preference hint so the recipe selector can lean
  /// sweet/savoury when scoring otherwise-equivalent options.
  /// One of: `tatli`, `tuzlu`, `karisik`.
  final String tastePreference;

  WizardState copyWith({
    String? name,
    String? coachingTone,
    String? motivationStyle,
    bool? hasEquipment,
    Set<String>? bodyFeelings,
    Gender? gender,
    int? age,
    int? heightCm,
    int? weightKg,
    Physique? currentPhysique,
    GoalPhysique? targetPhysique,
    ActivityLevel? activityLevel,
    String? goal,
    String? experienceLevel,
    String? dailyMinutes,
    String? painPoint,
    String? activityDescription,
    String? experienceDescription,
    String? painPointDescription,
    String? dietPreference,
    String? allergies,
    String? mealFrequency,
    String? prepTime,
    String? nutritionGoal,
    String? waterIntake,
    String? tastePreference,
  }) {
    return WizardState(
      name: name ?? this.name,
      coachingTone: coachingTone ?? this.coachingTone,
      motivationStyle: motivationStyle ?? this.motivationStyle,
      hasEquipment: hasEquipment ?? this.hasEquipment,
      bodyFeelings: bodyFeelings ?? this.bodyFeelings,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      currentPhysique: currentPhysique ?? this.currentPhysique,
      targetPhysique: targetPhysique ?? this.targetPhysique,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      painPoint: painPoint ?? this.painPoint,
      activityDescription: activityDescription ?? this.activityDescription,
      experienceDescription:
          experienceDescription ?? this.experienceDescription,
      painPointDescription: painPointDescription ?? this.painPointDescription,
      dietPreference: dietPreference ?? this.dietPreference,
      allergies: allergies ?? this.allergies,
      mealFrequency: mealFrequency ?? this.mealFrequency,
      prepTime: prepTime ?? this.prepTime,
      nutritionGoal: nutritionGoal ?? this.nutritionGoal,
      waterIntake: waterIntake ?? this.waterIntake,
      tastePreference: tastePreference ?? this.tastePreference,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'coachingTone': coachingTone,
        'motivationStyle': motivationStyle,
        'hasEquipment': hasEquipment,
        'bodyFeelings': bodyFeelings.toList(),
        'gender': gender?.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'currentPhysique': currentPhysique?.name,
        'targetPhysique': targetPhysique?.name,
        'activityLevel': activityLevel?.name,
        'goal': goal,
        'experienceLevel': experienceLevel,
        'dailyMinutes': dailyMinutes,
        'painPoint': painPoint,
        'activityDescription': activityDescription,
        'experienceDescription': experienceDescription,
        'painPointDescription': painPointDescription,
        'dietPreference': dietPreference,
        'allergies': allergies,
        'mealFrequency': mealFrequency,
        'prepTime': prepTime,
        'nutritionGoal': nutritionGoal,
        'waterIntake': waterIntake,
        'tastePreference': tastePreference,
      };
}

class WizardController extends Notifier<WizardState> {
  @override
  WizardState build() => const WizardState();

  void setName(String v) => state = state.copyWith(name: v);
  void setCoachingTone(String v) => state = state.copyWith(coachingTone: v);
  void setMotivationStyle(String v) =>
      state = state.copyWith(motivationStyle: v);
  void setHasEquipment(bool v) => state = state.copyWith(hasEquipment: v);
  void setBodyFeelings(Set<String> v) =>
      state = state.copyWith(bodyFeelings: v);
  void setGender(Gender v) => state = state.copyWith(gender: v);
  void setAge(int v) => state = state.copyWith(age: v);
  void setHeight(int v) => state = state.copyWith(heightCm: v);
  void setWeight(int v) => state = state.copyWith(weightKg: v);
  void setCurrentPhysique(Physique v) =>
      state = state.copyWith(currentPhysique: v);
  void setTargetPhysique(GoalPhysique v) =>
      state = state.copyWith(targetPhysique: v);
  void setActivityLevel(ActivityLevel v) =>
      state = state.copyWith(activityLevel: v);
  void setGoal(String v) => state = state.copyWith(goal: v);
  void setExperienceLevel(String v) =>
      state = state.copyWith(experienceLevel: v);
  void setDailyMinutes(String v) => state = state.copyWith(dailyMinutes: v);
  void setPainPoint(String v) => state = state.copyWith(painPoint: v);
  void setActivityDescription(String v) =>
      state = state.copyWith(activityDescription: v);
  void setExperienceDescription(String v) =>
      state = state.copyWith(experienceDescription: v);
  void setPainPointDescription(String v) =>
      state = state.copyWith(painPointDescription: v);
  void setDietPreference(String v) => state = state.copyWith(dietPreference: v);
  void setAllergies(String v) => state = state.copyWith(allergies: v);
  void setMealFrequency(String v) => state = state.copyWith(mealFrequency: v);
  void setPrepTime(String v) => state = state.copyWith(prepTime: v);
  void setNutritionGoal(String v) => state = state.copyWith(nutritionGoal: v);
  void setWaterIntake(String v) => state = state.copyWith(waterIntake: v);
  void setTastePreference(String v) =>
      state = state.copyWith(tastePreference: v);
}

final wizardProvider =
    NotifierProvider<WizardController, WizardState>(WizardController.new);
