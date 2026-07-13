/// Real, calendar-day workout streak.
///
/// The previous "streak" counted the leading run of completed PROGRAM
/// days (day 1, day 2, …) — because every 4th program day is a rest
/// day that can never be completed, it structurally capped at 3, was
/// not time-based (7 completions in one afternoon = "7 gün seri"), and
/// made every ≥7 streak badge/XP milestone unreachable.
///
/// This implementation counts actual calendar days with at least one
/// completed workout, walking back from today:
///
///   • Same-day duplicates collapse (two workouts today = 1 day).
///   • A single missed calendar day between active days is TOLERATED —
///     the generated program prescribes a rest day every 4th day, and
///     a daily streak that dies on the program's own rest day would
///     cap at 3 all over again. Two or more consecutive missed days
///     break the run.
///   • The same tolerance applies at the tail: the streak survives
///     "yesterday was my rest day and today isn't over yet" (last
///     activity ≤ 2 days ago) and dies on the third empty day.
///
/// Examples (T = trained, · = rest):  T T T · T  → 5-day streak.
/// T T · · T → the two-day gap breaks it → streak restarts at the
/// last T.
int calendarStreak(Iterable<DateTime> completions, {required DateTime now}) {
  // Normalize to date-only in UTC space so day arithmetic is exact
  // 24h units — local-midnight DateTimes differ by 23/25h across DST
  // transitions and `inDays` would truncate a 23h day to 0.
  final days = completions.map(_dateOnly).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  if (days.isEmpty) return 0;

  final today = _dateOnly(now);
  final tailGap = today.difference(days.first).inDays;
  // Future-dated logs (clock changes) shouldn't kill the streak; treat
  // them as "today".
  if (tailGap >= 3) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    final gap = days[i - 1].difference(days[i]).inDays;
    // gap == 1 → consecutive days; gap == 2 → exactly one missed day
    // in between (the tolerated rest day); gap ≥ 3 → run broken.
    if (gap <= 2) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

DateTime _dateOnly(DateTime d) {
  final local = d.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}
