import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/domain/framing_validator.dart';
import 'package:sixpack_ai/features/workout/presentation/framing_hint.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · these two tests moved here with the copy they guard,
/// from framing_validator_test.dart. The invariants are unchanged; only
/// the layer they live in and the Localizations scope they need are new.
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
  group('hints', () {
    testWidgets(
        'every issue has non-empty guidance in every supported locale — '
        'a state with no copy would leave the user stuck', (tester) async {
      // The original test ran over FramingIssue.values against a single
      // hardcoded Turkish getter. Now that the copy is translated, the
      // gap that actually ships is a key some locale forgot, so the loop
      // covers locales too.
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await _l10n(tester, locale);
        for (final issue in FramingIssue.values) {
          expect(
            issue.hint(l10n).trim(),
            isNotEmpty,
            reason: '${issue.name} in ${locale.languageCode}',
          );
        }
      }
    });

    testWidgets('guidance instructs the setup rather than judging the user',
        (tester) async {
      // "biraz geri git" (move back a bit), not "you are too close".
      // Asserted per-locale because this is a translation instruction as
      // much as a copy rule: a translator who renders it as a verdict on
      // the user has broken the feature, not just the tone.
      final tr = await _l10n(tester, const Locale('tr'));
      expect(FramingIssue.tooClose.hint(tr), contains('geri git'));

      final en = await _l10n(tester, const Locale('en'));
      expect(FramingIssue.tooClose.hint(en), contains('Step back'));
    });

    testWidgets('every issue maps to a distinct line except the ready state',
        (tester) async {
      // Two issues sharing a string would silently tell a user to fix
      // the wrong thing — the hint is the only feedback they get.
      final l10n = await _l10n(tester, const Locale('tr'));
      final problems = FramingIssue.values
          .where((i) => i != FramingIssue.none)
          .map((i) => i.hint(l10n))
          .toList();
      expect(problems.toSet(), hasLength(problems.length));
    });
  });
}
