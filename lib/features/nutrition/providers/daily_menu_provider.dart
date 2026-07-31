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
    // P1-11/12 · the collected preferences now actually shape the plan
    // (they were stored and never read — a vegan got meat mains while
    // the onboarding claimed the plan was being personalized).
    final diet =
        (metrics['dietPreference'] as String?) ?? kDefaultDietPreference;
    final nutritionGoal =
        (metrics['nutritionGoal'] as String?) ?? kDefaultNutritionGoal;
    final taste =
        (metrics['tastePreference'] as String?) ?? kDefaultTastePreference;
    final dailyCalories = ref.watch(macroTargetProvider).calories;
    return _generateInitialPlan(
      recipes: recipes,
      frequency: frequency,
      diet: diet,
      nutritionGoal: nutritionGoal,
      taste: taste,
      dailyCalories: dailyCalories,
    );
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

  /// Rule-based (NOT ML) personalization — honest about what it is:
  ///   1. Diet filter first: vegan/vejetaryen match on curated recipe
  ///      tags; ketojenik matches a keto tag OR a real low-carb macro
  ///      (≤ 15 g). Falls back to the unfiltered pool when the
  ///      catalogue has no match, so a thin tag set can never blank a
  ///      meal slot.
  ///   2. Candidates are then ranked by closeness to the slot's share
  ///      of the user's real daily calorie target (Mifflin-St-Jeor via
  ///      macroTargetProvider), with goal bias (kas_kazanimi → protein
  ///      up-rank, yag_yakimi → over-budget penalty) and a taste-tag
  ///      bonus on snack slots.
  ///   3. Duplicate slots stagger through the ranked pool (offset)
  ///      so two mains in one day aren't the same recipe.
  List<PlannedMeal> _generateInitialPlan({
    required List<Recipe> recipes,
    required String frequency,
    required String diet,
    required String nutritionGoal,
    required String taste,
    required int dailyCalories,
  }) {
    final slots = _slotsForFrequency(frequency);
    final dietPool = _dietFiltered(recipes, diet);
    final result = <PlannedMeal>[];
    final pulled = <String, int>{};
    for (final slot in slots) {
      var candidates = _candidatesFor(slot, dietPool);
      if (candidates.isEmpty) {
        // Diet pool has nothing for this slot — degrade to the full
        // catalogue rather than serving an empty plan.
        candidates = _candidatesFor(slot, recipes);
      }
      if (candidates.isEmpty) continue;
      final budget = (dailyCalories * _slotShare(slot, frequency)).round();
      final ranked = [...candidates]..sort(
          (a, b) => _score(a, budget, nutritionGoal, taste, slot)
              .compareTo(_score(b, budget, nutritionGoal, taste, slot)),
        );
      final poolKey = _poolKeyFor(slot);
      final offset = pulled[poolKey] ?? 0;
      pulled[poolKey] = offset + 1;
      final recipe = ranked[offset % ranked.length];
      result.add(PlannedMeal(
        id: _nextId(),
        recipe: recipe,
        slot: slot,
      ));
    }
    return result;
  }

  /// Lower is better: distance to the slot's calorie budget, adjusted
  /// by goal + taste signals.
  int _score(
    Recipe r,
    int budget,
    String nutritionGoal,
    String taste,
    DailyMealSlot slot,
  ) {
    var score = (r.calories - budget).abs();
    switch (nutritionGoal) {
      case 'kas_kazanimi':
        // Protein-forward: every gram of protein buys ~2 kcal of
        // budget distance.
        score -= r.protein * 2;
      case 'yag_yakimi':
        // Cutting: going OVER the slot budget costs double.
        if (r.calories > budget) score += r.calories - budget;
    }
    if (slot == DailyMealSlot.snack) {
      final tags = r.tags.map((t) => t.toLowerCase());
      final wantsSweet = taste == 'tatli'; // i18n-ignore — stored value
      final wantsSavory = taste == 'tuzlu';
      final isSweet = tags.any((t) =>
          t.contains('tatlı') ||
          t.contains('tatli')); // i18n-ignore — DB tag value
      if ((wantsSweet && isSweet) || (wantsSavory && !isSweet)) {
        score -= 120;
      }
    }
    return score;
  }

  /// Diet filter over the curated `tags` text[] column. Ketojenik also
  /// accepts a real macro signal (carbs ≤ 15 g) so untagged low-carb
  /// rows still qualify. Empty result → caller falls back.
  List<Recipe> _dietFiltered(List<Recipe> recipes, String diet) {
    bool matches(Recipe r) {
      final tags = r.tags.map((t) => t.toLowerCase()).toList();
      switch (diet) {
        case 'vegan':
          return tags.any((t) => t.contains('vegan'));
        case 'vejetaryen':
          return tags.any(
            (t) =>
                t.contains('vegan') ||
                t.contains('vejetaryen') ||
                t.contains('vegetarian'),
          );
        case 'ketojenik':
          return tags.any((t) => t.contains('keto')) || r.carbs <= 15;
        default:
          return true;
      }
    }

    final filtered = recipes.where(matches).toList(growable: false);
    return filtered.isEmpty ? recipes : filtered;
  }

  /// Share of the daily calorie target assigned to each slot, per
  /// meal-frequency choice. Sums to ~1.0 within a frequency.
  double _slotShare(DailyMealSlot slot, String frequency) {
    switch (frequency) {
      case '2_ogun':
        return 0.5;
      case '4_ogun':
        return switch (slot) {
          DailyMealSlot.breakfast => 0.25,
          DailyMealSlot.lunch => 0.30,
          DailyMealSlot.snack => 0.15,
          DailyMealSlot.dinner => 0.30,
        };
      case '3_ogun':
      default:
        return switch (slot) {
          DailyMealSlot.breakfast => 0.30,
          DailyMealSlot.lunch => 0.35,
          DailyMealSlot.snack => 0.15,
          DailyMealSlot.dinner => 0.35,
        };
    }
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
        return type == 'breakfast' ||
            type == 'kahvalti' ||
            type == 'kahvaltı'; // i18n-ignore — DB meal_type value
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
