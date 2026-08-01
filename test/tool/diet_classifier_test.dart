import 'package:flutter_test/flutter_test.dart';

import '../../tool/recipe_pipeline/diet_classifier.dart';

/// Roadmap Phase 7 · the classifier behind `recipes.diet_flags`.
///
/// A flag here is a claim made to somebody who may have a medical or an
/// ethical reason to rely on it. Every test below is either a collision
/// the probe found against the real 297-name catalogue, or the safety
/// property that makes the collisions survivable.
void main() {
  group('the safety property', () {
    test('one unrecognised ingredient silences the whole recipe', () {
      // Not "assume it is fine". A missing flag costs one recipe one
      // filter; a wrong flag serves a vegan a bowl of yoghurt.
      expect(classifyDiet(['domates', 'zeytinyağı']), isNotEmpty);
      expect(classifyDiet(['domates', 'kırlangıç otu']), isEmpty);
    });

    test('an empty ingredient list makes no claim', () {
      expect(classifyDiet(const []), isEmpty);
    });

    test('halal is never derived, however plainly plant-based', () {
      expect(classifyDiet(['domates', 'salatalık']), isNot(contains('halal')));
      expect(kDerivableDietFlags, isNot(contains('halal')));
    });

    test('a packet whose contents vary is unrecognised on purpose', () {
      // Granola is oats plus *something* — honey in most brands. Guessing
      // either way is worse than being silent.
      expect(classifyIngredient('granola'), isEmpty);
      expect(classifyIngredient('şekersiz granola'), isEmpty);
    });
  });

  group('collisions the live catalogue actually contains', () {
    test('`un` (flour) does not match inside `olgun` or `limonun`', () {
      // A plain `contains` marked ripe tomatoes and lemon juice as
      // gluten, which silently stripped `gluten_free` off 20+ recipes.
      expect(classifyIngredient('olgun domates'),
          isNot(contains(IngredientKind.gluten)));
      expect(classifyIngredient('limonun suyu'),
          isNot(contains(IngredientKind.gluten)));
      expect(classifyIngredient('un'), contains(IngredientKind.gluten));
      expect(classifyIngredient('tam buğday unu'),
          contains(IngredientKind.gluten));
    });

    test('`hindi` (turkey) does not match inside `hindistan cevizi`', () {
      // Coconut classified as poultry. Every coconut-milk recipe would
      // have lost `vegan` and `vegetarian`.
      expect(classifyIngredient('hindistan cevizi rendesi'),
          {IngredientKind.plant});
      expect(
          classifyIngredient('hindistancevizi yağı'), {IngredientKind.plant});
      expect(classifyIngredient('hindi göğsü'), contains(IngredientKind.meat));
    });

    test('`bal` (honey) does not match inside `balığı`', () {
      expect(classifyIngredient('ton balığı'), {IngredientKind.fish});
      expect(classifyIngredient('bal'), {IngredientKind.honey});
    });

    test('`su` (water) does not match inside `sucuk`', () {
      expect(classifyIngredient('sucuk'), {IngredientKind.meat});
      expect(classifyIngredient('su'), {IngredientKind.plant});
    });

    test('a plant milk is not dairy', () {
      for (final milk in [
        'badem sütü',
        'hindistan cevizi sütü',
        'şekersiz badem sütü',
      ]) {
        expect(classifyIngredient(milk), isNot(contains(IngredientKind.dairy)),
            reason: '$milk read as dairy');
      }
      expect(classifyIngredient('yağsız süt'), contains(IngredientKind.dairy));
    });

    test('rice and corn flour are not wheat flour', () {
      expect(classifyIngredient('pirinç unu'), {IngredientKind.plant});
      expect(classifyIngredient('mısır unu'), {IngredientKind.plant});
    });

    test('a lentil köfte is not a meat köfte', () {
      // The recipe most likely to be sought by exactly the person a
      // wrong flag would fail.
      expect(classifyIngredient('ev yapımı mercimek köftesi'),
          {IngredientKind.plant});
      expect(classifyIngredient('hazır köfte harcı'),
          contains(IngredientKind.meat));
    });

    test('Turkish consonant mutation does not hide an ingredient', () {
      // `ekmek` → `ekmeği`, `pirinç` → `pirinci`, `fıstık` → `fıstığı`.
      // All three appeared in the catalogue and all three were
      // unrecognised before the stems were shortened.
      expect(classifyIngredient('köy ekmeği'), contains(IngredientKind.gluten));
      expect(classifyIngredient('yasemin pirinci'), {IngredientKind.plant});
      expect(
          classifyIngredient('kavrulmuş yer fıstığı'), {IngredientKind.plant});
    });
  });

  group('an ingredient can be more than one thing', () {
    test('meat-filled wheat dumplings are both', () {
      // An earlier draft returned one kind, filed this as meat, and
      // would have claimed gluten_free on a plate of mantı.
      expect(classifyIngredient('hazır pişmiş mantı'),
          {IngredientKind.meat, IngredientKind.gluten});
      expect(
          classifyDiet(['hazır pişmiş mantı']), isNot(contains('gluten_free')));
    });

    test('tarhana is fermented wheat AND yoghurt', () {
      expect(
          classifyDiet(['tarhana', 'domates']), isNot(contains('dairy_free')));
    });

    test('whey protein is dairy even when the flavour is plant', () {
      expect(classifyDiet(['çikolatalı whey protein tozu']),
          isNot(contains('dairy_free')));
    });
  });

  group('the flags themselves', () {
    test('a plant-only recipe earns every flag except halal', () {
      expect(
        classifyDiet(['domates', 'salatalık', 'zeytinyağı', 'tuz']),
        ['vegan', 'vegetarian', 'pork_free', 'gluten_free', 'dairy_free'],
      );
    });

    test('honey blocks vegan but not vegetarian', () {
      // The exact case the cross-check caught in the live catalogue:
      // `Fırın Tarçınlı Elma` was hand-tagged Vegan and contains 10 g of
      // honey.
      final flags = classifyDiet(['elma', 'tarçın', 'bal', 'çiğ ceviz']);
      expect(flags, isNot(contains('vegan')));
      expect(flags, contains('vegetarian'));
    });

    test('an egg blocks vegan but not vegetarian or dairy_free', () {
      final flags = classifyDiet(['yumurta', 'ıspanak']);
      expect(flags, isNot(contains('vegan')));
      expect(flags, contains('vegetarian'));
      expect(flags, contains('dairy_free'));
    });

    test('fish blocks vegetarian', () {
      expect(classifyDiet(['somon fileto', 'limon']),
          isNot(contains('vegetarian')));
    });

    test('every recognised recipe is pork_free — the catalogue audit', () {
      // sucuk and pastırma are beef in Turkey; the only cured slice is
      // turkey salami. Stated as a test so the day a pork ingredient is
      // added, this is what fails.
      for (final meat in ['sucuk', 'pastırma', 'hindi salam', 'dana kıyma']) {
        expect(classifyDiet([meat]), contains('pork_free'));
      }
    });
  });
}
