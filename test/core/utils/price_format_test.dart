import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/price_format.dart';

/// The struck-through "monthly equivalent" on the paywall's annual card
/// is the one number on that screen the store did not format for us. It
/// sits directly beside a real store price, so if it uses a different
/// number system the discount it frames reads as a typo — or worse, as
/// a different currency.
///
/// The regression these tests exist for: the previous implementation
/// hardcoded Turkish separators, so a US user saw `$9.99` on the monthly
/// card and `$119,88` struck through on the annual one.
void main() {
  group('scaleStorePrice · the locale it came from is the locale it stays in',
      () {
    test('tr-TR — comma decimals, dot grouping', () {
      expect(scaleStorePrice('₺179,99', 2159.88), '₺2.159,88');
    });

    test('en-US — dot decimals, comma grouping (the regression)', () {
      expect(scaleStorePrice(r'$9.99', 119.88), r'$119.88');
      expect(scaleStorePrice(r'$99.99', 1199.88), r'$1,199.88');
    });

    test('the founder pricing target renders correctly in both markets', () {
      // ₺400/mo × 12 = ₺4.800,00 struck through beside a ₺1.200,00 annual.
      expect(scaleStorePrice('₺400,00', 4800), '₺4.800,00');
      // $10.00/mo × 12 = $120.00 struck through beside a $50.00 annual.
      expect(scaleStorePrice(r'$10.00', 120), r'$120.00');
    });

    test('suffix currencies keep their spacing and their symbol', () {
      // de-DE. The old regex swallowed the trailing space into the
      // number body, which glued the symbol onto the digits.
      expect(scaleStorePrice('9,99 €', 119.88), '119,88 €');
    });

    test('a non-breaking space groups where the store grouped with one', () {
      // fr-FR writes 1 234,56 € with U+00A0.
      expect(scaleStorePrice('1 234,56 €', 14814.72), '14 814,72 €');
    });

    test('zero-decimal currencies stay zero-decimal', () {
      // ja-JP. Three digits after a separator is grouping, never a
      // fraction — ¥1,200 is twelve hundred yen, not 1.2 yen.
      expect(scaleStorePrice('¥1,200', 14400), '¥14,400');
      // id-ID groups with dots and bills whole rupiah.
      expect(scaleStorePrice('Rp 149.000', 1788000), 'Rp 1.788.000');
    });

    test('a store that does not group is not taught to', () {
      // 4+ integer digits written flat is the store telling us it does
      // not group. Inventing a separator would not match the card above.
      expect(scaleStorePrice('₺1200,00', 14400), '₺14400,00');
    });

    test('multi-character prefixes survive intact', () {
      expect(scaleStorePrice(r'US$ 9.99', 119.88), r'US$ 119.88');
      expect(scaleStorePrice(r'BR$ 1.999,99', 23999.88), r'BR$ 23.999,88');
    });

    test('an unreadable price yields null, never a guess', () {
      expect(scaleStorePrice(null, 100), isNull);
      expect(scaleStorePrice('', 100), isNull);
      // No digits at all — e.g. a store that returned a placeholder.
      expect(scaleStorePrice('Free', 100), isNull);
    });

    test('single-digit prices infer the conventional partner separator', () {
      // Nothing in "₺9,99" shows how this locale groups thousands, so
      // the decimal separator picks its conventional partner.
      expect(scaleStorePrice('₺9,99', 1199.88), '₺1.199,88');
      expect(scaleStorePrice(r'$9.99', 1199.88), r'$1,199.88');
    });

    test('one-decimal and three-decimal-looking sources are read correctly',
        () {
      // One fraction digit is still a fraction.
      expect(scaleStorePrice('9,9', 118.8), '118,8');
      // Three digits after the separator is grouping. 1.234 is a
      // thousand two hundred thirty-four, so the result has no decimals.
      expect(scaleStorePrice('1.234', 14808), '14.808');
    });

    test('scaling preserves the source decimal count, not a hardcoded 2', () {
      // ¥ has none; the result must not sprout ",00" or ".00".
      expect(scaleStorePrice('¥500', 6000), '¥6000');
    });

    test('no separator anywhere means no separator invented', () {
      // "¥500" is the one input that carries zero locale signal: no
      // decimal separator to take a conventional partner from, and too
      // few integer digits to have shown grouping. Guessing "," would
      // print ¥6,000 in a market that writes ¥6.000 — a wrong separator
      // beside a right one reads worse than no separator at all. So the
      // rule from the null return holds here too: state nothing we
      // cannot read off the store.
      expect(scaleStorePrice('¥500', 6000), '¥6000');
      // Give it one grouped example and it groups the same way.
      expect(scaleStorePrice('¥1.500', 18000), '¥18.000');
      expect(scaleStorePrice('¥1,500', 18000), '¥18,000');
    });
  });
}
