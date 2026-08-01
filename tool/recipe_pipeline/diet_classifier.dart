/// Roadmap Phase 7 · what a recipe's ingredients say about who can eat it.
///
/// Migration `015_recipe_origin_and_diet.sql` adds `recipes.diet_flags`.
/// This decides what goes in it, for the 292 authored recipes and for
/// anything the pipeline proposes afterwards.
///
/// ## The rule: an unknown ingredient blocks every claim
///
/// A missing `vegan` flag means one recipe does not appear in one
/// filter. A wrong `vegan` flag means a vegan was served yoghurt. Those
/// are not comparable errors, and nothing downstream can tell a derived
/// flag from an authored one.
///
/// So classification is **positive recognition, not negative
/// inference**: every ingredient in a recipe must match a known term
/// before any flag is derived. One unrecognised word and the recipe
/// makes no dietary claim at all — it is still in the catalogue, still
/// searchable, just silent about diets.
///
/// That is also what happens to a packet whose contents genuinely vary.
/// `granola` is oats plus *something* — honey in most brands, maple in
/// some, neither in others — and the honest classification of "we do not
/// know" is [IngredientKind.unknown], not a guess in whichever direction
/// looks safer this week.
///
/// ## An ingredient can be more than one thing
///
/// [classifyIngredient] returns a **set**. `hazır pişmiş mantı` is meat
/// *and* wheat; an earlier draft returned one kind, filed it as meat,
/// and would have claimed `gluten_free` on a plate of dumplings.
///
/// ## Matching is word-initial, not substring
///
/// `un` is Turkish for flour and is also inside `olgun` and `limonun`.
/// A plain `contains` marked ripe tomatoes and lemon juice as gluten. So
/// a term matches only where a word starts — suffixes after it are fine,
/// which is what makes `ekme` cover both `ekmek` and `ekmeği` across
/// Turkish consonant mutation.
///
/// ## `halal` is never derived
///
/// It cannot be. Halal requires the animal to have been slaughtered a
/// particular way, which is not a property of the word "dana kıyma".
/// Deriving it from "no pork" would be the exact conflation the plan
/// calls out — two different claims, and getting the stronger one wrong
/// is how an app becomes untrustworthy in a market. `halal` stays
/// authored; [classifyDiet] never sets it.
///
/// `pork_free` **is** derived, and is a real and separately useful
/// claim. The audit behind it: `sucuk` and `pastırma` are beef in
/// Turkey, and the only cured slice in the catalogue is `hindi salam` —
/// turkey. None of the 297 distinct ingredient names is pork.
library;

/// What an ingredient rules out.
enum IngredientKind {
  plant,
  dairy,
  egg,

  /// Honey. Not meat, not dairy, and not vegan — the one category that
  /// exists solely because a vegan claim is stricter than a vegetarian
  /// one.
  honey,
  meat,
  fish,

  /// Carries gluten. Orthogonal to the rest: bread is plant *and* this.
  gluten,
}

/// The flags [classifyDiet] can derive. `halal` is deliberately absent —
/// see the library doc.
const List<String> kDerivableDietFlags = [
  'vegan',
  'vegetarian',
  'pork_free',
  'gluten_free',
  'dairy_free',
];

/// Names whose reading the term tables would get wrong, resolved first.
///
/// Every entry here is a case where the general rule produces a
/// defensible-looking answer that is false.
const Map<String, Set<IngredientKind>> _overrides = {
  // Plant milks contain the word for milk.
  'badem sütü': {IngredientKind.plant},
  'hindistan cevizi sütü': {IngredientKind.plant},
  'hindistancevizi sütü': {IngredientKind.plant},
  'soya sütü': {IngredientKind.plant},
  'yulaf sütü': {IngredientKind.plant, IngredientKind.gluten},
  // Not wheat flour.
  'pirinç unu': {IngredientKind.plant},
  'mısır unu': {IngredientKind.plant},
  'nohut unu': {IngredientKind.plant},
  'badem unu': {IngredientKind.plant},
  // A lentil köfte is not a meat köfte, and this is the recipe most
  // likely to be sought by exactly the person a wrong flag would fail.
  'mercimek köftesi': {IngredientKind.plant},
  // Bulgur and spice. The classic is meatless, and it is sold as a mix.
  'hazır çiğ köfte karışımı': {IngredientKind.plant, IngredientKind.gluten},
  // Meat-filled wheat dumplings — both, which is the whole reason
  // classification returns a set.
  'mantı': {IngredientKind.meat, IngredientKind.gluten},
  // Stock is meat-derived even as a cube.
  'et suyu': {IngredientKind.meat},
  'tavuk suyu': {IngredientKind.meat},
  'sebze suyu': {IngredientKind.plant},
  // "honey or maple syrup" — the reader may use either, so the stricter
  // reading is the safe one.
  'bal veya akçaağaç şurubu': {IngredientKind.honey},
  // Coconut. `hindi` is turkey and starts this word; without the
  // override, coconut milk is poultry.
  'hindistan cevizi': {IngredientKind.plant},
  'hindistancevizi': {IngredientKind.plant},
  // Tuna. `bal` is honey and starts `balığı`.
  'ton balığı': {IngredientKind.fish},
  // Fermented wheat AND yoghurt. Matching only the wheat would have
  // claimed `dairy_free` on tarhana soup.
  'tarhana': {IngredientKind.gluten, IngredientKind.dairy},
  // A meatball mix is meat and, in every packet sold, breadcrumb.
  'köfte harcı': {IngredientKind.meat, IngredientKind.gluten},
};

