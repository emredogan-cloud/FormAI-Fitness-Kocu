import '../models/macro_target.dart';
import '../models/recipe.dart';

/// Rule-based next-meal recommender. Consumes the user's **remaining**
/// macro budget (target − consumed) and returns the single best
/// candidate from the recipe catalogue, or `null` when the catalogue
/// is empty.
///
/// Priority tiers from the phase 23.2 spec, in order:
///   1. **Protein focus** — when the protein gap is large (>30 g
///      outstanding), pick the highest-protein non-dessert recipe that
///      itself carries >25 g protein.
///   2. **Low-calorie finish** — when the user has less than 400 kcal
///      remaining, pick the lightest recipe under 300 kcal.
///   3. **Balance** — fall back to minimising Euclidean distance
///      between `(protein, carbs, fat)` grams of the recipe and the
///      remaining macro vector. This keeps the suggestion centered on
///      what the user still needs to eat today.
///
/// Higher tiers fall through to the next when they match zero
/// candidates, so a user with a big protein gap and no high-protein
/// recipes in the catalogue still gets a useful balance-tier pick.
class NextBestMealService {
  const NextBestMealService();

  /// Remaining-macro thresholds that trigger the protein / low-cal arms.
  /// Tuned to the spec — surfaced as constants so tests and the coach
  /// banner can reference the same numbers if they need to explain
  /// *why* a tier fired.
  static const int proteinGapThreshold = 30;
  static const int proteinRecipeThreshold = 25;
  static const int lowCalorieGapThreshold = 400;
  static const int lowCalorieRecipeThreshold = 300;

  Recipe? suggestNextMeal({
    required List<Recipe> recipes,
    required MacroTarget remaining,
  }) {
    if (recipes.isEmpty) return null;

    // Priority 1 — protein-led suggestion.
    if (remaining.protein > proteinGapThreshold) {
      final picks = recipes
          .where((r) =>
              r.protein > proteinRecipeThreshold &&
              r.mealType.toLowerCase() != 'dessert')
          .toList();
      if (picks.isNotEmpty) {
        picks.sort((a, b) => b.protein.compareTo(a.protein));
        return picks.first;
      }
    }

    // Priority 2 — light-finish suggestion.
    if (remaining.calories < lowCalorieGapThreshold) {
      final picks =
          recipes.where((r) => r.calories < lowCalorieRecipeThreshold).toList();
      if (picks.isNotEmpty) {
        picks.sort((a, b) => a.calories.compareTo(b.calories));
        return picks.first;
      }
    }

    // Priority 3 — minimise squared Euclidean distance on the macro
    // triple. No need for `sqrt`: the ordering is preserved, and
    // skipping it means one less floating-point operation per candidate.
    Recipe? best;
    double bestDistance = double.infinity;
    for (final recipe in recipes) {
      final dProtein = (recipe.protein - remaining.protein).toDouble();
      final dCarbs = (recipe.carbs - remaining.carbs).toDouble();
      final dFat = (recipe.fat - remaining.fat).toDouble();
      final distance = dProtein * dProtein + dCarbs * dCarbs + dFat * dFat;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = recipe;
      }
    }
    return best;
  }
}
