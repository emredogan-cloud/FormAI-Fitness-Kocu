import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';

void main() {
  group('Recipe.fromJson', () {
    test('parses core fields with typed values', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'title': 'Yumurta Omlet',
        'meal_type': 'breakfast',
        'calories': 320,
        'protein': 25,
        'carbs': 8,
        'fat': 18,
        'prep_time_minutes': 10,
        'image_url': 'https://example.com/x.jpg',
        'instructions': 'Karıştır, pişir.',
        'tags': <String>[],
      });

      expect(recipe.id, 'r1');
      expect(recipe.title, 'Yumurta Omlet');
      expect(recipe.mealType, 'breakfast');
      expect(recipe.calories, 320);
      expect(recipe.protein, 25);
      expect(recipe.carbs, 8);
      expect(recipe.fat, 18);
      expect(recipe.prepTimeMinutes, 10);
      expect(recipe.imageUrl, 'https://example.com/x.jpg');
      expect(recipe.instructions, 'Karıştır, pişir.');
      expect(recipe.tags, isEmpty);
    });

    test('coerces numeric fields from doubles / numeric strings', () {
      final recipe = Recipe.fromJson(const {
        'id': 42,
        'calories': 410.7,
        'protein': 30.0,
        'carbs': '55',
        'fat': 'abc',
        'prep_time_minutes': 15.4,
      });

      expect(recipe.id, '42', reason: 'id is coerced via toString');
      expect(recipe.calories, 411, reason: '410.7 rounds up to 411');
      expect(recipe.protein, 30);
      expect(recipe.carbs, 55);
      expect(recipe.fat, 0, reason: 'malformed numeric falls back to 0');
      expect(recipe.prepTimeMinutes, 15);
    });

    test('falls back to defaults on missing / null fields', () {
      final recipe = Recipe.fromJson(const <String, dynamic>{});

      expect(recipe.id, '');
      expect(recipe.title, '');
      expect(recipe.mealType, 'snack');
      expect(recipe.calories, 0);
      expect(recipe.protein, 0);
      expect(recipe.carbs, 0);
      expect(recipe.fat, 0);
      expect(recipe.prepTimeMinutes, 0);
      expect(recipe.imageUrl, isNull);
      expect(recipe.instructions, isNull);
      expect(recipe.tags, isEmpty);
    });
  });

  group('Recipe.fromJson tags parsing — List path', () {
    test('returns a clean list for a typed List<String>', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': ['Vegan', 'Sıkılaşma', 'Yüksek Protein'],
      });

      expect(recipe.tags, ['Vegan', 'Sıkılaşma', 'Yüksek Protein']);
    });

    test('trims whitespace on each element', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': [' Vegan ', '  Sıkılaşma'],
      });

      expect(recipe.tags, ['Vegan', 'Sıkılaşma']);
    });

    test('drops empty entries so the UI does not render blank chips', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': ['Vegan', '', '   ', 'Hacim'],
      });

      expect(recipe.tags, ['Vegan', 'Hacim']);
    });
  });

  group('Recipe.fromJson tags parsing — Postgres string path', () {
    test('handles the unquoted {Vegan, Sıkılaşma} form', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': '{Vegan, Sıkılaşma}',
      });

      expect(
        recipe.tags,
        ['Vegan', 'Sıkılaşma'],
        reason: 'leading space after comma must be stripped',
      );
    });

    test('handles the double-quoted {"Yüksek Protein","Hacim"} form', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': '{"Yüksek Protein","Hacim"}',
      });

      expect(recipe.tags, ['Yüksek Protein', 'Hacim']);
    });

    test('handles a single-element Postgres literal', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': '{Vegan}',
      });

      expect(recipe.tags, ['Vegan']);
    });

    test('returns empty list for the literal empty array "{}"', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r1',
        'tags': '{}',
      });

      expect(recipe.tags, isEmpty);
    });

    test('returns empty list for an empty or whitespace-only string', () {
      final empty = Recipe.fromJson(const {'id': 'r1', 'tags': ''});
      final whitespace = Recipe.fromJson(const {'id': 'r1', 'tags': '   '});

      expect(empty.tags, isEmpty);
      expect(whitespace.tags, isEmpty);
    });
  });

  group('Recipe.fromJson tags parsing — misc fallbacks', () {
    test('returns empty list when tags is null', () {
      final recipe = Recipe.fromJson(const {'id': 'r1', 'tags': null});

      expect(recipe.tags, isEmpty);
    });

    test('returns empty list for unexpected types (int)', () {
      final recipe = Recipe.fromJson(const {'id': 'r1', 'tags': 7});

      expect(recipe.tags, isEmpty);
    });

    test('returns empty list when tags key is missing entirely', () {
      final recipe = Recipe.fromJson(const {'id': 'r1'});

      expect(recipe.tags, isEmpty);
    });
  });
}
