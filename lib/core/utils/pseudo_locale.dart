/// Roadmap Phase 5 (C11) · pseudo-localisation for QA.
///
/// The point is to find two classes of bug *before* paying a translator
/// a single word:
///
///   1. **Un-extracted strings.** Every localised string comes back
///      bracketed. Anything still rendering as plain Turkish is a
///      literal the extraction missed — and it stands out at a glance
///      instead of hiding until a real translation ships.
///   2. **Layout that only fits Turkish.** German runs ~35% longer, so
///      the inflated text surfaces the overflow and fold problems now.
///      This codebase has shipped a clipped primary CTA three times
///      (RC-17 paywall, RC-18 Başla, and the Phase 3b report screen) —
///      each one found on a device, late. Inflating every string by 40%
///      turns that from a device-QA lottery into something a widget test
///      can assert.
///
/// Debug-only by construction: [pseudoLocalize] is a pure function, and
/// the delegate that applies it is gated on `kDebugMode` at its single
/// call site so it cannot reach a release build.
library;

/// How much longer the pseudo string is than the original. 0.4 ≈ the
/// German/Turkish ratio with headroom.
const double kPseudoInflation = 0.4;

/// Characters appended to pad a string out. Accented so they also prove
/// the font and the text shaping handle non-ASCII — a real failure mode
/// on custom fonts with partial glyph coverage.
const String _padChars = 'ëẍţëñdëd';

/// Wraps and inflates [value] so un-extracted strings are obvious and
/// long-language layout problems surface early.
///
/// Placeholders are preserved verbatim: inflating `{count}` into
/// `{coëëunt}` would break ICU at runtime and turn a layout check into a
/// crash, which teaches the team that pseudo mode is broken rather than
/// that their layout is.
String pseudoLocalize(String value) {
  if (value.isEmpty) return value;

  final buffer = StringBuffer('⟦');
  var padBudget = 0;

  // Walk the string, copying `{placeholder}` runs untouched and
  // counting only real text toward the inflation budget.
  var index = 0;
  while (index < value.length) {
    final char = value[index];
    if (char == '{') {
      final close = value.indexOf('}', index);
      if (close != -1) {
        buffer.write(value.substring(index, close + 1));
        index = close + 1;
        continue;
      }
    }
    buffer.write(char);
    padBudget++;
    index++;
  }

  final padLength = (padBudget * kPseudoInflation).round();
  if (padLength > 0) {
    buffer.write(' ');
    for (var i = 0; i < padLength; i++) {
      buffer.write(_padChars[i % _padChars.length]);
    }
  }
  buffer.write('⟧');
  return buffer.toString();
}

/// True when [value] has been through [pseudoLocalize]. Used by tests
/// to assert that a screen's text actually went through localisation.
bool isPseudoLocalized(String value) =>
    value.startsWith('⟦') && value.endsWith('⟧');
