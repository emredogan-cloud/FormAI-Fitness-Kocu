import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe_ingredient.dart';
import 'package:sixpack_ai/features/nutrition/presentation/recipe_detail_screen.dart';
import 'package:sixpack_ai/features/referral/providers/referral_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The full recipe view. It takes a [Recipe] directly, so the tests
/// exercise its rendering (title / meal pill / macros / instructions /
/// action buttons) and the favourite-state read path. The favourite
/// *toggle* interaction (which fires a self-dismissing TopToast timer)
/// is already covered by favorites_screen_test, so these focus on the
/// static surface to stay timer-clean.

const String _kFavKey = 'sixpack.favorite_recipe_ids';

Recipe _recipe({
  required String id,
  String title = 'Protein Bowl',
  String mealType = 'lunch',
  String? instructions,
  List<RecipeIngredient> ingredientRows = const [],
}) {
  return Recipe(
    id: id,
    title: title,
    mealType: mealType,
    calories: 400,
    protein: 30,
    carbs: 40,
    fat: 15,
    prepTimeMinutes: 15,
    tags: const [],
    instructions: instructions,
    ingredientRows: ingredientRows,
  );
}

Widget _host(Recipe recipe, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // The share button reads the referral code; stub it so the test
      // never reaches the referral service / Supabase.
      referralCodeProvider.overrideWith((ref) async => 'TESTCODE'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      home: RecipeDetailScreen(recipe: recipe),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
    'renders the hero, meal pill, macros, instructions and CTAs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_host(
        _recipe(id: '1', instructions: 'Malzemeleri karıştır ve servis et.'),
        prefs,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Protein Bowl'), findsOneWidget);
      // Phase 7 device walk · this asserted 'LUNCH' — the raw
      // `meal_type` token uppercased — inside a `Locale('tr')` host, so
      // the test was pinning the defect in place rather than catching it.
      expect(find.text('ÖĞLE YEMEĞİ'), findsOneWidget);
      expect(find.text('15 dk'), findsOneWidget);
      expect(find.text('KALORİ'), findsOneWidget);
      // The macro value is a RichText (value span + unit span).
      expect(find.text('400 kcal', findRichText: true), findsOneWidget);
      expect(find.text('Hazırlanışı'), findsOneWidget);
      expect(find.text('Malzemeleri karıştır ve servis et.'), findsOneWidget);
      expect(find.text('Plana Ekle'), findsOneWidget);
      // Not favourited yet → outline heart.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    },
  );

  testWidgets('shows a filled heart when the recipe is already favourited',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      _kFavKey: <String>['1'],
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(_recipe(id: '1'), prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  // Phase 7 device walk · all five values `recipes.meal_type` takes.
  // `dessert` is the one the daily-plan timeline never renders, which is
  // why its label did not exist until this pill needed it. One
  // `testWidgets` each rather than a loop inside one: the favourites
  // notifier holds a `late` field that a second ProviderScope in the
  // same tester re-initialises.
  const mealTypeLabels = {
    'breakfast': 'KAHVALTI',
    'lunch': 'ÖĞLE YEMEĞİ',
    'dinner': 'AKŞAM YEMEĞİ',
    'snack': 'ARA ÖĞÜN',
    'dessert': 'TATLI',
  };
  mealTypeLabels.forEach((token, label) {
    testWidgets(
        'Phase 7 device walk · meal_type "$token" renders as copy, not the '
        'raw token', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_host(_recipe(id: '1', mealType: token), prefs));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
      // The English token must not survive anywhere on the screen.
      expect(find.text(token.toUpperCase()), findsNothing);
    });
  });

  testWidgets(
      'Phase 7 device walk · an English blob splits into sections and does '
      'not reprint the ingredient list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Exactly the shape `build_recipe_en.py` writes into
    // `instructions_en`, on a row that also carries structured
    // ingredients — which every live row does. The screen knew only
    // `MALZEMELER:` / `HAZIRLANIŞI:`, matched nothing here, and fell
    // through to the unstructured branch, which prints the whole blob.
    // So the English reader got the list from the structured rows and
    // then the identical list again inside the method.
    await tester.pumpWidget(_host(
      _recipe(
        id: '1',
        instructions: 'INGREDIENTS:\n- 150 g mozzarella\n- 200 g tomatoes\n\n'
            'METHOD:\n1. Slice them to the same thickness.',
        ingredientRows: const [
          RecipeIngredient(
              position: 1, name: 'mozzarella', quantity: 150, unit: 'g'),
          RecipeIngredient(
              position: 2, name: 'tomatoes', quantity: 200, unit: 'g'),
        ],
      ),
      prefs,
    ));
    await tester.pumpAndSettle();

    // The method step renders...
    expect(
      find.textContaining('Slice them to the same thickness'),
      findsOneWidget,
    );
    // ...and the raw markers never reach the screen.
    expect(find.textContaining('INGREDIENTS:'), findsNothing);
    expect(find.textContaining('METHOD:'), findsNothing);
    // The ingredient line appears once — in the structured section the
    // blob's own copy is meant to replace, not in both.
    expect(find.textContaining('150 g mozzarella'), findsOneWidget);
  });

  testWidgets('omits the instructions section when the recipe has none',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(_recipe(id: '1', instructions: null), prefs));
    await tester.pumpAndSettle();

    expect(find.text('Hazırlanışı'), findsNothing);
    // The rest of the screen still renders.
    expect(find.text('Protein Bowl'), findsOneWidget);
    expect(find.text('Plana Ekle'), findsOneWidget);
  });
}
