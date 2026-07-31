import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/notification_service.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · notification copy moved to ARB.
///
/// Notifications are the one surface composed with no widget tree: the
/// workout repository and the smart-reminder scheduler both schedule
/// from far outside any BuildContext. The service therefore loads its
/// own [AppLocalizations] from [NotificationService.copyLocale], and
/// these tests pin the two things that can silently break as a result —
/// that loading works without a tree at all, and that the locale the
/// app resolves is the locale the service is actually told.
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

  test('copyLocale defaults to Turkish', () {
    // The default matters: it is what a notification scheduled before
    // the first frame is written in.
    expect(NotificationService.copyLocale, const Locale('tr'));
  });
}
