/// Roadmap Phase 7 §7 · the shape a proposed recipe arrives in, and the
/// deterministic gate it has to survive.
///
/// ## Why a proposal is not a row
///
/// A proposal is bilingual, unsaved, and untrusted. A row is one
/// language per read, in Postgres, and shown to somebody deciding what
/// to eat. Everything between the two is this file.
///
/// ## The validator has no model in it
///
/// Every check below is arithmetic or set membership. That is what makes
/// it a gate rather than a second opinion: a check that sometimes says
/// yes to the same input is not a check. The plausibility pass that
/// *does* need judgement is [scoreProposal], and it is scored separately
/// and never blocks on its own.
library;

import 'diet_classifier.dart';

/// One ingredient of a proposed recipe, in both languages.
class ProposedIngredient {
  const ProposedIngredient({
    required this.nameEn,
    required this.nameTr,
    this.quantity,
    this.unit,
    this.noteEn,
    this.noteTr,
    this.toTaste = false,
  });

  final String nameEn;
  final String nameTr;
  final num? quantity;
  final String? unit;
  final String? noteEn;
  final String? noteTr;

  /// Marks an ingredient that deliberately has no amount — salt, pepper,
  /// a squeeze of lemon.
  ///
  /// The flag exists so the validator can require a quantity everywhere
  /// else. Without it the rule has to be "most ingredients have
  /// amounts", which is a threshold nobody can defend, and a forgotten
  /// quantity looks exactly like a seasoning.
  final bool toTaste;

  factory ProposedIngredient.fromJson(Map<String, dynamic> json) =>
      ProposedIngredient(
        nameEn: (json['name_en'] as String? ?? '').trim(),
        nameTr: (json['name_tr'] as String? ?? '').trim(),
        quantity: json['quantity'] as num?,
        unit: (json['unit'] as String?)?.trim(),
        noteEn: (json['note_en'] as String?)?.trim(),
        noteTr: (json['note_tr'] as String?)?.trim(),
        toTaste: json['to_taste'] as bool? ?? false,
      );
}

/// A recipe somebody or something proposed. Not yet a row.
class RecipeProposal {
  const RecipeProposal({
    required this.slug,
    required this.titleEn,
    required this.titleTr,
    required this.mealType,
    required this.cuisine,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.prepTimeMinutes,
    required this.tagTokens,
    required this.localeScope,
    required this.ingredients,
    required this.stepsEn,
    required this.stepsTr,
    required this.imagePrompt,
  });

  /// Stable identity for this proposal across runs, used to build a
  /// deterministic uuid so re-running the seed updates rather than
  /// duplicates.
  final String slug;

  final String titleEn;
  final String titleTr;
  final String mealType;
  final String cuisine;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int prepTimeMinutes;
  final List<String> tagTokens;
  final List<String> localeScope;
  final List<ProposedIngredient> ingredients;
  final List<String> stepsEn;
  final List<String> stepsTr;

  /// What to generate the photograph from. 100 new recipes need 100
  /// images and `image_url` is non-null on all 292 existing rows — an
  /// empty tile would be the most visible regression of the phase.
  final String imagePrompt;

  factory RecipeProposal.fromJson(Map<String, dynamic> json) => RecipeProposal(
        slug: (json['slug'] as String? ?? '').trim(),
        titleEn: (json['title_en'] as String? ?? '').trim(),
        titleTr: (json['title_tr'] as String? ?? '').trim(),
        mealType: (json['meal_type'] as String? ?? '').trim(),
        cuisine: (json['cuisine'] as String? ?? '').trim(),
        calories: (json['calories'] as num? ?? 0).round(),
        protein: (json['protein'] as num? ?? 0).round(),
        carbs: (json['carbs'] as num? ?? 0).round(),
        fat: (json['fat'] as num? ?? 0).round(),
        prepTimeMinutes: (json['prep_time_minutes'] as num? ?? 0).round(),
        tagTokens: _strings(json['tag_tokens']),
        localeScope: _strings(json['locale_scope']),
        ingredients: (json['ingredients'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ProposedIngredient.fromJson)
            .toList(growable: false),
        stepsEn: _strings(json['steps_en']),
        stepsTr: _strings(json['steps_tr']),
        imagePrompt: (json['image_prompt'] as String? ?? '').trim(),
      );

  static List<String> _strings(dynamic value) => value is List
      ? value.map((e) => e.toString().trim()).toList(growable: false)
      : const [];

  /// Diet flags derived from the ingredient list. Never authored — a
  /// proposal that declared its own would be a claim nobody checked.
  List<String> get dietFlags => classifyDiet(ingredients.map((i) => i.nameTr));
}

/// Why a proposal was rejected. One reason is enough to kill it.
class ValidationFailure {
  const ValidationFailure(this.rule, this.detail);
  final String rule;
  final String detail;

