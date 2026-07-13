import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../workout/data/session_log_repository.dart';
import '../domain/streak_calculator.dart';

/// Single source of truth for the user's live workout streak.
///
/// Replaces the nine copy-pasted `_streakOf(List<WorkoutDay>)` helpers
/// that counted the leading run of completed program days (structurally
/// capped at 3 by the every-4th-day rest slot — audit P1-1). Derives a
/// real calendar-day streak from:
///
///   • [sessionLogsProvider] — one timestamped log per completed
///     program day (the authoritative history), and
///   • [AppPreferences.lastWorkoutAt] — stamped on EVERY completion
///     including ad-hoc plan workouts, which have no program-day log,
///     so training "off plan" today still keeps the flame alive.
///
/// Loading state reads as 0 — every consumer treated missing data as
/// streak-0 before, so the fallback is behavior-compatible.
final currentStreakProvider = Provider<int>((ref) {
  final logs = ref.watch(sessionLogsProvider).value;
  final lastWorkoutAt = ref.watch(appPreferencesProvider).lastWorkoutAt;

  final dates = <DateTime>[
    if (logs != null)
      for (final log in logs.values)
        if (DateTime.tryParse(log.completedAtIso) != null)
          DateTime.parse(log.completedAtIso),
    if (lastWorkoutAt != null) lastWorkoutAt,
  ];
  if (dates.isEmpty) return 0;
  return calendarStreak(dates, now: DateTime.now());
});
