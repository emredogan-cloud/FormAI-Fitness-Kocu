import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nutrition_repository.dart';
import '../domain/models/recipe.dart';
import '../domain/services/nutrition_calculator_service.dart';

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
