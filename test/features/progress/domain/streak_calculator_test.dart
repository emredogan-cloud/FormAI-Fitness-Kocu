import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/domain/streak_calculator.dart';

void main() {
  // Fixed "now": a Thursday noon, local time.
  final now = DateTime(2026, 7, 9, 12, 0);
  DateTime daysAgo(int n, {int hour = 18}) =>
      DateTime(2026, 7, 9 - n, hour, 30);

  group('calendarStreak · basics', () {
    test('no completions → 0', () {
      expect(calendarStreak(const [], now: now), 0);
    });

    test('single workout today → 1', () {
      expect(calendarStreak([daysAgo(0)], now: now), 1);
    });

    test(
        'several workouts the same day collapse to one streak day '
        '(the old program-run counter called one afternoon of catch-up '
        'a multi-day streak)', () {
      expect(
        calendarStreak(
          [daysAgo(0, hour: 9), daysAgo(0, hour: 14), daysAgo(0, hour: 20)],
          now: now,
        ),
        1,
      );
    });

    test('5 consecutive days → 5 (the old counter could never exceed 3)', () {
      expect(
        calendarStreak(
          [for (var i = 0; i < 5; i++) daysAgo(i)],
          now: now,
        ),
        5,
      );
    });

    test(
        '7 consecutive days → 7, so the ≥7 badges/XP milestones are '
        'reachable again', () {
      expect(
        calendarStreak(
          [for (var i = 0; i < 7; i++) daysAgo(i)],
          now: now,
        ),
        7,
      );
    });
  });

  group('calendarStreak · rest-day tolerance', () {
    test('T T T · T (one rest day inside the run) → 4', () {
      // Trained 0,1,2 days ago, rested 3 days ago, trained 4 days ago.
      expect(
        calendarStreak(
          [daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(4)],
          now: now,
        ),
        4,
      );
    });

    test(
        'the 3+1 program cadence chains across weeks: '
        'T T T · T T T · T → 7', () {
      // Gaps of exactly one day at positions 3 and 7.
      final dates = [
        daysAgo(0), daysAgo(1), daysAgo(2), // block 1
        daysAgo(4), daysAgo(5), daysAgo(6), // block 2 (rest at 3)
        daysAgo(8), // block 3 (rest at 7)
      ];
      expect(calendarStreak(dates, now: now), 7);
    });

    test('two consecutive missed days break the run: T T · · T → 2', () {
      expect(
        calendarStreak(
          [daysAgo(0), daysAgo(1), daysAgo(4), daysAgo(5)],
          now: now,
        ),
        2,
      );
    });
  });

  group('calendarStreak · trailing edge', () {
    test('last workout yesterday, today pending → streak alive', () {
      expect(
        calendarStreak([daysAgo(1), daysAgo(2)], now: now),
        2,
      );
    });

    test(
        'last workout 2 days ago (yesterday = rest, today pending) '
        '→ still alive', () {
      expect(
        calendarStreak([daysAgo(2), daysAgo(3)], now: now),
        2,
      );
    });

    test('last workout 3 days ago → dead (0)', () {
      expect(
        calendarStreak([daysAgo(3), daysAgo(4), daysAgo(5)], now: now),
        0,
      );
    });

    test(
        'slightly future-dated completion (device clock skew) does not '
        'crash or kill the streak', () {
      expect(
        calendarStreak([now.add(const Duration(hours: 5)), daysAgo(1)],
            now: now),
        2,
      );
    });
  });

  group('calendarStreak · timezone/DST safety', () {
    test('dates provided as UTC instants normalize to local days', () {
      // 2026-07-08 22:30 UTC == 2026-07-09 01:30 TR (UTC+3): counts as
      // "today" in local terms.
      final utcLateYesterday = DateTime.utc(2026, 7, 8, 22, 30);
      final streak = calendarStreak([utcLateYesterday], now: now);
      // Whatever the host zone, the value must be a live 1 (the
      // instant is within the last day), never 0.
      expect(streak, 1);
    });
  });
}
