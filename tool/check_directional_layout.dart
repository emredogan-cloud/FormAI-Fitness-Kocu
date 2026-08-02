// Roadmap Phase 8 (C13) · the direction-neutrality gate.
//
// Run:
//   dart run tool/check_directional_layout.dart            # report
//   dart run tool/check_directional_layout.dart --list     # every flagged line
//   dart run tool/check_directional_layout.dart --baseline # rewrite baseline
//
// WHY A GATE AND NOT A CONVERSION
//
// `lib/` holds ~120 directional `Alignment.*Left/*Right` and ~55
// `Positioned(left:/right:)` call sites. Converting all of them in one
// pass is a large diff over screens nobody is otherwise touching, and
// most of those call sites are decorative — a glow blob, a badge on a
// photograph — where mirroring is a judgement call rather than a bug.
// So this runs as a **ratchet**, exactly like
// `check_hardcoded_strings.dart`: a committed baseline records the count
// per file and the build fails only when a file's count goes UP.
// Converting a screen lowers the baseline; nothing raises it.
//
// WHY THE RTL SWEEP IS NOT ENOUGH ON ITS OWN
//
// `test/i18n/rtl_readiness_test.dart` and `rtl_app_sweep_test.dart`
// render surfaces right-to-left and assert nothing overflows. An
// `Alignment.centerLeft` does not overflow — it lays out perfectly, on
// the wrong side. The sweep cannot see that and never will; only reading
// the source can. The two checks are complements, not duplicates.
//
// WHAT IS NOT FLAGGED, AND WHY
//
//   * `EdgeInsets.fromLTRB` where left == right. All 127 call sites in
//     `lib/` are horizontally symmetric today, which means none of them
//     mirrors wrong. Flagging them would be 127 findings with a true
//     positive rate of zero — the fastest way to get a gate muted.
//     Asymmetric ones ARE flagged.
//   * `Alignment.center`, `.topCenter`, `.bottomCenter` — no direction.
//   * Anything on a line carrying `// rtl-ignore` with a reason.

import 'dart:convert';
import 'dart:io';

const _scannedRoot = 'lib';
const _baselinePath = 'tool/directional_layout_baseline.json';

/// `Alignment.centerLeft` and friends. `AlignmentDirectional` is the
/// fix, so it must not itself match — hence the `(?<!Directional)`.
final _alignment = RegExp(
  r'\bAlignment(?<!Directional)\.[a-zA-Z]*(Left|Right)\b',
);

/// `Positioned(... left: 8 ...)`. Matches the argument, not the widget,
/// because `Positioned.fill` and `PositionedDirectional` are both fine.
final _positioned = RegExp(r'\b(left|right)\s*:');

/// Only inside a `Positioned(` — `left:` also appears on `Rect.fromLTRB`
/// and on `EdgeInsets.only`, which are handled separately.
final _positionedOpen = RegExp(r'\bPositioned\s*\(');

/// `EdgeInsets.only(left: ...)` / `.only(right: ...)`.
final _edgeOnly = RegExp(r'\bEdgeInsets\.only\s*\([^)]*\b(left|right)\s*:');

/// `EdgeInsets.fromLTRB(a, _, b, _)` where a != b.
final _fromLtrb = RegExp(
  r'\bEdgeInsets\.fromLTRB\s*\(\s*([0-9.]+)\s*,\s*[0-9.]+\s*,\s*([0-9.]+)\s*,',
);

final _textAlign = RegExp(r'\bTextAlign\.(left|right)\b');

class _Finding {
  _Finding(this.file, this.line, this.text, this.kind);
  final String file;
  final int line;
  final String text;
  final String kind;
}

bool _skip(String line) =>
    line.contains('// rtl-ignore') || line.trimLeft().startsWith('///');

List<_Finding> _scan() {
  final findings = <_Finding>[];
  final dir = Directory(_scannedRoot);
  if (!dir.existsSync()) return findings;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    // Generated localisations are ~40k lines of no interest here.
    if (entity.path.contains('app_localizations')) continue;

    final lines = entity.readAsLinesSync();
    var positionedDepth = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_skip(line)) continue;
      final rel = entity.path;

      if (_alignment.hasMatch(line)) {
        findings.add(_Finding(rel, i + 1, line.trim(), 'alignment'));
      }
      if (_textAlign.hasMatch(line)) {
        findings.add(_Finding(rel, i + 1, line.trim(), 'textAlign'));
      }
      if (_edgeOnly.hasMatch(line)) {
        findings.add(_Finding(rel, i + 1, line.trim(), 'edgeInsetsOnly'));
      }
      final ltrb = _fromLtrb.firstMatch(line);
      if (ltrb != null &&
          double.parse(ltrb.group(1)!) != double.parse(ltrb.group(2)!)) {
        findings.add(_Finding(rel, i + 1, line.trim(), 'asymmetricLTRB'));
      }

      // `Positioned(` often wraps onto following lines, so track a small
      // window rather than requiring the argument on the same line.
      if (_positionedOpen.hasMatch(line)) positionedDepth = 6;
      if (positionedDepth > 0) {
        if (_positioned.hasMatch(line) &&
            !line.contains('PositionedDirectional')) {
          findings.add(_Finding(rel, i + 1, line.trim(), 'positioned'));
        }
        positionedDepth--;
      }
    }
  }
  findings.sort((a, b) =>
      a.file == b.file ? a.line.compareTo(b.line) : a.file.compareTo(b.file));
  return findings;
}

Map<String, int> _countsByFile(List<_Finding> findings) {
  final counts = <String, int>{};
  for (final f in findings) {
    counts[f.file] = (counts[f.file] ?? 0) + 1;
  }
  return counts;
}

Map<String, int> _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return {};
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, v as int));
}

void _writeBaseline(Map<String, int> counts) {
  final sorted = Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  File(_baselinePath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
  );
}

void main(List<String> args) {
  final findings = _scan();
  final counts = _countsByFile(findings);

  if (args.contains('--baseline')) {
    _writeBaseline(counts);
    stdout.writeln('wrote $_baselinePath — ${findings.length} findings '
        'across ${counts.length} files');
    return;
  }

  if (args.contains('--list')) {
    for (final f in findings) {
      stdout.writeln('${f.file}:${f.line}  [${f.kind}]  ${f.text}');
    }
    stdout.writeln('');
  }

  final baseline = _readBaseline();
  final regressions = <String>[];
  for (final entry in counts.entries) {
    final was = baseline[entry.key] ?? 0;
    if (entry.value > was) {
      regressions.add('  ${entry.key}: $was → ${entry.value}');
    }
  }

  final byKind = <String, int>{};
  for (final f in findings) {
    byKind[f.kind] = (byKind[f.kind] ?? 0) + 1;
  }
  stdout.writeln('directional layout: ${findings.length} in '
      '${counts.length} files');
  for (final entry in (byKind.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value)))) {
    stdout.writeln('  ${entry.value.toString().padLeft(4)}  ${entry.key}');
  }

  if (regressions.isEmpty) {
    stdout.writeln('  ✓ no regressions');
    return;
  }
  stderr
    ..writeln('')
    ..writeln('✗ direction-neutrality regressed:')
    ..writeln(regressions.join('\n'))
    ..writeln('')
    ..writeln('Use AlignmentDirectional / PositionedDirectional /')
    ..writeln('EdgeInsetsDirectional, or mark the line `// rtl-ignore`')
    ..writeln('with a reason if the position is genuinely absolute.');
  exit(1);
}
