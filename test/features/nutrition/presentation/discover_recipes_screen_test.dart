import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/presentation/discover_recipes_screen.dart';
import 'package:sixpack_ai/features/nutrition/providers/nutrition_provider.dart';

Widget _host(List<Recipe> recipes) {
  return ProviderScope(
    overrides: [
      recipesProvider.overrideWith((ref) async => recipes),
    ],
    child: const MaterialApp(
      home: DiscoverRecipesScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

Recipe _recipe({
  required String id,
  required String title,
  List<String> tags = const [],
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
    tags: tags,
  );
}

void main() {
  testWidgets('shows the filter row and a grid of recipes without overflow',
      (tester) async {
    await tester.pumpWidget(_host([
      _recipe(id: '1', title: 'Protein Bowl', tags: const ['Yüksek Protein']),
      _recipe(id: '2', title: 'Vegan Wrap', tags: const ['Vegan']),
      _recipe(id: '3', title: 'Light Salad', tags: const ['Düşük Kalori']),
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
      _recipe(id: '1', title: 'Protein Bowl', tags: const ['Yüksek Protein']),
      _recipe(id: '2', title: 'Vegan Wrap', tags: const ['Vegan']),
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
    expect(find.text('Bu filtreye uygun tarif bulunamadı.'), findsOneWidget);
  });
}
