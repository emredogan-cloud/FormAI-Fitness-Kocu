import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../data/nutrition_repository.dart';
import '../domain/models/macro_target.dart';
import '../domain/models/planned_meal.dart';
import '../domain/models/recipe.dart';
import '../domain/services/next_best_meal_service.dart';
import '../domain/services/nutrition_calculator_service.dart';
import 'daily_menu_provider.dart';

/// Stateless macro engine — wrapped in a plain [Provider] because it
/// holds no per-user state and its output depends only on the inputs
/// passed to `calculateDailyMacros`.
final nutritionCalculatorProvider = Provider<NutritionCalculatorService>(
  (ref) => const NutritionCalculatorService(),
);

/// Supabase-backed recipe repository. Exposed separately so UI layers
/// that need more than the basic `fetchRecipes()` (filtered queries,
/// pagination, future CRUD) can reach it directly.
final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepository(),
);

/// Full recipe catalogue loaded from Supabase. `FutureProvider` so the
/// UI can branch on `.loading` / `.error` / `.data`, and callers can
/// `ref.invalidate(recipesProvider)` to retry after a network failure.
final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repo = ref.watch(nutritionRepositoryProvider);
  return repo.fetchRecipes();
});

/// The user's daily macro target derived from persisted body metrics.
/// Lifted out of `nutrition_tab.dart` in phase 23.2 so the next-best-
/// meal engine can read the same number without duplicating the
/// `calculateDailyMacros` call. Guest defaults match the tab's
/// previous behaviour (70 kg / 175 cm / 28 / male / sedentary /
/// sixpack) so onboarded users see the same recommendations they used
/// to.
final macroTargetProvider = Provider<MacroTarget>((ref) {
  final calc = ref.watch(nutritionCalculatorProvider);
  final metrics = ref.watch(appPreferencesProvider).userMetrics ??
      const <String, dynamic>{};
  return calc.calculateDailyMacros(
    weight: (metrics['weightKg'] as int?) ?? 70,
    height: (metrics['heightCm'] as int?) ?? 175,
    age: (metrics['age'] as int?) ?? 28,
    gender: (metrics['gender'] as String?) ?? 'male',
    activityLevel: (metrics['activityLevel'] as String?) ?? 'sedentary',
    goal: (metrics['targetPhysique'] as String?) ?? 'sixpack',
  );
});

/// Derived macro total for meals the user has marked as `completed`.
/// Watching [dailyMenuProvider] means the nutrition tab's calorie ring
/// + macro bars re-render the moment a user taps "Yedim" or "Geri Al"
/// on the timeline — no manual invalidation required.
///
/// While the plan is still loading (or errored) the consumed totals
/// default to zero so the UI shows a clean empty state rather than
/// glitching.
final consumedMacrosProvider = Provider<MacroTarget>((ref) {
  final meals = ref.watch(dailyMenuProvider).value ?? const <PlannedMeal>[];
  var calories = 0;
  var protein = 0;
  var carbs = 0;
  var fat = 0;
  for (final meal in meals) {
    if (meal.status != MealStatus.completed) continue;
    calories += meal.recipe.calories;
    protein += meal.recipe.protein;
    carbs += meal.recipe.carbs;
    fat += meal.recipe.fat;
  }
  return MacroTarget(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
});

/// What's left of the user's daily target after the meals they've
/// marked as completed. Feeds the AI coach banner + the next-best-meal
/// recommender. Can go negative when the user has overshot their
/// target — the UI branches on `remaining.calories < 0` to switch
/// copy from "low alım" to "hedefi aştın".
final remainingMacrosProvider = Provider<MacroTarget>((ref) {
  final target = ref.watch(macroTargetProvider);
  final consumed = ref.watch(consumedMacrosProvider);
  return MacroTarget(
    calories: target.calories - consumed.calories,
    protein: target.protein - consumed.protein,
    carbs: target.carbs - consumed.carbs,
    fat: target.fat - consumed.fat,
  );
});

/// Stateless recommendation engine — served via a plain [Provider]
/// because it holds no state; the call site injects `recipes` and
/// `remaining` at read time.
final nextBestMealServiceProvider = Provider<NextBestMealService>(
  (ref) => const NextBestMealService(),
);

/// The single best next meal for the user right now. Returns `null`
/// while the recipe catalogue is still loading — consumers should
/// treat `null` as "hide the suggestion surface" rather than "no good
/// option", because a null reflects "we don't know yet" more often
/// than "there's nothing to suggest".
///
/// Phase 25.2 upgraded this from `Recipe?` to [NextMealRecommendation?]
/// so the UI can show why a meal was picked and what impact adding it
/// will have on the day's macros.
final nextBestMealProvider = Provider<NextMealRecommendation?>((ref) {
  final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
  if (recipes.isEmpty) return null;
  final remaining = ref.watch(remainingMacrosProvider);
  return ref
      .watch(nextBestMealServiceProvider)
      .suggestNextMeal(recipes: recipes, remaining: remaining);
});

/// Daily gamification score from 0 to 100. Reads [macroTargetProvider]
/// and [consumedMacrosProvider] and awards points for each macro that
/// lands close to target:
///   • Calories within ±10% of target → +40
///   • Protein ≥ 90% of target        → +30
///   • Carbs within ±15%              → +15
///   • Fat within ±15%                → +15
///
/// Scores are read-only — future phases may persist a rolling weekly
/// average to SharedPreferences, but today the value is derived from
/// live consumed macros and updates every time a meal is logged.
final dailyScoreProvider = Provider<int>((ref) {
  final target = ref.watch(macroTargetProvider);
  final consumed = ref.watch(consumedMacrosProvider);
  var score = 0;
  if (_within(consumed.calories, target.calories, 0.10)) score += 40;
  if (target.protein > 0 && consumed.protein >= target.protein * 0.9) {
    score += 30;
  }
  if (_within(consumed.carbs, target.carbs, 0.15)) score += 15;
  if (_within(consumed.fat, target.fat, 0.15)) score += 15;
  return score;
});

/// Helper for the score arithmetic. Returns true when `consumed` sits
/// within `tolerance` (expressed as a fraction of `target`) of
/// `target`. `target <= 0` short-circuits to false so an unset target
/// never awards points accidentally.
bool _within(int consumed, int target, double tolerance) {
  if (target <= 0) return false;
  final delta = (consumed - target).abs();
  return delta <= (target * tolerance).round();
}

/// Current nutrition streak in whole days. Phase 25.2 ships the UI
/// only; a future cron job will increment this at midnight based on
/// the previous day's score. Today the value comes straight from
/// [AppPreferences.nutritionStreak] (default 0).
final nutritionStreakProvider = Provider<int>((ref) {
  return ref.watch(appPreferencesProvider).nutritionStreak;
});
