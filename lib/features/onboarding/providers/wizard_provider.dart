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

class WizardState {
  const WizardState({
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
    this.dietPreference = kDefaultDietPreference,
    this.allergies = kDefaultAllergies,
    this.mealFrequency = kDefaultMealFrequency,
    this.prepTime = kDefaultPrepTime,
  });

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

  WizardState copyWith({
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
    String? dietPreference,
    String? allergies,
    String? mealFrequency,
    String? prepTime,
  }) {
    return WizardState(
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
      dietPreference: dietPreference ?? this.dietPreference,
      allergies: allergies ?? this.allergies,
      mealFrequency: mealFrequency ?? this.mealFrequency,
      prepTime: prepTime ?? this.prepTime,
    );
  }

  Map<String, dynamic> toJson() => {
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
        'dietPreference': dietPreference,
        'allergies': allergies,
        'mealFrequency': mealFrequency,
        'prepTime': prepTime,
      };
}

class WizardController extends Notifier<WizardState> {
  @override
  WizardState build() => const WizardState();

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
  void setDietPreference(String v) => state = state.copyWith(dietPreference: v);
  void setAllergies(String v) => state = state.copyWith(allergies: v);
  void setMealFrequency(String v) => state = state.copyWith(mealFrequency: v);
  void setPrepTime(String v) => state = state.copyWith(prepTime: v);
}

final wizardProvider =
    NotifierProvider<WizardController, WizardState>(WizardController.new);
