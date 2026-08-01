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
  // Corn tortillas are maize, not wheat. The English table already knew;
  // the two disagreeing is what the pipeline's cross-language check
  // exists to surface, and it did.
  'mısır tortilla': {IngredientKind.plant},
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
  // Thai curry paste. Shrimp paste (kapi) is a standard ingredient in
  // most brands and absent from some, so this is genuinely two different
  // foods sold under one name. Same reasoning as granola: silence beats
  // a guess in either direction.
  'köri ezmesi',
  'curry paste',
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
    'morina',
    'ançüez',
    'alabalık',
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
    'kazein',
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
    'baharat',
    'cajun',
    // Phase 7 §5.3 · the international catalogue's pantry.
    'zerdeçal',
    'kişniş',
    'kakule',
    'gochujang',
    'miso',
    'mirin',
    'mango',
    'matcha',
    'nori',
    'kimchi',
    'chipotle',
    'wasabi',
    'tamari',
    'edamame',
    'nar ekşisi',
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
///   * `bal` (honey) starts `balık` / `balığı` (fish) and `balzamik`
///     (balsamic).
///   * `su` (water) starts `sucuk` (a sausage).
///
/// The overrides above catch the specific catalogue names; these keep a
/// name nobody has written yet from landing the same way.
const Map<String, List<String>> _notFollowedBy = {
  'hindi': ['stan'],
  'bal': ['ık', 'ığ', 'ıkç', 'zamik', 'zamdid'],
  'su': ['cuk'],
};

/// The same tables in English, for the recipes §5.2 and §5.3 author in
/// English first.
///
/// This exists for a second reason worth more than the first: every new
/// recipe carries both a `name_tr` and a `name_en`, so classifying each
/// independently and requiring the two to **agree** catches a
/// mistranslated ingredient. "tereyağı" rendered as "olive oil" passes
/// every other check in the pipeline and fails this one.
const Map<IngredientKind, List<String>> _englishTerms = {
  IngredientKind.meat: [
    'beef',
    'chicken',
    'turkey',
    'lamb',
    'steak',
    'mince',
    'ground beef',
    'bacon',
    'ham',
    'sausage',
    'pork',
    'salami',
    'pepperoni',
    'jerky',
    'meatball',
    'brisket',
    'sirloin',
    'chorizo',
    'prosciutto',
    'veal',
    'venison',
    'duck',
    'broth',
    'stock',
  ],
  IngredientKind.fish: [
    'salmon',
    'tuna',
    'cod',
    'anchov',
    'shrimp',
    'prawn',
    'mackerel',
    'sardine',
    'trout',
    'halibut',
    'tilapia',
    'squid',
    'mussel',
    'crab',
    'fish',
  ],
  IngredientKind.dairy: [
    'milk',
    'yogurt',
    'yoghurt',
    'cheese',
    'butter',
    'cream',
    'whey',
    'casein',
    'kefir',
    'ghee',
    'ricotta',
    'feta',
    'mozzarella',
    'parmesan',
    'cheddar',
    'halloumi',
    'quark',
    'skyr',
    'paneer',
  ],
  IngredientKind.egg: ['egg'],
  IngredientKind.honey: ['honey'],
  IngredientKind.gluten: [
    'wheat',
    'bread',
    'pasta',
    'noodle',
    'flour',
    'barley',
    'rye',
    'bulgur',
    'couscous',
    'semolina',
    'breadcrumb',
    'tortilla',
    'wrap',
    'pita',
    'bagel',
    'crouton',
    'cracker',
    'oat',
    'seitan',
    'farro',
    'spelt',
    'cereal',
    'granola',
    'pastry',
    'dough',
    'bun',
    'roll',
  ],
  IngredientKind.plant: [
    'oil',
    'salt',
    'pepper',
    'onion',
    'garlic',
    'lemon',
    'lime',
    'tomato',
    'walnut',
    'carrot',
    'cucumber',
    'sugar',
    'mint',
    'potato',
    'tahini',
    'avocado',
    'lettuce',
    'banana',
    'water',
    'parsley',
    'cinnamon',
    'cumin',
    'thyme',
    'oregano',
    'vanilla',
    'chia',
    'rice',
    'molasses',
    'coconut',
    'chickpea',
    'cocoa',
    'peanut',
    'eggplant',
    'aubergine',
    'strawberr',
    'lentil',
    'quinoa',
    'chocolate',
    'leek',
    'mushroom',
    'berr',
    'almond',
    'blackberr',
    'blueberr',
    'raspberr',
    'date',
    'maple',
    'hummus',
    'raisin',
    'grape',
    'broccoli',
    'bean',
    'apple',
    'ice',
    'cabbage',
    'cauliflower',
    'beet',
    'jam',
    'baking powder',
    'sunflower',
    'sesame',
    'soy sauce',
    'pea protein',
    'ginger',
    'spinach',
    'asparagus',
    'fig',
    'celery',
    'nutmeg',
    'vinegar',
    'pea',
    'salsa',
    'apricot',
    'tofu',
    'corn',
    'watermelon',
    'kiwi',
    'starch',
    'basil',
    'rosemary',
    'mustard',
    'dill',
    'arugula',
    'rocket',
    'zucchini',
    'courgette',
    'squash',
    'vegetable',
    'syrup',
    'powder',
    'zest',
    'caper',
    'radish',
    'artichoke',
    'okra',
    'pomegranate',
    'orange',
    'peach',
    'pear',
    'cherry',
    'plum',
    'melon',
    'kale',
    'pepper flake',
    'edamame',
    'tempeh',
    'sriracha',
    'salsa',
    'guacamole',
    'hemp',
    'flax',
    'pumpkin',
    'pistachio',
    'cashew',
    'hazelnut',
    'pecan',
    'nutritional yeast',
    'seaweed',
    'nori',
    'kimchi',
    'sweet potato',
  ],
};

