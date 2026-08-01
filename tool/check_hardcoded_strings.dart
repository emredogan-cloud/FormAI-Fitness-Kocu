// Roadmap Phase 5 (C11) · the hardcoded-string gate.
//
// Extraction is a one-time cost. Re-introduction is a permanent one:
// without a gate, every future PR adds a handful of Turkish literals
// back into presentation code and the ARB drifts out of date until
// nobody trusts it. This script is what makes the extraction stick.
//
// Run:
//   dart run tool/check_hardcoded_strings.dart            # report
//   dart run tool/check_hardcoded_strings.dart --list     # every flagged line
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
// cries wolf gets muted. A literal is flagged when it is under `lib/`
// outside the allowlist, is at least two characters, is not obviously
// technical (an asset path, a route, a key, a locale tag, a format
// pattern), is not on an `// i18n-ignore` line, and either **reads as
// Turkish**, **is shaped like a label**, or **places a locale-ordered
// symbol against a value**.
//
// The last two clauses were both added in Phase 6, which is why this
// comment no longer says "contains a Turkish character". See
// [_looksLikeLabel] and [_hasLocaleOrderedSymbol] for what each of them
// caught in shipped screens.

import 'dart:convert';
import 'dart:io';

/// Directories whose user-visible strings must eventually live in ARB.
///
/// This was `lib/features` + `lib/core/widgets` until the camera
/// tutorial slice: see [_isGatedPath] for why it is now all of `lib`.
const _scannedRoots = <String>[
  'lib',
];

/// The documented allowlist the roadmap calls for: paths whose literals
/// are genuinely not user-facing.
///
/// `features/admin/**` is the internal content-ops panel. It is
/// reachable only by an account carrying the `admin` claim — the router
/// redirects everyone else — and it exists so the team can edit the
/// exercise and recipe catalogues. Its audience is the people who build
/// FormAI, in the language they work in. Translating it would cost
/// translator budget on strings no user can reach, and gating it would
/// leave ~96 permanent violations sitting in the report training
/// everyone to ignore the number.
///
/// Anything added here needs the same test: could a user, on any locale,
/// on any path through the app, see this string? If yes, it is not
/// allowlist material.
const _allowlistedPrefixes = <String>[
  'lib/features/admin/',
  // Developer CLI scripts. Their strings are console output for whoever
  // runs `dart run lib/scripts/...` — they never reach a user, and the
  // person reading them is the person who wrote them.
  'lib/scripts/',
  // The seeded exercise and plan catalogue: names, descriptions and
  // cues that mirror rows in the `exercises` / `workout_plans` tables.
  // These are the one genuine case of the original "domain and data
  // hold content" argument — they are DATA IDENTITY, not app copy, and
  // Phase 7 localises them through the `*_i18n` columns added in
  // migration 011. Putting them in ARB would fork the catalogue: the
  // seed would translate and the database rows would not.
  'lib/features/workout/data/workout_repository.dart',
];

