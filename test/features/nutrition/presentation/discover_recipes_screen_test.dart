import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/presentation/discover_recipes_screen.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Phase 48 · `recipesProvider` switched from a `FutureProvider` to an
/// `AsyncNotifierProvider`, so tests can no longer override it with a
/// plain async factory. This stub returns the seeded list as the first
/// page and reports `hasMore = false` so the UI doesn't try to
/// paginate during tests.
class _StubRecipesNotifier extends PaginatedRecipesNotifier {
  _StubRecipesNotifier(this._seed);
  final List<Recipe> _seed;

  @override
  Future<List<Recipe>> build() async => _seed;
}

/// [recipes] is what the paginated catalogue has resident; [buckets] is
/// what Postgres returns for a given chip token.
///
/// Phase 7 device walk · the two are deliberately separate. A chip used
/// to narrow `recipes`, so a token whose rows had not paginated in yet
/// reported a count that grew as the user scrolled. Seeding them
/// independently is what lets a test tell the two sources apart —
/// `buckets` defaults to filtering `recipes` so the older tests, which
/// only care that a chip narrows the grid, keep reading as written.
Widget _host(
  List<Recipe> recipes, {
  Map<String, List<Recipe>>? buckets,
}) {
  return ProviderScope(
    overrides: [
      recipesProvider.overrideWith(() => _StubRecipesNotifier(recipes)),
      tagFilteredRecipesProvider.overrideWith(
        (ref, token) async =>
            buckets?[token] ??
            recipes.where((r) => r.tagTokens.contains(token)).toList(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      home: DiscoverRecipesScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Phase 7 · seeded with `tagTokens`, not the Turkish `tags` column.
/// The chips render `recipeTagLabel`, so this host (locale `tr`) still
/// reads "Yüksek Protein" — but the value the filter compares is now
/// `high_protein`, and that is the whole point of the split.
Recipe _recipe({
  required String id,
  required String title,
  List<String> tagTokens = const [],
  int protein = 20,
  int calories = 400,
}) {
  return Recipe(
    id: id,
    title: title,
    mealType: 'lunch',
    calories: calories,
    protein: protein,
    carbs: 40,
    fat: 15,
    prepTimeMinutes: 15,
    tagTokens: tagTokens,
  );
}

void main() {
  testWidgets('shows the filter row and a grid of recipes without overflow',
      (tester) async {
    await tester.pumpWidget(_host([
      _recipe(
          id: '1', title: 'Protein Bowl', tagTokens: const ['high_protein']),
      _recipe(id: '2', title: 'Vegan Wrap', tagTokens: const ['vegan']),
      _recipe(id: '3', title: 'Light Salad', tagTokens: const ['low_calorie']),
    ]));
    // Let the FutureProvider settle.
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Tüm Tarifler'), findsOneWidget);
    expect(find.text('Yüksek Protein'), findsWidgets);
    expect(find.text('Protein Bowl'), findsOneWidget);
    expect(find.text('Vegan Wrap'), findsOneWidget);
  });

  testWidgets('tapping a filter chip narrows the grid to matching recipes',
      (tester) async {
    await tester.pumpWidget(_host([
      _recipe(
          id: '1', title: 'Protein Bowl', tagTokens: const ['high_protein']),
      _recipe(id: '2', title: 'Vegan Wrap', tagTokens: const ['vegan']),
    ]));
    await tester.pump();
    await tester.pump();

    // The filter chip lives inside the top filter row; tapping it
    // should hide the non-matching "Vegan Wrap" card.
    await tester.tap(find.text('Yüksek Protein').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Protein Bowl'), findsOneWidget);
    expect(find.text('Vegan Wrap'), findsNothing);
  });

  testWidgets('shows an empty state when the filter excludes everything',
      (tester) async {
    await tester.pumpWidget(_host([
      _recipe(id: '1', title: 'Unflagged Bowl'),
    ]));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Vegan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    // Roadmap Phase 2 (C37) · this screen's private `_EmptyState` was
    // replaced by the shared `EmptyState`, which splits the old single
    // sentence into a title + body and adds a CTA that clears the filter.
    expect(find.text('Bu filtreye uygun tarif bulunamadı'), findsOneWidget);
    expect(find.text('Filtreyi Kaldır'), findsOneWidget);
  });

  testWidgets(
      'Phase 7 device walk · a chip reports the whole catalogue, not the '
      'pages that happen to be resident', (tester) async {
    // Page 1 as the user meets it on open: one vegan row among the
    // twenty that have loaded.
    final residentPage = [
      _recipe(id: '1', title: 'Vegan Wrap', tagTokens: const ['vegan']),
      _recipe(
          id: '2', title: 'Protein Bowl', tagTokens: const ['high_protein']),
    ];
    // What Postgres actually holds for that token.
    await tester.pumpWidget(_host(
      residentPage,
      buckets: {
        'vegan': [
          _recipe(id: '1', title: 'Vegan Wrap', tagTokens: const ['vegan']),
          _recipe(id: '9', title: 'Vegan Chili', tagTokens: const ['vegan']),
          _recipe(id: '17', title: 'Vegan Pancake', tagTokens: const ['vegan']),
        ],
      },
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Vegan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    // The two rows that had not paginated in are the whole point: before
    // the server-side fetch this screen said "1 tarif bulundu · Vegan"
    // and no amount of scrolling changed it, because a one-card grid
    // never reaches the bottom that triggers the next page.
    expect(find.text('3 tarif bulundu · Vegan'), findsOneWidget);
    expect(find.text('Vegan Wrap'), findsOneWidget);
    expect(find.text('Vegan Chili'), findsOneWidget);
    // And the resident non-matching row is gone, as before.
    expect(find.text('Protein Bowl'), findsNothing);

    // The third card is on the grid's second row, below an 800×600 test
    // viewport — scroll it in rather than trusting the count alone.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Vegan Pancake'), findsOneWidget);
  });

  testWidgets(
      'Roadmap Phase 2 (C37) · the empty state no longer dead-ends — its '
      'CTA clears the filter and the results come back', (tester) async {
    await tester.pumpWidget(_host([
      _recipe(id: '1', title: 'Unflagged Bowl'),
    ]));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Vegan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Unflagged Bowl'), findsNothing);

    await tester.tap(find.text('Filtreyi Kaldır'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    expect(find.text('Unflagged Bowl'), findsOneWidget);
  });
}
