import '../models/macro_target.dart';

/// Computes a daily caloric + macronutrient target from the user's body
/// metrics, activity level, and goal.
///
/// Pipeline:
///   1. BMR — Mifflin-St Jeor equation (1990), the standard used by the
///      Academy of Nutrition and Dietetics. More accurate on modern
///      populations than the older Harris-Benedict formula.
///   2. TDEE — BMR multiplied by an activity factor.
///   3. Calorie adjustment — TDEE shifted up or down by the goal's
///      caloric delta (cut / tone / bulk).
///   4. Macros — calories split by the goal-specific ratio, then
///      converted to grams using 4 kcal/g for protein + carbs and 9
///      kcal/g for fat.
///
/// The service is stateless; a single instance is served via
/// `nutritionCalculatorProvider`.
class NutritionCalculatorService {
  const NutritionCalculatorService();

  /// Energy density (kcal per gram) for each macronutrient — Atwater
  /// factors. Fat is more than twice as dense as protein/carbs, which
  /// is why the conversion uses different divisors.
  static const double _kcalPerGramProtein = 4;
  static const double _kcalPerGramCarbs = 4;
  static const double _kcalPerGramFat = 9;

  MacroTarget calculateDailyMacros({
    required int weight,
    required int height,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) {
    final bmr = _mifflinStJeorBmr(
      weightKg: weight,
      heightCm: height,
      age: age,
      gender: gender,
    );
    final tdee = bmr * _activityMultiplier(activityLevel);
    final goalProfile = _goalProfile(goal);
    final calories = tdee + goalProfile.calorieDelta;
    return _buildMacroTarget(calories, goalProfile.ratios);
  }

  // ==========================================================================
  // BMR
  // ==========================================================================

  /// Mifflin-St Jeor:
  ///   Men:   (10 × kg) + (6.25 × cm) - (5 × age) + 5
  ///   Women: (10 × kg) + (6.25 × cm) - (5 × age) - 161
  ///
  /// For `other` / unknown gender we use the average of the two (i.e.
  /// `(5 - 161) / 2 = -78` as the sex correction), so the formula stays
  /// fair to non-binary users without rounding them into either bucket.
  double _mifflinStJeorBmr({
    required int weightKg,
    required int heightCm,
    required int age,
    required String gender,
  }) {
    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age);
    return base + _sexCorrection(gender);
  }

  double _sexCorrection(String gender) {
    switch (gender.trim().toLowerCase()) {
      case 'male':
      case 'm':
      case 'erkek':
        return 5;
      case 'female':
      case 'f':
      // A stored profile value, not copy: translating it would silently
      // change every existing user's BMR.
      case 'kadın': // i18n-ignore
      case 'kadin':
        return -161;
      default:
        // "other" / unspecified — midpoint of male (+5) and female (-161).
        return -78;
    }
  }

  // ==========================================================================
  // TDEE multiplier
  // ==========================================================================

  /// Accepts both the Phase-20 spec strings (`sedentary`, `light`,
  /// `active`, `very_active`) and the onboarding `ActivityLevel` enum
  /// names (`sedentary`, `light`, `active`) so the wizard's stored
  /// value maps straight through.
  double _activityMultiplier(String raw) {
    final v = raw.trim().toLowerCase().replaceAll('-', '_');
    switch (v) {
      case 'sedentary':
      case 'hareketsiz':
        return 1.2;
      case 'light':
      case 'lightly_active':
      case 'hafif':
        return 1.375;
      case 'active':
      case 'moderate':
      case 'moderately_active':
      case 'aktif':
        return 1.55;
      case 'very_active':
      case 'athlete':
      // Stored activity-level token, not copy.
      case 'çok_aktif': // i18n-ignore
      case 'cok_aktif':
        return 1.725;
      default:
        // Treat unknown input as sedentary — the most conservative
        // multiplier, so an unrecognised value can't accidentally
        // recommend a 3000-kcal day to a desk worker.
        return 1.2;
    }
  }

  // ==========================================================================
  // Goal modifier
  // ==========================================================================

  _GoalProfile _goalProfile(String raw) {
    final v = raw.trim().toLowerCase().replaceAll('-', '_');
    // Cut / six-pack profile.
    if (v == 'six_pack' ||
        v == 'sixpack' ||
        v == 'cut' ||
        v == 'lose' ||
        v == 'lose_weight') {
      return const _GoalProfile(
        calorieDelta: -500,
        ratios: _MacroRatios(protein: 0.40, fat: 0.30, carbs: 0.30),
      );
    }
    // Bulk / hypertrophy profile.
    if (v == 'bulk' ||
        v == 'hacim' ||
        v == 'hypertrophy' ||
        v == 'gain' ||
        v == 'gain_muscle') {
      return const _GoalProfile(
        calorieDelta: 500,
        ratios: _MacroRatios(protein: 0.30, fat: 0.20, carbs: 0.50),
      );
    }
    // Tone / recomp profile — the default for anything we don't
    // recognise, because "maintain-ish with a small deficit" is the
    // least harmful fallback for an ambiguous goal.
    return const _GoalProfile(
      calorieDelta: -200,
      ratios: _MacroRatios(protein: 0.35, fat: 0.30, carbs: 0.35),
    );
  }

  // ==========================================================================
  // Macro construction
  // ==========================================================================

  MacroTarget _buildMacroTarget(double calories, _MacroRatios ratios) {
    // Floor calories at a conservative 1200 kcal/day so a tall deficit
    // or a low-BMR profile can't produce an unsafe recommendation.
    final safeCalories = calories < 1200 ? 1200.0 : calories;
    final proteinGrams = (safeCalories * ratios.protein) / _kcalPerGramProtein;
    final carbGrams = (safeCalories * ratios.carbs) / _kcalPerGramCarbs;
    final fatGrams = (safeCalories * ratios.fat) / _kcalPerGramFat;
    return MacroTarget(
      calories: safeCalories.round(),
      protein: proteinGrams.round(),
      carbs: carbGrams.round(),
      fat: fatGrams.round(),
    );
  }
}

class _GoalProfile {
  const _GoalProfile({required this.calorieDelta, required this.ratios});
  final int calorieDelta;
  final _MacroRatios ratios;
}

class _MacroRatios {
  const _MacroRatios({
    required this.protein,
    required this.fat,
    required this.carbs,
  });
  final double protein;
  final double fat;
  final double carbs;
}
