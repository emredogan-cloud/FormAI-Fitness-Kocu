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
  String displayLine({String languageCode = 'tr'}) {
    final buffer = StringBuffer();
    if (quantity != null) buffer.write(formatQuantity(quantity!));
    final rendered = localizedUnit(unit, quantity, languageCode: languageCode);
    if (rendered != null) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(rendered);
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

/// Renders [unit] in [languageCode], or null when the line should carry
/// no unit at all.
///
/// ## Naming, not converting
///
/// A `yemek kaşığı` becomes `tbsp` and never `15 ml`. §6.2 of the Phase 7
/// plan forbids converting a unit inside a translation for a specific
/// reason: `core/utils/unit_system.dart` is where conversion belongs, and
/// a value converted during translation cannot be converted back. So this
/// is a naming table — the same measure, said in the reader's language.
///
/// The Turkish column stays authoritative. It is the authored value and
/// is what the seed scripts, the audit and the pipeline all compare on;
/// this is presentation, exactly like `formatWeight`.
///
/// ## `adet` renders as nothing
///
/// Turkish counts with an explicit classifier — `10 adet zeytin`. English
/// does not: "10 pieces olives" is not a sentence anyone writes. The
/// honest rendering of a classifier a language does not have is nothing.
///
/// ## Why this exists at all
///
/// The Phase 7 translation audit found `2 yemek kaşığı olive oil` in the
/// generated English instructions of every new recipe. The ingredient
/// names had been translated and the units had not, because they live in
/// a different column and nothing had ever needed to read them in
/// English before.
///
/// ## Why the names are literals and not ARB keys
///
/// The hardcoded-string gate flags all twelve, and it is right to. They
/// are kept here anyway, marked, for a reason the gate cannot see:
///
///   * This is a **measurement glossary**, not product copy. There is one
///     correct English word for `yemek kaşığı` and no decision to make.
///     `docs/i18n/README.md` already carves out data identity for exactly
///     this shape of thing.
///   * `RecipeIngredient` is a pure model with no `BuildContext` and no
///     `AppLocalizations`, and the recipe pipeline — which has to render
///     the same line to build `instructions_en` — is a command-line tool
///     with no Flutter at all. Routing this through ARB would leave the
///     tool needing its own copy, which is how two copies become three.
///
/// There is already a second copy, in
/// `tool/recipe_pipeline/translations/build_recipe_en.py`, because that
/// script is Python. `test/tool/unit_glossary_parity_test.dart` reads
/// both files and fails when they disagree — two copies are acceptable
/// only when something proves they agree.
String? localizedUnit(
  String? unit,
  num? quantity, {
  required String languageCode,
}) {
  if (unit == null || unit.isEmpty) return null;
  if (languageCode == 'tr') return unit;

  final entry = kUnitGlossaryEn[unit];
  // An unknown unit renders as written. Dropping it would silently
  // remove an amount; guessing at it would silently change one.
  if (entry == null) return unit;
  final plural = quantity != null && quantity > 1;
  return plural ? entry.plural : entry.singular;
}

/// Turkish kitchen unit → its English name, singular and plural.
///
/// A measurement glossary, not copy — see [localizedUnit]'s doc for why
/// this is not in ARB. A null [UnitName.singular] means the unit renders
/// as nothing: Turkish counts with a classifier (`10 adet zeytin`) and
/// English does not.
// i18n-ignore — measurement glossary, mirrored by a parity test
const Map<String, UnitName> kUnitGlossaryEn = {
  // Metric abbreviations are already international.
  'g': UnitName('g', 'g'), // i18n-ignore
  'kg': UnitName('kg', 'kg'), // i18n-ignore
  'ml': UnitName('ml', 'ml'), // i18n-ignore
  'l': UnitName('l', 'l'), // i18n-ignore
  'adet': UnitName(null, null), // i18n-ignore
  'yemek kaşığı': UnitName('tbsp', 'tbsp'), // i18n-ignore
  'çay kaşığı': UnitName('tsp', 'tsp'), // i18n-ignore
  'tatlı kaşığı': UnitName('dessertspoon', 'dessertspoon'), // i18n-ignore
  'kaşık': UnitName('spoon', 'spoons'), // i18n-ignore
  'su bardağı': UnitName('glass', 'glasses'), // i18n-ignore
  'bardak': UnitName('glass', 'glasses'), // i18n-ignore
  'fincan': UnitName('small cup', 'small cups'), // i18n-ignore
  'dilim': UnitName('slice', 'slices'), // i18n-ignore
  'diş': UnitName('clove', 'cloves'), // i18n-ignore
  'demet': UnitName('bunch', 'bunches'), // i18n-ignore
  'dal': UnitName('sprig', 'sprigs'), // i18n-ignore
  'yaprak': UnitName('leaf', 'leaves'), // i18n-ignore
  'tutam': UnitName('pinch', 'pinches'), // i18n-ignore
  'çimdik': UnitName('pinch', 'pinches'), // i18n-ignore
  'avuç': UnitName('handful', 'handfuls'), // i18n-ignore
  'paket': UnitName('packet', 'packets'), // i18n-ignore
  'kutu': UnitName('can', 'cans'), // i18n-ignore
  'porsiyon': UnitName('portion', 'portions'), // i18n-ignore
  'ölçek': UnitName('scoop', 'scoops'), // i18n-ignore
  'baş': UnitName('head', 'heads'), // i18n-ignore
  'top': UnitName('ball', 'balls'), // i18n-ignore
};

/// One glossary entry. Null on both fields means "render nothing".
class UnitName {
  const UnitName(this.singular, this.plural);
  final String? singular;
  final String? plural;
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
