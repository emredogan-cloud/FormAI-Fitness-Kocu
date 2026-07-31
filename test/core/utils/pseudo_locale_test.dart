import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/pseudo_locale.dart';

/// Roadmap Phase 5 (C11) · pseudo-localisation.
///
/// Two jobs, and the tests are one per job: make un-extracted strings
/// visible, and make long-language layout problems reproducible before a
/// translator is paid. The third property — not breaking ICU — is what
/// keeps the tool from being abandoned the first time it "crashes".
void main() {
  group('bracketing', () {
    test('wraps a string so un-extracted text stands out', () {
      final out = pseudoLocalize('Antrenman');
      expect(out.startsWith('⟦'), isTrue);
      expect(out.endsWith('⟧'), isTrue);
      expect(out, contains('Antrenman'));
    });

    test('isPseudoLocalized recognises its own output', () {
      expect(isPseudoLocalized(pseudoLocalize('Merhaba')), isTrue);
    });

    test(
        'and rejects a plain string — which is how a missed literal is '
        'detected', () {
      expect(isPseudoLocalized('Merhaba'), isFalse);
      expect(isPseudoLocalized('⟦ only opening'), isFalse);
      expect(isPseudoLocalized('only closing⟧'), isFalse);
    });

    test('an empty string is left alone', () {
      expect(pseudoLocalize(''), '');
    });
  });

  group('inflation', () {
    test('makes the string meaningfully longer', () {
      const original = 'Bugün dönüşümünün ilk günü';
      final out = pseudoLocalize(original);
      expect(out.length, greaterThan(original.length * 1.3));
    });

    test('inflation scales with the original length', () {
      final short = pseudoLocalize('Aç');
      final long =
          pseudoLocalize('Antrenmanın hakkında bana soru sorabilirsin');
      expect(long.length, greaterThan(short.length));
    });

    test('padding uses non-ASCII so glyph coverage is exercised too', () {
      final out = pseudoLocalize('Test');
      expect(RegExp(r'[ëẍţñd]').hasMatch(out), isTrue);
    });
  });

  group('ICU placeholders survive', () {
    test('a placeholder is copied verbatim', () {
      final out = pseudoLocalize('{count} gün');
      expect(out, contains('{count}'));
    });

    test('multiple placeholders all survive', () {
      final out = pseudoLocalize('{name}, {count} tekrar yaptın');
      expect(out, contains('{name}'));
      expect(out, contains('{count}'));
    });

    test('placeholder characters are not padded into', () {
      // Inflating inside the braces would break ICU at runtime and make
      // pseudo mode look like the bug.
      final out = pseudoLocalize('{count}');
      expect(out, contains('{count}'));
      expect(RegExp(r'\{[^}]*[ëẍţ][^}]*\}').hasMatch(out), isFalse);
    });

    test('an unclosed brace does not swallow the rest of the string', () {
      final out = pseudoLocalize('bozuk {count gün');
      expect(out, contains('gün'));
    });

    test('a placeholder-only string still gets bracketed', () {
      expect(isPseudoLocalized(pseudoLocalize('{count}')), isTrue);
    });
  });

  group('the inflation constant', () {
    test('is at least the German/Turkish length ratio', () {
      // German runs ~35% longer; anything below that would let real
      // overflow through.
      expect(kPseudoInflation, greaterThanOrEqualTo(0.35));
    });
  });
}
