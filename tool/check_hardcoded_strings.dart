// Roadmap Phase 5 (C11) · the hardcoded-string gate.
//
// Extraction is a one-time cost. Re-introduction is a permanent one:
// without a gate, every future PR adds a handful of Turkish literals
// back into presentation code and the ARB drifts out of date until
// nobody trusts it. This script is what makes the extraction stick.
//
// Run:
//   dart run tool/check_hardcoded_strings.dart            # report
//   dart run tool/check_hardcoded_strings.dart --baseline # rewrite baseline
//
// HOW IT AVOIDS BEING IGNORED
//
// A gate that fails on day one against 1,900 pre-existing violations is
// a gate somebody disables in week one. So it runs as a **ratchet**: a
// committed baseline records the current count per file, and the build
// fails only when a file's count goes UP. Extraction lowers the
// baseline; nothing can raise it. That makes the gate useful from the
// first commit rather than after the last one.
//
// WHAT COUNTS AS USER-FACING
//
// Heuristics, deliberately biased toward false negatives — a gate that
// cries wolf gets muted. A literal is flagged when it is in a
// presentation file, contains a Turkish-alphabet character or a common
// Turkish word, is at least two characters, and is not obviously
// technical (an asset path, a route, a key, a locale tag, a format
// pattern) or already inside an `// i18n-ignore` line.

import 'dart:convert';
import 'dart:io';

/// Directories whose user-visible strings must eventually live in ARB.
const _scannedRoots = <String>[
  'lib/features',
  'lib/core/widgets',
];

/// Only presentation-layer files are gated. Domain and data files hold
/// content (exercise names, FAQ bodies) that Phase 7 localises through
/// the database rather than ARB, and flagging them here would train
/// people to ignore the tool.
bool _isGatedPath(String path) {
  final p = path.replaceAll(r'\', '/');
  if (!p.endsWith('.dart')) return false;
  if (p.contains('/l10n/')) return false;
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
  if (p.startsWith('lib/core/widgets/')) return true;
  return p.contains('/presentation/');
}

final _turkishSignal = RegExp(
  r'[çğıöşüÇĞİÖŞÜ]|\b('
  r've|için|bir|bu|ile|sana|senin|daha|gün|hafta|antrenman|kalori|'
  r'tekrar|hedef|seni|sen|ama|çok|yeni|şimdi'
  r')\b',
  caseSensitive: false,
);

/// Literals that are technical rather than user-facing.
final _technical = <RegExp>[
  RegExp(r'^[a-z0-9_./-]+\.(png|jpg|jpeg|webp|svg|json|riv|mp4|otf|ttf)$'),
  RegExp(r'^/[a-z0-9/_-]*$'), // routes
  RegExp(r'^[a-z][a-zA-Z0-9]*$'), // identifiers / tokens
  RegExp(r'^[a-z0-9_]+$'), // snake_case keys
  RegExp(r'^https?://'),
  RegExp(r'^#[0-9a-fA-F]{3,8}$'),
  RegExp(r'^[\d\s\-+*/%.,:()]+$'), // pure punctuation / numbers
  RegExp(r'^[A-Za-z]{2}(_[A-Za-z]{2})?$'), // locale tags
];

bool _isTechnical(String value) {
  final v = value.trim();
  if (v.length < 2) return true;
  for (final pattern in _technical) {
    if (pattern.hasMatch(v)) return true;
  }
  return false;
}

/// Matches single- and double-quoted Dart literals without escapes or
/// interpolation braces. Deliberately simple: a literal this misses is
/// a false negative, which is the direction we want to err in.
final _literal = RegExp(r"'([^'\\\n$]{2,}?)'|" r'"([^"\\\n$]{2,}?)"');

int _countViolations(String source) {
  var count = 0;
  for (final rawLine in const LineSplitter().convert(source)) {
    final line = rawLine.trim();
    if (line.startsWith('//')) continue;
    if (line.contains('i18n-ignore')) continue;
    for (final match in _literal.allMatches(rawLine)) {
      final value = match.group(1) ?? match.group(2) ?? '';
      if (_isTechnical(value)) continue;
      if (!_turkishSignal.hasMatch(value)) continue;
      count++;
    }
  }
  return count;
}

Map<String, int> _scan() {
  final counts = <String, int>{};
  for (final root in _scannedRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!_isGatedPath(path)) continue;
      final count = _countViolations(entity.readAsStringSync());
      if (count > 0) counts[path] = count;
    }
  }
  return counts;
}

const _baselinePath = 'tool/hardcoded_strings_baseline.json';

void main(List<String> args) {
  final counts = _scan();
  final total = counts.values.fold<int>(0, (a, b) => a + b);

  if (args.contains('--baseline')) {
    final sorted = Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    File(_baselinePath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
    );
    stdout.writeln('Baseline written: $total literals in ${counts.length} '
        'files → $_baselinePath');
    return;
  }

  final baselineFile = File(_baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('No baseline at $_baselinePath. '
        'Run with --baseline to create one.');
    exit(2);
  }

  final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map)
      .map((k, v) => MapEntry(k as String, v as int));
  final baselineTotal = baseline.values.fold<int>(0, (a, b) => a + b);

  final regressions = <String, ({int was, int now})>{};
  counts.forEach((path, count) {
    final was = baseline[path] ?? 0;
    if (count > was) regressions[path] = (was: was, now: count);
  });

  stdout.writeln('Hardcoded user-facing strings in gated paths:');
  stdout.writeln('  now:      $total in ${counts.length} files');
  stdout.writeln('  baseline: $baselineTotal in ${baseline.length} files');

  if (regressions.isEmpty) {
    final improved = baselineTotal - total;
    if (improved > 0) {
      stdout.writeln('  ✓ $improved fewer than baseline — '
          'run with --baseline to lock the gain in.');
    } else {
      stdout.writeln('  ✓ no regressions');
    }
    return;
  }

  stderr.writeln('\n✗ hardcoded strings INCREASED in '
      '${regressions.length} file(s):');
  final entries = regressions.entries.toList()
    ..sort((a, b) => (b.value.now - b.value.was) - (a.value.now - a.value.was));
  for (final entry in entries) {
    stderr.writeln('    ${entry.key}: '
        '${entry.value.was} → ${entry.value.now}');
  }
  stderr.writeln('\nMove the new user-facing strings into lib/l10n/app_tr.arb '
      'and read them through AppLocalizations.');
  stderr.writeln('If a flagged literal is genuinely not user-facing, append '
      '`// i18n-ignore` to its line.');
  exit(1);
}
