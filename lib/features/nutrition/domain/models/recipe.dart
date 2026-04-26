import '../../../../core/utils/media_url.dart';

/// Row from the Supabase `recipes` table. Columns are snake_case on the
/// server; [Recipe.fromJson] maps them to camelCase fields so the rest
/// of the app doesn't have to think about SQL naming conventions.
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
    this.ingredients = const [],
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

  /// Dietitian-curated category labels (e.g. "Yüksek Protein", "Vegan").
  /// Populated from the Postgres `text[]` column of the same name. The
  /// list is immutable; callers should treat missing/empty as "no tag
  /// overrides, fall back to macro-based heuristics".
  final List<String> tags;

  /// Phase 57 · structured ingredients list. Optional Postgres
  /// `text[]` column; when present the share / shopping-list builders
  /// prefer it over heuristic extraction from `instructions`.
  /// Mirrors the [_parseTags] tolerance for both List and Postgres
  /// array-literal payloads so a backend that hasn't migrated to a
  /// proper text[] yet can still ship rows.
  final List<String> ingredients;

  /// Tolerant parser: coerces numeric fields from either `int` or `num`
  /// (Supabase sometimes returns `double` for integer columns depending
  /// on the driver path), and falls back to 0 for any missing numeric
  /// so a malformed row never crashes the recipe list.
  ///
  /// `tags` is delegated to [_parseTags] which handles both a Postgres
  /// text[] (decoded as `List<dynamic>`) and the raw Postgres array
  /// literal String form that certain driver paths return.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
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
      instructions: json['instructions'] as String?,
      tags: _parseTags(json['tags']),
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
