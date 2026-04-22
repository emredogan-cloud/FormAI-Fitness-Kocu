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

  /// Tolerant parser: coerces numeric fields from either `int` or `num`
  /// (Supabase sometimes returns `double` for integer columns depending
  /// on the driver path), and falls back to 0 for any missing numeric
  /// so a malformed row never crashes the recipe list.
  ///
  /// `tags` handles both a Postgres text[] (decoded as `List<dynamic>`
  /// of strings) and a JSON array, coercing each entry through
  /// `toString()` so a stray non-string element doesn't throw.
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
      imageUrl: json['image_url'] as String?,
      instructions: json['instructions'] as String?,
      tags: _asStringList(json['tags']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }
}
