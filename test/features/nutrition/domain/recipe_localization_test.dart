import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe_ingredient.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_ingredient_lines.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_localization.dart';

/// Roadmap Phase 7 · which language a recipe renders in.
///
/// The rule under test — **one recipe, one language** — is the one the
/// plan singles out as most likely to be broken by a later change, so
/// it gets the most tests here. A resolver that decides per *field*
/// looks correct in every unit test written per field, and produces an
/// English title over Turkish steps on a real half-translated row.
Map<String, dynamic> _row({
  String? titleEn,
  String? instructionsEn,
  List<Map<String, dynamic>>? ingredients,
}) =>
    {
      'id': 'r1',
      'title': 'Menemen',
      'instructions': 'MALZEMELER:\n- 3 yumurta\n\nHAZIRLANIŞI:\n1. Kavurun.',
      'meal_type': 'breakfast',
      'calories': 350,
      'protein': 20,
      'carbs': 12,
      'fat': 22,
      'prep_time_minutes': 15,
      if (titleEn != null) 'title_en': titleEn,
      if (instructionsEn != null) 'instructions_en': instructionsEn,
      if (ingredients != null) 'recipe_ingredients': ingredients,
    };

Map<String, dynamic> _ingredient({
  int position = 1,
  num? quantity = 3,
  String? unit,
  String nameTr = 'yumurta',
  String? nameEn,
  String? noteTr,
  String? noteEn,
}) =>
    {
      'position': position,
      'quantity': quantity,
      'unit': unit,
      'name_tr': nameTr,
      if (nameEn != null) 'name_en': nameEn,
      if (noteTr != null) 'note_tr': noteTr,
      if (noteEn != null) 'note_en': noteEn,
    };

