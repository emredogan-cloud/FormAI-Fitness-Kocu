/// Roadmap Phase 7 · one row of `public.recipe_ingredients`.
///
/// Before migration `014_recipe_ingredients.sql` an ingredient list was
/// prose inside `recipes.instructions`, and three surfaces — the detail
/// screen, the favourites shopping-list export and the share sheet —
/// each re-parsed that prose with their own splitter. This type is what
/// replaced all three.
///
/// The reason it exists rather than a `List<String>` is that quantities
/// and units have to survive translation **byte-exact**. A translator —
/// human or model — handed "50 g sucuk" can return "2 oz sucuk", and the
/// app has `core/utils/unit_system.dart` for conversion; doing it inside
/// a translation makes it un-round-trippable. Splitting the number away
/// from the words means only the words are ever translated.
library;

class RecipeIngredient {
  const RecipeIngredient({
    required this.position,
    required this.name,
    this.quantity,
    this.unit,
    this.note,
  });

  /// Line order in the authored list, 1-based. The sort key.
  final int position;

  /// The ingredient, already resolved to the reader's language by
  /// [RecipeIngredient.fromJson]. Never null — an ingredient with no
  /// name is not an ingredient.
  final String name;

  /// Null when the author stated no amount ("Tuz", "Pul biber, tuz,
  /// karabiber"). Null is the honest answer; a guessed 1 would appear in
  /// a shopping list as a fact nobody wrote.
  final num? quantity;

  /// A Turkish kitchen unit (`g`, `ml`, `yemek kaşığı`, `diş`) or null
  /// for a bare count. Deliberately not translated — see the library
  /// doc.
  final String? unit;

  /// Prep state ("kuru ölçü", "ince doğranmış") or, for an ingredient
  /// that stays a proper noun abroad, what to buy instead.
  final String? note;

  /// Renders as one line, the way the shopping list and the share sheet
  /// want it: `100 g kinoa (kuru ölçü)`.
  ///
  /// The quantity is formatted, not interpolated: `0.5` has to read as
  /// `1/2` and `100.0` as `100`, and every caller getting that right
  /// independently is how one of them stops.
  String get displayLine {
    final buffer = StringBuffer();
    if (quantity != null) buffer.write(formatQuantity(quantity!));
    if (unit != null) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(unit);
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(name);
    if (note != null && note!.isNotEmpty) buffer.write(' ($note)');
    return buffer.toString();
  }

  /// Reads the row, taking the localized name and note when the column
  /// for [languageCode] is populated and falling back to Turkish when it
  /// is not.
  ///
  /// The fallback is **Turkish, not English**: `name_tr` is the authored
  /// column and is never null, while `name_en` is a translation that may
  /// not exist yet. Falling back to a possibly-null column produces
  /// blank ingredient lines, which is worse than a Turkish word beside a
  /// number everyone can read.
  factory RecipeIngredient.fromJson(
    Map<String, dynamic> json, {
    required String languageCode,
  }) {
    String? localized(String column) {
      final value = json['${column}_$languageCode'];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return RecipeIngredient(
      position: _asInt(json['position']),
      name: localized('name') ?? (json['name_tr'] as String? ?? ''),
      quantity: json['quantity'] is String
          ? num.tryParse(json['quantity'] as String)
          : json['quantity'] as num?,
      unit: (json['unit'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['unit'] as String?,
      note: localized('note') ?? (json['note_tr'] as String?),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Formats a stored quantity the way a recipe writes it.
///
/// Whole numbers lose their decimal, and the four fractions a kitchen
/// actually uses render as fractions — `0.5` is written `1/2` in every
/// cookbook in every language, and `0.5 avokado` reads like a rounding
/// error.
///
/// Locale-independent by construction: it only ever emits ASCII digits
/// and a slash, so it cannot pick up a decimal comma from one locale and
/// a point from another the way `price_format.dart` had to guard against.
String formatQuantity(num quantity) {
  if (quantity == quantity.roundToDouble()) return quantity.round().toString();
  // A list of pairs rather than a map: a `const` map keyed on double is
  // a compile error, and comparing doubles by equality is what the
  // tolerance below exists to avoid anyway.
  const fractions = [
    (0.25, '1/4'),
    (0.333, '1/3'),
    (0.5, '1/2'),
    (0.75, '3/4'),
  ];
  final whole = quantity.floor();
  for (final (value, label) in fractions) {
    if ((quantity - value).abs() < 0.005) return label;
    if (whole > 0 && (quantity - whole - value).abs() < 0.005) {
      return '$whole $label';
    }
  }
  return quantity
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
