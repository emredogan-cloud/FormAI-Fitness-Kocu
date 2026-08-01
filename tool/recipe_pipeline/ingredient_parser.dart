/// Roadmap Phase 7 · turns a `MALZEMELER:` block into rows.
///
/// The 292 authored recipes store their ingredients as prose inside
/// `recipes.instructions`. Migration `014_recipe_ingredients.sql` gives
/// them a table; this is what fills it, and what the recipe pipeline
/// reuses to read back anything a model proposes.
///
/// ## The rule that shapes everything here
///
/// **A line this parser is unsure about is reported, never guessed.** A
/// missing quantity is a gap someone can see and fix. A wrong quantity
/// is a recipe that lies, and nothing downstream can tell the two apart.
/// So every branch below either produces a value it can defend or hands
/// the line back with [ParsedIngredient.confident] false.
///
/// ## What is deliberately not parsed
///
/// * **Combined seasoning lines** — `Pul biber, tuz, karabiber`. Three
///   ingredients on one line with no amounts. Splitting them on the
///   comma would be inventing three rows out of a line the author wrote
///   as one, and the amounts would still be null. Kept whole.
/// * **Adjectives that look like units.** `1 küçük kuru soğan` has no
///   unit — "küçük" is a size, not a measure. Only the closed list in
///   [_units] counts, which is why that list is data rather than a
///   pattern.
library;

/// One line of a `MALZEMELER:` block, resolved.
class ParsedIngredient {
  const ParsedIngredient({
    required this.position,
    required this.nameTr,
    required this.raw,
    this.quantity,
    this.unit,
    this.noteTr,
    this.confident = true,
  });

  /// 1-based line order, which is `recipe_ingredients.position`.
  final int position;

  /// The ingredient itself, adjectives included, parenthetical removed.
  final String nameTr;

  /// The source line, kept so the review sheet can show what was read.
  final String raw;

  /// Null when the line states no amount ("Tuz"). See the class doc.
  final num? quantity;

  /// One of [kKnownUnits], or null for a bare count ("3 yumurta").
  final String? unit;

  /// The parenthetical, if the line carried one: "kuru ölçü",
  /// "ince doğranmış".
  final String? noteTr;

  /// False when the line needs a human before it can be trusted. The
  /// row is still produced — dropping it would silently shorten a
  /// recipe — but the review sheet lists it.
  final bool confident;

  @override
  String toString() =>
      'ParsedIngredient($position, q=$quantity, u=$unit, "$nameTr"'
      '${noteTr == null ? '' : ', note="$noteTr"'}'
      '${confident ? '' : ', NEEDS REVIEW'})';
}

/// A whole `instructions` blob, split.
class ParsedRecipeBody {
  const ParsedRecipeBody({
    required this.ingredients,
    required this.steps,
    required this.problems,
  });

  final List<ParsedIngredient> ingredients;

  /// The `HAZIRLANIŞI:` half, header stripped, otherwise untouched.
  /// Empty when the blob had no method section.
  final String steps;

  /// Human-readable reasons this blob is not fully understood. Empty is
  /// the only acceptable state for a shipped row.
  final List<String> problems;

  bool get isClean => problems.isEmpty;
}

/// The kitchen units the catalogue actually uses, longest first so
/// `çay kaşığı` is matched before the bare `kaşığı` inside it.
///
/// A closed list rather than a pattern, because the alternative — "the
/// token after the number is the unit" — turns every adjective into a
/// unit and every `1 küçük kuru soğan` into 1 küçük of soğan.
const List<String> kKnownUnits = [
  'yemek kaşığı',
  'tatlı kaşığı',
  'çay kaşığı',
  'su bardağı',
  'çorba kaşığı',
  'porsiyon',
  'bardak',
  'fincan',
  'paket',
  'ölçek',
  'demet',
  'tutam',
  'dilim',
  'yaprak',
  'avuç',
  'kutu',
  'adet',
  'kaşık',
  'diş',
  'dal',
  'baş',
  'top',
  'kg',
  'gr',
  'ml',
  'lt',
  'g',
  'l',
];

/// Section headers seen in the live catalogue. `YAPILIŞ:` is not a typo
/// — two of the oldest seed rows use it, and a parser that only knows
/// the common spelling reports them as broken when they are merely old.
const List<String> kIngredientHeaders = ['MALZEMELER:', 'MALZEMELER'];
const List<String> kMethodHeaders = [
  'HAZIRLANIŞI:',
  'HAZIRLANISI:',
  'YAPILIŞ:',
  'YAPILISI:',
  'HAZIRLANIŞ:',
];

final RegExp _bullet = RegExp(r'^\s*[-•*–]\s*');
final RegExp _numberedStep = RegExp(r'^\s*\d+\s*[.)]\s');

/// `3`, `1.5`, `1,5`, `1/2`, `2-3`, `2–3`.
final RegExp _quantity = RegExp(
  r'^(\d+(?:[.,]\d+)?)'
  r'(?:\s*(?:/)\s*(\d+))?'
  r'(?:\s*[-–]\s*(\d+(?:[.,]\d+)?))?',
);

final RegExp _parenthetical = RegExp(r'\(([^)]*)\)');

