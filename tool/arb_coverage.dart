// Roadmap Phase 5 (C11) · ARB key coverage report.
//
// Run:
//   dart run tool/arb_coverage.dart          # report
//   dart run tool/arb_coverage.dart --strict # exit 1 on any gap
//
// Answers three questions the translation pipeline needs, and that
// nobody can answer by reading the files:
//
//   1. **Which keys is a locale missing?** These are the strings that
//      would silently fall back to the template locale in production —
//      a user seeing Turkish inside an English app, with no error
//      anywhere to tell you.
//   2. **Which keys does nothing use?** Dead keys cost translator money
//      per word, forever, for text no user will ever read.
//   3. **Do placeholders match across locales?** A translation that
//      drops `{count}` doesn't fail to compile — it renders a sentence
//      with a hole in it.
//
// The third check is the one worth having. Missing keys are visible the
// moment you look at a screen; a mismatched placeholder set survives
// review because both files look fine in isolation.

import 'dart:convert';
import 'dart:io';

const _arbDir = 'lib/l10n';
const _templateLocale = 'en';

final _placeholder = RegExp(r'\{(\w+)\}');

Map<String, dynamic> _readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

Set<String> _keysOf(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Set<String> _placeholdersOf(String value) =>
    _placeholder.allMatches(value).map((m) => m.group(1)!).toSet();

/// Every `AppLocalizations.of(context).key` / `l10n.key` reference in
/// lib/, so unused keys can be reported.
Set<String> _usedKeys() {
  final used = <String>{};
  final pattern = RegExp(
    r'(?:AppLocalizations\.of\([^)]*\)|\bl10n|\bstrings)\s*\.\s*([a-zA-Z_]\w*)',
  );
  final dir = Directory('lib');
  if (!dir.existsSync()) return used;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('/l10n/')) continue;
    for (final match in pattern.allMatches(entity.readAsStringSync())) {
      used.add(match.group(1)!);
    }
  }
  return used;
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final dir = Directory(_arbDir);
  if (!dir.existsSync()) {
    stderr.writeln('No ARB directory at $_arbDir');
    exit(2);
  }

  final arbs = <String, Map<String, dynamic>>{};
  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.arb')) continue;
    final name = entity.uri.pathSegments.last; // app_tr.arb
    final locale = name.replaceAll('app_', '').replaceAll('.arb', '');
    arbs[locale] = _readArb(entity);
  }

  final template = arbs[_templateLocale];
  if (template == null) {
    stderr.writeln('No template ARB for "$_templateLocale" in $_arbDir');
    exit(2);
  }

  final templateKeys = _keysOf(template);
  stdout.writeln('ARB coverage (template: $_templateLocale, '
      '${templateKeys.length} keys)\n');

  var problems = 0;

  // 1 + 3 · per-locale completeness and placeholder parity.
  for (final entry in arbs.entries) {
    final locale = entry.key;
    if (locale == _templateLocale) continue;
    final keys = _keysOf(entry.value);
    final missing = templateKeys.difference(keys);
    final extra = keys.difference(templateKeys);
    final pct = templateKeys.isEmpty
        ? 100.0
        : (keys.intersection(templateKeys).length / templateKeys.length) * 100;

    stdout.writeln('  $locale: ${pct.toStringAsFixed(1)}% '
        '(${keys.length} keys)');
    if (missing.isNotEmpty) {
      problems += missing.length;
      stdout.writeln('    missing (${missing.length}): '
          '${missing.take(10).join(', ')}'
          '${missing.length > 10 ? ', …' : ''}');
    }
    if (extra.isNotEmpty) {
      stdout.writeln('    not in template (${extra.length}): '
          '${extra.take(10).join(', ')}'
          '${extra.length > 10 ? ', …' : ''}');
    }

    final mismatched = <String>[];
    for (final key in keys.intersection(templateKeys)) {
      final a = _placeholdersOf('${template[key]}');
      final b = _placeholdersOf('${entry.value[key]}');
      if (a.length != b.length || !a.containsAll(b)) mismatched.add(key);
    }
    if (mismatched.isNotEmpty) {
      problems += mismatched.length;
      stdout.writeln('    ✗ placeholder mismatch (${mismatched.length}): '
          '${mismatched.take(10).join(', ')}');
    }
  }

  // 2 · unused keys.
  final used = _usedKeys();
  final unused = templateKeys.difference(used).toList()..sort();
  stdout.writeln(
      '\n  referenced in lib/: ${used.intersection(templateKeys).length}'
      ' / ${templateKeys.length}');
  if (unused.isNotEmpty) {
    stdout.writeln('  unused (${unused.length}): '
        '${unused.take(15).join(', ')}${unused.length > 15 ? ', …' : ''}');
  }

  if (strict && problems > 0) {
    stderr.writeln('\n✗ $problems ARB problem(s)');
    exit(1);
  }
  stdout.writeln('\n✓ report complete');
}
