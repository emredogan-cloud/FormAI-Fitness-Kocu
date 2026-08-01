/// Roadmap Phase 7 · one answer to "what are this recipe's ingredients".
///
/// There used to be two copies of this logic — `FavoritesScreen`'s
/// shopping-list export and `ShareService`'s recipe share — with a
/// comment on both saying "a third caller is the trigger to refactor".
/// Migration `014_recipe_ingredients.sql` is that third caller: the
/// detail screen now renders structured rows too, and three hand-rolled
/// blob scanners that must agree is three that eventually will not.
///
/// ## The order, and why
///
///   1. **[Recipe.ingredientRows]** — the `recipe_ingredients` table.
///      Quantity, unit, name and note as separate fields, already
///      resolved to the recipe's language.
///   2. **`recipes.ingredients`** — the flat `text[]` from Phase 57.
///      Null on every live row, kept because the column exists.
///   3. **The `MALZEMELER:` blob** — scanned out of `instructions`.
///
/// Step 3 is the one that has to survive. Migration `014` is applied but
/// `instructions` still carries the block, and will until `016`; more to
/// the point, a client running against a database that has not been
/// migrated must not show an empty ingredient list. The fallback is what
/// makes the schema change invisible rather than staged.
library;

import 'models/recipe.dart';

/// The ingredient lines to render, in the recipe's own order.
///
/// Returns an empty list only when the recipe genuinely states no
/// ingredients anywhere — which no live row does.
List<String> recipeIngredientLines(Recipe recipe) {
  if (recipe.ingredientRows.isNotEmpty) {
    return recipe.ingredientRows
        .map((row) => row.displayLine)
        .toList(growable: false);
  }
  if (recipe.ingredients.isNotEmpty) return recipe.ingredients;
  return ingredientsFromInstructions(recipe.instructions);
}

/// The pre-014 fallback: find the `MALZEMELER:` header and collect the
/// lines under it.
///
/// Case-insensitive and accent-tolerant on the header because the seed
/// data spells the method header three ways (`HAZIRLANIŞI:`, `YAPILIŞ:`,
/// and one row that had neither until Phase 7 fixed it by hand).
List<String> ingredientsFromInstructions(String? instructions) {
  final raw = (instructions ?? '').trim();
  if (raw.isEmpty) return const [];

  final extracted = <String>[];
  var inBlock = false;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (inBlock) break; // a blank line ends the block
      continue;
    }
    if (_ingredientHeader.hasMatch(trimmed)) {
      inBlock = true;
      continue;
    }
    if (_methodHeader.hasMatch(trimmed)) {
      if (inBlock) break;
      continue;
    }
    if (inBlock) extracted.add(_stripBullet(trimmed));
  }
  if (extracted.isNotEmpty) return extracted;

  // No header at all. Split the first sentence on commas — this is what
  // a single-line recipe looks like ("2 yumurta, 1 dilim peynir"). The
  // length guard stops a paragraph being filed as one ingredient, and
  // requiring two parts stops a plain sentence qualifying.
  final firstSentence = raw.split(RegExp(r'(?<=[.!?])\s+')).first;
  if (firstSentence.length > 240) return const [];
  final commaSplit = firstSentence
      .split(RegExp(r'[,;]'))
      .map((part) => _stripBullet(part.trim()))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return commaSplit.length >= 2 ? commaSplit : const [];
}

/// Parse markers embedded in stored recipe text, NOT UI copy. Localising
/// these would stop them matching the row being parsed.
final RegExp _ingredientHeader =
    RegExp(r'^malzemeler\s*:?\s*$', caseSensitive: false); // i18n-ignore
final RegExp _methodHeader = RegExp(
  r'^(yapılışı|yapılış|hazırlanışı|hazırlanış|tarif)\s*:?\s*$',
  caseSensitive: false,
); // i18n-ignore

String _stripBullet(String line) =>
    line.replaceFirst(RegExp(r'^[-•*–]\s*'), '').trim();
