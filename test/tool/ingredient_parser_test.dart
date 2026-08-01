import 'package:flutter_test/flutter_test.dart';

import '../../tool/recipe_pipeline/ingredient_parser.dart';

/// Roadmap Phase 7 · the parser that turned 1,642 lines of prose into
/// rows.
///
/// It ran once over the live catalogue, so the obvious question is why
/// it needs tests at all. Three reasons:
///
///   * The recipe pipeline reuses it to read back anything a model
///     proposes, which is not a one-off.
///   * `parse_catalogue.dart` is re-runnable after any content edit, and
///     a regression there would rewrite real rows.
///   * A wrong quantity is undetectable downstream. These tests are the
///     only place the difference between "50 g sucuk" and "50 sucuk" is
///     ever checked by something other than a person reading SQL.
void main() {
  group('section splitting', () {
    test('reads the canonical shape', () {
      final body = parseRecipeBody('''
MALZEMELER:
- 3 yumurta
- 50g sucuk dilimleri

HAZIRLANIŞI:
1. Sucukları kavurun.
2. Yumurtaları ekleyin.
''');
      expect(body.isClean, isTrue);
      expect(body.ingredients, hasLength(2));
      expect(body.steps, '1. Sucukları kavurun.\n2. Yumurtaları ekleyin.');
    });

    test('accepts YAPILIŞ: — two seed rows spell it that way', () {
      final body = parseRecipeBody('''
MALZEMELER:
- 150g somon

YAPILIŞ:
1. Somonu pişir.
''');
      expect(body.isClean, isTrue);
      expect(body.steps, '1. Somonu pişir.');
    });

    test('reports prose with no ingredient header instead of guessing', () {
      final body = parseRecipeBody(
        '1 ölçek protein tozu ve yarım avokadoyu blenderdan geçirin.',
      );
      expect(body.isClean, isFalse);
      expect(body.problems.single, contains('no ingredient header'));
      expect(body.ingredients, isEmpty);
    });

    test('reports a numbered step that leaked into the ingredient block', () {
      // This is what a missing or misspelled method header looks like
      // from the inside. Filing "1. Soğanı kavurun" as food would be
      // silent and wrong.
      final body = parseRecipeBody('''
MALZEMELER:
- 2 soğan
1. Soğanı kavurun.
''');
      expect(body.isClean, isFalse);
      // Both complaints are true and both are reported: the header is
      // missing *and* a step ended up where food belongs.
      expect(
        body.problems,
        contains(predicate<String>((p) => p.contains('numbered step'))),
      );
      expect(body.ingredients.map((i) => i.nameTr), ['soğan']);
    });

    test('an empty ingredient block is a problem, not an empty success', () {
      final body = parseRecipeBody('MALZEMELER:\n\nHAZIRLANIŞI:\n1. Pişir.');
      expect(body.isClean, isFalse);
      expect(body.problems, contains('ingredient block is empty'));
    });
  });

  group('quantities', () {
    ParsedIngredient one(String line) =>
        parseRecipeBody('MALZEMELER:\n$line\n\nHAZIRLANIŞI:\n1. x')
            .ingredients
            .single;

    test('a bare count has no unit', () {
      final i = one('- 3 yumurta');
      expect(i.quantity, 3);
      expect(i.unit, isNull);
      expect(i.nameTr, 'yumurta');
    });

    test('a unit glued to the number still separates', () {
      final i = one('- 50g sucuk dilimleri');
      expect(i.quantity, 50);
      expect(i.unit, 'g');
      expect(i.nameTr, 'sucuk dilimleri');
    });

    test('a fraction becomes a real number', () {
      final i = one('- 1/2 avokado');
      expect(i.quantity, 0.5);
      expect(i.nameTr, 'avokado');
    });

    test('a decimal written with a comma parses — Turkish writes 1,5', () {
      expect(one('- 1,5 kg tavuk').quantity, 1.5);
    });

    test('a range keeps its low end and records the range in the note', () {
      // The low end is what the recipe definitely needs, which is what a
      // shopping list has to carry. Losing the range entirely would be
      // dropping something the author wrote.
      final i = one('- 2-3 diş sarımsak');
      expect(i.quantity, 2);
      expect(i.unit, 'diş');
      expect(i.noteTr, '2–3');
    });

    test('a line with no amount keeps a null quantity, never a guessed 1', () {
      final i = one('- Tuz');
      expect(i.quantity, isNull);
      expect(i.unit, isNull);
      expect(i.nameTr, 'Tuz');
      expect(i.confident, isTrue);
    });
  });

  group('units', () {
    ParsedIngredient one(String line) =>
        parseRecipeBody('MALZEMELER:\n$line\n\nHAZIRLANIŞI:\n1. x')
            .ingredients
            .single;

    test('multi-word units win over the shorter unit inside them', () {
      // `kaşık` is a unit and sits inside `çay kaşığı`. Matching the
      // short one first would leave "ı pul biber" as the ingredient.
      final i = one('- 1 çay kaşığı pul biber');
      expect(i.unit, 'çay kaşığı');
      expect(i.nameTr, 'pul biber');
    });

    test('a unit must end on a word boundary', () {
      // `g` starts "göğsü". "180g tavuk göğsü" is 180 g of chicken
      // breast, not 180 of "öğsü".
      final i = one('- 180g tavuk göğsü fileto');
      expect(i.unit, 'g');
      expect(i.nameTr, 'tavuk göğsü fileto');
    });

    test('an adjective is not a unit', () {
      // "küçük" is a size. A parser that takes the token after the
      // number turns this into 1 küçük of "kuru soğan".
      final i = one('- 1 küçük kuru soğan');
      expect(i.unit, isNull);
      expect(i.nameTr, 'küçük kuru soğan');
    });

    test('spelling variants collapse to one unit', () {
      // Two columns for the same unit means a shopping list has to sum
      // both, and one day will not.
      expect(one('- 200 gr yoğurt').unit, 'g');
      expect(one('- 1 lt su').unit, 'l');
      expect(one('- 2 çorba kaşığı zeytinyağı').unit, 'yemek kaşığı');
    });
  });

  group('notes', () {
    ParsedIngredient one(String line) =>
        parseRecipeBody('MALZEMELER:\n$line\n\nHAZIRLANIŞI:\n1. x')
            .ingredients
            .single;

    test('lifts the parenthetical off the name', () {
      final i = one('- 100g kinoa (kuru ölçü)');
      expect(i.quantity, 100);
      expect(i.unit, 'g');
      expect(i.nameTr, 'kinoa');
      expect(i.noteTr, 'kuru ölçü');
    });

    test('a number inside the parenthetical is not the line quantity', () {
      // "(1 cm dilim)" would otherwise be read as the amount.
      final i = one('- 250g tatlı patates (kabuklu, 1 cm dilim)');
      expect(i.quantity, 250);
      expect(i.noteTr, 'kabuklu, 1 cm dilim');
      expect(i.nameTr, 'tatlı patates');
    });
  });

  group('what is deliberately left alone', () {
    test('a combined seasoning line stays one row', () {
      // Three ingredients on one line with no amounts. Splitting on the
      // comma invents three rows out of a line the author wrote as one,
      // and every amount would still be null.
      final body = parseRecipeBody('MALZEMELER:\n- Pul biber, tuz, karabiber\n'
          '\nHAZIRLANIŞI:\n1. x');
      expect(body.isClean, isTrue);
      expect(body.ingredients.single.nameTr, 'Pul biber, tuz, karabiber');
    });

    test('position is line order, 1-based, and survives blank lines', () {
      final body = parseRecipeBody('''
MALZEMELER:
- 1 yumurta

- 2 domates

HAZIRLANIŞI:
1. x
''');
      expect(body.ingredients.map((i) => i.position), [1, 2]);
    });
  });

  group('confidence', () {
    test('an unbulleted line is produced but flagged', () {
      // Dropping it would silently shorten the recipe; trusting it would
      // silently accept a stray line as food. It is kept and reported.
      final body = parseRecipeBody(
        'MALZEMELER:\n2 yumurta\n\nHAZIRLANIŞI:\n1. x',
      );
      expect(body.isClean, isFalse);
      expect(body.ingredients.single.confident, isFalse);
      expect(body.ingredients.single.nameTr, 'yumurta');
    });

    test('an amount with no ingredient is flagged', () {
      final body = parseRecipeBody(
        'MALZEMELER:\n- 200 g\n\nHAZIRLANIŞI:\n1. x',
      );
      expect(body.isClean, isFalse);
      expect(body.problems.first, contains('no ingredient'));
      expect(body.ingredients.single.confident, isFalse);
    });
  });
}