/// Every Dart file under `lib/` is gated, minus the allowlist above.
///
/// It used to be presentation-only, on the reasoning that "domain and
/// data files hold content that Phase 7 localises through the database".
/// That reasoning held for exactly one file (the exercise catalogue) and
/// was wrong about the rest.
///
/// What it missed: `FramingResult.hint` — the live "can I see you?"
/// guidance under the camera preview, six hardcoded Turkish strings in
/// `domain/`, and the most-read line on the calibration screen. The
/// tutorial screen could be extracted to zero and reported clean while
/// its most important sentence stayed untranslated. Behind it sat ~540
/// more in the same blind spot: spoken coach lines, notification bodies,
/// badge names, form warnings, FAQ answers — none of it DB-backed, all
/// of it read by users.
///
/// A gate is a claim about coverage. Scoping it to the layer where copy
/// is *supposed* to live means it can only ever verify the discipline of
/// people who already have it, and stays silent about the copy that
/// leaked. So the scope is now "all of lib", and anything genuinely not
/// user-facing earns an allowlist entry with a written reason — visible
/// in the report, rather than invisible in a path rule.
bool _isGatedPath(String path) {
  final p = path.replaceAll(r'\', '/');
  if (!p.endsWith('.dart')) return false;
  if (p.contains('/l10n/')) return false;
  if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
  for (final prefix in _allowlistedPrefixes) {
    if (p.startsWith(prefix)) return false;
  }
  return true;
}

final _turkishSignal = RegExp(
  r'[çğıöşüÇĞİÖŞÜ]|\b('
  r've|için|bir|bu|ile|sana|senin|daha|gün|hafta|antrenman|kalori|'
  r'tekrar|hedef|seni|sen|ama|çok|yeni|şimdi'
  r')\b',
  caseSensitive: false,
);

/// A literal shaped like something a person reads, rather than a key.
///
/// Blind spot #4, found in Phase 6 while adding the language picker.
/// `_turkishSignal` recognises Turkish by its diacritics or by a short
/// stopword list, so it was silent on every Turkish word that happens to
/// be pure ASCII and isn't one of those eighteen. `'Tema'` sat in the
/// profile tab's theme tile — a title on a settings screen — and the
/// gate reported the file at zero.
///
/// It was not alone: widening to this rule surfaced `'Rozetler'` (the
/// badges screen title), the calendar's `'Tamamlanan'` / `'Bekleyen'` /
/// `'Planlanan'` legend, four separate `'DEVAM ET'` buttons, the body-
/// feelings options, `'Beslenme'` on the dashboard, and the spotlight
/// tour's `'Devam'` / `'Atla'`. All of it would have rendered Turkish
/// inside the English app.
///
/// The shape, not the language: a sentence-cased word, or two words with
/// a space between them. Keys are `snake_case`, `camelCase` or dotted;
/// none of those match. This is what makes the gate bilingual — an
/// English literal in `lib/` is now just as wrong as a Turkish one, and
/// as of Phase 6 that is the truth the gate needs to enforce.
final _labelShape = RegExp(
  // A sentence-cased word: `Tema`, `Rozetler`, `Beslenme`.
  r'^[A-ZÇĞİÖŞÜ][a-zçğıöşü]'
  // Or two letter-words separated by a space: `Plana Ekle`, `ya da`.
  r'|^[a-zA-ZÇĞİÖŞÜçğıöşü]+ [a-zA-ZÇĞİÖŞÜçğıöşü]',
);

bool _looksLikeLabel(String value) => _labelShape.hasMatch(value.trim());

/// Literals that are technical rather than user-facing.
final _technical = <RegExp>[
  RegExp(r'^[a-z0-9_./-]+\.(png|jpg|jpeg|webp|svg|json|riv|mp4|otf|ttf)$'),
  RegExp(r'^/[a-z0-9/_-]*$'), // routes
  RegExp(r'^[a-z][a-zA-Z0-9]*$'), // identifiers / tokens
  RegExp(r'^[a-z0-9_]+$'), // snake_case keys
  // Dotted storage / analytics keys — `sixpack.theme_mode`. Only
  // excluded now that the label rule would otherwise catch the ones
  // with two dotted segments.
  RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)+$'),
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

/// A line that is producing a diagnostic rather than user-facing copy.
///
/// Log messages, assertion reasons and regex sources are the bulk of
/// what an interpolation-aware scan turns up, and none of them is
/// translatable. Checking the two lines above the literal as well
/// catches the common shape where the call opens on one line and the
/// message wraps onto the next.
final _diagnostic = RegExp(
  r'AppLogger\.|debugPrint\(|stderr\.|stdout\.|RegExp\(|assert\(|'
  r'throw \w*(Exception|Error)|reason:|toString\(\) =>',
);

/// A literal made of nothing but interpolations and punctuation.
///
/// `'$a · $b'` is composition of values that are already localised, not
/// copy. Flagging it would push people toward wrapping every join in a
/// pointless ARB key.
final _onlyInterpolation = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]');
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

/// Punctuation whose PLACEMENT is a language decision.
///
/// Blind spot #6, found on a device during the Phase 6 English walk. The
/// progress tab rendered `%0` inside the English app, because five
/// screens built their percentage as `'%$value'` — and Turkish writes
/// the symbol before the number while English writes it after.
///
/// The composition rule was right that there is no *word* to translate
/// there. It was wrong that there is nothing to localise: the order is
/// the localisation. Only `%` qualifies today; a currency symbol would
/// belong here too if the app ever formatted one by hand.
/// It has to be a positive SIGNAL, not merely an un-exclusion. The first
/// attempt only stopped `'%$value'` being called pure composition, and
/// the literal then failed both the Turkish test and the label test and
/// was skipped anyway — the gate still reported zero. A synthetic probe
/// caught that; the real files would not have.
bool _hasLocaleOrderedSymbol(String value) {
  final withoutValues = value.replaceAll(_interpolation, '');
  // A bare "%" on its own is a unit, not an ordering decision. It only
  // matters when there is a value for it to sit before or after.
  if (withoutValues.trim() == value.trim()) return false;
  return withoutValues.contains('%');
}

