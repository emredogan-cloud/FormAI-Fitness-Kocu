import '../../../../core/utils/media_url.dart';
import '../recipe_localization.dart';
import 'recipe_ingredient.dart';

/// Row from the Supabase `recipes` table. Columns are snake_case on the
/// server; [Recipe.fromJson] maps them to camelCase fields so the rest
/// of the app doesn't have to think about SQL naming conventions.
///
/// Phase 7 · the row arrives with a `<column>_<lang>` per shipped
/// language and [Recipe.fromJson] picks one language for the whole row.
/// [language] records which. See `domain/recipe_localization.dart` for
/// why that decision is per recipe rather than per field.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.prepTimeMinutes,
    this.imageUrl,
    this.instructions,
    this.tags = const [],
    this.tagTokens = const [],
    this.ingredients = const [],
    this.ingredientRows = const [],
    this.language = kRecipeFallbackLanguage,
  });

  /// Primary key. Stored as [String] regardless of whether the column is
  /// a SQL `uuid`, `bigint`, or `text` — callers treat it as opaque.
  final String id;

  final String title;

  /// One of: `breakfast`, `lunch`, `dinner`, `snack`. Kept as a plain
  /// string instead of an enum so new meal types can be added server-
  /// side without a client migration.
  final String mealType;

  /// Total kilocalories in one serving.
  final int calories;

  /// Macronutrients in grams for one serving.
  final int protein;
  final int carbs;
  final int fat;

  /// Approximate prep + cook time in whole minutes.
  final int prepTimeMinutes;

  /// Optional hero image URL (Supabase Storage, or a CDN reference).
  final String? imageUrl;

  /// Optional step-by-step instructions. Rendered as-is; may contain
  /// newlines for paragraph breaks.
  final String? instructions;

  /// **Legacy.** The Turkish category labels this catalogue shipped with
  /// (e.g. "Yüksek Protein", "Vegan"), read straight off the `tags`
  /// `text[]` column.
  ///
  /// Phase 7 replaced this with [tagTokens]. Nothing filters or renders
  /// on it any more; it is still parsed because migration `016` has not
  /// dropped the column yet and a model that silently ignores a column
  /// the server still returns is a model that lies about the row.
  final List<String> tags;

  /// Phase 7 · stable category identities from the `tag_tokens` `text[]`
  /// column — `high_protein`, `vegan`, `budget_friendly` and so on.
  ///
  /// These are **data identity, never copy**: they are what the
  /// repository filters on server-side and what the UI resolves to a
  /// localized label through `recipeTagLabel`. That split is the whole
  /// point — the Turkish [tags] column could not be translated without
  /// breaking the filter that read it.
  final List<String> tagTokens;

  /// Phase 57 · flat ingredient strings from the `recipes.ingredients`
  /// `text[]` column.
  ///
  /// **Null on every live row** and superseded by [ingredientRows], which
  /// carries quantity and unit as separate fields so a translation can
  /// never touch them. Still parsed because the column exists and a
  /// model that ignores a column the server returns is a model that lies
  /// about the row.
  final List<String> ingredients;

  /// Phase 7 · the `public.recipe_ingredients` rows for this recipe, in
  /// `position` order, already resolved to [language].
  ///
  /// Empty unless the caller asked for the embed — see
  /// `NutritionRepository._selectWithIngredients`. Empty is not the same
  /// as "this recipe has no ingredients"; the resolver in
  /// `domain/recipe_ingredient_lines.dart` is what tells the two apart.
  final List<RecipeIngredient> ingredientRows;

  /// The language every copy field on this instance is written in.
  ///
  /// Not necessarily the language the user picked: a row that is not
  /// fully translated renders entirely in Turkish rather than half in
  /// each. Surfaces that care — the audit, a "translation coming soon"
  /// affordance — read this instead of guessing from the text.
  final String language;

  /// Tolerant parser: coerces numeric fields from either `int` or `num`
  /// (Supabase sometimes returns `double` for integer columns depending
  /// on the driver path), and falls back to 0 for any missing numeric
  /// so a malformed row never crashes the recipe list.
  ///
  /// `tags` is delegated to [_parseTags] which handles both a Postgres
  /// text[] (decoded as `List<dynamic>`) and the raw Postgres array
  /// literal String form that certain driver paths return.
  ///
  /// Phase 7 · [languageCode] is what the reader asked for, not
  /// necessarily what they get. `resolveRecipeLanguage` decides once for
  /// the whole row and every copy field below follows that one decision,
  /// so a half-translated recipe renders entirely in Turkish rather than
  /// an English title over Turkish steps. Defaults to Turkish — the
  /// authored language, and the right answer for every caller that has
  /// no locale to offer.
  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    String languageCode = kRecipeFallbackLanguage,
  }) {
    final language = resolveRecipeLanguage(json, preferred: languageCode);
    return Recipe(
      id: json['id']?.toString() ?? '',
      title: localizedRecipeField(json, 'title', language: language) ?? '',
      mealType: (json['meal_type'] as String?) ?? 'snack',
      calories: _asInt(json['calories']),
      protein: _asInt(json['protein']),
      carbs: _asInt(json['carbs']),
      fat: _asInt(json['fat']),
      prepTimeMinutes: _asInt(json['prep_time_minutes']),
      // Phase 51 · route through MediaUrl so a configured CDN_BASE_URL
      // rewrites Supabase Storage URLs without touching the database.
      // External URLs (Unsplash etc.) pass through unchanged because
      // they're already CDN-served by their respective providers.
      imageUrl: MediaUrl.resolve(
        json['image_url'] as String?,
        bucket: 'recipes_images',
      ),
      instructions:
          localizedRecipeField(json, 'instructions', language: language),
      language: language,
      ingredientRows: _parseIngredients(json, language),
      tags: _parseTags(json['tags']),
      // Phase 7 · same tolerant parser; `tag_tokens` is a text[] with
      // exactly the two driver shapes `tags` has.
      tagTokens: _parseTags(json['tag_tokens']),
      // Phase 57 · `_parseTags` does the right thing for any
      // PG text[] column. Reuses the same tolerant parser instead of
      // duplicating the array-literal logic.
      ingredients: _parseTags(json['ingredients']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Reads the PostgREST embedded `recipe_ingredients(*)` resource.
  ///
  /// Sorted here rather than in the query because PostgREST orders an
  /// embedded resource with `order=recipe_ingredients(position)`, a
  /// syntax the supabase-flutter builder does not expose — and a
  /// six-element sort is not worth a raw RPC. Absent embed → empty list,
  /// which is the correct reading of "the caller did not ask".
  static List<RecipeIngredient> _parseIngredients(
    Map<String, dynamic> json,
    String language,
  ) {
    final embedded = json['recipe_ingredients'];
    if (embedded is! List) return const [];
    final rows = embedded
        .whereType<Map>()
        .map((row) => RecipeIngredient.fromJson(
              row.cast<String, dynamic>(),
              languageCode: language,
            ))
        .where((row) => row.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return List.unmodifiable(rows);
  }

  /// Tolerant parser for the `tags` column. Supabase returns Postgres
  /// arrays in two different shapes depending on the driver path:
  ///
  ///   • **List path** — the canonical PostgREST response; arrays
  ///     decode to `List<dynamic>` and each element is already a
  ///     `String`. Straight map + toString + trim.
  ///   • **String path** — hit when the column comes through an RPC,
  ///     a view with a cast, or certain edge cases in the supabase-
  ///     flutter client. The row arrives as the raw Postgres array
  ///     literal: `"{Vegan, Sıkılaşma}"` or with quoted elements
  ///     `'{"Yüksek Protein","Hacim"}'`. We strip the curly braces
  ///     and split on comma, trimming whitespace + stripping any
  ///     surrounding double-quotes from each element.
  ///
  /// Both paths return a clean `List<String>` like `["Vegan",
  /// "Sıkılaşma"]`. Null / anything unexpected falls through to an
  /// empty list so the UI doesn't crash on a malformed row.
  ///
  /// Phase 33 rename: was `_asStringList`. The name masked what the
  /// function was actually for — parsing the Postgres-shaped tags
  /// payload. Every call site was `tags`-specific anyway.
  ///
  /// **Every element goes through `.trim()`** so an incidental leading
  /// or trailing space from either path (e.g. `"{Vegan, Sıkılaşma}"`
  /// has a space after the comma) can never cause `==` comparisons
  /// with the chip labels to silently fail.
  static List<String> _parseTags(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      var s = value.trim();
      if (s.isEmpty) return const [];
      if (s.startsWith('{') && s.endsWith('}')) {
        s = s.substring(1, s.length - 1);
      }
      if (s.isEmpty) return const [];
      return s
          .split(',')
          .map((raw) {
            var element = raw.trim();
            if (element.length >= 2 &&
                element.startsWith('"') &&
                element.endsWith('"')) {
              element = element.substring(1, element.length - 1).trim();
            }
            return element;
          })
          .where((element) => element.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
