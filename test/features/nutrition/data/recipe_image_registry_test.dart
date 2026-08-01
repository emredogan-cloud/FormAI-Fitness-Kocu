import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/data/recipe_image_registry.dart';

/// Roadmap Phase 7 · nothing is ever a blank tile.
///
/// Phase 7 adds 100 recipes and no photography, and the daily menu puts
/// four or five recipe tiles on the home screen every morning. The
/// property under test is that a recipe with no photograph of its own
/// still resolves to a photograph.
void main() {
  setUp(RecipeImageRegistry.debugReset);
  tearDown(RecipeImageRegistry.debugReset);

  group('the fallback chain', () {
    test('a bundled photograph wins', () {
      RecipeImageRegistry.debugSeed(
        {'photos/meals/overnight-protein-oats.webp'},
      );
      expect(
        RecipeImageRegistry.fallbackFor(
          slug: 'overnight-protein-oats',
          mealType: 'breakfast',
        ),
        'photos/meals/overnight-protein-oats.webp',
      );
    });

    test('a recipe with no photograph falls back to its meal type', () {
      RecipeImageRegistry.debugSeed(const {});
      expect(
        RecipeImageRegistry.fallbackFor(
          slug: 'overnight-protein-oats',
          mealType: 'breakfast',
        ),
        'photos/meals/budget_cover_breakfast.webp',
      );
    });

    test('every meal type has a cover, so the map is total', () {
      // If this fails, one meal type's recipes paint a gradient.
      for (final mealType in [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'dessert',
      ]) {
        expect(
          RecipeImageRegistry.fallbackFor(slug: null, mealType: mealType),
          isNotNull,
          reason: '$mealType has no cover photograph',
        );
      }
    });

    test('an unknown meal type resolves to null rather than a wrong image', () {
      expect(
        RecipeImageRegistry.fallbackFor(slug: 'x', mealType: 'brunch'),
        isNull,
      );
      expect(RecipeImageRegistry.fallbackFor(), isNull);
    });
  });

  group('the manifest contract', () {
    test('resolution works before warmUp, using the meal-type cover', () {
      // The registry is cold on first frame. Answering with a real
      // photograph rather than null is what stops a tile flashing empty.
      expect(RecipeImageRegistry.isWarm, isFalse);
      expect(
        RecipeImageRegistry.fallbackFor(slug: 'anything', mealType: 'lunch'),
        'photos/meals/budget_cover_lunch.webp',
      );
    });

    test('a slug is only claimed when the asset is actually bundled', () {
      // The failure this prevents: a code-side list saying a file exists
      // when it does not, which paints nothing at all. The lookup is
      // against the bundle's own manifest for exactly this reason.
      RecipeImageRegistry.debugSeed(
          {'photos/meals/chicken-and-rice-bowl.webp'});
      expect(
        RecipeImageRegistry.ownImageFor('chicken-and-rice-bowl'),
        isNotNull,
      );
      expect(RecipeImageRegistry.ownImageFor('not-generated-yet'), isNull);
      expect(RecipeImageRegistry.ownImageFor(''), isNull);
      expect(RecipeImageRegistry.ownImageFor(null), isNull);
    });

    test('covers live under the directory pubspec declares', () {
      // A file that never reaches the APK cannot be found by any lookup.
      for (final cover in RecipeImageRegistry.mealTypeCover.values) {
        expect(cover.startsWith(RecipeImageRegistry.mealDir), isTrue);
      }
    });
  });
}