  @override
  String toString() => '$rule: $detail';
}

/// Calories per gram. Not approximations — these are the Atwater factors
/// nutrition labels are computed with, which is what makes the ±10 %
/// tolerance below a real check rather than a wide guess.
const int kKcalPerGramProtein = 4;
const int kKcalPerGramCarb = 4;
const int kKcalPerGramFat = 9;

/// Plausible calorie bands per meal type, from the live catalogue's own
/// distribution rather than from an opinion about portion sizes.
const Map<String, ({int min, int max})> kCalorieBands = {
  'breakfast': (min: 150, max: 750),
  'lunch': (min: 250, max: 900),
  'dinner': (min: 250, max: 900),
  'snack': (min: 80, max: 500),
  'dessert': (min: 80, max: 550),
};

const List<String> kKnownCuisines = [
  'turkish',
  'american',
  'mediterranean',
  'japanese',
  'korean',
  'mexican',
  'indian',
  'greek',
  'levantine',
  'thai',
  'italian',
  'generic',
];

/// Everything wrong with [proposal]. Empty means it may be seeded.
///
/// [existingTitles] and [existingIngredientSets] are the live catalogue,
/// so the duplicate checks compare against what is actually there rather
/// than against the rest of this batch alone.
List<ValidationFailure> validateProposal(
  RecipeProposal proposal, {
  Set<String> existingTitles = const {},
  Map<String, Set<String>> existingIngredientSets = const {},
  List<String> knownTagTokens = const [],
}) {
  final failures = <ValidationFailure>[];

  void fail(String rule, String detail) =>
      failures.add(ValidationFailure(rule, detail));

  // ─── identity ─────────────────────────────────────────────────────
  if (proposal.slug.isEmpty) fail('slug', 'missing');
  if (proposal.titleEn.isEmpty) fail('title_en', 'missing');
  if (proposal.titleTr.isEmpty) fail('title_tr', 'missing');
  if (!kCalorieBands.containsKey(proposal.mealType)) {
    fail('meal_type', '"${proposal.mealType}" is not one of the five tokens');
  }
  if (!kKnownCuisines.contains(proposal.cuisine)) {
    fail('cuisine', '"${proposal.cuisine}" is not a known cuisine');
  }
  for (final token in proposal.tagTokens) {
    if (knownTagTokens.isNotEmpty && !knownTagTokens.contains(token)) {
      fail('tag_tokens', '"$token" is not in public.recipe_tags');
    }
  }
  if (proposal.tagTokens.isEmpty) {
    // An untagged recipe is invisible to every chip and every category
    // screen — the exact state migration 013's backfill had to repair.
    fail('tag_tokens', 'empty: the recipe would be unreachable');
  }

  // ─── macros ───────────────────────────────────────────────────────
  final derived = proposal.protein * kKcalPerGramProtein +
      proposal.carbs * kKcalPerGramCarb +
      proposal.fat * kKcalPerGramFat;
  if (proposal.calories <= 0) {
    fail('calories', 'must be positive');
  } else {
    final drift = (derived - proposal.calories).abs() / proposal.calories;
    if (drift > 0.10) {
      fail(
        'macro arithmetic',
        '${proposal.protein}p/${proposal.carbs}c/${proposal.fat}f is '
            '$derived kcal against a stated ${proposal.calories} — '
            '${(drift * 100).toStringAsFixed(0)}% off',
      );
    }
  }
  final band = kCalorieBands[proposal.mealType];
  if (band != null &&
      (proposal.calories < band.min || proposal.calories > band.max)) {
    fail(
      'calorie band',
      '${proposal.calories} kcal is outside ${band.min}–${band.max} for a '
          '${proposal.mealType}',
    );
  }
  if (proposal.protein < 0 || proposal.carbs < 0 || proposal.fat < 0) {
    fail('macros', 'negative');
  }
  if (proposal.prepTimeMinutes <= 0 || proposal.prepTimeMinutes > 240) {
    fail('prep_time_minutes', '${proposal.prepTimeMinutes} is not plausible');
  }

  // ─── ingredients ──────────────────────────────────────────────────
  if (proposal.ingredients.length < 2) {
    fail('ingredients', 'fewer than two');
  }
  for (final ingredient in proposal.ingredients) {
    final label = ingredient.nameEn.isEmpty ? '(unnamed)' : ingredient.nameEn;
    if (ingredient.nameEn.isEmpty) fail('ingredient', 'missing name_en');
    if (ingredient.nameTr.isEmpty) {
      fail('ingredient', '"$label" has no name_tr');
    }
    if (!ingredient.toTaste && ingredient.quantity == null) {
      fail(
        'ingredient quantity',
        '"$label" has no quantity and is not marked to_taste',
      );
    }
    if (ingredient.quantity != null && ingredient.quantity! <= 0) {
      fail('ingredient quantity', '"$label" is ${ingredient.quantity}');
    }
    // The check that catches a mistranslation: classify each language
    // independently and require them to agree. "tereyağı" rendered as
    // "olive oil" passes everything else.
    final en = classifyEnglishIngredient(ingredient.nameEn);
    final tr = classifyTurkishIngredient(ingredient.nameTr);
    if (en.isNotEmpty && tr.isNotEmpty && !_compatible(en, tr)) {
      fail(
        'translation',
        '"${ingredient.nameEn}" reads as ${_names(en)} but '
            '"${ingredient.nameTr}" reads as ${_names(tr)}',
      );
    }
  }

  // ─── steps ────────────────────────────────────────────────────────
  if (proposal.stepsEn.isEmpty) fail('steps_en', 'missing');
  if (proposal.stepsEn.length != proposal.stepsTr.length) {
    fail(
      'step count',
      '${proposal.stepsEn.length} English against '
          '${proposal.stepsTr.length} Turkish — a merged step breaks the '
          'step-by-step reader',
    );
  }
  for (var i = 0; i < proposal.stepsEn.length; i++) {
    if (i >= proposal.stepsTr.length) break;
    final enNumbers = _numbers(proposal.stepsEn[i]);
    final trNumbers = _numbers(proposal.stepsTr[i]);
    if (!_sameMultiset(enNumbers, trNumbers)) {
      fail(
        'step numbers',
        'step ${i + 1} says $enNumbers in English and $trNumbers in Turkish',
      );
    }
  }

  // ─── images ───────────────────────────────────────────────────────
  if (proposal.imagePrompt.isEmpty) {
    // `image_url` is non-null on all 292 existing rows. A tile with no
    // photograph is the most visible regression available.
    fail('image_prompt', 'missing: the recipe tile would have no photograph');
  }

  // ─── duplicates ───────────────────────────────────────────────────
  for (final title in [proposal.titleEn, proposal.titleTr]) {
    if (existingTitles.contains(_normaliseTitle(title))) {
      fail('duplicate title', '"$title" is already in the catalogue');
    }
  }
  final fingerprint = ingredientFingerprint(
    proposal.ingredients.map((i) => i.nameTr),
  );
  for (final entry in existingIngredientSets.entries) {
    final overlap = fingerprint.intersection(entry.value).length;
    final union = fingerprint.union(entry.value).length;
    if (union == 0) continue;
    if (overlap / union >= 0.8) {
      fail(
        'near-duplicate',
        'ingredients are ${(overlap / union * 100).round()}% the same as '
            '"${entry.key}"',
      );
    }
  }

  return failures;
}

/// A comparable set of ingredient names, for the near-duplicate check.
Set<String> ingredientFingerprint(Iterable<String> names) =>
    names.map((n) => n.toLowerCase().trim()).where((n) => n.isNotEmpty).toSet();

String _normaliseTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Two readings agree when they overlap at all, or when one is purely
/// [IngredientKind.plant] and the other adds a detail like gluten.
///
/// Strict equality would reject "oats" (gluten+plant in English, gluten
/// in Turkish) for no reason. What must not pass is a reading in one
/// language that names an animal the other does not.
bool _compatible(Set<IngredientKind> en, Set<IngredientKind> tr) {
  const animal = {
    IngredientKind.meat,
    IngredientKind.fish,
    IngredientKind.dairy,
    IngredientKind.egg,
    IngredientKind.honey,
  };
  final enAnimal = en.intersection(animal);
  final trAnimal = tr.intersection(animal);
  if (!_setEquals(enAnimal, trAnimal)) return false;
  return en.contains(IngredientKind.gluten) ==
      tr.contains(IngredientKind.gluten);
}

bool _setEquals(Set<IngredientKind> a, Set<IngredientKind> b) =>
    a.length == b.length && a.containsAll(b);

String _names(Set<IngredientKind> kinds) {
  final names = kinds.map((k) => k.name).toList()..sort();
  return names.join('+');
}

List<num> _numbers(String text) => RegExp(r'\d+(?:[.,]\d+)?')
    .allMatches(text)
    .map((m) => num.parse(m.group(0)!.replaceAll(',', '.')))
    .toList();

bool _sameMultiset(List<num> a, List<num> b) {
  if (a.length != b.length) return false;
  final sortedA = [...a]..sort();
  final sortedB = [...b]..sort();
  for (var i = 0; i < sortedA.length; i++) {
    if (sortedA[i] != sortedB[i]) return false;
  }
  return true;
}

// ─── the cost pass ───────────────────────────────────────────────────

/// How hard this recipe is to actually make, and how likely somebody is
/// to bother.
///
/// §7.1 describes this as a second model pass. It is not one, and saying
/// so is the point: a claim that a model reviewed something it did not
/// is worse than no claim. What is here is the part of that judgement
/// that can be measured — how many ingredients are outside a normal
/// pantry, how long it takes, how many steps — and it is scored, printed
/// on the review sheet, and never blocks a recipe on its own.
///
/// A human reads the sheet. That is the review step.
class ProposalScore {
  const ProposalScore({
    required this.shoppingDifficulty,
    required this.specialityIngredients,
    required this.stepCount,
    required this.notes,
  });

