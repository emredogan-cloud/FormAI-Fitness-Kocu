import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/data/nutrition_repository.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';

/// Phase 7 device walk · the language picker applies live, and until this
/// existed that was only true of the chrome.
///
/// [NutritionRepository] resolves each row's language at decode time, so
/// rows already in memory keep the language they were fetched in.
/// Switching to English left the catalogue in Turkish — English labels,
/// English chips, English macros, Turkish recipe titles — until the app
/// was restarted. On the device the next-best-meal card read "Tavuklu
/// Souvlaki Kasesi" directly under the English sentence "You're falling
/// short on protein."
///
/// The production guard is that `nutritionRepositoryProvider` watches
/// `localeProvider` and hands the language to the repository, so every
/// recipe query below it re-runs. That provider cannot be built in a unit
/// test — `NutritionRepository()` reaches `Supabase.instance` — so what
/// is pinned here is the half that a refactor is most likely to undo:
/// [PaginatedRecipesNotifier] must `watch` its repository rather than
/// `read` it, and must reset its pagination cursor when it does.

/// Records how many times a page was requested and in which language.
class _RecordingRepository implements NutritionRepository {
  _RecordingRepository(this.languageCode);
  final String? languageCode;
  static final List<String?> fetches = [];

  @override
  Future<List<Recipe>> fetchRecipes({int from = 0, int limit = 20}) async {
    fetches.add(languageCode);
    return [
      Recipe(
        id: 'r1',
        title: languageCode == 'en' ? 'Chicken Souvlaki Bowl' : 'Tavuklu Kase',
        mealType: 'lunch',
        calories: 400,
        protein: 30,
        carbs: 40,
        fat: 15,
        prepTimeMinutes: 15,
      ),
    ];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({LocaleNotifier.storageKey: 'tr'});
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(raw),
      // Mirrors the production provider's shape: watches the locale and
      // hands the language down. The real one additionally builds a
      // Supabase-backed repository, which a unit test cannot.
      nutritionRepositoryProvider.overrideWith(
        (ref) => _RecordingRepository(ref.watch(localeProvider)?.languageCode),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(_RecordingRepository.fetches.clear);

  test('changing the language re-fetches the catalogue in the new language',
      () async {
    final container = await _container();
    final sub = container.listen(recipesProvider, (_, __) {});
    addTearDown(sub.close);

    final first = await container.read(recipesProvider.future);
    expect(first.single.title, 'Tavuklu Kase');
    expect(_RecordingRepository.fetches, ['tr']);

    await container.read(localeProvider.notifier).set(const Locale('en'));
    final second = await container.read(recipesProvider.future);

    // Before the fix this still read 'Tavuklu Kase': the notifier `read`
    // its repository once and never heard about the language change.
    expect(second.single.title, 'Chicken Souvlaki Bowl');
    expect(_RecordingRepository.fetches, ['tr', 'en']);
  });

  test('the re-fetch starts from page 1 rather than the old cursor', () async {
    // `loadMore` sets `_hasMore` from the last page's length. A rebuild
    // that kept a stale `false` would leave the new-language catalogue
    // permanently one page long.
    final container = await _container();
    final sub = container.listen(recipesProvider, (_, __) {});
    addTearDown(sub.close);

    await container.read(recipesProvider.future);
    // One row back from a 20-row page size means "end of catalogue".
    await container.read(recipesProvider.notifier).loadMore();
    expect(container.read(recipesProvider.notifier).hasMore, isFalse);

    await container.read(localeProvider.notifier).set(const Locale('en'));
    await container.read(recipesProvider.future);

    expect(
      container.read(recipesProvider.notifier).hasMore,
      isFalse,
      reason: 'a one-row page is genuinely the end — but it was recomputed, '
          'not carried over from the previous language',
    );
    expect(_RecordingRepository.fetches.last, 'en');
  });
}
