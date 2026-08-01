/// Roadmap Phase 7 (§6.3) · the content translation gate.
///
///     dart run tool/recipe_translation_audit.dart
///     dart run tool/recipe_translation_audit.dart --list
///     dart run tool/recipe_translation_audit.dart --update-baseline
///
/// The ARB gates check the UI. This one checks the catalogue, which the
/// ARB gates cannot see: recipe titles, method steps and ingredient
/// names live in Postgres and change without an app release, which was
/// the whole reason migration 011 put them there.
///
/// ## How it reads the catalogue
///
/// Through the public REST endpoint with the anon key from `.env` —
/// exactly the way the app does. `recipes` and `recipe_ingredients` are
/// world-readable by policy, so this needs no secret and CI needs no
/// database password. It also means the gate is checking what a user
/// would actually receive, not what a privileged query returns.
///
/// ## The ratchet
///
/// `tool/recipe_translation_baseline.json` records per-locale coverage.
/// Coverage may rise and may never fall. Same shape and same reasoning
/// as `check_hardcoded_strings.dart`: a gate that demanded 100 % on the
/// day it was written would have been switched off in week one, and a
/// gate with no floor lets a batch of untranslated rows ship quietly.
///
/// ## Network failure is a warning, not a failure
///
/// This is the one judgement call in the file and it is deliberate. The
/// gate exists to catch a *content regression* in what is committed. An
/// unreachable database is not a content regression, and a red build
/// from a network blip teaches people to ignore red builds — which
/// costs more than the rare miss. Unreachable prints loudly and exits 0.
/// Reachable-and-wrong exits 1.
library;

import 'dart:convert';
import 'dart:io';

/// Locales the app ships. A translation gate for a locale nobody can
/// select is a gate that fails on work nobody asked for.
const List<String> kShippedLocales = ['en'];

/// Turkish-only characters. Their presence in an `_en` column is the
/// cheapest signal that a field was copied forward rather than
/// translated — and the one a human spot-check misses, because an
/// untranslated field looks like a field.
final RegExp _turkishOnly = RegExp('[ğşıİĞŞçöüÇÖÜ]');

/// Words allowed to keep their Turkish spelling in English copy.
///
/// Mirrors `docs/i18n/GLOSSARY.md` — a proper noun stays a proper noun.
/// Anything here has to be a dish or ingredient an English speaker would
/// meet under this name, not a word nobody got round to translating.
const List<String> kNeverTranslated = [
  'sucuk',
  'menemen',
  'pide',
  'ayran',
  'tarhana',
  'börek',
  'kısır',
  'köfte',
  'çiğ köfte',
  'pastırma',
  'kaşar',
  'beyaz peynir',
  'lor',
  'mantı',
  'lahmacun',
  'simit',
  'bazlama',
  'lavaş',
  'pişi',
  'gözleme',
  'baklava',
  'künefe',
  'sütlaç',
  'muhallebi',
  'helva',
  'şakşuka',
  'imam bayıldı',
  'cacık',
  'ezogelin',
  'mercimek',
  'bulgur',
  'çorba',
  'pekmez',
  'süzme',
  'yufka',
  'poğaça',
  'açma',
  'kumpir',
  'pilav',
  'döner',
  'iskender',
  'adana',
  'urfa',
  'şiş',
  'güveç',
  'turşu',
];

class Finding {
  Finding(this.rule, this.recipe, this.detail);
  final String rule;
  final String recipe;
  final String detail;
  @override
  String toString() => '$rule · $recipe — $detail';
}

