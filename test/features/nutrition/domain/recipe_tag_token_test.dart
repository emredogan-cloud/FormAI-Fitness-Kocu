import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_tag_token.dart';
import 'package:sixpack_ai/features/nutrition/presentation/widgets/recipe_tags.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 7 · the token ⇄ label split.
///
/// The property under test is the one migration
/// `013_recipe_tag_tokens.sql` exists to create: **the value the filter
/// compares never changes with the language, and the value the user
/// reads always does.** Before Phase 7 they were the same string, so
/// exactly one of those could be true at a time.
Future<AppLocalizations> _l10n(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

Recipe _recipe(List<String> tokens) => Recipe(
      id: 'r',
      title: 'T',
      mealType: 'lunch',
      calories: 400,
      protein: 30,
      carbs: 40,
      fat: 12,
      prepTimeMinutes: 15,
      tagTokens: tokens,
    );

void main() {
  group('token registry', () {
    test('carries exactly the six tokens migration 013 seeded', () {
      expect(kRecipeTagTokens, [
        'budget_friendly',
        'high_protein',
        'low_calorie',
        'bulking',
        'toning',
        'vegan',
      ]);
    });

    test('every token has both a label and a style in every locale', () async {
      for (final code in ['tr', 'en']) {
        final l10n = await _l10n(code);
        for (final token in kRecipeTagTokens) {
          expect(
            recipeTagLabel(l10n, token),
            isNotNull,
            reason: '$token has no $code label — the chip would not render',
          );
          expect(recipeTagStyle(token), isNotNull,
              reason: '$token has no style');
        }
      }
    });

    test('tokens are snake_case ASCII — they are database identities', () {
      for (final token in kRecipeTagTokens) {
        expect(
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(token),
          isTrue,
          reason: '$token is not a stable identifier',
        );
      }
    });
  });

  group('label resolution', () {
    test('the same token reads differently in each language', () async {
      final tr = await _l10n('tr');
      final en = await _l10n('en');
      expect(recipeTagLabel(tr, 'high_protein'), 'Yüksek Protein');
      expect(recipeTagLabel(en, 'high_protein'), 'High protein');
      expect(recipeTagLabel(tr, 'bulking'), 'Hacim');
      expect(recipeTagLabel(en, 'bulking'), 'Bulking');
    });

    test('no English label carries a Turkish-only character', () async {
      final en = await _l10n('en');
      for (final token in kRecipeTagTokens) {
        expect(
          recipeTagLabel(en, token)!.contains(RegExp('[ğşıİçöüĞŞÇÖÜ]')),
          isFalse,
          reason: '$token still reads Turkish in the English app',
        );
      }
    });

    test('an unknown token resolves to null, never to the raw token', () async {
      final en = await _l10n('en');
      // A seventh token shipping server-side must not leak a database
      // identifier onto a chip. Null means "render nothing".
      expect(recipeTagLabel(en, 'gluten_free'), isNull);
      expect(recipeTagStyle('gluten_free'), isNull);
    });
  });

  group('badge selection', () {
    test('maps tokens to badges in the order the server stored them', () async {
      final en = await _l10n('en');
      final badges = recipeTags(en, _recipe(['vegan', 'high_protein']));
      expect(badges.map((b) => b.label), ['Vegan', 'High protein']);
    });

    test('silently skips a token this build has no label for', () async {
      final en = await _l10n('en');
      final badges = recipeTags(en, _recipe(['high_protein', 'gluten_free']));
      expect(badges.map((b) => b.label), ['High protein']);
    });

    test(
        'an untagged recipe gets no badges — the macro heuristic moved into '
        'migration 013 and must not live in two places', () async {
      final en = await _l10n('en');
      // 40 g protein and 600 kcal would have produced two badges under
      // the old client-side fallback. The database now assigns those
      // tokens at backfill time, so the client asking again could only
      // ever disagree with it.
      final beefy = Recipe(
        id: 'r',
        title: 'T',
        mealType: 'dinner',
        calories: 600,
        protein: 40,
        carbs: 50,
        fat: 20,
        prepTimeMinutes: 10,
      );
      expect(recipeTags(en, beefy), isEmpty);
    });

    test('the legacy Turkish tags column no longer selects anything', () async {
      final en = await _l10n('en');
      final legacyOnly = Recipe(
        id: 'r',
        title: 'T',
        mealType: 'lunch',
        calories: 400,
        protein: 30,
        carbs: 40,
        fat: 12,
        prepTimeMinutes: 15,
        tags: const ['Yüksek Protein'],
      );
      expect(recipeTags(en, legacyOnly), isEmpty);
    });
  });

  group('Recipe.fromJson', () {
    test('parses tag_tokens alongside the legacy tags column', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r',
        'title': 'T',
        'meal_type': 'lunch',
        'calories': 400,
        'protein': 30,
        'carbs': 40,
        'fat': 12,
        'prep_time_minutes': 15,
        'tags': ['Yüksek Protein'],
        'tag_tokens': ['high_protein'],
      });
      expect(recipe.tags, ['Yüksek Protein']);
      expect(recipe.tagTokens, ['high_protein']);
    });

    test('tolerates the Postgres array-literal shape', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r',
        'title': 'T',
        'meal_type': 'lunch',
        'tag_tokens': '{high_protein,"budget_friendly"}',
      });
      expect(recipe.tagTokens, ['high_protein', 'budget_friendly']);
    });

    test('a row from before migration 013 parses to an empty token list', () {
      final recipe = Recipe.fromJson(const {
        'id': 'r',
        'title': 'T',
        'meal_type': 'lunch',
      });
      expect(recipe.tagTokens, isEmpty);
    });
  });
}
