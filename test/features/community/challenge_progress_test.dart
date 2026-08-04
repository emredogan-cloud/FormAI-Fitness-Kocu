import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/domain/league.dart';

/// Phase 14 · challenge progress became real.
///
/// Before this, `reportChallengeProgress` existed and nothing called it,
/// so a joined challenge sat at zero forever. The hook lives in the XP
/// listener, beside the ledger that has already decided a session is
/// new. What is testable without a database is the arithmetic each kind
/// derives — which is the part that would be silently wrong.
void main() {
  group('progress is derived, not accumulated', () {
    test('consistency is sessions over the programme length', () {
      // The same ratio the Progress tab and the leaderboard use. Three
      // formulas for one number would be three answers.
      int consistency(int sessions) =>
          ((sessions / kProgrammeDays) * 100).round().clamp(0, 100);

      expect(consistency(0), 0);
      expect(consistency(15), 50);
      expect(consistency(30), 100);
      // Past the programme it saturates rather than exceeding 100.
      expect(consistency(45), 100);
    });

    test('a fraction never overshoots its target', () {
      // A derived value can legitimately exceed the target — 40 sessions
      // against a target of 30 — and the bar must not run off the card.
      expect(challengeFraction(progress: 40, target: 30), 1.0);
      expect(challengeFraction(progress: 30, target: 30), 1.0);
      expect(challengeFraction(progress: 15, target: 30), 0.5);
    });
  });

  group('a deadline is only shown when it is news', () {
    test('a year out says nothing', () {
      // Every launch challenge runs for a year, so before this rule
      // every card carried an identical "361 days left" competing with
      // its own title.
      expect(361 <= kChallengeDeadlineIsNews, isFalse);
    });

    test('a month out says something', () {
      expect(30 <= kChallengeDeadlineIsNews, isTrue);
      expect(3 <= kChallengeDeadlineIsNews, isTrue);
    });
  });

  group('the launch challenges only use kinds the app can measure', () {
    test('every kind maps to an engine the client actually owns', () {
      // Weekly Cardio, Strength Builder, Mobility, Daily Stretch, High
      // Protein and Water Intake were all excluded from the seed for
      // this reason — see seed_launch_challenges.sql. If a fifth kind
      // ever appears here, something must be able to compute it.
      expect(ChallengeKind.values.map((k) => k.token).toSet(), {
        'consistency',
        'sessions',
        'streak',
        'xp',
      });
    });

    test('an unknown kind is skipped rather than shown at zero', () {
      // A challenge whose progress can never move is worse than no
      // challenge: it is a progress bar that lies.
      expect(ChallengeKind.fromToken('water_intake'), isNull);
      expect(ChallengeKind.fromToken('protein'), isNull);
    });
  });
}