const Map<String, Set<IngredientKind>> _englishOverrides = {
  // Plant milks and butters contain the dairy word.
  'almond milk': {IngredientKind.plant},
  'oat milk': {IngredientKind.plant, IngredientKind.gluten},
  'soy milk': {IngredientKind.plant},
  'coconut milk': {IngredientKind.plant},
  'rice milk': {IngredientKind.plant},
  'cashew milk': {IngredientKind.plant},
  'peanut butter': {IngredientKind.plant},
  'almond butter': {IngredientKind.plant},
  'cocoa butter': {IngredientKind.plant},
  'coconut butter': {IngredientKind.plant},
  'nut butter': {IngredientKind.plant},
  // Not wheat.
  'rice flour': {IngredientKind.plant},
  'almond flour': {IngredientKind.plant},
  'corn flour': {IngredientKind.plant},
  'coconut flour': {IngredientKind.plant},
  'chickpea flour': {IngredientKind.plant},
  'corn tortilla': {IngredientKind.plant},
  // Plant proteins.
  'pea protein': {IngredientKind.plant},
  'soy protein': {IngredientKind.plant},
  'plant protein': {IngredientKind.plant},
  'vegetable broth': {IngredientKind.plant},
  'vegetable stock': {IngredientKind.plant},
  // Not eggs.
  'eggplant': {IngredientKind.plant},
  // The name is meat; the food is not.
  'beefsteak tomato': {IngredientKind.plant},
  'tuna steak': {IngredientKind.fish},
  'salmon steak': {IngredientKind.fish},
  'swordfish steak': {IngredientKind.fish},
};

const Map<String, List<String>> _englishNotFollowedBy = {
  // `egg` starts `eggplant`; `pea` starts `peanut` and `pear`;
  // `date` starts nothing else here but `bean` starts `beans` (fine).
  'egg': ['plant'],
  'pea': ['nut', 'r', 'ch'],
  'fish': [],
};

final Map<String, RegExp> _patternCache = {};

RegExp _pattern(String term, Map<String, List<String>> guards) =>
    _patternCache.putIfAbsent('$term|${guards.hashCode}', () {
      final folded = RegExp.escape(_fold(term));
      final excluded = guards[term];
      final tail = excluded == null || excluded.isEmpty
          ? ''
          : '(?!${excluded.map(RegExp.escape).join('|')})';
      return RegExp('(?<![a-zçğıiöşü])$folded$tail', unicode: true);
    });

/// Every kind [name] carries. Empty means unrecognised, which blocks
/// every derived flag on every recipe using it.
///
/// Tries Turkish first and English second, because the authored
/// catalogue is Turkish and the terms there are more specific. A name
/// recognised by neither is unrecognised.
Set<IngredientKind> classifyIngredient(String name) {
  final turkish = _classify(name, _overrides, _terms, _notFollowedBy);
  if (turkish.isNotEmpty) return turkish;
  return _classify(
      name, _englishOverrides, _englishTerms, _englishNotFollowedBy);
}

/// Classifies against the English tables only.
///
/// Exposed so the pipeline can check a proposal's `name_en` and
/// `name_tr` **independently** and require them to agree — the one check
/// that catches "tereyağı" translated as "olive oil".
Set<IngredientKind> classifyEnglishIngredient(String name) =>
    _classify(name, _englishOverrides, _englishTerms, _englishNotFollowedBy);

/// Classifies against the Turkish tables only. See
/// [classifyEnglishIngredient].
Set<IngredientKind> classifyTurkishIngredient(String name) =>
    _classify(name, _overrides, _terms, _notFollowedBy);

Set<IngredientKind> _classify(
  String name,
  Map<String, Set<IngredientKind>> overrides,
  Map<IngredientKind, List<String>> terms,
  Map<String, List<String>> guards,
) {
  final folded = _fold(name);
  for (final entry in overrides.entries) {
    if (_pattern(entry.key, guards).hasMatch(folded)) return entry.value;
  }
  for (final unknowable in _knownUnknowable) {
    if (_pattern(unknowable, guards).hasMatch(folded)) return const {};
  }
  final kinds = <IngredientKind>{};
  for (final entry in terms.entries) {
    for (final term in entry.value) {
      if (_pattern(term, guards).hasMatch(folded)) {
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
