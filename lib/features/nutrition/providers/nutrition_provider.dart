import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nutrition_repository.dart';
import '../domain/models/macro_target.dart';
import '../domain/models/planned_meal.dart';
import '../domain/models/recipe.dart';
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
