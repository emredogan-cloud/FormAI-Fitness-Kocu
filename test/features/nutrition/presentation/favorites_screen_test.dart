import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/presentation/favorites_screen.dart';
import 'package:sixpack_ai/features/nutrition/providers/favorite_recipes_provider.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';

/// "Favorilerim" filters the full recipe catalogue down to the ids the
/// user has hearted (persisted in SharedPreferences). The tests seed
/// the mock prefs and drive the *real* [FavoriteRecipesNotifier] so the
/// read + reactive-toggle path is exercised end to end.

const String _kFavKey = 'sixpack.favorite_recipe_ids';

class _StubRecipesNotifier extends PaginatedRecipesNotifier {
  _StubRecipesNotifier(this._seed);
  final List<Recipe> _seed;

  @override
  Future<List<Recipe>> build() async => _seed;
}

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

Widget _host(List<Recipe> recipes, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      recipesProvider.overrideWith(() => _StubRecipesNotifier(recipes)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(
      home: FavoritesScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
    'lists only the hearted recipes and offers the shopping-list export',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        _kFavKey: <String>['1', '3'],
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_host([
        _recipe(id: '1', title: 'Protein Bowl'),
        _recipe(id: '2', title: 'Vegan Wrap'),
        _recipe(id: '3', title: 'Light Salad'),
      ], prefs));
      await tester.pump();
      await tester.pump();

      expect(find.text('Protein Bowl'), findsOneWidget);
      expect(find.text('Light Salad'), findsOneWidget);
      expect(find.text('Vegan Wrap'), findsNothing);
      expect(find.text('Alışveriş Listesi Oluştur'), findsOneWidget);
    },
  );

  testWidgets('shows the empty state when nothing is hearted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host([
      _recipe(id: '1', title: 'Protein Bowl'),
    ], prefs));
    await tester.pump();
    await tester.pump();

    expect(find.text('Henüz favori tarifin yok'), findsOneWidget);
    expect(find.text('Protein Bowl'), findsNothing);
    expect(find.text('Alışveriş Listesi Oluştur'), findsNothing);
  });

  testWidgets('un-hearting a recipe reactively removes its row',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      _kFavKey: <String>['1', '2'],
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host([
      _recipe(id: '1', title: 'Protein Bowl'),
      _recipe(id: '2', title: 'Vegan Wrap'),
    ], prefs));
    await tester.pump();
    await tester.pump();

    expect(find.text('Protein Bowl'), findsOneWidget);
    expect(find.text('Vegan Wrap'), findsOneWidget);

    // Tap the first row's heart to un-favourite "Protein Bowl".
    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pump();
    await tester.pump();

    expect(find.text('Protein Bowl'), findsNothing);
    expect(find.text('Vegan Wrap'), findsOneWidget);
  });
}
