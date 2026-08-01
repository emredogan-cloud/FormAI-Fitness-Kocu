/// Roadmap Phase 7 §7 · the recipe authoring pipeline.
///
///     generate → validate → cost → review → seed
///
///     dart run tool/recipe_pipeline/pipeline.dart \
///         --proposals tool/recipe_pipeline/proposals/western.json \
///         --catalogue <live_catalogue.json> \
///         --sql       supabase/sql/phase07_recipes_western.sql \
///         --review    docs/nutrition/RECIPE_BATCH_WESTERN.md \
///         --images    docs/nutrition/MEAL_IMAGE_REQUESTS.md
///
/// Add `--dry-run` to validate and score without writing anything.
///
/// ## The two rules that make this safe
///
/// **Nothing here writes to the database.** Every path ends in a `.sql`
/// file and a markdown sheet, both of which a person reads. The
/// validation step is not a formality — it is what makes an unreviewed
/// batch impossible to ship, because the only way a recipe reaches
/// Postgres is through a file somebody opened.
///
/// **A rejected proposal is deleted, not repaired.** There is no
/// `--fix` and there will not be one. Repairing means another pass over
/// output already known to be wrong, and it produces plausible garbage
/// that reads better than the failure did. Authoring is the cheap part.
///
/// ## Where `generate` is
///
/// Deliberately outside this file, as `--proposals`: a JSON array in the
/// shape `RecipeProposal` parses. That is the seam. A model writing
/// straight to the pipeline and a person writing the same JSON by hand
/// are the same input, which means the validator cannot be bypassed by
/// whichever one is more convenient today — and it means the 100 recipes
/// Phase 7 ships were reviewed by exactly the same gate any future batch
/// will be.
library;

import 'dart:convert';
import 'dart:io';

import 'package:sixpack_ai/features/nutrition/domain/models/recipe_ingredient.dart';

import 'recipe_proposal.dart';

