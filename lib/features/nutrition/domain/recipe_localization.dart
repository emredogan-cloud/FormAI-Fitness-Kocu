/// Roadmap Phase 7 · which language a recipe row renders in.
///
/// Migration `011_content_localization_schema.sql` gave `recipes` a
/// `<column>_<lang>` for every shipped language and left them null.
/// Migration `014` did the same for `recipe_ingredients`. This is the
/// one place that decides which set of columns a row is read from.
///
/// ## Three properties, and why each one matters
///
/// **The fallback is Turkish, not English.** `title` is the authored
/// column and is `not null` on every row; `title_en` is a translation
/// that may not have been written yet. A resolver that fell back to
/// English would produce blank cards for every untranslated recipe — a
/// worse failure than a Turkish one, because it looks like the app is
/// broken rather than the content being incomplete.
///
/// **It resolves in one place, with the locale passed in.** The same
/// shape `core/utils/unit_system.dart` uses: a pure function taking the
/// language as an argument rather than reading a `BuildContext`
/// scattered through the repository. That is what makes the rule below
/// testable without a widget tree.
///
/// **Resolution is per recipe, not per field.** This is the rule a later
/// change is most likely to break, so it is stated plainly: a recipe
/// with `title_en` but no `instructions_en` renders an **English title
/// over Turkish steps**, which is worse than being entirely Turkish —
/// it reads as a bug rather than as untranslated content, and it is the
/// state a half-finished translation pass leaves rows in. So if any
/// required field is missing for the requested language, the **whole
/// recipe** falls back. One recipe, one language.
///
/// The ingredient names are part of that decision, not separate from it.
/// A recipe whose title and steps are English but whose ingredient list
/// is Turkish is the same defect one layer down.
library;

import 'models/recipe.dart';

/// The language every recipe is authored in and falls back to.
const String kRecipeFallbackLanguage = 'tr';

/// The columns that must all be present for a recipe to render in a
/// non-Turkish language.
///
/// `image_url`, the macros and `prep_time_minutes` are absent on purpose
/// — they are not copy, so they cannot be missing "for English".
const List<String> kLocalizedRecipeColumns = ['title', 'instructions'];

/// Decides the language [json] renders in, given what the reader asked
/// for.
///
/// Returns [kRecipeFallbackLanguage] unless every column in
/// [kLocalizedRecipeColumns] — and every ingredient name, when the
/// ingredients came down with the row — is populated for [preferred].
String resolveRecipeLanguage(
  Map<String, dynamic> json, {
  required String preferred,
}) {
  if (preferred == kRecipeFallbackLanguage) return kRecipeFallbackLanguage;

  for (final column in kLocalizedRecipeColumns) {
    if (!_hasText(json['${column}_$preferred'])) {
      return kRecipeFallbackLanguage;
    }
  }

  // The embedded ingredient rows, when the caller asked for them. A
  // recipe is not translated until its shopping list is.
  final embedded = json['recipe_ingredients'];
  if (embedded is List) {
    for (final row in embedded) {
      if (row is! Map) continue;
      if (!_hasText(row['name_$preferred'])) return kRecipeFallbackLanguage;
    }
  }

  return preferred;
}

/// Reads `<column>` for [language], falling back to the authored Turkish
/// column when the localized one is absent.
///
/// Callers should pass the language [resolveRecipeLanguage] returned, not
/// the one the user picked — that is what keeps a row from rendering two
/// languages at once. The fallback here is a safety net for the columns
/// [kLocalizedRecipeColumns] does not cover, not the primary mechanism.
String? localizedRecipeField(
  Map<String, dynamic> json,
  String column, {
  required String language,
}) {
  if (language != kRecipeFallbackLanguage) {
    final value = json['${column}_$language'];
    if (_hasText(value)) return value as String;
  }
  final base = json[column];
  return base is String ? base : null;
}

bool _hasText(dynamic value) => value is String && value.trim().isNotEmpty;

/// Orders [recipes] so the ones authored for [language] lead.
///
/// This is the entire mechanism behind `recipes.locale_scope`, and the
/// property that matters is what it does **not** do: nothing is removed.
/// An English reader sees overnight oats first and menemen further down;
/// a Turkish reader sees the reverse. Both see all of it.
///
/// Filtering by locale was the obvious implementation and is a trap — it
/// halves the catalogue for everyone, and a user who has heard of a dish
/// and cannot find it concludes the app does not have it.
///
/// Stable: recipes with the same scope keep their incoming order, so the
/// caller's own sort (macro fit, id, relevance) survives underneath.
List<Recipe> sortRecipesForLocale(List<Recipe> recipes, String language) {
  final indexed = recipes.indexed.toList()
    ..sort((a, b) {
      final rank = _localeRank(a.$2, language) - _localeRank(b.$2, language);
      return rank != 0 ? rank : a.$1 - b.$1;
    });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

/// 0 for a recipe authored for this language, 1 for one authored for
/// nobody in particular, 2 for one authored for a different language.
///
/// Three ranks rather than two: a recipe scoped to *another* language
/// still appears, just last. That is what keeps "it orders, it does not
/// filter" true for the case the rule was written for.
int _localeRank(Recipe recipe, String language) {
  if (recipe.localeScope.isEmpty) return 1;
  return recipe.localeScope.contains(language) ? 0 : 2;
}
