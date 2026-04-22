import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../domain/models/recipe.dart';
import 'nutrition_provider.dart';

/// One row in the daily meal plan — a slot type plus every recipe the
/// catalogue offers for that type. The UI shows `candidates[initialIndex]`
/// as the primary pick; the "Değiştir" button advances through the rest
/// of the list locally without re-querying the provider.
class DailyMenuSlot {
  const DailyMenuSlot({
    required this.slot,
    required this.candidates,
    required this.initialIndex,
  });

  final DailyMealSlot slot;

  /// Every recipe matching this slot's filter, in catalogue order.
  /// Empty when the catalogue has no recipe for this slot — the card
  /// then renders an empty-state placeholder instead of crashing.
  final List<Recipe> candidates;

  /// Where to start in [candidates]. Non-zero when multiple slots of
  /// the same pool appear in one day (e.g. a 3-meal plan has two main
  /// slots pulling from the same pool; lunch uses 0, dinner uses 1 so
  /// the user doesn't see the same recipe twice).
  final int initialIndex;
}

/// Slot identities used by the daily plan. Distinct from
/// [Recipe.mealType] because:
///   • `lunch` and `dinner` both filter from the catalogue's `main`
///     bucket — the enum values only differ for the UI label.
///   • The set is closed and knowable at compile time, which lets the
///     timeline widget switch on it exhaustively.
enum DailyMealSlot { breakfast, lunch, dinner, snack }

/// Builds the user's daily meal plan. Reads the recipe catalogue
/// asynchronously and the persisted meal frequency from
/// [AppPreferences].
///
/// **Note on source-of-truth:** the phase spec suggested reading
/// `wizardProvider.mealFrequency`, but [WizardController.build] returns
/// a fresh default `WizardState` on every app launch, so that provider
/// only carries the user's choice during the session in which they
/// onboarded. Subsequent sessions need [AppPreferences.userMetrics],
/// which is where `saveUserMetrics(wizard.toJson())` persists the value
/// at onboarding completion.
final dailyMenuProvider = FutureProvider<List<DailyMenuSlot>>((ref) async {
  final recipes = await ref.watch(recipesProvider.future);
  final metrics = ref.watch(appPreferencesProvider).userMetrics ??
      const <String, dynamic>{};
  final frequency =
      (metrics['mealFrequency'] as String?) ?? kDefaultMealFrequency;
  return buildDailyMenu(recipes: recipes, mealFrequency: frequency);
});

/// Pure function so it's trivial to unit test without Riverpod setup.
/// Returns one [DailyMenuSlot] per meal the user should eat today, in
/// chronological order (breakfast first, dinner last).
List<DailyMenuSlot> buildDailyMenu({
  required List<Recipe> recipes,
  required String mealFrequency,
}) {
  final slots = _slotsForFrequency(mealFrequency);
  final result = <DailyMenuSlot>[];
  // Tracks how many times we've already pulled from each candidate pool
  // so duplicates in the frequency list (two mains in a 3_ogun plan,
  // say) advance through the pool instead of re-showing the same
  // recipe.
  final pulled = <String, int>{};

  for (final slot in slots) {
    final candidates = _candidatesFor(slot, recipes);
    if (candidates.isEmpty) {
      result.add(DailyMenuSlot(
        slot: slot,
        candidates: const [],
        initialIndex: 0,
      ));
      continue;
    }
    final poolKey = _poolKeyFor(slot);
    final offset = pulled[poolKey] ?? 0;
    pulled[poolKey] = offset + 1;
    result.add(DailyMenuSlot(
      slot: slot,
      candidates: candidates,
      initialIndex: offset % candidates.length,
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
  return recipes.where((r) => _matches(slot, r.mealType.toLowerCase())).toList(
        growable: false,
      );
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

/// Groups slots that share a candidate pool so `lunch` and `dinner`
/// advance through the same `main` bucket without colliding.
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
