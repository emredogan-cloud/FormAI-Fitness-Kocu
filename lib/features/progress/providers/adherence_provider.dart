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
/// **Two guards stop it inventing a failure**, and the roadmap's
/// emotional-safety requirement is why both exist:
///
///   * The week is a count, not a percentage. One of four on a Tuesday
///     is not 25 % of anything yet.
///   * The thirty-day percentage waits for a week of history. Below
///     that it is an artefact of which weekday somebody installed on.
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

  // How much history this install actually has.
  final observedDays = prefs.daysSinceInstall + 1;

  final completions = <DateTime>{};
  for (final log in (logs ?? const {}).values) {
    final at = DateTime.tryParse(log.completedAtIso);
    if (at == null) continue;
    completions.add(DateTime(at.year, at.month, at.day));
  }

  int completedSince(DateTime from) =>
      completions.where((day) => !day.isBefore(from)).length;

  const window = 30;
  final thirtyCompleted =
      completedSince(today.subtract(const Duration(days: window - 1)));

  double? thirtyDayFraction() {
    if (observedDays < kAdherenceMinObservedDays) return null;
    final days = observedDays < window ? observedDays : window;
    final planned = (perWeek * days / 7).round();
    if (planned <= 0) return null;
    // Clamped at 1: someone who trained six times against a plan of four
    // is not 150 % adherent, they simply did everything asked — and
    // "%150" on a card whose job is to be readable at a glance is not.
    final value = thirtyCompleted / planned;
    return value > 1 ? 1 : value;
  }

  return AdherenceSummary(
    weekCompleted: completedSince(weekStart),
    // The whole week's cadence, never prorated to the days elapsed. A
    // Tuesday does not shrink the week's plan; it just has not finished
    // it yet.
    weekPlanned: observedDays <= 0 ? null : perWeek,
    rollingThirtyDay: thirtyDayFraction(),
    // `maxStreak` is a high-water mark bumped on completion, so a streak
    // still running has not been recorded into it yet.
    longestStreak:
        prefs.maxStreak > currentStreak ? prefs.maxStreak : currentStreak,
    currentStreak: currentStreak,
  );
});
