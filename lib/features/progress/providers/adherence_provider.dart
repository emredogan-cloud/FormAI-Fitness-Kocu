import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../onboarding/domain/ai_personalization_engine.dart';
import '../../workout/data/session_log_repository.dart';
import '../domain/trend_calculator.dart';
import 'streak_provider.dart';

/// Roadmap Phase 9 (C3) · how reliably the user turns up.
///
/// **Completed is measured, planned is promised.** The completed count
/// comes from real session-log timestamps — the workout pipeline's own
/// ground truth — bucketed by calendar date. The planned count comes
/// from `weeklyWorkoutCountFor`, the cadence the onboarding report told
/// this user they would train at. Dividing the second into the first is
/// the only honest reading of "adherence": it measures the app's promise
/// against reality, rather than inventing a target after the fact.
///
/// It deliberately does NOT use the 30-day program's day numbers. Those
/// are a sequence, not a schedule — the calendar screen anchors day 1 at
/// "today minus however far you have got", which makes every completed
/// day land on a day it was planned for and every adherence figure
/// exactly 100 %. A number that cannot be anything but perfect is not a
/// measurement.
///
/// **A window that planned nothing yields null, never zero.** A user
/// three days into their install has not missed twelve sessions, and a
/// rest week is not a 0 % week. Rendering either as a failure invents
/// one out of the program's own design, which is the specific thing the
/// roadmap's emotional-safety requirement forbids.
final adherenceProvider = Provider<AdherenceSummary>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final logs = ref.watch(sessionLogsProvider).value;
  final currentStreak = ref.watch(currentStreakProvider);

  final perWeek = weeklyWorkoutCountFor(
    prefs.userMetrics?['experienceLevel'] as String?,
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Monday-anchored, matching the calendar header's weekday row. The
  // week the user is in, not a trailing seven days: "this week" has to
  // mean the same thing on the card as it does in their head.
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  // How much of each window this install has actually existed for. The
  // guard that stops a three-day-old account reading as 8 % adherent.
  final observedDays = prefs.daysSinceInstall + 1;

  final completions = <DateTime>{};
  for (final log in (logs ?? const {}).values) {
    final at = DateTime.tryParse(log.completedAtIso);
    if (at == null) continue;
    completions.add(DateTime(at.year, at.month, at.day));
  }

  int completedSince(DateTime from) =>
      completions.where((day) => !day.isBefore(from)).length;

  /// Sessions the cadence implies over [windowDays], clipped to the days
  /// this install has been observed for. Null when that is none.
  int? plannedOver(int windowDays) {
    final days = windowDays < observedDays ? windowDays : observedDays;
    if (days <= 0) return null;
    final planned = (perWeek * days / 7).round();
    return planned <= 0 ? null : planned;
  }

  double? ratio(int completed, int? planned) {
    if (planned == null) return null;
    // Clamped at 1: someone who trained six times against a plan of four
    // is not 150 % adherent, they simply did everything asked. An
    // uncapped figure would also render as "%150" on a card whose whole
    // job is to be readable at a glance.
    final value = completed / planned;
    return value > 1 ? 1 : value;
  }

  final weekDaysElapsed = today.difference(weekStart).inDays + 1;
  final weekPlanned = plannedOver(weekDaysElapsed);
  final weekCompleted = completedSince(weekStart);

  const thirtyDays = 30;
  final thirtyPlanned = plannedOver(thirtyDays);
  final thirtyCompleted =
      completedSince(today.subtract(const Duration(days: thirtyDays - 1)));

  return AdherenceSummary(
    plannedSessions: thirtyPlanned ?? 0,
    completedSessions: thirtyCompleted,
    weeklyConsistency: ratio(weekCompleted, weekPlanned),
    rollingThirtyDay: ratio(thirtyCompleted, thirtyPlanned),
    // `maxStreak` is a high-water mark bumped on completion, so a streak
    // still running has not been recorded into it yet.
    longestStreak:
        prefs.maxStreak > currentStreak ? prefs.maxStreak : currentStreak,
    currentStreak: currentStreak,
  );
});

/// The sessions planned and completed in the current week, for the
/// card's "3 of 4" line. Separate from the 30-day figures on the summary
/// because the card shows both and they are different windows.
final weeklySessionCountsProvider =
    Provider<({int completed, int? planned})>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final logs = ref.watch(sessionLogsProvider).value;
  final perWeek = weeklyWorkoutCountFor(
    prefs.userMetrics?['experienceLevel'] as String?,
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final observedDays = prefs.daysSinceInstall + 1;
  final elapsed = today.difference(weekStart).inDays + 1;
  final days = elapsed < observedDays ? elapsed : observedDays;

  var completed = 0;
  final seen = <DateTime>{};
  for (final log in (logs ?? const {}).values) {
    final at = DateTime.tryParse(log.completedAtIso);
    if (at == null) continue;
    final day = DateTime(at.year, at.month, at.day);
    if (day.isBefore(weekStart)) continue;
    if (seen.add(day)) completed++;
  }

  final planned = days <= 0 ? null : (perWeek * days / 7).round();
  return (completed: completed, planned: (planned ?? 0) <= 0 ? null : planned);
});