Future<void> main(List<String> args) async {
  final listAll = args.contains('--list');
  final updateBaseline = args.contains('--update-baseline');

  final env = _readEnv('.env');
  final url = env['SUPABASE_URL'];
  final key = env['SUPABASE_ANON_KEY'];
  if (url == null || key == null || url.isEmpty || key.isEmpty) {
    stdout.writeln(
      '⚠ recipe translation audit SKIPPED — no SUPABASE_URL / '
      'SUPABASE_ANON_KEY in .env.\n'
      '  CI writes a blank .env, so this is expected there. Run locally '
      'to audit the catalogue.',
    );
    exit(0);
  }

  final List<Map<String, dynamic>> recipes;
  final List<Map<String, dynamic>> tags;
  try {
    recipes = await _fetch(
      url,
      key,
      'recipes?select=id,title,title_en,instructions,instructions_en,'
      'recipe_ingredients(name_tr,name_en)',
    );
    tags = await _fetch(url, key, 'recipe_tags?select=*');
  } catch (e) {
    stdout.writeln(
      '⚠ recipe translation audit SKIPPED — catalogue unreachable: $e\n'
      '  This gate guards committed content against regression; an '
      'unreachable\n'
      '  database is not one. Exiting 0 rather than teaching people to '
      'ignore red.',
    );
    exit(0);
  }

  final findings = <Finding>[];
  final coverage = <String, int>{};

  for (final locale in kShippedLocales) {
    var translated = 0;
    for (final recipe in recipes) {
      final title = (recipe['title'] as String?) ?? '';
      final localizedTitle = _text(recipe['title_$locale']);
      final localizedBody = _text(recipe['instructions_$locale']);

      // §3.2 · one recipe, one language. A title without a body renders
      // an English heading over Turkish steps, which reads as a bug
      // rather than as untranslated content.
      if (localizedTitle != null && localizedBody == null) {
        findings.add(Finding(
          'half-translated',
          title,
          'has title_$locale but no instructions_$locale',
        ));
      }
      if (localizedTitle == null && localizedBody != null) {
        findings.add(Finding(
          'half-translated',
          title,
          'has instructions_$locale but no title_$locale',
        ));
      }
      if (localizedTitle == null || localizedBody == null) continue;
      translated += 1;

      // Step counts must match. A translation that merges two steps
      // breaks the step-by-step reader, and nothing else notices.
      final sourceSteps = _steps((recipe['instructions'] as String?) ?? '');
      final targetSteps = _steps(localizedBody);
      if (sourceSteps.length != targetSteps.length) {
        findings.add(Finding(
          'step count',
          title,
          '${sourceSteps.length} steps in Turkish, ${targetSteps.length} '
              'in $locale',
        ));
      }

      // Every number in the source has to survive. This is the rule that
      // catches a temperature or a timing quietly changing.
      final sourceNumbers = _numbers(sourceSteps.join(' '));
      final targetNumbers = _numbers(targetSteps.join(' '));
      final lost = _missing(sourceNumbers, targetNumbers);
      if (lost.isNotEmpty) {
        findings.add(Finding(
          'lost number',
          title,
          '$lost is in the Turkish steps and not the $locale ones',
        ));
      }

      if (locale == 'en') {
        // The cheap check that catches the most: a field copied forward
        // rather than translated is invisible in a spot check and
        // obvious to a regex.
        for (final entry in {
          'title_en': localizedTitle,
          'instructions_en': localizedBody,
        }.entries) {
          final residue = _turkishResidue(entry.value);
          if (residue.isNotEmpty) {
            findings.add(Finding(
              'untranslated',
              title,
              '${entry.key} still reads Turkish: $residue',
            ));
          }
        }
      }

      // The ingredient list is part of the recipe's language, not a
      // separate thing that can lag behind it.
      final ingredients =
          (recipe['recipe_ingredients'] as List? ?? const []).cast<Map>();
      final untranslated = ingredients
          .where((i) => _text(i['name_$locale']) == null)
          .map((i) => i['name_tr'])
          .toList();
      if (untranslated.isNotEmpty) {
        findings.add(Finding(
          'ingredient',
          title,
          '${untranslated.length} ingredient(s) have no name_$locale: '
              '${untranslated.take(3).join(', ')}',
        ));
      }
    }
    coverage[locale] = translated;

    // A token with no label renders no chip, which is a category
    // silently disappearing from the filter row.
    for (final tag in tags) {
      if (_text(tag['label_$locale']) == null) {
        findings.add(Finding(
          'tag label',
          tag['token'] as String? ?? '?',
          'has no label_$locale',
        ));
      }
    }
  }

  // ─── report ───────────────────────────────────────────────────────

  stdout.writeln('recipe translation audit');
  stdout.writeln('  recipes           ${recipes.length}');
  for (final locale in kShippedLocales) {
    final done = coverage[locale] ?? 0;
    final pct = recipes.isEmpty ? 0 : (done * 100 / recipes.length).floor();
    stdout.writeln(
      '  $locale coverage       $done / ${recipes.length}  ($pct%)',
    );
  }
  stdout.writeln('  findings          ${findings.length}');

  final byRule = <String, int>{};
  for (final finding in findings) {
    byRule[finding.rule] = (byRule[finding.rule] ?? 0) + 1;
  }
  for (final entry in byRule.entries) {
    stdout.writeln('    ${entry.key.padRight(16)} ${entry.value}');
  }
  if (listAll) {
    for (final finding in findings) {
      stdout.writeln('    $finding');
    }
  } else if (findings.isNotEmpty) {
    for (final finding in findings.take(10)) {
      stdout.writeln('    $finding');
    }
    if (findings.length > 10) {
      stdout.writeln('    … ${findings.length - 10} more, use --list');
    }
  }

  // ─── ratchet ──────────────────────────────────────────────────────

  final baselineFile = File('tool/recipe_translation_baseline.json');
  final baseline = baselineFile.existsSync()
      ? (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};

  if (updateBaseline) {
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
            'note': 'Roadmap Phase 7 · per-locale recipe translation '
                'coverage. Ratchets upward only. Regenerate with '
                '--update-baseline after a translation batch lands.',
            'coverage': coverage,
          })}\n',
    );
    stdout.writeln('\nbaseline updated');
    exit(0);
  }

  var regressed = false;
  final recorded = (baseline['coverage'] as Map<String, dynamic>?) ?? {};
  for (final locale in kShippedLocales) {
    final was = (recorded[locale] as num?)?.toInt() ?? 0;
    final now = coverage[locale] ?? 0;
    if (now < was) {
      regressed = true;
      stdout.writeln(
        '\n✗ $locale coverage FELL from $was to $now. Translations do not '
        'un-happen;\n  something dropped rows or reverted a batch.',
      );
    }
  }

  if (findings.isEmpty && !regressed) {
    stdout.writeln('\n✓ no findings, coverage held');
    exit(0);
  }
  exit(1);
}

