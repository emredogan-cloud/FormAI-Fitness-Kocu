import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/presentation/category_recipes_screen.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The per-category recipe list. Two behaviours are worth protecting:
///
///   • the AppBar title is derived from the route param (and, for the
///     `budget` sentinel, composed with the meal sub-filter);
///   • the body renders one card per recipe, or an empty state.
///
/// [categoryRecipesProvider] is a `FutureProvider.family`, overridden
/// here to return a seeded list without touching the repository.

Recipe _recipe({required String id, required String title}) {
  return Recipe(
    id: id,
    title: title,
    mealType: 'lunch',
    calories: 400,
    protein: 20,
    carbs: 40,
    fat: 15,
    prepTimeMinutes: 15,
    tags: const [],
  );
}

Widget _host({
  required String type,
  String? sub,
  required List<Recipe> recipes,
}) {
  return ProviderScope(
    overrides: [
      categoryRecipesProvider.overrideWith((ref, key) async => recipes),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      home: CategoryRecipesScreen(categoryType: type, mealTypeSubFilter: sub),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets('derives the category title and shows the empty state',
      (tester) async {
    await tester.pumpWidget(_host(type: 'breakfast', recipes: const []));
    await tester.pump();
    await tester.pump();

    expect(find.text('Kahvaltı Tarifleri'), findsOneWidget);
    expect(find.text('Bu kategoride henüz tarif yok.'), findsOneWidget);
  });

  testWidgets('composes the budget title with the meal sub-filter',
      (tester) async {
    await tester.pumpWidget(
      _host(type: 'budget', sub: 'breakfast', recipes: const []),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pratik & Ekonomik · Kahvaltı'), findsOneWidget);
  });

  testWidgets('renders a card per recipe with its macros', (tester) async {
    await tester.pumpWidget(_host(type: 'lunch', recipes: [
      _recipe(id: '1', title: 'Protein Bowl'),
      _recipe(id: '2', title: 'Chicken Wrap'),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Öğle Yemeği Tarifleri'), findsOneWidget);
    expect(find.text('Protein Bowl'), findsOneWidget);
    expect(find.text('Chicken Wrap'), findsOneWidget);
    expect(find.text('400 kcal'), findsWidgets);
    expect(find.text('Bu kategoride henüz tarif yok.'), findsNothing);
  });
}
