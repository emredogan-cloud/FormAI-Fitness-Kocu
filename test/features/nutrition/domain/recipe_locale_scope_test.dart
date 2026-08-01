import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_localization.dart';

/// Roadmap Phase 7 · `recipes.locale_scope` orders, it does not filter.
///
/// The trap this guards is specific and attractive: `where(scope
/// contains language)` is one line shorter than a sort and reads as
/// obviously correct. It halves the catalogue for every user, and
/// somebody who has heard of a dish and cannot find it concludes the app
/// does not have it.
Recipe _recipe(String id, {List<String> scope = const []}) => Recipe(
      id: id,
      title: id,
      mealType: 'lunch',
      calories: 400,
      protein: 20,
      carbs: 40,
      fat: 12,
      prepTimeMinutes: 15,
      localeScope: scope,
    );

void main() {
  group('sortRecipesForLocale', () {
    test('nothing is ever dropped', () {
      final source = [
        _recipe('menemen'),
        _recipe('overnight-oats', scope: ['en']),
        _recipe('kisir', scope: ['tr']),
      ];
      for (final language in ['tr', 'en', 'de']) {
        expect(
          sortRecipesForLocale(source, language).map((r) => r.id).toSet(),
          {'menemen', 'overnight-oats', 'kisir'},
          reason: '$language lost a recipe',
        );
      }
    });

    test('the reader\'s own language leads', () {
      final source = [
        _recipe('menemen'),
        _recipe('overnight-oats', scope: ['en']),
      ];
      expect(
        sortRecipesForLocale(source, 'en').map((r) => r.id),
        ['overnight-oats', 'menemen'],
      );
    });

    test('an unscoped recipe outranks one scoped to another language', () {
      // Three ranks, not two. A recipe written for English readers still
      // reaches a Turkish one — last, but reachable.
      final source = [
        _recipe('overnight-oats', scope: ['en']),
        _recipe('menemen'),
        _recipe('kisir', scope: ['tr']),
      ];
      expect(
        sortRecipesForLocale(source, 'tr').map((r) => r.id),
        ['kisir', 'menemen', 'overnight-oats'],
      );
    });

    test('is stable, so the caller\'s own ordering survives underneath', () {
      // The category screen sorts by id; the menu generator sorts by
      // macro fit. Neither should be scrambled by the locale pass.
      final source = [
        _recipe('a'),
        _recipe('b'),
        _recipe('c'),
        _recipe('d', scope: ['en']),
      ];
      expect(
        sortRecipesForLocale(source, 'tr').map((r) => r.id),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('an empty scope is the common case and never sorts last', () {
      final source = [
        _recipe('scoped', scope: ['fr']),
        _recipe('open')
      ];
      expect(
        sortRecipesForLocale(source, 'en').map((r) => r.id),
        ['open', 'scoped'],
      );
    });
  });

  group('Recipe.fromJson · Phase 7 columns', () {
    test('reads cuisine, diet_flags and locale_scope', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r',
        'title': 'T',
        'meal_type': 'dinner',
        'cuisine': 'american',
        'diet_flags': ['high_protein_is_not_a_diet', 'gluten_free'],
        'locale_scope': ['en'],
      });
      expect(recipe.cuisine, 'american');
      expect(recipe.dietFlags, contains('gluten_free'));
      expect(recipe.localeScope, ['en']);
    });

    test('a row from before migration 015 reads as no claim, not as safe', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r',
        'title': 'T',
        'meal_type': 'dinner',
      });
      expect(recipe.cuisine, isNull);
      expect(recipe.dietFlags, isEmpty);
      expect(recipe.localeScope, isEmpty);
      // The distinction that matters: empty is not "vegan-safe".
      expect(recipe.dietFlags.contains('vegan'), isFalse);
    });
  });
}
