import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Roadmap Phase 12 · a static gate over `019_social_profiles.sql`.
///
/// **What this is not.** The roadmap asks for "RLS penetration tests —
/// verify a user cannot read another user's data via crafted queries",
/// and this file cannot do that: it executes no SQL, connects to no
/// database, and holds no second user's session. The live adversarial
/// pass is an operator task and is recorded as such in the phase report.
///
/// **What this is.** The properties of an RLS layer that can be checked
/// by reading it, checked on every CI run, so the classes of mistake
/// that are invisible in review cannot reach a database:
///
///   * a table that was added without `enable row level security` —
///     which reads exactly like a table with policies, because the
///     policies are right there above it;
///   * a policy with `using (true)`, which is the shape of "we will
///     tighten this later";
///   * a policy with no `auth.uid()` anywhere in it, which is the same
///     mistake wearing a predicate.
///
/// A green run here means the shape is right. It does not mean the
/// semantics are, and the file says so out loud so nobody mistakes it
/// for the penetration pass.
void main() {
  late String sql;
  late List<String> statements;

  setUpAll(() {
    sql =
        File('supabase/migrations/019_social_profiles.sql').readAsStringSync();
    // Comments first: this migration explains at length why a block is
    // symmetric and why `using (true)` would be wrong, and matching
    // those phrases inside the prose would fail the test on its own
    // documentation.
    final code = sql.replaceAll(RegExp(r'--.*', multiLine: true), '');
    statements = code
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  });

  /// Every table this migration creates, read out of the file rather
  /// than hardcoded — a table added later without a policy is exactly
  /// the regression this suite exists to catch, and a hardcoded list
  /// would not see it.
  List<String> createdTables() => RegExp(
        r'create table if not exists public\.(\w+)',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(1)!).toList(growable: false);

  test('the migration creates the tables the phase needs', () {
    expect(
      createdTables(),
      containsAll(<String>[
        'public_profiles',
        'blocks',
        'friendships',
        'squads',
        'squad_members',
        'activity_events',
        'activity_reactions',
        'user_reports',
      ]),
    );
  });

  test('every table it creates enables row level security', () {
    for (final table in createdTables()) {
      expect(
        sql.contains('alter table public.$table enable row level security'),
        isTrue,
        reason: 'public.$table has no RLS — a table with policies above it '
            'and no ENABLE is indistinguishable from a protected one',
      );
    }
  });

  test('every table it creates has at least one policy', () {
    for (final table in createdTables()) {
      expect(
        sql.contains('on public.$table for '),
        isTrue,
        reason: 'public.$table is RLS-enabled with no policy, which denies '
            'everything including the owner',
      );
    }
  });

  group('no policy is permissive by accident', () {
    List<String> policyStatements() => statements
        .where((s) => s.toLowerCase().startsWith('create policy'))
        .toList(growable: false);

    test('there are policies to check', () {
      expect(policyStatements().length, greaterThan(15));
    });

    test('none of them is using (true)', () {
      for (final policy in policyStatements()) {
        final flat = policy.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        expect(flat.contains('using (true)'), isFalse,
            reason: 'a permissive policy: $flat');
        expect(flat.contains('with check (true)'), isFalse,
            reason: 'a permissive policy: $flat');
      }
    });

    test('every one of them constrains on auth.uid()', () {
      for (final policy in policyStatements()) {
        final flat = policy.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          flat.contains('auth.uid()'),
          isTrue,
          reason: 'a policy with no auth.uid() predicate is open to every '
              'signed-in user: $flat',
        );
      }
    });
  });

  group('the properties the phase actually promises', () {
    test('a profile publishes nothing by default', () {
      // The three visibility flags all default false. If any of them
      // ever defaults true, creating a profile publishes it.
      for (final column in ['is_public', 'show_badges', 'show_stats']) {
        expect(
          RegExp('$column boolean not null default false').hasMatch(sql),
          isTrue,
          reason: '$column must default false',
        );
      }
    });

    test('a block is checked in both directions wherever it is checked', () {
      // The roadmap requires a block to "fully sever visibility both
      // ways". A one-directional check lets somebody keep watching a
      // profile that blocked them.
      // Whole statements rather than a sub-match: a non-greedy regex
      // stops at the first ')' and truncates the clause before the OR
      // it is looking for, which made the first draft of this test fail
      // on a migration that was correct.
      final consulting = statements
          .where((s) => s.contains('from public.blocks b'))
          .toList(growable: false);

      expect(consulting.length, greaterThanOrEqualTo(3),
          reason: 'blocks are consulted by profiles, friendships and the feed');

      for (final statement in consulting) {
        final flat = statement.replaceAll(RegExp(r'\s+'), ' ');
        expect(flat.contains('b.blocker_id'), isTrue);
        expect(flat.contains('b.blocked_id'), isTrue);
        expect(
          RegExp(r'b\.blocker_id.*\bor\b.*b\.blocker_id').hasMatch(flat),
          isTrue,
          reason: 'a block check naming blocker_id once is one-directional, '
              'and a blocked user could keep watching: $flat',
        );
      }
    });

    test('a block is readable only by the blocker', () {
      // The blocked user must not be able to discover the block — that
      // is the difference between a safety tool and an escalation.
      expect(
        sql.contains('create policy blocks_select_own\n'
            '  on public.blocks for select\n'
            '  using (auth.uid() = blocker_id)'),
        isTrue,
      );
      expect(sql.contains('blocked_id)\n  ;'), isFalse);
    });

    test('a friendship is one row per pair, ordered and unique', () {
      expect(sql.contains('check (user_a < user_b)'), isTrue,
          reason: 'without the ordering a pair has two representations');
      expect(sql.contains('unique (user_a, user_b)'), isTrue);
    });

    test('only the party who did not ask may respond', () {
      // `create policy`, not the `drop policy` above it — that one
      // names the policy and carries none of its predicates.
      final policy = statements.firstWhere(
        (s) =>
            s.toLowerCase().startsWith('create policy') &&
            s.contains('friendships_update_recipient'),
      );
      final flat = policy.replaceAll(RegExp(r'\s+'), ' ');
      expect(flat.contains('auth.uid() <> requester_id'), isTrue,
          reason: 'otherwise the requester can accept their own request');
    });

    test('the squad size cap is enforced in one statement, not two', () {
      // A client that counts and then inserts has a race: two people
      // joining a squad of 11 both read 11 and both insert.
      expect(
          sql.contains('create or replace function public.join_squad'), isTrue);
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains('if v_count >= 12 then'), isTrue);
      expect(sql.contains('revoke all on function public.join_squad(text)'),
          isTrue,
          reason: 'a SECURITY DEFINER function granted to public is a '
              'privilege escalation');
    });

    test('the feed carries no free text to moderate', () {
      final reactions = statements.firstWhere(
        (s) =>
            s.contains('create table if not exists public.activity_reactions'),
      );
      expect(reactions.contains('text not null check (reaction in'), isTrue);
      // An events table with a body column would be the comment feature
      // this phase deliberately does not ship.
      final events = statements.firstWhere(
        (s) => s.contains('create table if not exists public.activity_events'),
      );
      for (final banned in ['body', 'message', 'comment', 'caption']) {
        expect(events.contains('$banned text'), isFalse,
            reason: 'activity_events has a free-text column: $banned');
      }
    });

    test('everything cascades from auth.users, so deletion reaches it', () {
      for (final table in createdTables()) {
        final statement = statements.firstWhere(
          (s) => s.contains('create table if not exists public.$table'),
        );
        // squads reference auth.users via owner_id; join tables via
        // their own FKs. Every one of them must cascade somewhere, or a
        // deleted account leaves rows behind.
        expect(
          statement.contains('on delete cascade'),
          isTrue,
          reason: 'public.$table does not cascade — a deleted account '
              'would leave its rows',
        );
      }
    });
  });
}