bool _isPureComposition(String value) =>
    !_onlyInterpolation.hasMatch(value.replaceAll(_interpolation, ''));

/// Matches single- and double-quoted Dart literals, INCLUDING ones that
/// interpolate a value.
///
/// Escape sequences ARE matched: the pattern used to reject any literal
/// containing a backslash, which made every `'İKİ\nSATIR'` invisible to
/// this gate. Three real strings were hiding behind that — a hero
/// speech bubble, a report eyebrow, and a share hashtag — all of which
/// looked extracted because nothing was counting them.
///
/// Interpolation used to be excluded, which hid a class of string this
/// project had a lot of: `'Gün $dayNumber tamamlandı!'`. Sixty of those
/// were sitting in shipped screens while the gate reported zero — one
/// of them a live rendering bug, `'İleri Seviye $_categoryLabel(...)'`,
/// which interpolated a method tear-off and printed `Closure: ...` on
/// the plan screen.
final _literal = RegExp(
  r"'((?:[^'\\\n]|\\.){2,}?)'" r'|"((?:[^"\\\n]|\\.){2,}?)"',
);

/// One flagged literal, with enough to go and fix it.
class Violation {
  Violation(this.line, this.value);
  final int line;
  final String value;
}

List<Violation> _findViolations(String source) {
  final found = <Violation>[];
  final lines = const LineSplitter().convert(source);
  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final line = rawLine.trim();
    if (line.startsWith('//')) continue;
    if (line.contains('i18n-ignore')) continue;
    final context = lines.sublist(i < 2 ? 0 : i - 2, i + 1).join('\n');
    if (_diagnostic.hasMatch(context)) continue;
    for (final match in _literal.allMatches(rawLine)) {
      final value = match.group(1) ?? match.group(2) ?? '';
      if (_isTechnical(value)) continue;
      final ordered = _hasLocaleOrderedSymbol(value);
      if (!ordered && _isPureComposition(value)) continue;
      if (!ordered &&
          !_turkishSignal.hasMatch(value) &&
          !_looksLikeLabel(value)) {
        continue;
      }
      found.add(Violation(i + 1, value));
    }
  }
  return found;
}

int _countViolations(String source) => _findViolations(source).length;

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

/// How many literals each allowlist entry is suppressing, so the report
/// can say so out loud rather than letting an exclusion masquerade as
/// progress.
///
/// Reported per entry, not as one total: an allowlist is a standing
/// promise that a body of strings is genuinely unreachable, and a promise
/// nobody can audit line by line is one that quietly grows.
Map<String, int> _allowlistedCounts() {
  final counts = <String, int>{};
  for (final prefix in _allowlistedPrefixes) {
    var total = 0;
    // Entries are either a directory prefix or a single file path.
    final asFile = File(prefix);
    if (asFile.existsSync()) {
      total = _countViolations(asFile.readAsStringSync());
    } else {
      final dir = Directory(prefix);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart')) continue;
        if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
          continue;
        }
        total += _countViolations(entity.readAsStringSync());
      }
    }
    if (total > 0) counts[prefix] = total;
  }
  return counts;
}

const _baselinePath = 'tool/hardcoded_strings_baseline.json';

void main(List<String> args) {
  final counts = _scan();
  final total = counts.values.fold<int>(0, (a, b) => a + b);

  // A count tells you a file regressed; it doesn't tell you which line.
  // Every extraction pass so far has started by re-deriving this list by
  // hand, so the gate may as well print it.
  if (args.contains('--list')) {
    final paths = counts.keys.toList()..sort();
    for (final path in paths) {
      for (final v in _findViolations(File(path).readAsStringSync())) {
        stdout.writeln('$path:${v.line}: ${v.value}');
      }
    }
    stdout.writeln('\n$total literals in ${counts.length} files');
    return;
  }

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

  // Report what the allowlist is hiding, every run.
  //
  // Otherwise a path added to `_allowlistedPrefixes` looks identical to
  // extraction work in the numbers, and "we got the count down" stops
  // meaning anything. An allowlisted string is untranslated; it is just
  // untranslated on purpose.
  final allowlisted = _allowlistedCounts();
  if (allowlisted.isNotEmpty) {
    final sum = allowlisted.values.fold<int>(0, (a, b) => a + b);
    stdout.writeln('  (excluded by allowlist, NOT extracted: $sum)');
    for (final entry in allowlisted.entries) {
      stdout.writeln('      ${entry.value.toString().padLeft(5)}  '
          '${entry.key}');
    }
  }

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
