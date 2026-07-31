import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/app_copy.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · notification copy moved to ARB.
///
/// Notifications are the one surface composed with no widget tree: the
/// workout repository and the smart-reminder scheduler both schedule
/// from far outside any BuildContext. The service therefore loads its
/// own [AppLocalizations] through [AppCopy], and these tests pin the two
/// things that can silently break as a result — that loading works
/// without a tree at all, and that the locale the app resolves is the
/// locale those surfaces are actually told.
void main() {
  test('copy loads with no widget tree, in every supported locale', () async {
    // If this ever throws, every scheduled notification silently stops:
    // the schedule call is wrapped in try/catch by design so a platform
    // quirk cannot take down a workout completion.
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.notifTrainTimeTitle.trim(), isNotEmpty);
      expect(l10n.notifChannelDailyName.trim(), isNotEmpty);
      expect(l10n.notifStreakAtRiskBody.trim(), isNotEmpty);
    }
  });

  test('every reminder variant has a distinct title within its pool', () async {
    // The pools exist so two consecutive days never show identical
    // copy. A duplicate inside a pool silently defeats that.
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    final pools = <String, List<String>>{
      'noWorkout': [
        l10n.notifTrainTimeTitle,
        l10n.notifTodaysWorkoutWaitsTitle,
        l10n.notifYouHaveAGoalTitle,
      ],
      'workoutNoFood': [
        l10n.notifFuelNeededTitle,
        l10n.notifRecoveryTimeTitle,
      ],
      'bothDone': [
        l10n.notifConqueredTheDayTitle,
        l10n.notifPerfectDayTitle,
        l10n.notifKeepGoingTitle,
      ],
      'streak': [
        l10n.notifStreakAtRiskTitle,
        l10n.notifTimeToComeBackTitle,
      ],
    };
    pools.forEach((name, titles) {
      expect(titles.toSet(), hasLength(titles.length), reason: name);
    });
  });

  test('AppCopy.locale defaults to Turkish', () {
    // The default matters: it is what a notification scheduled before
    // the first frame is written in.
    expect(AppCopy.locale, const Locale('tr'));
  });

  test('AppCopy.load resolves copy for the locale it is set to', () async {
    // The whole point of the indirection: main.dart assigns this once
    // and every tree-less surface follows. If load() ignored it, the
    // home widget and notifications would silently keep speaking the
    // previous language.
    final original = AppCopy.locale;
    addTearDown(() => AppCopy.locale = original);
    for (final locale in AppLocalizations.supportedLocales) {
      AppCopy.locale = locale;
      final copy = await AppCopy.load();
      expect(copy.localeName, locale.languageCode);
    }
  });
}