/// Names that are deliberately unrecognised.
///
/// Not an oversight — a prepared food whose composition varies by brand.
/// Listing them here rather than leaving them to fall through keeps the
/// distinction visible: this is "we know we do not know", not "we forgot
/// a word".
const Set<String> _knownUnknowable = {
  'granola',
};

/// Substrings that mark a kind, matched at a word start.
///
/// Stems rather than whole words where Turkish consonant mutation moves
/// the ending: `ekme` covers `ekmek` and `ekmeği`, `pirin` covers
/// `pirinç` and `pirinci`, `fıstı` covers `fıstık` and `fıstığı`.
const Map<IngredientKind, List<String>> _terms = {
  IngredientKind.meat: [
    'dana',
    'sığır',
    'tavuk',
    'hindi',
    'kıyma',
    'kuşbaşı',
    'bonfile',
    'pirzola',
    'köfte',
    'sucuk',
    'pastırma',
    'salam',
    'jambon',
    'sosis',
    'kuzu',
    'et suyu',
    'bifte',
    'antrikot',
  ],
  IngredientKind.fish: [
    'somon',
    'levrek',
    'hamsi',
    'balı',
    'balığ',
    'karides',
    'midye',
    'çipura',
    'uskumru',
    'sardalya',
  ],
  IngredientKind.dairy: [
    'süt',
    'yoğurt',
    'peynir',
    'tereyağ',
    'kaşar',
    'lor',
    'parmesan',
    'çedar',
    'hellim',
    'kefir',
    'ayran',
    'krema',
    'whey',
    'kaymak',
  ],
  IngredientKind.egg: ['yumurta'],
  IngredientKind.honey: ['bal'],
  IngredientKind.gluten: [
    'buğday',
    'ekme',
    'makarna',
    'erişte',
    'bulgur',
    'irmik',
    'galeta',
    'lavaş',
    'bazlama',
    'kruton',
    'tortilla',
    'şehriye',
    'kuskus',
    'hamur',
    'tarhana',
    'yulaf',
    'arpa',
    'çavdar',
    'un',
    'maya',
    'gevre',
    'pişi',
    'aşurelik',
    'börek',
    'yufka',
    'pide',
  ],
  IngredientKind.plant: [
    'zeytin',
    'tuz',
    'soğan',
    'sarımsak',
    'limon',
    'domates',
    'salça',
    'ceviz',
    'havuç',
    'salatalık',
    'şeker',
    'biber',
    'nane',
    'patates',
    'tahin',
    'avokado',
    'marul',
    'muz',
    'su',
    'maydanoz',
    'tarçın',
    'karabiber',
    'kimyon',
    'kekik',
    'vanilya',
    'chia',
    'pirin',
    'pekmez',
    'hindistan cevizi',
    'hindistancevizi',
    'nohut',
    'kakao',
    'fıstı',
    'patlıcan',
    'çilek',
    'mercimek',
    'kinoa',
    'çikolata',
    'pırasa',
    'mantar',
    'badem',
    'böğürtlen',
    'hurma',
    'akçaağaç',
    'humus',
    'üzüm',
    'brokoli',
    'fasulye',
    'elma',
    'buz',
    'lahana',
    'karnabahar',
    'pancar',
    'reçel',
    'yaban mersini',
    'kabartma tozu',
    'ayçiçek',
    'susam',
    'barbunya',
    'börülce',
    'kabuklu',
    'soya sosu',
    'bitkisel protein',
    'ahududu',
    'zencefil',
    'ıspanak',
    'ispanak',
    'kuşkonmaz',
    'incir',
    'kereviz',
    'muskat',
    'ayçekirdeği',
    'sıvı yağ',
    'sirke',
    'bezelye',
    'salsa',
    'kayısı',
    'tofu',
    'mısır',
    'karpuz',
    'kivi',
    'nişasta',
    'fesleğen',
    'biberiye',
    'hardal',
    'dereotu',
    'roka',
    'kabak',
    'sebze',
    'şurup',
    'toz',
    'rende',
    'kapari',
    'turp',
    'enginar',
    'bamya',
    'nar',
    'meyve',
    'yer fıstı',
    'portakal',
    'şeftali',
    'armut',
    'kiraz',
    'vişne',
    'erik',
    'kavun',
  ],
};

