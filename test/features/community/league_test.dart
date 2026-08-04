import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/domain/league.dart';

/// Roadmap Phase 13 (C23 · R6) · the rules that keep a leaderboard from
/// being cruel, and the two numbers that must agree with the database.
void main() {
  group('the caps agree with the database', () {
    // The Dart constants are what the UI explains to a user; the SQL is
    // what actually rejects a write. A disagreement means the app
    // promises something the server refuses, and the user sees an error
    // they cannot act on. This test is the only thing holding the two
    // copies together.
    final sql =
        File('supabase/migrations/020_leaderboards.sql').readAsStringSync();

    test('the weekly XP ceiling is the same number in both', () {
      expect(kWeeklyXpCap, 3500);
      expect(sql, contains('weekly_xp <= $kWeeklyXpCap'));
    });

    test('the daily jump limit is the same number in both', () {
      expect(kDailyXpCap, 500);
      expect(sql, contains('old.weekly_xp + $kDailyXpCap'));
    });

    test('the session ceiling is the same number in both', () {
      expect(sql, contains('sessions <= $kMaxWeeklySessions'));
    });
  });

  group('promotion and relegation', () {
    test('the top five go up', () {
      for (var rank = 1; rank <= kPromotionSlots; rank++) {
        expect(
          outcomeFor(tier: LeagueTier.silver, rank: rank, size: kLeagueSize),
          LeagueOutcome.promoted,
        );
      }
    });

    test('the bottom five go down', () {
      for (var rank = kLeagueSize - kRelegationSlots + 1;
          rank <= kLeagueSize;
          rank++) {
        expect(
          outcomeFor(tier: LeagueTier.silver, rank: rank, size: kLeagueSize),
          LeagueOutcome.relegated,
        );
      }
    });

    test('the middle is the largest group and nothing happens to it', () {
      final held = [
        for (var rank = 1; rank <= kLeagueSize; rank++)
          if (outcomeFor(
                tier: LeagueTier.silver,
                rank: rank,
                size: kLeagueSize,
              ) ==
              LeagueOutcome.held)
            rank,
      ];
      expect(held.length, greaterThan(kPromotionSlots + kRelegationSlots));
    });

    test('bronze has nowhere to fall', () {
      // Reporting "relegated" and leaving somebody in Bronze is a
      // message that contradicts what they can see.
      expect(
        outcomeFor(tier: LeagueTier.bronze, rank: 30, size: 30),
        LeagueOutcome.held,
      );
      expect(tierAfter(LeagueTier.bronze, LeagueOutcome.relegated),
          LeagueTier.bronze);
    });

    test('diamond has nowhere to climb', () {
      expect(
        outcomeFor(tier: LeagueTier.diamond, rank: 1, size: 30),
        LeagueOutcome.held,
      );
      expect(tierAfter(LeagueTier.diamond, LeagueOutcome.promoted),
          LeagueTier.diamond);
    });

    test('a league of one is not a competition', () {
      // The common case early in the app's life. Promoting somebody for
      // being alone makes the tier mean nothing on the day it matters.
      expect(
        outcomeFor(tier: LeagueTier.bronze, rank: 1, size: 1),
        LeagueOutcome.held,
      );
    });

    test('an unknown tier is null, never bronze', () {
      // Showing Bronze because we did not recognise a newer server's
      // tier would be inventing a demotion.
      expect(LeagueTier.fromToken('emerald'), isNull);
      expect(LeagueTier.fromToken(null), isNull);
      expect(LeagueTier.fromToken('gold'), LeagueTier.gold);
    });
  });

  group('weeks are the same week everywhere on earth', () {
    test('every hour of a UTC day lands on the same Monday', () {
      // 2026-08-05 is a Wednesday.
      final mondays = {
        for (var hour = 0; hour < 24; hour++)
          weekStartUtc(DateTime.utc(2026, 8, 5, hour)),
      };
      expect(mondays.length, 1);
      expect(mondays.single, DateTime.utc(2026, 8, 3));
    });

    test('a Monday is its own week start', () {
      expect(weekStartUtc(DateTime.utc(2026, 8, 3)), DateTime.utc(2026, 8, 3));
    });

    test('a Sunday belongs to the week that began six days earlier', () {
      expect(weekStartUtc(DateTime.utc(2026, 8, 9)), DateTime.utc(2026, 8, 3));
    });

    test('two users either side of the date line share a bucket', () {
      // The roadmap names timezone rollover as a classic source of bugs.
      // Same instant, two local renderings, one week.
      final instant = DateTime.utc(2026, 8, 6, 12);
      final auckland = instant.add(const Duration(hours: 12));
      final honolulu = instant.subtract(const Duration(hours: 10));
      expect(weekStartUtc(auckland), weekStartUtc(honolulu));
    });

    test('the result carries no time of day', () {
      final start = weekStartUtc(DateTime.utc(2026, 8, 5, 17, 42, 13));
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.isUtc, isTrue);
    });
  });

  group('how a rank is told to the person who holds it', () {
    test('a small number is a position', () {
      expect(presentRank(rank: 4, total: 30), const RankPosition(4));
    });

    test('the roadmap\'s 40,000th is never shown as a position', () {
      // "A first-week user must never open a leaderboard and see
      // themselves last out of 40,000."
      final shown = presentRank(rank: 40000, total: 40000);
      expect(shown, isA<RankPercentile>());
      expect((shown as RankPercentile).percentile, 100);
    });

    test('a percentile is never zero', () {
      // "top 0%" is not a thing, and rounding a genuine leader down to
      // zero reads as a bug.
      final shown = presentRank(rank: 101, total: 1000000);
      expect(shown, isA<RankPercentile>());
      expect((shown as RankPercentile).percentile, greaterThanOrEqualTo(1));
    });

    test('the boundary is inclusive on the position side', () {
      expect(presentRank(rank: kRankTellsPosition, total: 5000),
          isA<RankPosition>());
      expect(presentRank(rank: kRankTellsPosition + 1, total: 5000),
          isA<RankPercentile>());
    });

    test('nonsense is unranked rather than wrong', () {
      expect(presentRank(rank: 0, total: 10), const RankUnranked());
      expect(presentRank(rank: 11, total: 10), const RankUnranked());
      expect(presentRank(rank: 1, total: 0), const RankUnranked());
    });

    test('the default scope is never global', () {
      // Beginner protection is a design requirement, and this is where
      // that decision lives rather than an initializer in a widget.
      expect(defaultScope, isNot(LeaderboardScope.global));
    });
  });

  group('challenges', () {
    test('progress is clamped at finished', () {
      // 140% of a target is not more finished than 100%, and a bar that
      // overshoots looks broken.
      expect(challengeFraction(progress: 14, target: 10), 1.0);
      expect(challengeFraction(progress: 5, target: 10), 0.5);
      expect(challengeFraction(progress: 0, target: 10), 0.0);
    });

    test('a target of zero does not divide by zero', () {
      expect(challengeFraction(progress: 3, target: 0), 0.0);
    });

    test('an ended challenge is not joinable', () {
      // The alternative is a join that silently earns nothing.
      final now = DateTime.utc(2026, 8, 10);
      expect(
        challengeIsOpen(
          startsAt: DateTime.utc(2026, 7, 1),
          endsAt: DateTime.utc(2026, 8, 1),
          now: now,
        ),
        isFalse,
      );
    });

    test('a future challenge is not joinable yet', () {
      expect(
        challengeIsOpen(
          startsAt: DateTime.utc(2026, 9, 1),
          endsAt: DateTime.utc(2026, 10, 1),
          now: DateTime.utc(2026, 8, 10),
        ),
        isFalse,
      );
    });

    test('the window is open at its start and closed at its end', () {
      final start = DateTime.utc(2026, 8, 1);
      final end = DateTime.utc(2026, 9, 1);
      expect(challengeIsOpen(startsAt: start, endsAt: end, now: start), isTrue);
      expect(challengeIsOpen(startsAt: start, endsAt: end, now: end), isFalse);
    });

    test('an unknown kind is skipped rather than guessed', () {
      expect(ChallengeKind.fromToken('moon_phase'), isNull);
      expect(ChallengeKind.fromToken('streak'), ChallengeKind.streak);
    });

    group('"not open" is TWO states', () {
      // Found on a device. Every challenge `021` shipped had already
      // started, so the screen's "open ? days left : Ended" was right
      // every time it could be checked. `025` staggers its start dates
      // on purpose, and the first future-dated card rendered "Bitti" —
      // "Ended" — for something starting tomorrow.
      final start = DateTime.utc(2026, 9, 1);
      final end = DateTime.utc(2026, 10, 1);

      test('before the window it is upcoming, not ended', () {
        expect(
          challengeIsUpcoming(startsAt: start, now: DateTime.utc(2026, 8, 10)),
          isTrue,
        );
      });

      test('after the window it is ended, not upcoming', () {
        expect(
          challengeIsUpcoming(startsAt: start, now: DateTime.utc(2026, 10, 5)),
          isFalse,
        );
        expect(
          challengeIsOpen(
              startsAt: start, endsAt: end, now: DateTime.utc(2026, 10, 5)),
          isFalse,
        );
      });

      test('the three states are mutually exclusive and exhaustive', () {
        for (final now in [
          DateTime.utc(2026, 8, 1),
          start,
          DateTime.utc(2026, 9, 15),
          end,
          DateTime.utc(2026, 12, 1),
        ]) {
          final open = challengeIsOpen(startsAt: start, endsAt: end, now: now);
          final upcoming = challengeIsUpcoming(startsAt: start, now: now);
          expect(open && upcoming, isFalse,
              reason: 'both true at $now — the card would contradict itself');
        }
      });

      test('the countdown is in CALENDAR days, not elapsed hours', () {
        // A challenge starting at midnight tonight is nine hours away
        // at 15:00, and `Duration.inDays` calls that zero — which would
        // render "starts today" on the day before it starts.
        final tonight = DateTime(2026, 8, 5);
        expect(
          challengeDaysUntilStart(
            startsAt: tonight,
            now: DateTime(2026, 8, 4, 15),
          ),
          1,
        );
        expect(
          challengeDaysUntilStart(
            startsAt: tonight,
            now: DateTime(2026, 8, 5, 0, 30),
          ),
          0,
        );
      });

      test('a start already past counts as zero, never negative', () {
        // The label is only read while upcoming, but a negative day
        // count would reach an ICU plural and read as nonsense.
        expect(
          challengeDaysUntilStart(
            startsAt: DateTime(2026, 8, 1),
            now: DateTime(2026, 8, 20),
          ),
          0,
        );
      });
    });
  });

  group('clamping a week before writing it', () {
    test('an implausible week is clamped to what the server accepts', () {
      final clamped =
          clampWeek(xp: 99999, sessions: 99, streak: -4, consistency: 250);
      expect(clamped.xp, kWeeklyXpCap);
      expect(clamped.sessions, kMaxWeeklySessions);
      expect(clamped.streak, 0);
      expect(clamped.consistency, 100);
    });

    test('an honest week passes through untouched', () {
      final clamped =
          clampWeek(xp: 420, sessions: 4, streak: 11, consistency: 57);
      expect(clamped.xp, 420);
      expect(clamped.sessions, 4);
      expect(clamped.streak, 11);
      expect(clamped.consistency, 57);
    });
  });
}
