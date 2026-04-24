import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../domain/models/daily_meal_slot.dart';
import '../domain/models/planned_meal.dart';
import '../domain/models/recipe.dart';
import 'nutrition_provider.dart';

/// Source of truth for the user's daily meal plan. Was a plain
/// `FutureProvider<List<DailyMenuSlot>>` in phase 22.2; phase 23.1
/// promotes it to an `AsyncNotifier<List<PlannedMeal>>` so each row has
/// a lifecycle (`planned` → `completed` / `skipped` with reset) and the
/// UI can drive real-time macro updates through [consumedMacrosProvider].
///
/// Lifecycle:
///   • `build()` awaits the recipe catalogue, reads the user's
///     meal-frequency preference, and produces a list of planned meals.
///   • `markAsCompleted` / `markAsSkipped` / `resetMeal` mutate a single
///     entry.
///   • `addRecipeToPlan` appends a brand-new meal (used by the recipe
///     detail screen's "Plana Ekle" CTA).
///
/// **Note on source-of-truth:** we read `mealFrequency` from
/// [AppPreferences], not [wizardProvider]. `WizardController.build`
/// returns a fresh default `WizardState` on every app launch, so
/// `wizardProvider` only carries the user's choice during the session
/// in which they onboarded. Subsequent sessions need the value that was
/// persisted via `saveUserMetrics(wizard.toJson())` at onboarding
/// completion.
class DailyMenuNotifier extends AsyncNotifier<List<PlannedMeal>> {
  /// Monotonic counter feeding [_nextId]. Reset on every `build` so a
  /// fresh plan starts back at `pm_1`.
  int _counter = 0;

  String _nextId() => 'pm_${++_counter}';

  @override
  Future<List<PlannedMeal>> build() async {
    _counter = 0;
    final recipes = await ref.watch(recipesProvider.future);
    final metrics = ref.watch(appPreferencesProvider).userMetrics ??
        const <String, dynamic>{};
    final frequency =
        (metrics['mealFrequency'] as String?) ?? kDefaultMealFrequency;
    return _generateInitialPlan(recipes: recipes, frequency: frequency);
  }

  // ==========================================================================
  // Mutations
  // ==========================================================================

  /// Flips the named meal to [MealStatus.completed]. No-op if the id is
  /// not in the current plan or the state is still loading.
  void markAsCompleted(String mealId) =>
      _setStatus(mealId, MealStatus.completed);

  /// Flips the named meal to [MealStatus.skipped]. Same no-op semantics.
  void markAsSkipped(String mealId) => _setStatus(mealId, MealStatus.skipped);

  /// Returns a completed or skipped meal to [MealStatus.planned] so the
  /// user can re-decide.
  void resetMeal(String mealId) => _setStatus(mealId, MealStatus.planned);

  void _setStatus(String mealId, MealStatus next) {
    final current = state.value;
    if (current == null) return;
    final updated = [
      for (final meal in current)
        meal.id == mealId ? meal.copyWith(status: next) : meal,
    ];
    state = AsyncData(updated);
  }

  /// Appends a new [PlannedMeal] to the current plan. [slot] accepts
  /// either an enum name (`breakfast` / `lunch` / `dinner` / `snack`)
  /// or a Turkish label (`kahvaltı`, `öğle`, `akşam`, `atıştırmalık`);
  /// unknown values fall back to `snack` rather than throwing.
  ///
  /// The new meal is created with `status = planned` so the user still
  /// needs to confirm they actually ate it. That matters because this
  /// method is the "Plana Ekle" entry point — the user is saying "I
  /// want this meal", not "I already had it".
  void addRecipeToPlan(Recipe recipe, String slot) {
    final current = state.value;
    if (current == null) return;
    final parsed = parseDailyMealSlot(slot);
    final next = [
      ...current,
      PlannedMeal(
        id: _nextId(),
        recipe: recipe,
        slot: parsed,
        status: MealStatus.planned,
      ),
    ];
    state = AsyncData(next);
    // Phase 42 analytics — captures the "Plana Ekle" intent so the
    // funnel can correlate recipe discovery → adoption → completion.
    AnalyticsService.instance.recipeAddedToPlan(
      recipeId: recipe.id,
      mealType: slot,
    );
  }

  // ==========================================================================
  // Initial plan generation
  // ==========================================================================

  List<PlannedMeal> _generateInitialPlan({
    required List<Recipe> recipes,
    required String frequency,
  }) {
    final slots = _slotsForFrequency(frequency);
    final result = <PlannedMeal>[];
    // Count pulls per candidate pool so duplicate slots in one day
    // (two mains in a 3-ögun plan) stagger through the pool instead of
    // re-showing the same recipe.
    final pulled = <String, int>{};
    for (final slot in slots) {
      final candidates = _candidatesFor(slot, recipes);
      if (candidates.isEmpty) continue;
      final poolKey = _poolKeyFor(slot);
      final offset = pulled[poolKey] ?? 0;
      pulled[poolKey] = offset + 1;
      final recipe = candidates[offset % candidates.length];
      result.add(PlannedMeal(
        id: _nextId(),
        recipe: recipe,
        slot: slot,
      ));
    }
    return result;
  }

  List<DailyMealSlot> _slotsForFrequency(String frequency) {
    switch (frequency) {
      case '2_ogun':
        return const [DailyMealSlot.lunch, DailyMealSlot.dinner];
      case '4_ogun':
        return const [
          DailyMealSlot.breakfast,
          DailyMealSlot.lunch,
          DailyMealSlot.snack,
          DailyMealSlot.dinner,
        ];
      case '3_ogun':
      default:
        return const [
          DailyMealSlot.breakfast,
          DailyMealSlot.lunch,
          DailyMealSlot.dinner,
        ];
    }
  }

  List<Recipe> _candidatesFor(DailyMealSlot slot, List<Recipe> recipes) {
    return recipes
        .where((r) => _matches(slot, r.mealType.toLowerCase()))
        .toList(growable: false);
  }

  bool _matches(DailyMealSlot slot, String type) {
    switch (slot) {
      case DailyMealSlot.breakfast:
        return type == 'breakfast' || type == 'kahvalti' || type == 'kahvaltı';
      case DailyMealSlot.lunch:
      case DailyMealSlot.dinner:
        return type == 'main' || type == 'lunch' || type == 'dinner';
      case DailyMealSlot.snack:
        return type == 'snack' || type == 'atistirmalik';
    }
  }

  String _poolKeyFor(DailyMealSlot slot) {
    switch (slot) {
      case DailyMealSlot.breakfast:
        return 'breakfast';
      case DailyMealSlot.lunch:
      case DailyMealSlot.dinner:
        return 'main';
      case DailyMealSlot.snack:
        return 'snack';
    }
  }
}

final dailyMenuProvider =
    AsyncNotifierProvider<DailyMenuNotifier, List<PlannedMeal>>(
  DailyMenuNotifier.new,
);