void main() {
  group('the fallback is Turkish, not English', () {
    test('an untranslated row asked for in English renders Turkish', () {
      final recipe = Recipe.fromJson(_row(), languageCode: 'en');
      expect(recipe.language, 'tr');
      expect(recipe.title, 'Menemen');
      expect(recipe.instructions, contains('MALZEMELER'));
    });

    test('never returns a blank title — the failure a wrong fallback gives',
        () {
      // `title` is not null on any row; `title_en` is a translation that
      // may not exist. Falling back to the possibly-null column is how a
      // catalogue renders as blank cards.
      for (final code in ['en', 'de', 'zz']) {
        expect(Recipe.fromJson(_row(), languageCode: code).title, 'Menemen');
      }
    });

    test('asking for Turkish never consults a translation column', () {
      final recipe = Recipe.fromJson(
        _row(titleEn: 'Turkish Scrambled Eggs'),
        languageCode: 'tr',
      );
      expect(recipe.title, 'Menemen');
      expect(recipe.language, 'tr');
    });
  });

  group('one recipe, one language', () {
    test('a fully translated row renders entirely in English', () {
      final recipe = Recipe.fromJson(
        _row(
          titleEn: 'Turkish Scrambled Eggs',
          instructionsEn: 'INGREDIENTS:\n- 3 eggs\n\nMETHOD:\n1. Scramble.',
        ),
        languageCode: 'en',
      );
      expect(recipe.language, 'en');
      expect(recipe.title, 'Turkish Scrambled Eggs');
      expect(recipe.instructions, contains('METHOD'));
    });

    test('a title without instructions falls the WHOLE recipe back', () {
      // The defect this rule exists to prevent: an English title over
      // Turkish steps, which reads as a bug rather than as untranslated
      // content.
      final recipe = Recipe.fromJson(
        _row(titleEn: 'Turkish Scrambled Eggs'),
        languageCode: 'en',
      );
      expect(recipe.language, 'tr');
      expect(recipe.title, 'Menemen');
    });

    test('instructions without a title falls the whole recipe back', () {
      final recipe = Recipe.fromJson(
        _row(instructionsEn: 'METHOD:\n1. Scramble.'),
        languageCode: 'en',
      );
      expect(recipe.language, 'tr');
      expect(recipe.instructions, contains('MALZEMELER'));
    });

    test('an empty-string translation counts as missing, not as translated',
        () {
      // A blank cell in a spreadsheet import arrives as '' rather than
      // null, and a recipe titled '' is the worst possible outcome.
      final recipe = Recipe.fromJson(
        _row(titleEn: '   ', instructionsEn: 'METHOD:\n1. Scramble.'),
        languageCode: 'en',
      );
      expect(recipe.language, 'tr');
      expect(recipe.title, 'Menemen');
    });

    test('one untranslated ingredient falls the whole recipe back', () {
      // The same defect one layer down: English title, English steps,
      // Turkish shopping list.
      final recipe = Recipe.fromJson(
        _row(
          titleEn: 'Turkish Scrambled Eggs',
          instructionsEn: 'METHOD:\n1. Scramble.',
          ingredients: [
            _ingredient(position: 1, nameTr: 'yumurta', nameEn: 'eggs'),
            _ingredient(position: 2, nameTr: 'sucuk'),
          ],
        ),
        languageCode: 'en',
      );
      expect(recipe.language, 'tr');
      expect(recipe.title, 'Menemen');
      expect(recipe.ingredientRows.map((i) => i.name), ['yumurta', 'sucuk']);
    });

    test('fully translated ingredients keep the recipe in English', () {
      final recipe = Recipe.fromJson(
        _row(
          titleEn: 'Turkish Scrambled Eggs',
          instructionsEn: 'METHOD:\n1. Scramble.',
          ingredients: [
            _ingredient(position: 1, nameTr: 'yumurta', nameEn: 'eggs'),
            _ingredient(
              position: 2,
              nameTr: 'sucuk',
              nameEn: 'sucuk',
              noteTr: 'dilimlenmiş',
              noteEn: 'Turkish beef sausage; chorizo works',
            ),
          ],
        ),
        languageCode: 'en',
      );
      expect(recipe.language, 'en');
      expect(recipe.ingredientRows.map((i) => i.name), ['eggs', 'sucuk']);
      expect(recipe.ingredientRows.last.note, contains('chorizo'));
    });
  });

  group('what is never translated', () {
    test('numbers, meal_type and the image survive the language switch', () {
      final tr = Recipe.fromJson(_row(), languageCode: 'tr');
      final en = Recipe.fromJson(
        _row(titleEn: 'X', instructionsEn: 'Y'),
        languageCode: 'en',
      );
      expect(en.calories, tr.calories);
      expect(en.protein, tr.protein);
      expect(en.mealType, tr.mealType);
      expect(en.prepTimeMinutes, tr.prepTimeMinutes);
    });

    test('a quantity and its unit are separate fields, never in the copy', () {
      final recipe = Recipe.fromJson(
        _row(ingredients: [
          _ingredient(quantity: 50, unit: 'g', nameTr: 'sucuk'),
        ]),
        languageCode: 'tr',
      );
      final row = recipe.ingredientRows.single;
      expect(row.quantity, 50);
      expect(row.unit, 'g');
      expect(row.name, 'sucuk');
    });
  });

  group('embedded ingredients', () {
    test('are sorted by position regardless of arrival order', () {
      final recipe = Recipe.fromJson(
        _row(ingredients: [
          _ingredient(position: 3, nameTr: 'tuz'),
          _ingredient(position: 1, nameTr: 'yumurta'),
          _ingredient(position: 2, nameTr: 'sucuk'),
        ]),
        languageCode: 'tr',
      );
      expect(
        recipe.ingredientRows.map((i) => i.name),
        ['yumurta', 'sucuk', 'tuz'],
      );
    });

    test('an absent embed is an empty list, not a crash', () {
      expect(Recipe.fromJson(_row()).ingredientRows, isEmpty);
    });
  });

  group('resolveRecipeLanguage directly', () {
    test('the fallback language short-circuits every check', () {
      expect(resolveRecipeLanguage(const {}, preferred: 'tr'), 'tr');
    });

    test('an unknown language falls back rather than reading null columns', () {
      expect(
        resolveRecipeLanguage(_row(titleEn: 'X'), preferred: 'de'),
        'tr',
      );
    });
  });

  group('recipeIngredientLines', () {
    test('prefers structured rows over the legacy blob', () {
      final recipe = Recipe.fromJson(
        _row(ingredients: [
          _ingredient(quantity: 100, unit: 'g', nameTr: 'kinoa'),
        ]),
        languageCode: 'tr',
      );
      expect(recipeIngredientLines(recipe), ['100 g kinoa']);
    });

    test('falls back to the MALZEMELER blob when there are no rows', () {
      // A client running against a database that has not had migration
      // 014 applied must not show an empty ingredient list.
      final recipe = Recipe.fromJson(_row(), languageCode: 'tr');
      expect(recipeIngredientLines(recipe), ['3 yumurta']);
    });

    test('falls back through the Phase 57 flat text[] in between', () {
      const recipe = Recipe(
        id: 'r',
        title: 'T',
        mealType: 'lunch',
        calories: 1,
        protein: 1,
        carbs: 1,
        fat: 1,
        prepTimeMinutes: 1,
        ingredients: ['2 yumurta', '1 dilim ekmek'],
      );
      expect(recipeIngredientLines(recipe), ['2 yumurta', '1 dilim ekmek']);
    });

    test('reads a single-sentence recipe by splitting on commas', () {
      expect(
        ingredientsFromInstructions('2 yumurta, 1 dilim peynir, 1 avokado.'),
        ['2 yumurta', '1 dilim peynir', '1 avokado.'],
      );
    });

    test('refuses to file a paragraph as one ingredient', () {
      expect(
          ingredientsFromInstructions('Bir tencerede suyu kaynatın.'), isEmpty);
      expect(ingredientsFromInstructions('${'x' * 250}, y'), isEmpty);
    });

    test('handles the YAPILIŞ: spelling the oldest seed rows use', () {
      expect(
        ingredientsFromInstructions(
          'MALZEMELER:\n- 150g somon\n- 200g tatlı patates\n'
          '\nYAPILIŞ:\n1. Pişir.',
        ),
        ['150g somon', '200g tatlı patates'],
      );
    });
  });

  group('formatQuantity', () {
    test('whole numbers lose their decimal', () {
      expect(formatQuantity(3), '3');
      expect(formatQuantity(100.0), '100');
    });

    test('kitchen fractions read as fractions, not as decimals', () {
      // "0.5 avokado" reads like a rounding error. Every cookbook in
      // every language writes 1/2.
      expect(formatQuantity(0.5), '1/2');
      expect(formatQuantity(0.25), '1/4');
      expect(formatQuantity(0.75), '3/4');
      expect(formatQuantity(0.333), '1/3');
    });

    test('a mixed number keeps its whole part', () {
      expect(formatQuantity(1.5), '1 1/2');
      expect(formatQuantity(2.25), '2 1/4');
    });

    test('anything else keeps a short decimal', () {
      expect(formatQuantity(1.2), '1.2');
    });

    test('emits ASCII only — it can never pick up a locale separator', () {
      for (final value in [0.5, 1.5, 1.2, 3, 100.0, 0.333]) {
        expect(RegExp(r'^[0-9 /.]+$').hasMatch(formatQuantity(value)), isTrue);
      }
    });
  });

  group('RecipeIngredient.displayLine', () {
    test('renders quantity, unit, name and note in that order', () {
      const row = RecipeIngredient(
        position: 1,
        quantity: 100,
        unit: 'g',
        name: 'kinoa',
        note: 'kuru ölçü',
      );
      expect(row.displayLine, '100 g kinoa (kuru ölçü)');
    });

    test('omits each part it does not have', () {
      expect(
        const RecipeIngredient(position: 1, name: 'Tuz').displayLine,
        'Tuz',
      );
      expect(
        const RecipeIngredient(position: 1, quantity: 3, name: 'yumurta')
            .displayLine,
        '3 yumurta',
      );
    });
  });
}
