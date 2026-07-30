import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/monetization/domain/rating_trigger.dart';

/// Roadmap Phase 1 (R2.2 · C10) · the rating-trigger policy.
///
/// The whole point of extracting [selectRatingTrigger] as a pure
/// function is that the policy — which moment wins, how often we may
/// ask, when we must stay silent — is provable without a widget tree or
/// a clock. These tests are the specification.
void main() {
  const maxPrompts = 3;
  const cooldown = Duration(days: 90);
  final now = DateTime(2026, 7, 30, 12);

  RatingTrigger? select({
    required RatingContext context,
    Set<String> fired = const <String>{},
    int promptCount = 0,
    DateTime? lastPromptAt,
  }) {
    return selectRatingTrigger(
      context: context,
      firedTokens: fired,
      promptCount: promptCount,
      lastPromptAt: lastPromptAt,
      now: now,
      maxLifetimePrompts: maxPrompts,
      cooldown: cooldown,
    );
  }

  group('trigger eligibility', () {
    test('a user with nothing completed is never asked', () {
      final result = select(
        context: const RatingContext(completedDays: 0, currentStreak: 0),
      );
      expect(result, isNull);
    });

    test('one completed workout unlocks the firstWorkout trigger', () {
      final result = select(
        context: const RatingContext(completedDays: 1, currentStreak: 1),
      );
      expect(result, RatingTrigger.firstWorkout);
    });

    test(
        'C10 · eligibility does not consider Pro status — the Phase 136 '
        'isPro gate is gone, which was the whole point of the change', () {
      // There is no isPro input to the policy at all. This test exists
      // to pin that: if someone reintroduces a subscription gate, the
      // signature changes and this test stops compiling.
      final result = select(
        context: const RatingContext(completedDays: 3, currentStreak: 3),
      );
      expect(result, isNotNull);
    });

    test('badgeUnlocked requires the caller to report a fresh unlock', () {
      // 3 completed days would satisfy thirdWorkout, so exclude it to
      // isolate the badge trigger.
      final withoutBadge = select(
        context: const RatingContext(completedDays: 3, currentStreak: 0),
        fired: {
          RatingTrigger.thirdWorkout.token,
          RatingTrigger.firstWorkout.token,
        },
      );
      expect(withoutBadge, isNull);

      final withBadge = select(
        context: const RatingContext(
          completedDays: 3,
          currentStreak: 0,
          badgeJustUnlocked: true,
        ),
        fired: {
          RatingTrigger.thirdWorkout.token,
          RatingTrigger.firstWorkout.token,
        },
      );
      expect(withBadge, RatingTrigger.badgeUnlocked);
    });
  });

  group('trigger priority', () {
    test(
        'a user who crosses several thresholds at once is asked at the '
        'highest-emotion moment (program completion beats all)', () {
      final result = select(
        context: const RatingContext(
          completedDays: 30,
          currentStreak: 10,
          badgeJustUnlocked: true,
        ),
      );
      expect(result, RatingTrigger.programComplete);
    });

    test('a 7-day streak outranks the third workout', () {
      final result = select(
        context: const RatingContext(completedDays: 8, currentStreak: 7),
      );
      expect(result, RatingTrigger.streakSeven);
    });

    test(
        'firstWorkout is the fallback, never the winner when richer '
        'moments are available', () {
      final ctx = const RatingContext(completedDays: 30, currentStreak: 7);
      expect(ctx.eligibleTriggers.last, RatingTrigger.firstWorkout);
    });
  });

  group('one-shot ledger', () {
    test('a fired trigger never fires again', () {
      final result = select(
        context: const RatingContext(completedDays: 1, currentStreak: 1),
        fired: {RatingTrigger.firstWorkout.token},
      );
      expect(result, isNull);
    });

    test('the next unfired eligible trigger takes over', () {
      final result = select(
        context: const RatingContext(completedDays: 3, currentStreak: 0),
        fired: {RatingTrigger.thirdWorkout.token},
      );
      expect(result, RatingTrigger.firstWorkout);
    });
  });

  group('cooldown', () {
    test('a prompt inside the cooldown window is suppressed', () {
      final result = select(
        context: const RatingContext(completedDays: 30, currentStreak: 7),
        promptCount: 1,
        lastPromptAt: now.subtract(const Duration(days: 89)),
      );
      expect(result, isNull);
    });

    test('a prompt past the cooldown window is allowed', () {
      final result = select(
        context: const RatingContext(completedDays: 30, currentStreak: 7),
        promptCount: 1,
        lastPromptAt: now.subtract(const Duration(days: 91)),
      );
      expect(result, RatingTrigger.programComplete);
    });

    test(
        'cooldown is evaluated even when many triggers are eligible — '
        'a growing trigger set must never become nagging', () {
      final result = select(
        context: const RatingContext(
          completedDays: 30,
          currentStreak: 7,
          badgeJustUnlocked: true,
        ),
        promptCount: 1,
        lastPromptAt: now.subtract(const Duration(hours: 2)),
      );
      expect(result, isNull);
    });
  });

  group('lifetime cap', () {
    test('the cap ends prompting permanently', () {
      final result = select(
        context: const RatingContext(completedDays: 30, currentStreak: 7),
        promptCount: maxPrompts,
        lastPromptAt: now.subtract(const Duration(days: 400)),
      );
      expect(result, isNull);
    });

    test('one below the cap still prompts', () {
      final result = select(
        context: const RatingContext(completedDays: 30, currentStreak: 7),
        promptCount: maxPrompts - 1,
        lastPromptAt: now.subtract(const Duration(days: 400)),
      );
      expect(result, isNotNull);
    });
  });

  group('token stability', () {
    test('tokens are unique — the ledger keys off them', () {
      final tokens = RatingTrigger.values.map((t) => t.token).toList();
      expect(tokens.toSet().length, tokens.length);
    });

    test(
        'tokens are the exact persisted strings; renaming one silently '
        're-asks every existing user', () {
      expect(RatingTrigger.programComplete.token, 'program_complete');
      expect(RatingTrigger.streakSeven.token, 'streak_seven');
      expect(RatingTrigger.thirdWorkout.token, 'third_workout');
      expect(RatingTrigger.badgeUnlocked.token, 'badge_unlocked');
      expect(RatingTrigger.firstWorkout.token, 'first_workout');
    });
  });
}
