import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/presentation/badge_copy.dart';
import 'package:sixpack_ai/features/progress/providers/badge_unlocks_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · badge copy moved out of the const catalogue.
///
/// [BadgeCopy] switches on a String ID rather than an enum, because
/// badge IDs are persisted and keyed on by the XP calculator — turning
/// them into an enum for compile-time exhaustiveness would drag a
/// storage migration into a copy extraction. This file buys the same
/// guarantee at test time: a badge cannot ship without words.
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
  testWidgets('every badge has a title and an unlock line in every locale',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await _l10n(tester, locale);
      for (final badge in kBadgeCatalog) {
        // The fallback in BadgeCopy returns the raw ID rather than
        // throwing, so an unmapped badge shows as its own token instead
        // of crashing the celebration. That is a deliberate soft
        // failure — this assertion is what stops it reaching a user.
        expect(badge.title(l10n), isNot(badge.id),
            reason: '${badge.id} has no title in ${locale.languageCode}');
        expect(badge.unlockMessage(l10n), isNot(badge.id),
            reason: '${badge.id} has no unlock line in '
                '${locale.languageCode}');
        expect(badge.title(l10n).trim(), isNotEmpty);
        expect(badge.unlockMessage(l10n).trim(), isNotEmpty);
      }
    }
  });

  testWidgets('no two badges share a title', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await _l10n(tester, locale);
      final titles = kBadgeCatalog.map((b) => b.title(l10n)).toList();
      expect(titles.toSet(), hasLength(titles.length),
          reason: 'duplicate badge title in ${locale.languageCode}');
    }
  });

  testWidgets('the unlock line differs from the gallery goal line',
      (tester) async {
    // The gallery states the goal ("finish your first day"), the
    // celebration states the achievement ("you finished your first
    // day!"). Collapsing them would make the reward read like the task.
    final l10n = await _l10n(tester, const Locale('tr'));
    final firstStep = badgeById('first_step')!;
    expect(firstStep.unlockMessage(l10n), isNot(l10n.badgeFirstStepDesc));
  });
}
