import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The badge strip under the Gelişim tab renders each label in an 82 px
/// column. It used to wrap the label in a `FittedBox`, which lays its
/// child out unbounded — so the text never wrapped AND never shrank, and
/// "30 Gün Şampiyonu" rendered as "30 Gün Şampiy", clipped mid-word.
/// Found on a device.
///
/// The widget is private, so what is asserted here is the property that
/// made the bug possible: every badge label has to fit two lines at the
/// strip's chip width and font size. If a future label is long enough
/// to need three, this fails before anyone sees it truncated.
///
/// The measurement uses the test font, whose glyphs are wider than the
/// real one — so passing here is a stricter bar than the device needs,
/// which is the direction to err in.

/// Mirrors `_HexBadge`'s `SizedBox(width:)`.
const double _stripChipWidth = 100;
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every badge-strip label fits two lines in its column',
      (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr')],
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final labels = <String>[
      l10n.badgeStripFirstWeek,
      l10n.badgeStripDisciplined,
      l10n.badgeStripCalorieHunter,
      l10n.badgeStripThirtyDayChampion,
      l10n.badgeStripHiitMaster,
    ];

    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: _stripChipWidth);

      expect(
        painter.didExceedMaxLines,
        isFalse,
        reason: '"$label" needs more than two lines under the hex badge',
      );
    }
  });
}
