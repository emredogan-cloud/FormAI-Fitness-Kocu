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
/// Read by name so adding a community migration without adding it here
/// is a visible omission rather than a silent one.
const List<String> communityMigrations = [
  '019_social_profiles.sql',
  '020_leaderboards.sql',
  '022_fix_challenge_peer_policy.sql',
  '023_rls_recursion_and_block_direction.sql',
  '026_squad_owner_can_read_own.sql',
];

/// The content tables this suite expects to exist.
///
/// A tripwire, not a permission. The exemption below is derived from the
/// schema; this constant only makes a *change* in what qualifies
/// visible, so a table that quietly becomes exempt has to be looked at
/// by a person.
const Set<String> kExpectedContentTables = {'challenges'};

void main() {
  late String sql;
  late String code;
  late List<String> statements;

  setUpAll(() {
    // EVERY community migration, not one of them. The first version of
    // this suite read only `019` and passed with a flourish while `020`
    // — which it had never opened — carried a `using (true)`. A gate
    // that names its input by hand is green about the file it happens
    // to know, which is the third time a gate in this codebase has been
    // confident about something it does not measure.
    sql = communityMigrations
        .map((name) => File('supabase/migrations/$name').readAsStringSync())
        .join('\n');
    // Comments first: this migration explains at length why a block is
    // symmetric and why `using (true)` would be wrong, and matching
    // those phrases inside the prose would fail the test on its own
    // documentation.
    code = sql.replaceAll(RegExp(r'--.*', multiLine: true), '');
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

  /// Tables that structurally cannot hold user data: no `user_id`
  /// column and no reference to `auth.users`.
  ///
  /// This is the only thing that exempts a policy from the three
  /// generic assertions below, and it is deliberately **derived from
  /// the schema rather than declared**. An earlier draft exempted a
  /// policy that carried an `rls-gate-ok` comment, which is a promise;
  /// a table with nowhere to put a user id is a fact. This codebase has
  /// twice been burned by a gate widened with an exclusion instead of a
  /// signal.
  Set<String> contentTables() {
    final content = <String>{};
    for (final table in createdTables()) {
      final create = statements.firstWhere(
        (s) => s.contains('create table if not exists public.$table'),
        orElse: () => '',
      );
      if (create.isEmpty) continue;
      if (!create.contains('user_id') && !create.contains('auth.users')) {
        content.add(table);
      }
    }
    return content;
  }

  bool isContentPolicy(String policy) =>
      contentTables().any((t) => policy.contains('public.$t'));

  /// Every policy **as it finally stands**, one entry per name.
  ///
  /// Migrations are read in order and every policy is written as
  /// `drop ... if exists` followed by `create`, so a later file
  /// supersedes an earlier one. Checking every historical statement
  /// would fail on a defect that has already been repaired — which is
  /// exactly what happened when `022` fixed two policies and the suite
  /// kept reporting `019`'s original text. The live database has one
  /// definition per name, and that is what this asserts.
  List<String> policyStatements() {
    final latest = <String, String>{};
    for (final statement in statements) {
      if (!statement.toLowerCase().startsWith('create policy')) continue;
      final name = RegExp(r'create policy\s+"?(\w+)"?', caseSensitive: false)
          .firstMatch(statement)
          ?.group(1);
      if (name == null) continue;
      latest[name] = statement;
    }
    return latest.values.toList(growable: false);
  }

  /// The table a policy is attached to — `on public.X for select`.
  String? policyTable(String policy) => RegExp(
        r'on\s+public\.(\w+)\s+for\b',
        caseSensitive: false,
      ).firstMatch(policy)?.group(1);

  /// The `private.*` helpers, keyed by name, each mapped to its whole
  /// declaration — header and `$$` body together.
  ///
  /// These exist because a policy cannot read a table whose RLS is part
  /// of the question it is asking — see `023`. They are read here so the
  /// assertions below can check what a helper actually does rather than
  /// trusting its name.
  ///
  /// Parsed out of the raw text and NOT out of `statements`, because a
  /// function body contains semicolons and the splitter cuts the
  /// declaration in half at the first one. That is also why `019`'s
  /// `join_squad` has only ever been checked with `sql.contains`.
  Map<String, String> privateHelpers() => {
        for (final m in RegExp(
          r'create or replace function private\.(\w+)\s*\([\s\S]*?'
          r'\$\$[\s\S]*?\$\$',
          caseSensitive: false,
        ).allMatches(code))
          m.group(1)!: m.group(0)!,
      };

  test('the set of content tables is the one we think it is', () {
    // If this fails, a table stopped holding user data or started to.
    // Either way the exemption changed and somebody has to look.
    expect(contentTables(), kExpectedContentTables);
  });

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
    test('there are policies to check', () {
      expect(policyStatements().length, greaterThan(15));
    });

    test('none of them is using (true)', () {
      for (final policy in policyStatements()) {
        if (isContentPolicy(policy)) continue;
        final flat = policy.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        expect(flat.contains('using (true)'), isFalse,
            reason: 'a permissive policy: $flat');
        expect(flat.contains('with check (true)'), isFalse,
            reason: 'a permissive policy: $flat');
      }
    });

    test('every one of them constrains on auth.uid()', () {
      // `023` moved three predicates into `private.*` helpers, because a
      // policy cannot read a table whose RLS is part of the question it
      // is asking. So a policy may now constrain on the caller without
      // the literal `auth.uid()` appearing in it.
      //
      // **That is widened with a signal, not an exclusion.** "Calls a
      // private helper" would be a free pass — a helper is just a
      // function name and could contain anything. What earns the pass is
      // reading the helper's own body and finding `auth.uid()` in it. A
      // helper that stopped constraining on the caller would take every
      // policy that calls it down with it, which is the correct
      // blast radius.
      final helpers = privateHelpers();
      final constrained = {
        for (final entry in helpers.entries)
          if (entry.value.contains('auth.uid()')) entry.key,
      };
      expect(constrained, isNotEmpty,
          reason: 'no private helper constrains on auth.uid() — either they '
              'were removed or the parser stopped finding them, and either '
              'way the pass below is being handed out for free');

      for (final policy in policyStatements()) {
        if (isContentPolicy(policy)) continue;
        final flat = policy.replaceAll(RegExp(r'\s+'), ' ');
        final viaHelper = constrained.any((h) => flat.contains('private.$h('));
        expect(
          flat.contains('auth.uid()') || viaHelper,
          isTrue,
          reason: 'a policy with no auth.uid() predicate is open to every '
              'signed-in user: $flat',
        );
      }
    });

    test('no policy queries the table it is attached to', () {
      // The defect that made joining a challenge do nothing, and that
      // had `squads`, `squad_members`, `activity_events` and
      // `activity_reactions` answering 500 in production from the day
      // `019` was applied:
      //
      //   create policy challenge_participants_select_peers
      //     on public.challenge_participants for select
      //     using (exists (select 1 from public.challenge_participants ...))
      //
      // Postgres applies row security to the tables a policy expression
      // reads — including the one the policy is on — so evaluating it
      // re-enters it. `42P17 infinite recursion detected in policy`, on
      // every request, forever. A table three others reference in their
      // own policies takes them down with it.
      //
      // No gate in this file could see it: the shape is a correlated
      // subquery, which is what a correct policy looks like. The route
      // out is a `security definer` helper, which reads the table
      // without row security.
      for (final policy in policyStatements()) {
        final table = policyTable(policy);
        if (table == null) continue;
        expect(
          RegExp('from\\s+public\\.$table\\b', caseSensitive: false)
              .hasMatch(policy),
          isFalse,
          reason: 'policy on public.$table reads public.$table — this '
              'recurses and every request against the table returns 42P17. '
              'Move the predicate into a private.* security definer '
              'helper: $policy',
        );
      }
    });

    test('no policy compares a column to itself through an alias', () {
      // 020 shipped `mine.challenge_id = challenge_id` inside a policy
      // on `challenge_participants`. The unqualified name resolves to
      // the innermost scope, so the predicate was
      // `mine.challenge_id = mine.challenge_id` — always true — and the
      // read degraded to "has the caller joined anything at all". 019
      // had the same defect in `squad_members_select_member`.
      //
      // **The check is precise, not merely suspicious.** An unqualified
      // column inside a correlated subquery is only ambiguous if the
      // aliased table actually has a column by that name. So the table's
      // columns are read out of its own `create table` statement:
      //
      //   `from public.squads s ... where s.id = squad_id`
      //
      // is CORRECT, because `squads` has no `squad_id` — the bare name
      // can only mean the outer row. The first draft of this test
      // flagged it, which is the difference between a gate that measures
      // something and one that just fires a lot.
      final columnsByTable = <String, Set<String>>{};
      for (final statement in statements) {
        final match = RegExp(
          r'create table if not exists public\.(\w+)\s*\(([\s\S]*)',
          caseSensitive: false,
        ).firstMatch(statement);
        if (match == null) continue;
        columnsByTable[match.group(1)!] =
            RegExp(r'^\s*(\w+)\s+\w', multiLine: true)
                .allMatches(match.group(2)!)
                .map((m) => m.group(1)!)
                .toSet();
      }

      final aliasSub = RegExp(
        r'from\s+public\.(\w+)\s+(\w+)\s+where([\s\S]*?)\)',
        caseSensitive: false,
      );
      for (final policy in policyStatements()) {
        for (final match in aliasSub.allMatches(policy)) {
          final table = match.group(1)!;
          final alias = match.group(2)!;
          final body = match.group(3)!;
          final owned = columnsByTable[table] ?? const <String>{};
          final shadowed = RegExp(r'(?<![.\w])(\w+)\b')
              .allMatches(body)
              .map((m) => m.group(1)!)
              .where(owned.contains)
              .toSet();
          expect(
            shadowed,
            isEmpty,
            reason: 'unqualified $shadowed beside alias "$alias" over '
                'public.$table, which has those columns — the outer row '
                'must be written table.column or it silently resolves to '
                'the alias: $policy',
          );
        }
      }
    });

    test('a content table has no writer policy at all', () {
      // The exemption only covers reads. `challenges` is authored by
      // content ops through the service role, and the absence of any
      // insert/update/delete policy is what stops a client writing one —
      // the same shape as the progress-photo repository, where the
      // guarantee is the absence of code rather than a flag over it.
      for (final table in contentTables()) {
        for (final policy in policyStatements()) {
          if (!policy.contains('public.$table')) continue;
          expect(
            RegExp(r'for (insert|update|delete|all)').hasMatch(policy),
            isFalse,
            reason: 'public.$table has a client write policy: $policy',
          );
        }
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

    test('no policy reads public.blocks directly', () {
      // The version of this test that `023` replaced asserted that every
      // block check named `blocker_id` on both sides of an `or`. Every
      // one of them did. **The blocks were still not working**, and two
      // real accounts against production proved it: A blocked B, and B
      // went on reading A's profile.
      //
      // `blocks_select_own` deliberately shows a block row only to the
      // blocker, and a policy expression is evaluated as the querying
      // user — so the row matching the second half of that symmetric
      // predicate is invisible to exactly the person it is meant to
      // stop. The predicate was symmetric and the data it read was not.
      //
      // So the property worth checking is no longer "is it written both
      // ways". It is: nothing reads `public.blocks` from inside a policy
      // at all. There is one reader, it is `security definer`, and it is
      // checked below.
      for (final policy in policyStatements()) {
        // The `on public.blocks for select` header of the policies that
        // govern the table itself is not a read of it.
        final predicate = policy.replaceFirst(
          RegExp(r'on\s+public\.\w+\s+for\b', caseSensitive: false),
          '',
        );
        expect(
          predicate.contains('public.blocks'),
          isFalse,
          reason: 'a policy reading public.blocks sees only the rows the '
              'CALLER wrote, so the "someone blocked me" direction never '
              'matches. Use private.is_blocked_with: $policy',
        );
      }
    });

    test('the one thing that reads blocks checks both directions', () {
      final helper = privateHelpers()['is_blocked_with'];
      expect(helper, isNotNull,
          reason: 'private.is_blocked_with is the only sanctioned reader of '
              'public.blocks and it is gone');
      final flat = helper!.replaceAll(RegExp(r'\s+'), ' ');
      expect(flat.contains('from public.blocks'), isTrue,
          reason: 'sanity: this is meant to be the one thing that reads the '
              'table, and it does not: $flat');
      expect(
        RegExp(r'blocker_id.*\bor\b.*blocker_id').hasMatch(flat),
        isTrue,
        reason: 'the roadmap requires a block to sever visibility both ways, '
            'and this is now the single place that decides it: $flat',
      );
    });

    test('every private helper is security definer and pins search_path', () {
      // A SECURITY DEFINER function runs as its owner. One that resolves
      // an unqualified name through a caller-controlled search_path runs
      // somebody else's code as its owner.
      final helpers = privateHelpers();
      expect(helpers.keys, isNotEmpty, reason: 'the parser found no helpers');
      for (final entry in helpers.entries) {
        expect(entry.value.contains('security definer'), isTrue,
            reason: 'private.${entry.key} is not security definer, so it '
                'cannot read past RLS and the policy calling it still '
                'recurses');
        expect(entry.value.contains('set search_path'), isTrue,
            reason: 'private.${entry.key} does not pin search_path');
      }
    });

    test('the helpers are not reachable as PostgREST RPC', () {
      // They live in `private` rather than `public` on purpose.
      // `public.is_blocked_with(uuid)` would be an endpoint any signed-in
      // user could call for any id — an enumerable "did this person
      // block me?" oracle, which is the exact thing blocks_select_own
      // refuses to be.
      expect(sql.contains('create schema if not exists private'), isTrue);
      for (final name in privateHelpers().keys) {
        expect(
          sql.contains('create or replace function public.$name('),
          isFalse,
          reason: '$name also exists in the exposed public schema',
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
        if (contentTables().contains(table)) continue;
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
