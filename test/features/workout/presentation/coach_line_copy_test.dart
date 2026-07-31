import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/domain/coach_line.dart';
import 'package:sixpack_ai/features/workout/presentation/coach_line_copy.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · the analyzers now return a [CoachLine] verdict and
/// this extension is the only thing that turns one into words.
///
/// That makes it a single point of failure for the voice coach: a line
/// with missing or empty copy doesn't crash, it just goes silent. The
/// user hears nothing, the screen looks fine, and the feature they were
/// sold quietly stops working. These tests exist for that failure mode.
Future<AppLocalizations> _l10n(WidgetTester tester, Locale locale) async {
  late AppLocalizations found;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Builder(builder: (context) {
      found = AppLocalizations.of(context);
      return const SizedBox.shrink();
    }),
  ));
  return found;
}

void main() {
  testWidgets('every CoachLine has non-empty copy in every supported locale',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await _l10n(tester, locale);
      for (final line in CoachLine.values) {
        expect(
          line.text(l10n).trim(),
          isNotEmpty,
          reason: '${line.name} in ${locale.languageCode}',
        );
      }
    }
  });

  testWidgets(
      'no two lines share wording — a collision would coach the '
      'wrong fix', (tester) async {
    // Two faults resolving to one sentence means the user hears "keep
    // your hips level" for a neck problem. The analyzers can tell these
    // apart; the copy layer must not throw that away.
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await _l10n(tester, locale);
      final rendered = CoachLine.values.map((l) => l.text(l10n)).toList();
      expect(
        rendered.toSet(),
        hasLength(rendered.length),
        reason: 'duplicate coach copy in ${locale.languageCode}',
      );
    }
  });

  testWidgets('lines stay short enough to be spoken mid-rep', (tester) async {
    // These are read aloud while the user is under load. A long sentence
    // is still being spoken when the moment it describes has passed, and
    // the coach ends up narrating the previous rep.
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await _l10n(tester, locale);
      for (final line in CoachLine.values) {
        expect(
          line.text(l10n).split(RegExp(r'\s+')).length,
          lessThanOrEqualTo(9),
          reason: '${line.name} in ${locale.languageCode} is too long to '
              'land before the rep is over',
        );
      }
    }
  });
}