/// Splits [instructions] into structured ingredients and a method half.
ParsedRecipeBody parseRecipeBody(String instructions) {
  final problems = <String>[];
  final source = instructions.replaceAll('\r\n', '\n');

  final ingredientStart = _indexOfAny(source, kIngredientHeaders);
  final methodStart = _indexOfAny(source, kMethodHeaders);

  if (ingredientStart == null) {
    problems.add(
      'no ingredient header — expected one of ${kIngredientHeaders.join(" / ")}',
    );
    return ParsedRecipeBody(
      ingredients: const [],
      steps: source.trim(),
      problems: problems,
    );
  }
  if (methodStart == null) {
    problems.add(
      'no method header — expected one of ${kMethodHeaders.join(" / ")}',
    );
  }

  final blockStart = ingredientStart.index + ingredientStart.header.length;
  final blockEnd = methodStart == null || methodStart.index < blockStart
      ? source.length
      : methodStart.index;
  final block = source.substring(blockStart, blockEnd);

  final steps = methodStart == null
      ? ''
      : source.substring(methodStart.index + methodStart.header.length).trim();

  final ingredients = <ParsedIngredient>[];
  var position = 0;
  for (final rawLine in block.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    // A numbered step inside the ingredient block means the method
    // header was missing or misspelled and the two halves ran together.
    // Reporting it beats silently filing "1. Soğanı kavurun" as food.
    if (_numberedStep.hasMatch(line)) {
      problems.add('a numbered step landed in the ingredient block: "$line"');
      continue;
    }

    position += 1;
    ingredients.add(_parseLine(line, position, problems));
  }

  if (ingredients.isEmpty) {
    problems.add('ingredient block is empty');
  }
  return ParsedRecipeBody(
    ingredients: ingredients,
    steps: steps,
    problems: problems,
  );
}

ParsedIngredient _parseLine(String line, int position, List<String> problems) {
  final raw = line;
  var rest = line.replaceFirst(_bullet, '').trim();
  final hadBullet = rest.length != line.length;

  // Lift the parenthetical before anything else, so "(1 cm dilim)"
  // cannot be mistaken for the line's own quantity.
  String? note;
  final paren = _parenthetical.firstMatch(rest);
  if (paren != null) {
    note = paren.group(1)?.trim();
    if (note != null && note.isEmpty) note = null;
    rest = rest.replaceFirst(_parenthetical, '').trim();
  }

  num? quantity;
  String? unit;
  var needsReview = false;

  final match = _quantity.firstMatch(rest);
  if (match != null) {
    final whole = num.parse(match.group(1)!.replaceAll(',', '.'));
    final denominator = match.group(2);
    final rangeTop = match.group(3);

    if (denominator != null) {
      // "1/2" — a fraction, and the only reading of a slash between two
      // bare numbers in a quantity position.
      final bottom = num.parse(denominator);
      quantity = bottom == 0 ? null : whole / bottom;
      if (bottom == 0) needsReview = true;
    } else if (rangeTop != null) {
      // "2-3 yumurta". The low end is what a shopping list needs — it is
      // the amount the recipe definitely requires — and the range itself
      // survives in the note so nothing is lost.
      quantity = whole;
      final rangeNote = '$whole–$rangeTop';
      note = note == null ? rangeNote : '$rangeNote, $note';
    } else {
      quantity = whole;
    }
    rest = rest.substring(match.end).trim();

    final matchedUnit = _leadingUnit(rest);
    if (matchedUnit != null) {
      unit = matchedUnit.canonical;
      rest = rest.substring(matchedUnit.length).trim();
    }
  }

  if (rest.isEmpty) {
    // A line that is only a number and a unit names no food.
    problems.add('line $position has an amount but no ingredient: "$raw"');
    needsReview = true;
    rest = raw;
  }

  if (!hadBullet) {
    problems.add('line $position is not bulleted: "$raw"');
    needsReview = true;
  }

  return ParsedIngredient(
    position: position,
    nameTr: rest,
    raw: raw,
    quantity: quantity,
    unit: unit,
    noteTr: note,
    confident: !needsReview,
  );
}

({String canonical, int length})? _leadingUnit(String text) {
  final lower = text.toLowerCase();
  for (final unit in kKnownUnits) {
    if (!lower.startsWith(unit)) continue;
    // Must end on a word boundary: `g` matches the start of "göğsü",
    // and "180g göğsü" is not 180 g of "öğsü".
    final after = text.length > unit.length ? text[unit.length] : ' ';
    if (RegExp(r'[\wğüşıöçİĞÜŞÖÇ]').hasMatch(after)) continue;
    // `gr` and `g` are the same unit written two ways; storing both
    // would mean a shopping list summing two columns.
    final canonical = switch (unit) {
      'gr' => 'g',
      'lt' => 'l',
      'çorba kaşığı' => 'yemek kaşığı',
      _ => unit,
    };
    return (canonical: canonical, length: unit.length);
  }
  return null;
}

({int index, String header})? _indexOfAny(String source, List<String> headers) {
  ({int index, String header})? best;
  for (final header in headers) {
    final index = source.indexOf(header);
    if (index == -1) continue;
    if (best == null || index < best.index) {
      best = (index: index, header: header);
    }
  }
  return best;
}
