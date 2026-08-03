import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/domain/league.dart';
import 'package:sixpack_ai/features/community/domain/models/leaderboard_models.dart';

/// Roadmap Phase 13 (C25) · challenges are content, so the server can be
/// newer than the client. Every test here is about that.
Map<String, dynamic> _row({
  Object? kind = 'streak',
  Object? target = 10,
  Object? copy,
  Object? endsAt = '2026-09-01T00:00:00Z',
}) =>
    {
      'id': 'c1',
      'slug': 'jan_consistency',
      'kind': kind,
      'target': target,
      'starts_at': '2026-08-01T00:00:00Z',
      'ends_at': endsAt,
      'copy': copy ??
          {
            'en': {'title': 'Ten day streak', 'body': 'Train ten days.'},
            'tr': {'title': 'On günlük seri', 'body': 'On gün antrenman yap.'},
          },
    };

void main() {
  group('a row the client cannot honestly render is dropped', () {
    test('an unknown kind drops the challenge', () {
      // A newer server's challenge type. Guessing would track progress
      // against a rule this build does not implement.
      expect(Challenge.fromJson(_row(kind: 'moon_phase')), isNull);
    });

    test('a missing end date drops the challenge', () {
      expect(Challenge.fromJson(_row(endsAt: null)), isNull);
    });

    test('a missing target drops the challenge', () {
      expect(Challenge.fromJson(_row(target: null)), isNull);
    });

    test('a well-formed row parses', () {
      final challenge = Challenge.fromJson(_row());
      expect(challenge, isNotNull);
      expect(challenge!.kind, ChallengeKind.streak);
      expect(challenge.target, 10);
      expect(challenge.squadScope, isFalse);
    });
  });

  group('copy falls back rather than showing a slug', () {
    test('an exact locale wins', () {
      final c = Challenge.fromJson(_row())!;
      expect(c.title('tr'), 'On günlük seri');
    });

    test('a regional tag falls back to its language', () {
      // 'tr-TR' has no entry; 'tr' does.
      final c = Challenge.fromJson(_row())!;
      expect(c.title('tr-TR'), 'On günlük seri');
    });

    test('an unknown locale falls back to English', () {
      final c = Challenge.fromJson(_row())!;
      expect(c.title('ja'), 'Ten day streak');
    });

    test('no usable copy is null, never the slug', () {
      // A slug is an identifier. Showing one to a user is the same
      // mistake as rendering a badge token.
      final c = Challenge.fromJson(_row(copy: <String, dynamic>{}))!;
      expect(c.title('en'), isNull);
      expect(c.title('tr'), isNull);
    });

    test('an empty string counts as no copy', () {
      final c = Challenge.fromJson(_row(copy: {
        'tr': {'title': ''},
        'en': {'title': 'Fallback'},
      }))!;
      expect(c.title('tr'), 'Fallback');
    });

    test('malformed copy does not throw', () {
      final c = Challenge.fromJson(_row(copy: 'not a map'))!;
      expect(c.title('en'), isNull);
    });
  });

  test('an entry is complete only once the server says so', () {
    final open = ChallengeEntry.fromJson({
      'challenge_id': 'c1',
      'user_id': 'u',
      'progress': 10,
    })!;
    // Progress reaching the target is not the same as being marked
    // finished: completion is a moment, and the server owns it.
    expect(open.isComplete, isFalse);

    final done = ChallengeEntry.fromJson({
      'challenge_id': 'c1',
      'user_id': 'u',
      'progress': 10,
      'completed_at': '2026-08-20T10:00:00Z',
    })!;
    expect(done.isComplete, isTrue);
  });

  test('a league standing with an unknown tier is dropped', () {
    expect(LeagueStanding.fromJson({'tier': 'emerald'}), isNull);
    expect(LeagueStanding.fromJson({'tier': 'gold'})?.tier, LeagueTier.gold);
  });

  test('a standing says nothing about promotion until it knows the board', () {
    // A predicted promotion that does not arrive is worse than no
    // prediction.
    const standing = LeagueStanding(tier: LeagueTier.silver);
    expect(standing.projectedOutcome, isNull);
    expect(
      standing.withRank(rank: 2, size: 30).projectedOutcome,
      LeagueOutcome.promoted,
    );
  });
}
