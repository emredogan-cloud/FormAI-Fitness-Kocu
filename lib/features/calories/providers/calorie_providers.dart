import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calorie_repository.dart';
import '../data/open_food_facts_database.dart';
import '../domain/food_database.dart';
import '../domain/models/meal_entry.dart';
import '../domain/models/scan_result.dart';

/// The nutrition data source the app talks to.
///
/// Exposed as [FoodDatabase], never as the concrete class, so swapping
/// or adding a provider is one edit here and nothing anywhere else. To
/// put a Turkish composition database in front of Open Food Facts later,
/// this becomes:
///
///   FoodDatabaseChain([TurkishFoodDatabase(), OpenFoodFactsDatabase()])
///
/// and every call site is already correct.
final foodDatabaseProvider = Provider<FoodDatabase>(
  (ref) => OpenFoodFactsDatabase(),
);

final calorieRepositoryProvider = Provider<CalorieRepository>(
  (ref) => CalorieRepository(),
);

/// The day the dashboard is showing. Local midnight, not UTC — "today"
/// is a thing the user's calendar decides, not the server's.
///
/// A `NotifierProvider` rather than a `StateProvider` to match the rest
/// of the app (`localeProvider`, `unitSystemProvider`) — and because the
/// clamp below is behaviour, which a bare state holder has nowhere to put.
final selectedCalorieDayProvider =
    NotifierProvider<SelectedCalorieDayNotifier, DateTime>(
  SelectedCalorieDayNotifier.new,
);

class SelectedCalorieDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => today();

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Never moves past today. A future day is guaranteed empty, and an
  /// empty day the user cannot explain looks like the log lost their
  /// meals rather than like a date they should not have reached.
  void select(DateTime day) {
    final normalised = DateTime(day.year, day.month, day.day);
    state = normalised.isAfter(today()) ? today() : normalised;
  }

  void shiftDays(int delta) => select(state.add(Duration(days: delta)));
}

/// Meals for the selected day, with their items.
final dailyMealsProvider = FutureProvider.autoDispose<DailyTotals>((ref) async {
  final day = ref.watch(selectedCalorieDayProvider);
  final repo = ref.watch(calorieRepositoryProvider);
  return DailyTotals.from(await repo.mealsForDay(day));
});

/// Today's remaining scans.
///
/// Deliberately NOT derived from a local counter. The number shown to the
/// user and the number the server enforces have to agree, and only the
/// server's can be authoritative — a local count would drift the moment
/// the user scanned from a second device, and would be wrong in the
/// direction that looks like a bug ("it said I had one left").
final scanQuotaProvider = FutureProvider.autoDispose<ScanQuota>((ref) async {
  final repo = ref.watch(calorieRepositoryProvider);
  try {
    return await repo.quota();
  } catch (_) {
    // Unknown rather than zero. Telling a user they have no scans left
    // because we could not reach the server is a worse failure than
    // saying nothing and letting the scan itself report the truth.
    return ScanQuota.unknown;
  }
});

/// The last 14 days of totals, for the history view.
///
/// Keyed on nothing and `autoDispose`: history is read on a screen the
/// user opens deliberately, so keeping it warm between visits would hold
/// two weeks of rows for a screen most sessions never reach.
final calorieHistoryProvider =
    FutureProvider.autoDispose<Map<DateTime, DailyTotals>>((ref) async {
  final repo = ref.watch(calorieRepositoryProvider);
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  return repo.dailyTotalsForRange(
    from: end.subtract(const Duration(days: 13)),
    to: end,
  );
});

/// Invalidate everything the dashboard reads. Called after a meal is
/// logged, edited or deleted, and after a scan consumes a slot.
void refreshCalorieSurfaces(WidgetRef ref) {
  ref.invalidate(dailyMealsProvider);
  ref.invalidate(scanQuotaProvider);
  ref.invalidate(calorieHistoryProvider);
}
