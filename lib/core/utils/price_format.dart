/// Phase 6 polish · rescaling a store-formatted price without lying
/// about the locale it came from.
///
/// The paywall never formats a price itself. Every number a user sees is
/// [StoreProduct.priceString] verbatim — the store already formatted it
/// for the billing country, and second-guessing that is how an app ends
/// up showing a price it will not charge.
///
/// One number on that screen is not a store price: the struck-through
/// "monthly equivalent" on the annual card, which is `12 × the monthly
/// price`. It has to be *derived*, and it has to look like it belongs
/// next to the real one.
///
/// The previous implementation hardcoded Turkish conventions — "." for
/// thousands, "," for decimals — and its own doc comment admitted it was
/// only accidentally right for a `$` price. It was not: a US user saw
/// `$9.99` on the monthly card and `$119,88` struck through on the
/// annual one. Same screen, two number systems, and the wrong one is the
/// one framing the discount.
///
/// So the separators are read *off the store's own string* rather than
/// assumed. Whatever conventions the store used for the real price are
/// the conventions the derived one inherits, which is correct in every
/// locale by construction and cannot drift as markets are added.
library;

/// Digits, the two separator characters, and the space variants locales
/// actually group with — ASCII space, NBSP (fr-FR), narrow NBSP (fr-CA).
const String _kSpaces = '   ';

/// The store's number, sliced out of its currency chrome: first digit to
/// last digit, so a trailing " €" stays in the suffix instead of
/// being swallowed as grouping.
final RegExp _kNumberBody = RegExp('[0-9][0-9.,$_kSpaces]*[0-9]|[0-9]');

/// How a particular store string writes numbers.
class _NumberStyle {
  const _NumberStyle({
    required this.decimalSeparator,
    required this.decimalDigits,
    required this.groupSeparator,
  });

  /// Empty when the store wrote no fractional part at all (¥1,200,
  /// Rp 149.000).
  final String decimalSeparator;
  final int decimalDigits;

  /// Empty when the store does not group — either because the amount was
  /// too small to show grouping *and* we could not infer it, or because
  /// the store genuinely writes 4+ digits ungrouped.
  final String groupSeparator;
}

/// Reads [body] — a bare number as the store wrote it — and works out
/// which character is the decimal point, how many fraction digits it
/// carries, and which character groups the thousands.
///
/// The decimal separator is the last "." or "," followed by one or two
/// digits and nothing else. Three digits after a separator is grouping,
/// never a fraction: no currency bills to a thousandth, and `Rp 149.000`
/// is a hundred and forty-nine thousand rupiah.
_NumberStyle _styleOf(String body) {
  final lastDot = body.lastIndexOf('.');
  final lastComma = body.lastIndexOf(',');
  final lastSep = lastDot > lastComma ? lastDot : lastComma;

  var decimalSeparator = '';
  var decimalDigits = 0;
  var integerEnd = body.length;
  if (lastSep >= 0) {
    final tail = body.substring(lastSep + 1);
    if (tail.length <= 2 && RegExp(r'^[0-9]+$').hasMatch(tail)) {
      decimalSeparator = body[lastSep];
      decimalDigits = tail.length;
      integerEnd = lastSep;
    }
  }

  // Grouping, in order of confidence: what the store actually used in
  // this string, else the conventional partner of the decimal separator.
  final integerPart = body.substring(0, integerEnd);
  final used = RegExp('[.,$_kSpaces]').firstMatch(integerPart);
  final String groupSeparator;
  if (used != null) {
    groupSeparator = used[0]!;
  } else if (integerPart.length >= 4) {
    // The store had the chance to group and did not. Believe it.
    groupSeparator = '';
  } else {
    groupSeparator = switch (decimalSeparator) {
      ',' => '.',
      '.' => ',',
      _ => '',
    };
  }

  return _NumberStyle(
    decimalSeparator: decimalSeparator,
    decimalDigits: decimalDigits,
    groupSeparator: groupSeparator,
  );
}

/// Renders [amount] in the number system [source] is written in, keeping
/// [source]'s currency chrome exactly where it was.
///
/// `("₺179,99", 2159.88)` → `"₺2.159,88"`
/// `("\$9.99", 119.88)`   → `"\$119.88"`
/// `("9,99 €", 119.88)` → `"119,88 €"`
///
/// Returns null when [source] carries no parseable amount, so the caller
/// omits the strikethrough rather than fabricating one. That null is
/// load-bearing: a price we cannot read is not a price we may re-state.
String? scaleStorePrice(String? source, double amount) {
  if (source == null || source.isEmpty) return null;
  final match = _kNumberBody.firstMatch(source);
  if (match == null) return null;

  final prefix = source.substring(0, match.start);
  final suffix = source.substring(match.end);
  final style = _styleOf(match[0]!);

  final fixed = amount.toStringAsFixed(style.decimalDigits);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  final decPart = dot < 0 ? '' : fixed.substring(dot + 1);

  final out = StringBuffer(prefix);
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 &&
        style.groupSeparator.isNotEmpty &&
        (intPart.length - i) % 3 == 0) {
      out.write(style.groupSeparator);
    }
    out.write(intPart[i]);
  }
  if (decPart.isNotEmpty) out.write('${style.decimalSeparator}$decPart');
  out.write(suffix);
  return out.toString();
}