  /// Count of ingredients outside [kPantryStaples].
  final int shoppingDifficulty;
  final List<String> specialityIngredients;
  final int stepCount;
  final List<String> notes;
}

/// What a person plausibly already has, or can buy in any supermarket
/// anywhere. Deliberately short — the list is for finding the *unusual*
/// ingredient, so a long list would find nothing.
const List<String> kPantryStaples = [
  'salt',
  'pepper',
  'oil',
  'water',
  'onion',
  'garlic',
  'egg',
  'milk',
  'butter',
  'flour',
  'sugar',
  'rice',
  'pasta',
  'bread',
  'oat',
  'yogurt',
  'yoghurt',
  'cheese',
  'chicken',
  'beef',
  'tomato',
  'potato',
  'carrot',
  'lemon',
  'banana',
  'apple',
  'honey',
  'cinnamon',
  'vanilla',
  'cocoa',
  'lentil',
  'bean',
  'chickpea',
  'spinach',
  'cucumber',
  'vinegar',
  'mustard',
  'parsley',
  'mint',
  'cumin',
  'paprika',
  'olive',
];

ProposalScore scoreProposal(RecipeProposal proposal) {
  final speciality = <String>[];
  for (final ingredient in proposal.ingredients) {
    final name = ingredient.nameEn.toLowerCase();
    final isStaple = kPantryStaples.any(name.contains);
    if (!isStaple) speciality.add(ingredient.nameEn);
  }

  final notes = <String>[];
  if (speciality.length > 4) {
    notes.add('${speciality.length} ingredients outside a normal pantry');
  }
  if (proposal.prepTimeMinutes > 45) {
    notes.add('${proposal.prepTimeMinutes} min is a weekend recipe');
  }
  if (proposal.stepsEn.length > 8) {
    notes.add('${proposal.stepsEn.length} steps is a lot for a weekday meal');
  }
  if (proposal.ingredients.length > 12) {
    notes.add('${proposal.ingredients.length} ingredients');
  }

  return ProposalScore(
    shoppingDifficulty: speciality.length,
    specialityIngredients: speciality,
    stepCount: proposal.stepsEn.length,
    notes: notes,
  );
}
