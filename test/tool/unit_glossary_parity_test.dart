import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/recipe_ingredient.dart';

/// Roadmap Phase 7 · the unit glossary exists twice, and this is why
/// that is allowed.
///
/// `kUnitGlossaryEn` in `recipe_ingredient.dart` is what the app renders.
/// `UNITS_EN` in `tool/recipe_pipeline/translations/build_recipe_en.py`
/// is what builds the `INGREDIENTS:` half of every `instructions_en`.
/// They must produce the same line for the same row, and they cannot
/// share code because one is Dart in a Flutter app and the other is
/// Python in a build script.
///
/// So the rule is: **two copies are acceptable only when something proves
/// they agree.** This is that something. It parses the Python file rather
/// than importing it, which is crude and is the point — a test that
/// cannot run without a Python toolchain would be a test that gets
/// skipped.
///
/// If this fails, the app and the stored English instructions have
/// started disagreeing about what `2 diş sarımsak` says in English, and
/// nothing else in the suite would notice.
void main() {
  test('the Dart and Python unit glossaries carry the same units', () {
    final python = _parsePythonGlossary();
    expect(
      python.keys.toSet(),
      kUnitGlossaryEn.keys.toSet(),
      reason: 'the two glossaries know different units',
    );
  });

  test('they render the same singular and plural for every unit', () {
    final python = _parsePythonGlossary();
    for (final entry in kUnitGlossaryEn.entries) {
      final dart = entry.value;
      final py = python[entry.key];
      expect(
        [dart.singular, dart.plural],
        [py?.$1, py?.$2],
        reason: '"${entry.key}" renders differently in the two copies',
      );
    }
  });

  test('the file the test reads actually exists', () {
    // A parity test that silently passes because it found no file is
    // worse than no parity test.
    expect(File(_pythonPath).existsSync(), isTrue, reason: _pythonPath);
    expect(_parsePythonGlossary(), isNotEmpty);
  });
}

const String _pythonPath =
    'tool/recipe_pipeline/translations/build_recipe_en.py';

/// Reads `UNITS_EN` out of the Python source.
///
/// Handles the three shapes that file uses: `"g": "g"`, `"adet": None`,
/// and `"diş": ("clove", "cloves")`.
Map<String, (String?, String?)> _parsePythonGlossary() {
  final source = File(_pythonPath).readAsStringSync();
  final start = source.indexOf('UNITS_EN = {');
  if (start < 0) return {};
  final end = source.indexOf('\n}', start);
  final body = source.substring(start, end);

  final out = <String, (String?, String?)>{};
  final entry = RegExp(
    r'"([^"]+)":\s*(?:None|"([^"]*)"|\("([^"]*)",\s*"([^"]*)"\))',
    unicode: true,
  );
  for (final match in entry.allMatches(body)) {
    final key = match.group(1)!;
    if (match.group(2) != null) {
      out[key] = (match.group(2), match.group(2));
    } else if (match.group(3) != null) {
      out[key] = (match.group(3), match.group(4));
    } else {
      out[key] = (null, null);
    }
  }
  return out;
}