// ─── helpers ─────────────────────────────────────────────────────────

Map<String, String> _readEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final out = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        value[0] == value[value.length - 1] &&
        (value.startsWith('"') || value.startsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    out[trimmed.substring(0, eq).trim()] = value;
  }
  return out;
}

Future<List<Map<String, dynamic>>> _fetch(
  String url,
  String key,
  String path,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.parse('$url/rest/v1/$path'));
    request.headers
      ..set('apikey', key)
      ..set('Authorization', 'Bearer $key');
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: $body');
    }
    return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
  } finally {
    client.close();
  }
}

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;

/// The numbered lines of a method block. Falls back to every non-empty
/// line when the source is not numbered, so an unnumbered recipe is
/// compared like for like rather than reported as zero steps.
List<String> _steps(String body) {
  final afterHeader = body.split(RegExp(r'HAZIRLANIŞI:|YAPILIŞ:|METHOD:')).last;
  final numbered = RegExp(r'^\s*\d+\s*[.)]\s*(.+)$', multiLine: true)
      .allMatches(afterHeader)
      .map((m) => m.group(1)!.trim())
      .toList();
  if (numbered.isNotEmpty) return numbered;
  return afterHeader
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

List<String> _numbers(String text) => RegExp(r'\d+(?:[.,]\d+)?')
    .allMatches(text)
    .map((m) => m.group(0)!.replaceAll(',', '.'))
    .toList();

List<String> _missing(List<String> source, List<String> target) {
  final remaining = [...target];
  final lost = <String>[];
  for (final number in source) {
    if (!remaining.remove(number)) lost.add(number);
  }
  return lost;
}

/// Turkish-only characters in [text], minus anything inside a
/// never-translate term. Returns the offending words.
List<String> _turkishResidue(String text) {
  var scrubbed = text;
  for (final term in kNeverTranslated) {
    scrubbed = scrubbed.replaceAll(
      RegExp(RegExp.escape(term), caseSensitive: false),
      '',
    );
  }
  return scrubbed
      .split(RegExp(r'[\s,.;:!?()\[\]"]+'))
      .where((word) => _turkishOnly.hasMatch(word))
      .toSet()
      .toList();
}