/// Endings that must NOT follow a term, keyed by the term.
///
/// Word-initial matching is right almost everywhere and collides in two
/// places, both of them a short word living inside a longer unrelated
/// one. Listing the collision is honest and cheap; softening the matcher
/// until neither fires would cost every other term its precision.
///
///   * `hindi` (turkey) starts `hindistan cevizi` (coconut).
///   * `bal` (honey) starts `balık` / `balığı` (fish).
///   * `su` (water) starts `sucuk` (a sausage).
///
/// The overrides above catch the specific catalogue names; these keep a
/// name nobody has written yet from landing the same way.
const Map<String, List<String>> _notFollowedBy = {
  'hindi': ['stan'],
  'bal': ['ık', 'ığ', 'ıkç'],
  'su': ['cuk'],
};

final Map<String, RegExp> _patternCache = {};

RegExp _pattern(String term) => _patternCache.putIfAbsent(term, () {
      final folded = RegExp.escape(_fold(term));
      final excluded = _notFollowedBy[term];
      final tail = excluded == null
          ? ''
          : '(?!${excluded.map(RegExp.escape).join('|')})';
      return RegExp('(?<![a-zçğıiöşü])$folded$tail', unicode: true);
    });

/// Every kind [name] carries. Empty means unrecognised, which blocks
/// every derived flag on every recipe using it.
Set<IngredientKind> classifyIngredient(String name) {
  final folded = _fold(name);
  for (final entry in _overrides.entries) {
    if (_pattern(entry.key).hasMatch(folded)) return entry.value;
  }
  for (final unknowable in _knownUnknowable) {
    if (_pattern(unknowable).hasMatch(folded)) return const {};
  }
  final kinds = <IngredientKind>{};
  for (final entry in _terms.entries) {
    for (final term in entry.value) {
      if (_pattern(term).hasMatch(folded)) {
        kinds.add(entry.key);
        break;
      }
    }
  }
  return kinds;
}

/// The diet flags [ingredientNames] supports, or an empty list if any
/// ingredient is unrecognised.
///
/// Empty is the honest answer for an unclassifiable recipe: it makes no
/// claim rather than a wrong one.
List<String> classifyDiet(Iterable<String> ingredientNames) {
  final all = <IngredientKind>{};
  var count = 0;
  for (final name in ingredientNames) {
    count += 1;
    final kinds = classifyIngredient(name);
    if (kinds.isEmpty) return const [];
    all.addAll(kinds);
  }
  if (count == 0) return const [];

  final flags = <String>[];
  final hasMeat = all.contains(IngredientKind.meat);
  final hasFish = all.contains(IngredientKind.fish);
  final hasDairy = all.contains(IngredientKind.dairy);

  if (!hasMeat &&
      !hasFish &&
      !hasDairy &&
      !all.contains(IngredientKind.egg) &&
      !all.contains(IngredientKind.honey)) {
    flags.add('vegan');
  }
  if (!hasMeat && !hasFish) flags.add('vegetarian');
  // Every ingredient is recognised and none of the 297 names in the
  // catalogue is pork — see the library doc's audit.
  flags.add('pork_free');
  if (!all.contains(IngredientKind.gluten)) flags.add('gluten_free');
  if (!hasDairy) flags.add('dairy_free');
  return flags;
}

/// Lowercases without Dart's locale-dependent Turkish İ/I folding, which
/// would turn `Ispanak` into `ıspanak` on one platform and `ispanak` on
/// another. Both spellings are in the term table instead.
String _fold(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('â', 'a');