void main(List<String> args) {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');

  final proposalsPath = options['proposals'];
  if (proposalsPath == null || !File(proposalsPath).existsSync()) {
    stderr.writeln('missing --proposals <file.json>');
    exit(2);
  }

  final proposals = (jsonDecode(File(proposalsPath).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>()
      .map(RecipeProposal.fromJson)
      .toList();

  // The live catalogue, for the duplicate checks. Optional so the
  // pipeline can be exercised offline; the review sheet says when it ran
  // without one, because "no duplicates found" against no catalogue is
  // not a finding.
  // A batch's own previously-seeded rows are not duplicates of it.
  // Re-running a batch after an edit is the documented way to fix one —
  // the seed is idempotent by slug — so the catalogue snapshot has to be
  // read with this batch's own titles removed, or the second run rejects
  // everything it wrote on the first.
  final ownTitles = <String>{
    for (final p in proposals) ...[
      _normalise(p.titleEn),
      _normalise(p.titleTr),
    ],
  };

  final existingTitles = <String>{};
  final existingIngredients = <String, Set<String>>{};
  var knownTagTokens = <String>[];
  final cataloguePath = options['catalogue'];
  var checkedAgainstCatalogue = false;
  if (cataloguePath != null && File(cataloguePath).existsSync()) {
    checkedAgainstCatalogue = true;
    final catalogue = jsonDecode(File(cataloguePath).readAsStringSync())
        as Map<String, dynamic>;
    knownTagTokens =
        (catalogue['tag_tokens'] as List? ?? const []).cast<String>();
    for (final row in (catalogue['recipes'] as List? ?? const [])) {
      final map = row as Map<String, dynamic>;
      final titles = ['title', 'title_en']
          .map((k) => map[k] as String?)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .map(_normalise)
          .toList();
      if (titles.any(ownTitles.contains)) continue; // our own earlier seed
      existingTitles.addAll(titles);
      existingIngredients[map['title'] as String? ?? '?'] =
          ingredientFingerprint(
        (map['ingredients'] as List? ?? const []).map((e) => e.toString()),
      );
    }
  }

  final accepted = <RecipeProposal>[];
  final rejected = <({RecipeProposal proposal, List<ValidationFailure> why})>[];
  final scores = <String, ProposalScore>{};
  final seenSlugs = <String>{};

  for (final proposal in proposals) {
    final failures = validateProposal(
      proposal,
      existingTitles: existingTitles,
      existingIngredientSets: existingIngredients,
      knownTagTokens: knownTagTokens,
    );
    if (!seenSlugs.add(proposal.slug)) {
      failures.add(
        ValidationFailure('slug', '"${proposal.slug}" appears twice in batch'),
      );
    }
    if (failures.isEmpty) {
      accepted.add(proposal);
      scores[proposal.slug] = scoreProposal(proposal);
      // Within-batch duplicate detection: an accepted proposal joins the
      // comparison set, so two near-identical proposals in one file
      // cannot both pass.
      existingTitles
        ..add(_normalise(proposal.titleEn))
        ..add(_normalise(proposal.titleTr));
      existingIngredients[proposal.titleEn] =
          ingredientFingerprint(proposal.ingredients.map((i) => i.nameTr));
    } else {
      rejected.add((proposal: proposal, why: failures));
    }
  }

  stdout
    ..writeln('proposals   ${proposals.length}')
    ..writeln('accepted    ${accepted.length}')
    ..writeln('rejected    ${rejected.length}');
  for (final entry in rejected) {
    stdout.writeln('  ✗ ${entry.proposal.slug}');
    for (final failure in entry.why) {
      stdout.writeln('      $failure');
    }
  }

  if (dryRun) {
    stdout.writeln('\n--dry-run: nothing written');
    exit(rejected.isEmpty ? 0 : 1);
  }

  _write(options['sql'], _seedSql(accepted));
  _write(
    options['review'],
    _reviewSheet(accepted, rejected, scores, checkedAgainstCatalogue),
  );
  _write(options['images'], _imageSheet(accepted));

  // Non-zero when anything was rejected, so this is usable as a check.
  // The accepted half is still written: a batch of 60 with one bad
  // recipe should ship 59, not nothing.
  exit(rejected.isEmpty ? 0 : 1);
}

// ─── seed ────────────────────────────────────────────────────────────

String _seedSql(List<RecipeProposal> accepted) {
  final sql = StringBuffer()
    ..writeln('-- Roadmap Phase 7 · authored recipes.')
    ..writeln('-- Generated by tool/recipe_pipeline/pipeline.dart from a')
    ..writeln('-- reviewed proposal file. Do not hand-edit: change the')
    ..writeln('-- proposal and re-run, so the validator sees the change.')
    ..writeln('--')
    ..writeln('-- Idempotent. Ids are derived from the proposal slug via')
    ..writeln('-- uuid_generate_v5 against a fixed namespace, so re-running')
    ..writeln('-- after an edit updates the same rows instead of inserting')
    ..writeln('-- a second copy of the catalogue.')
    ..writeln()
    ..writeln('begin;')
    ..writeln()
    ..writeln('create extension if not exists "uuid-ossp";')
    ..writeln();

  for (final proposal in accepted) {
    final id = "uuid_generate_v5('$_slugNamespace'::uuid, "
        "'${_esc(proposal.slug)}')";
    final flags = proposal.dietFlags.map((f) => "'${_esc(f)}'").join(', ');
    final tokens = proposal.tagTokens.map((t) => "'${_esc(t)}'").join(', ');
    final scope = proposal.localeScope.map((s) => "'${_esc(s)}'").join(', ');

    sql
      ..writeln('-- ${proposal.titleEn}')
      ..writeln('insert into public.recipes (')
      ..writeln('  id, title, title_en, meal_type, calories, protein, carbs,')
      ..writeln('  fat, prep_time_minutes, instructions, instructions_en,')
      ..writeln('  tag_tokens, cuisine, diet_flags, locale_scope, image_url')
      ..writeln(') values (')
      ..writeln('  $id,')
      ..writeln('  ${_lit(proposal.titleTr)},')
      ..writeln('  ${_lit(proposal.titleEn)},')
      ..writeln('  ${_lit(proposal.mealType)},')
      ..writeln('  ${proposal.calories}, ${proposal.protein}, '
          '${proposal.carbs}, ${proposal.fat},')
      ..writeln('  ${proposal.prepTimeMinutes},')
      ..writeln('  ${_lit(_instructions(proposal, turkish: true))},')
      ..writeln('  ${_lit(_instructions(proposal, turkish: false))},')
      ..writeln('  ARRAY[$tokens]::text[],')
      ..writeln('  ${_lit(proposal.cuisine)},')
      ..writeln('  ARRAY[$flags]::text[],')
      ..writeln('  ARRAY[$scope]::text[],')
      ..writeln('  ${_lit(_imageUrl(proposal))}')
      ..writeln(')')
      ..writeln('on conflict (id) do update set')
      ..writeln('  title = excluded.title,')
      ..writeln('  title_en = excluded.title_en,')
      ..writeln('  meal_type = excluded.meal_type,')
      ..writeln('  calories = excluded.calories,')
      ..writeln('  protein = excluded.protein,')
      ..writeln('  carbs = excluded.carbs,')
      ..writeln('  fat = excluded.fat,')
      ..writeln('  prep_time_minutes = excluded.prep_time_minutes,')
      ..writeln('  instructions = excluded.instructions,')
      ..writeln('  instructions_en = excluded.instructions_en,')
      ..writeln('  tag_tokens = excluded.tag_tokens,')
      ..writeln('  cuisine = excluded.cuisine,')
      ..writeln('  diet_flags = excluded.diet_flags,')
      ..writeln('  locale_scope = excluded.locale_scope,')
      ..writeln('  image_url = excluded.image_url;')
      ..writeln()
      ..writeln('delete from public.recipe_ingredients')
      ..writeln('  where recipe_id = $id;')
      ..writeln('insert into public.recipe_ingredients')
      ..writeln('  (recipe_id, position, quantity, unit, name_tr, name_en,')
      ..writeln('   note_tr, note_en)')
      ..writeln('values');

    final values = <String>[];
    for (var i = 0; i < proposal.ingredients.length; i++) {
      final ingredient = proposal.ingredients[i];
      values.add(
        '  ($id, ${i + 1}, ${ingredient.quantity ?? 'null'}, '
        '${_lit(ingredient.unit)}, ${_lit(ingredient.nameTr)}, '
        '${_lit(ingredient.nameEn)}, ${_lit(ingredient.noteTr)}, '
        '${_lit(ingredient.noteEn)})',
      );
    }
    sql
      ..writeln('${values.join(',\n')};')
      ..writeln();
  }

  sql.writeln('commit;');
  return sql.toString();
}

/// A fixed uuid namespace, so a slug always maps to the same row id.
/// Random ids would make the seed non-idempotent, which is how a
/// re-runnable script turns into a duplicated catalogue.
const String _slugNamespace = '8f7e6d5c-4b3a-2910-8f7e-6d5c4b3a2910';

/// Rebuilds the `MALZEMELER:` / `HAZIRLANIŞI:` blob every existing row
/// carries.
///
/// New rows do not need it — they have structured ingredients from the
/// start — but a client shipped before migration 014 reads
/// `instructions` and nothing else, and a recipe that renders as an
/// empty screen on last month's build is worse than a redundant column.
/// It goes away with the rest in migration 016.
String _instructions(RecipeProposal proposal, {required bool turkish}) {
  final buffer = StringBuffer()
    ..writeln(turkish ? 'MALZEMELER:' : 'INGREDIENTS:');
  for (final ingredient in proposal.ingredients) {
    // Phase 7 · the unit is named in the reader's language, never
    // converted. The translation audit found `2 yemek kaşığı olive oil`
    // here — the names had been translated and the units had not,
    // because they live in a different column.
    final unit = localizedUnit(
      ingredient.unit,
      ingredient.quantity,
      languageCode: turkish ? 'tr' : 'en',
    );
    final parts = <String>[
      if (ingredient.quantity != null) _number(ingredient.quantity!),
      if (unit != null && unit.isNotEmpty) unit,
      turkish ? ingredient.nameTr : ingredient.nameEn,
    ];
    final note = turkish ? ingredient.noteTr : ingredient.noteEn;
    buffer.writeln(
      '- ${parts.join(' ')}${note == null || note.isEmpty ? '' : ' ($note)'}',
    );
  }
  buffer
    ..writeln()
    ..writeln(turkish ? 'HAZIRLANIŞI:' : 'METHOD:');
  final steps = turkish ? proposal.stepsTr : proposal.stepsEn;
  for (var i = 0; i < steps.length; i++) {
    buffer.writeln('${i + 1}. ${steps[i]}');
  }
  return buffer.toString().trimRight();
}

/// The filename the image request sheet asks for, resolved the same way
/// every other recipe image is.
String _imageUrl(RecipeProposal proposal) =>
    'photos/meals/${proposal.slug}.webp';

// ─── review ──────────────────────────────────────────────────────────

String _reviewSheet(
  List<RecipeProposal> accepted,
  List<({RecipeProposal proposal, List<ValidationFailure> why})> rejected,
  Map<String, ProposalScore> scores,
  bool checkedAgainstCatalogue,
) {
  final sheet = StringBuffer()
    ..writeln('# Recipe batch — review sheet')
    ..writeln()
    ..writeln('Generated by `tool/recipe_pipeline/pipeline.dart`.')
    ..writeln('Approval is a file edit, never a database write: the SQL beside')
    ..writeln('this sheet is the only path into Postgres, and somebody has to')
    ..writeln('run it.')
    ..writeln()
    ..writeln('```')
    ..writeln('proposals   ${accepted.length + rejected.length}')
    ..writeln('accepted    ${accepted.length}')
    ..writeln('rejected    ${rejected.length}');
  if (!checkedAgainstCatalogue) {
    sheet.writeln('duplicates  NOT CHECKED — no --catalogue was supplied');
  }
  sheet
    ..writeln('```')
    ..writeln();

  if (rejected.isNotEmpty) {
    sheet
      ..writeln('## Rejected')
      ..writeln()
      ..writeln('A rejected proposal is **deleted, not repaired**. Repairing')
      ..writeln('means another pass over output already known to be wrong.')
      ..writeln();
    for (final entry in rejected) {
      sheet.writeln('### ${entry.proposal.titleEn} (`${entry.proposal.slug}`)');
      sheet.writeln();
      for (final failure in entry.why) {
        sheet.writeln('- **${failure.rule}** — ${failure.detail}');
      }
      sheet.writeln();
    }
  }

  sheet
    ..writeln('## Accepted')
    ..writeln()
    ..writeln('`speciality` counts ingredients outside a normal pantry — the')
    ..writeln('measurable half of "would an ordinary person make this". It is')
    ..writeln('scored, not enforced; a high number is a question, not a')
    ..writeln('rejection.')
    ..writeln()
    ..writeln(
        '| recipe | meal | kcal | P/C/F | min | steps | speciality | diet |')
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final proposal in accepted) {
    final score = scores[proposal.slug];
    sheet.writeln(
      '| ${proposal.titleEn} | ${proposal.mealType} | ${proposal.calories} '
      '| ${proposal.protein}/${proposal.carbs}/${proposal.fat} '
      '| ${proposal.prepTimeMinutes} | ${score?.stepCount ?? 0} '
      '| ${score?.shoppingDifficulty ?? 0} '
      '| ${proposal.dietFlags.join(', ')} |',
    );
  }

  final flagged =
      accepted.where((p) => (scores[p.slug]?.notes ?? const []).isNotEmpty);
  sheet
    ..writeln()
    ..writeln('## Worth a second look')
    ..writeln();
  if (flagged.isEmpty) {
    sheet.writeln('Nothing scored outside the usual range.');
  } else {
    for (final proposal in flagged) {
      sheet.writeln('- **${proposal.titleEn}** — '
          '${scores[proposal.slug]!.notes.join('; ')}');
    }
  }

  return sheet.toString();
}

String _imageSheet(List<RecipeProposal> accepted) {
  final sheet = StringBuffer()
    ..writeln('# Meal image requests — Phase 7')
    ..writeln()
    ..writeln('Generated by `tool/recipe_pipeline/pipeline.dart`, in the style')
    ..writeln('`docs/MEAL_IMAGE_PROMPTS.md` already uses.')
    ..writeln()
    ..writeln('Every row below has a real `image_url` in the database already.')
    ..writeln('Until the file exists the tile falls back to its meal-type')
    ..writeln('artwork, so **nothing is ever blank** and this list can be')
    ..writeln('worked through at any pace.')
    ..writeln()
    ..writeln('Drop each file at `photos/meals/<filename>` and rebuild — the')
    ..writeln('lookup is against the asset manifest, so no code changes.')
    ..writeln();
  for (final proposal in accepted) {
    sheet
      ..writeln('### ${proposal.titleEn}')
      ..writeln()
      ..writeln('`photos/meals/${proposal.slug}.webp`')
      ..writeln()
      ..writeln('> ${proposal.imagePrompt}')
      ..writeln();
  }
  return sheet.toString();
}

// ─── plumbing ────────────────────────────────────────────────────────

void _write(String? path, String contents) {
  if (path == null || path.isEmpty) return;
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  stdout.writeln('wrote $path');
}

String _lit(String? value) {
  if (value == null || value.isEmpty) return 'null';
  return "'${_esc(value)}'";
}

String _esc(String value) => value.replaceAll("'", "''");

String _normalise(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

String _number(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (!args[i].startsWith('--')) continue;
    final key = args[i].substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[key] = args[i + 1];
      i += 1;
    } else {
      out[key] = 'true';
    }
  }
  return out;
}
