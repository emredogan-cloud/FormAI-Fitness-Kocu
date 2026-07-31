import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/macro_target.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/services/next_best_meal_service.dart';

Recipe _recipe({
  required String id,
  required int protein,
  required int calories,
  int carbs = 0,
  int fat = 0,
  String mealType = 'lunch',
}) {
  return Recipe(
    id: id,
    title: 'Recipe $id',
    mealType: mealType,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    prepTimeMinutes: 10,
  );
}

void main() {
  const service = NextBestMealService();

  group('NextBestMealService.suggestNextMeal — edge cases', () {
    test('returns null when the recipe catalogue is empty', () {
      final result = service.suggestNextMeal(
        recipes: const [],
        remaining: const MacroTarget(
          calories: 1200,
          protein: 60,
          carbs: 140,
          fat: 40,
        ),
      );

      expect(result, isNull);
    });
  });

  group('Tier 1: protein focus', () {
    test(
        'picks the highest-protein non-dessert recipe when protein gap '
        'exceeds the 30 g threshold', () {
      final recipes = [
        _recipe(id: 'salad', protein: 10, calories: 220),
        _recipe(id: 'steak', protein: 48, calories: 520),
        _recipe(id: 'chicken', protein: 40, calories: 410),
        _recipe(
          id: 'high_protein_cake',
          protein: 60,
          calories: 550,
          mealType: 'dessert',
        ),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 1800,
          protein: 80,
          carbs: 200,
          fat: 60,
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.recipe.id,
        'steak',
        reason: 'dessert-type recipes are excluded even when highest protein',
      );
      expect(result.reason, NextMealReason.proteinGap);
      expect(result.impactString, '+48g Protein | +520 kcal');
    });

    test('falls through when no recipe clears the 25 g protein floor', () {
      final recipes = [
        _recipe(id: 'soup', protein: 8, calories: 180),
        _recipe(id: 'yogurt', protein: 12, calories: 150),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 1200,
          protein: 70,
          carbs: 150,
          fat: 40,
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.reason,
        isNot(NextMealReason.proteinGap),
        reason: 'tier 1 must yield to tier 2 / tier 3 when no candidate '
            'matches the high-protein filter',
      );
    });
  });

  group('Tier 2: low-calorie finish', () {
    test(
        'picks the lightest recipe under 300 kcal when only ~350 kcal '
        'remain in the day', () {
      final recipes = [
        _recipe(id: 'light_salad', protein: 8, calories: 180),
        _recipe(id: 'snack_bar', protein: 6, calories: 230),
        _recipe(id: 'fat_bomb', protein: 20, calories: 520),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 350,
          protein: 10,
          carbs: 40,
          fat: 12,
        ),
      );

      expect(result, isNotNull);
      expect(result!.recipe.id, 'light_salad');
      expect(result.reason, NextMealReason.lowCalorie);
    });

    test(
        'still falls through when low-kcal gap fires but the catalogue has '
        'no recipe under the 300 kcal ceiling', () {
      final recipes = [
        _recipe(id: 'heavy_a', protein: 20, calories: 500),
        _recipe(id: 'heavy_b', protein: 22, calories: 600),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 300,
          protein: 10,
          carbs: 40,
          fat: 12,
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.reason,
        NextMealReason.bestBalance,
        reason: 'tier 2 empty → tier 3 balance recommendation fires',
      );
    });
  });

  group('Tier 3: macro-balance fallback', () {
    test(
        'ranks recipes by Euclidean distance on the (protein, carbs, fat) '
        'vector when neither specialised tier applies', () {
      // Remaining = (20g protein, 60g carbs, 10g fat). The balanced option
      // should win despite another recipe carrying more total calories.
      final recipes = [
        _recipe(
          id: 'far_off',
          protein: 80,
          calories: 800,
          carbs: 5,
          fat: 45,
        ),
        _recipe(
          id: 'balanced',
          protein: 22,
          calories: 420,
          carbs: 58,
          fat: 12,
        ),
        _recipe(id: 'another', protein: 15, calories: 380, carbs: 70, fat: 5),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 800,
          protein: 20,
          carbs: 60,
          fat: 10,
        ),
      );

      expect(result, isNotNull);
      expect(result!.recipe.id, 'balanced');
      expect(result.reason, NextMealReason.bestBalance);
    });

    test('distance metric treats each axis as equally weighted', () {
      // Remaining macro vector: (30g, 30g, 30g). The closest recipe wins
      // even if its raw protein is lower, because carbs and fat deltas
      // weigh into the Euclidean distance equally.
      final recipes = [
        _recipe(id: 'protein_only', protein: 30, calories: 200),
        _recipe(
          id: 'well_rounded',
          protein: 24,
          calories: 400,
          carbs: 28,
          fat: 26,
        ),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 800,
          protein: 30,
          carbs: 30,
          fat: 30,
        ),
      );

      expect(result, isNotNull);
      expect(result!.recipe.id, 'well_rounded');
    });
  });

  group('impact string formatting', () {
    test('impactString exposes the recipe protein and kcal preview', () {
      final recipes = [
        _recipe(
          id: 'balanced',
          protein: 22,
          calories: 420,
          carbs: 58,
          fat: 12,
        ),
      ];

      final result = service.suggestNextMeal(
        recipes: recipes,
        remaining: const MacroTarget(
          calories: 800,
          protein: 20,
          carbs: 60,
          fat: 10,
        ),
      );

      expect(result, isNotNull);
      expect(result!.impactString, '+22g Protein | +420 kcal');
    });
  });
}
