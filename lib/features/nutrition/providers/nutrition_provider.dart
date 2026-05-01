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

/// Phase 48 · global discovery filter chip selection. Was a local
/// `String? _active` inside `_DiscoverySectionState` (nutrition_tab)
/// and `_DiscoverRecipesScreenState` (full-screen discover view); both
/// surfaces now read from this provider so the same chip selection
/// persists when the user pivots between the compact strip and the
/// "Tüm Tarifler" grid. Null = no filter applied.
final filterChipsProvider =
    NotifierProvider<FilterChipsNotifier, String?>(FilterChipsNotifier.new);

class FilterChipsNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Toggles the chip — tapping the active one clears it, tapping a
  /// different one swaps to the new selection. Mirrors the prior local
  /// `setState(() => _active = selected ? null : label)` semantics.
  void toggle(String label) {
    state = state == label ? null : label;
  }
}

/// Supabase-backed recipe repository. Exposed separately so UI layers
/// that need more than the basic `fetchRecipes()` (filtered queries,
/// pagination, future CRUD) can reach it directly.
final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepository(),
);

/// Phase 48 · paginated recipe catalogue.
///
/// Was a `FutureProvider<List<Recipe>>` that yanked the entire `recipes`
/// table in one round-trip — fine for the seed catalogue (5-10 rows)
/// but unworkable once the table grows past ~200 entries (post-launch
/// projection). Now the notifier lazily requests one page at a time
/// via [NutritionRepository.fetchRecipes(from:, limit:)], and screens
/// like `discover_recipes_screen` and `category_recipes_screen` call
/// `ref.read(recipesProvider.notifier).loadMore()` when the user
/// scrolls near the bottom.
///
/// Read-side semantics for legacy consumers (next-best-meal,
/// daily-menu) are unchanged: `ref.watch(recipesProvider).value` still
/// returns the recipes loaded so far. Recommendation engines therefore
/// work off the first page until the user paginates further, which is
/// fine because the first 20 are the highest-id (newest) entries.
final recipesProvider =
    AsyncNotifierProvider<PaginatedRecipesNotifier, List<Recipe>>(
  PaginatedRecipesNotifier.new,
);

/// Phase 83 hotfix · per-category recipe list, server-side filtered.
///
/// `CategoryRecipesScreen` used to read [recipesProvider] and filter the
/// loaded page client-side. With 35+ rows in the `recipes` table that
/// approach silently broke for the new "Pratik & Ekonomik" tag bucket
/// because the random UUID ordering scattered the matching rows past
/// page 1, and the screen's empty filtered list never grew tall enough
/// to trigger `_onScroll → loadMore()`. The result was a category card
/// that opened to either an empty state or a list with a stuck bottom
/// spinner, depending on how many matches happened to land on page 1.
///
/// This family asks Postgres to do the filtering and returns the
/// complete category in one round-trip — no pagination, no
/// page-1-blindness. Keyed on the same route token
/// `CategoryRecipesScreen` receives (`breakfast` / `lunch` / `dinner` /
/// `snack` / `dessert` / `budget`), so navigating between categories
/// fans out to independent providers Riverpod will memoize.
final categoryRecipesProvider =
    FutureProvider.family<List<Recipe>, String>((ref, categoryToken) {
  final repo = ref.watch(nutritionRepositoryProvider);
  return repo.fetchRecipesByCategory(categoryToken);
});

/// Notifier that owns the accumulated recipe list + pagination cursor.
/// `build()` loads page 1; subsequent `loadMore()` calls append the
/// next page. The notifier is stateful (it holds the current offset
/// and "has more" flag) but kept inside `state` whenever possible so
/// Riverpod's normal invalidation semantics still apply.
class PaginatedRecipesNotifier extends AsyncNotifier<List<Recipe>> {
  static const int _pageSize = NutritionRepository.defaultPageSize;

  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Recipe>> build() async {
    final repo = ref.read(nutritionRepositoryProvider);
    final firstPage = await repo.fetchRecipes(from: 0, limit: _pageSize);
    _hasMore = firstPage.length >= _pageSize;
    return firstPage;
  }

  /// Whether there's likely more data to fetch. UI scroll-listeners
  /// should stop calling [loadMore] once this flips to `false`.
  bool get hasMore => _hasMore;

  /// Appends the next page to [state]. No-op while the previous page
  /// is still in-flight or after the end of the catalogue is reached.
  /// Errors leave the existing state intact so a transient network blip
  /// doesn't wipe what the user is already scrolling through.
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final current = state.value;
    if (current == null) return;
    _isLoadingMore = true;
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final next = await repo.fetchRecipes(
        from: current.length,
        limit: _pageSize,
      );
      _hasMore = next.length >= _pageSize;
      state = AsyncData([...current, ...next]);
    } finally {
      _isLoadingMore = false;
    }
  }
}

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
