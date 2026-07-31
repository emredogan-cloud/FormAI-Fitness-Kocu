import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
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
      expect(find.text('LUNCH'), findsOneWidget); // mealType.toUpperCase()
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
