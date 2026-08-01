@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_ingredient_lines.dart';
import 'package:sixpack_ai/features/nutrition/domain/recipe_tag_token.dart';

/// Roadmap Phase 7 · the read path, against the real catalogue.
///
///     flutter test --tags live test/features/nutrition/live_catalogue_read_path_test.dart
///
/// Excluded from the default run by its tag, because CI has no `.env` and
/// a test that needs the network is a test that makes the suite flaky.
/// It is the closest thing to a device walk that does not need a device:
/// it fetches through the same public endpoint the app uses, decodes with
/// the same `Recipe.fromJson`, and asserts on what a reader would
/// actually see.
///
/// It exists because the Phase 6 device walk found eight defects that 934
/// tests were green across, and every one of them was about what reached
/// the screen rather than what the code did. This checks the half of that
/// which is data.
void main() {
  late List<Map<String, dynamic>> rows;

  setUpAll(() async {
    final env = _readEnv('.env');
    final url = env['SUPABASE_URL'];
    final key = env['SUPABASE_ANON_KEY'];
    if (url == null || key == null || url.isEmpty || key.isEmpty) {
      markTestSkipped('no SUPABASE_URL / SUPABASE_ANON_KEY in .env');
      rows = const [];
      return;
    }
    rows = await _fetch(
      url,
      key,
      'recipes?select=*,recipe_ingredients(*)&limit=500',
    );
  });

  test('every recipe resolves fully in English', () {
    if (rows.isEmpty) return;
    final untranslated = <String>[];
    for (final row in rows) {
      final recipe = Recipe.fromJson(row, languageCode: 'en');
      if (recipe.language != 'en') untranslated.add(recipe.title);
    }
    expect(
      untranslated,
      isEmpty,
      reason: '${untranslated.length} recipes fall back to Turkish for an '
          'English reader: ${untranslated.take(5).join(', ')}',
    );
  });

  test('no English recipe renders a Turkish ingredient line', () {
    if (rows.isEmpty) return;
    final turkish = RegExp('[ğşıİĞŞÇÖÜ]');
    final offenders = <String>[];
    for (final row in rows) {
      final recipe = Recipe.fromJson(row, languageCode: 'en');
      for (final line in recipeIngredientLines(recipe)) {
        // The ingredient glossary keeps proper nouns, and those are the
        // only Turkish characters allowed through.
        final scrubbed = line.replaceAll(
            RegExp(
                'sucuk|pastırma|tarhana|beyaz peynir|kaşar|lor|pekmez|'
                'bazlama|lavaş|mantı|erişte|köfte|pişi|çiğ',
                caseSensitive: false,
                unicode: true),
            '');
        if (turkish.hasMatch(scrubbed)) {
          offenders.add('${recipe.title}: $line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join('\n'));
  });

  test('no English ingredient line carries a Turkish unit', () {
    // The defect the translation audit found in the authored batch:
    // `2 yemek kaşığı olive oil`.
    if (rows.isEmpty) return;
    const turkishUnits = [
      'yemek kaşığı',
      'çay kaşığı',
      'tatlı kaşığı',
      'avuç',
      'diş',
      'tutam',
      'dilim',
      'adet',
      'demet',
      'ölçek',
    ];
    final offenders = <String>[];
    for (final row in rows) {
      final recipe = Recipe.fromJson(row, languageCode: 'en');
      for (final line in recipeIngredientLines(recipe)) {
        for (final unit in turkishUnits) {
          if (line.contains(unit)) offenders.add('${recipe.title}: $line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).join('\n'));
  });

  test('every recipe has at least one tag token this build can render', () {
    if (rows.isEmpty) return;
    final unrenderable = <String>[];
    for (final row in rows) {
      final recipe = Recipe.fromJson(row);
      final known = recipe.tagTokens.where(kRecipeTagTokens.contains);
      if (known.isEmpty) unrenderable.add(recipe.title);
    }
    expect(
      unrenderable,
      isEmpty,
      reason: '${unrenderable.length} recipes would show no category chip',
    );
  });

  test('every recipe has ingredients and an image', () {
    if (rows.isEmpty) return;
    for (final row in rows) {
      final recipe = Recipe.fromJson(row, languageCode: 'en');
      expect(recipe.ingredientRows, isNotEmpty, reason: recipe.title);
      // The stored column, not `recipe.imageUrl`. `MediaUrl.resolve`
      // returns null for a bare filename when dotenv has not been
      // initialised — which it has not, here — and that is a documented
      // test-environment behaviour rather than a missing image.
      expect(row['image_url'], isNotNull, reason: recipe.title);
    }
  });

  test('a Turkish reader still gets Turkish', () {
    if (rows.isEmpty) return;
    for (final row in rows) {
      final recipe = Recipe.fromJson(row, languageCode: 'tr');
      expect(recipe.language, 'tr', reason: recipe.title);
    }
  });
}

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
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$url/rest/v1/$path'));
    request.headers
      ..set('apikey', key)
      ..set('Authorization', 'Bearer $key');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (jsonDecode(body) as List).cast<Map<String, dynamic>>();
  } finally {
    client.close();
  }
}
