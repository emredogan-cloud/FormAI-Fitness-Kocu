import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/league.dart';
import '../domain/models/community_models.dart';
import '../domain/models/leaderboard_models.dart';

/// Roadmap Phase 12 (R6, C22, C24, C47) · every read and write the
/// community surfaces make.
///
/// # `019_social_profiles.sql` is written and NOT applied
///
/// Which means every method here has to answer "the tables do not
/// exist" as a **state**, not as an error. Postgres reports a missing
/// relation as `42P01`, and a repository that lets that reach the UI
/// turns "this feature is not switched on yet" into a red error tile on
/// somebody's profile tab.
///
/// So [isAvailable] exists and every read returns an empty result rather
/// than throwing — see `_guard`, which turns a missing relation into a
/// fallback and lets every OTHER failure through, because a
/// swallow-everything wrapper would hide a broken policy as an empty
/// list. The screens render an honest "not available yet" instead of a
/// failure. When the founder applies the migration nothing in this file
/// changes.
///
/// # One repository, not four
///
/// Profiles, friendships, squads and the feed are four tables and one
/// feature: almost every screen needs two of them at once, and a friend
/// row is meaningless without the profile it points at. Splitting them
/// would mean four classes that each hold the same `SupabaseClient` and
/// call each other. The methods are grouped by table with headers.
///
/// # What is deliberately absent
///
/// No caching layer and no offline queue, unlike
/// `BodyMetricsRepository`. Body metrics are the user's own data and
/// must survive a plane; a squad feed is other people's activity and a
/// stale one is worse than an empty one. Community is online-only and
/// says so.
class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Cached across calls: whether the schema is there does not change
  /// while the app is running, and asking on every read would put a
  /// round trip in front of every screen.
  bool? _available;

  String? get _uid => _client.auth.currentUser?.id;

  /// The signed-in user's id, for screens that have to decide which side
  /// of a friendship they are on. Exposed rather than passed down from
  /// four call sites, all of which would be asking the same client.
  String? get currentUserId => _uid;

  /// True when `019` has been applied and the caller is signed in.
  ///
  /// A single `limit(1)` probe against one table. This is a reachability
  /// question rather than a read, and the row it may return is
  /// discarded.
  Future<bool> isAvailable() async {
    final cached = _available;
    if (cached != null) return cached;
    if (_uid == null) return false;
    try {
      await _client.from('public_profiles').select('user_id').limit(1);
      return _available = true;
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        AppLogger.info(
          'community: schema not applied — feature reports unavailable',
          category: 'community',
        );
        return _available = false;
      }
      rethrow;
    }
  }

  /// Postgres's `undefined_table`.
  ///
  /// The SQLSTATE is the real check; the message match is a fallback for
  /// deployments that surface a null code through PostgREST. Both are
  /// wire diagnostics rather than copy — hoisted to named constants
  /// because a `// i18n-ignore` on the expression's own line does not
  /// survive `dart format`, which is the same reason
  /// `auth_error_messages.dart` hoists its literals.
  static const String _undefinedTable = '42P01'; // i18n-ignore — SQLSTATE
  static const String _relationWord = 'relation'; // i18n-ignore — PG message
  static const String _missingWord = 'does not exist'; // i18n-ignore — PG

  static bool _isMissingRelation(PostgrestException e) =>
      e.code == _undefinedTable ||
      (e.message.contains(_relationWord) && e.message.contains(_missingWord));

  /// Runs [body], turning a missing schema into [fallback] and letting
  /// every other failure through.
  ///
  /// A swallow-everything wrapper would hide a broken policy as an empty
  /// list, which is the worst possible failure for a feature whose whole
  /// job is showing the right people the right things.
  Future<T> _guard<T>(Future<T> Function() body, T fallback) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        _available = false;
        return fallback;
      }
      rethrow;
    }
  }

  // ─── profiles ────────────────────────────────────────────────────

  /// The caller's own profile, or null when they have not made one.
  ///
  /// Null is the common case and it is not an error: the roadmap's rule
  /// is that a user who never touches community sees no change, and no
  /// row is what that looks like.
  Future<CommunityProfile?> myProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    return _guard(() async {
      final row = await _client
          .from('public_profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return row == null ? null : CommunityProfile.fromJson(row);
    }, null);
  }

  /// Somebody else's profile, by handle.
  ///
  /// Returns null for a handle that does not exist **and** for one that
  /// exists but is not visible to this caller — RLS makes those
  /// indistinguishable from here, which is the correct behaviour: a
  /// "this profile is private" message is a confirmation that the handle
  /// is taken.
  Future<CommunityProfile?> profileByHandle(String handle) => _guard(() async {
        final row = await _client
            .from('public_profiles')
            .select()
            .eq('handle', handle.toLowerCase())
            .maybeSingle();
        return row == null ? null : CommunityProfile.fromJson(row);
      }, null);

  /// Creates or updates the caller's profile.
  ///
  /// `upsert` rather than insert-then-update: a user who taps Save twice
  /// should get one profile, and the primary key already makes that the
  /// database's opinion too.
  Future<CommunityProfile?> saveProfile({
    required String displayName,
    required String handle,
    required ProfileVisibility visibility,
    String? avatarRef,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    return _guard(() async {
      final row = await _client
          .from('public_profiles')
          .upsert({
            'user_id': uid,
            'display_name': displayName.trim(),
            'handle': handle.trim().toLowerCase(),
            'avatar_ref': avatarRef,
            ...visibility.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return CommunityProfile.fromJson(row);
    }, null);
  }

  /// Display names for a set of user ids, for rendering a friend list
  /// without a row-by-row lookup.
  ///
  /// **Silently omits ids RLS will not return** — a friend whose profile
  /// is private, or who has blocked the caller since. The screen falls
  /// back to the handle-less placeholder rather than showing an empty
  /// row, because a friendship that exists with somebody you cannot see
  /// is a real state and hiding the row would make "remove" unreachable.
  Future<Map<String, CommunityProfile>> profilesByIds(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return const {};
    return _guard(() async {
      final rows = await _client
          .from('public_profiles')
          .select()
          .inFilter('user_id', ids);
      return {
        for (final row in rows)
          (row as Map)['user_id'] as String:
              CommunityProfile.fromJson(row.cast<String, dynamic>()),
      };
    }, const <String, CommunityProfile>{});
  }

  Future<void> deleteProfile() async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      await _client.from('public_profiles').delete().eq('user_id', uid);
    }, null);
  }

  // ─── friends ─────────────────────────────────────────────────────

  /// Every friendship the caller is party to, in either direction and
  /// any state. The caller filters; the repository does not decide what
  /// "my friends" means.
  Future<List<Friendship>> friendships() async {
    final uid = _uid;
    if (uid == null) return const [];
    return _guard(() async {
      final rows = await _client
          .from('friendships')
          .select()
          .or('user_a.eq.$uid,user_b.eq.$uid');
      return [
        for (final row in rows) _friendshipFrom(row),
      ];
    }, const <Friendship>[]);
  }

  Future<void> requestFriend(String otherUserId) async {
    final uid = _uid;
    if (uid == null) return;
    // The ordering the table's `check (user_a < user_b)` requires. Done
    // here rather than trusted to the caller so a screen cannot produce
    // a row the constraint rejects.
    final a = uid.compareTo(otherUserId) <= 0 ? uid : otherUserId;
    final b = uid.compareTo(otherUserId) <= 0 ? otherUserId : uid;
    await _guard(() async {
      await _client.from('friendships').insert({
        'user_a': a,
        'user_b': b,
        'requester_id': uid,
        'status': FriendshipStatus.pending.token,
      });
    }, null);
  }

  Future<void> respondToFriend({
    required String otherUserId,
    required bool accept,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final a = uid.compareTo(otherUserId) <= 0 ? uid : otherUserId;
    final b = uid.compareTo(otherUserId) <= 0 ? otherUserId : uid;
    await _guard(() async {
      await _client
          .from('friendships')
          .update({
            'status': accept
                ? FriendshipStatus.accepted.token
                : FriendshipStatus.declined.token,
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_a', a)
          .eq('user_b', b);
    }, null);
  }

  Future<void> removeFriend(String otherUserId) async {
    final uid = _uid;
    if (uid == null) return;
    final a = uid.compareTo(otherUserId) <= 0 ? uid : otherUserId;
    final b = uid.compareTo(otherUserId) <= 0 ? otherUserId : uid;
    await _guard(() async {
      await _client
          .from('friendships')
          .delete()
          .eq('user_a', a)
          .eq('user_b', b);
    }, null);
  }

  static Friendship _friendshipFrom(Map<String, dynamic> row) => Friendship(
        userA: row['user_a'] as String,
        userB: row['user_b'] as String,
        requesterId: row['requester_id'] as String,
        status: FriendshipStatus.fromToken(row['status'] as String?),
      );

  // ─── squads ──────────────────────────────────────────────────────

  /// Squads the caller is in, with their member counts.
  Future<List<Squad>> mySquads() async {
    final uid = _uid;
    if (uid == null) return const [];
    return _guard(() async {
      final memberships =
          await _client.from('squad_members').select('squad_id').eq(
                'user_id',
                uid,
              );
      final ids = [
        for (final row in memberships) (row as Map)['squad_id'] as String,
      ];
      if (ids.isEmpty) return const <Squad>[];

      final squads = await _client.from('squads').select().inFilter('id', ids);
      final counts = <String, int>{};
      final members =
          await _client.from('squad_members').select('squad_id').inFilter(
                'squad_id',
                ids,
              );
      for (final row in members) {
        final id = (row as Map)['squad_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }

      return [
        for (final row in squads)
          Squad(
            id: (row as Map)['id'] as String,
            name: row['name'] as String,
            ownerId: row['owner_id'] as String,
            inviteCode: row['invite_code'] as String,
            memberCount: counts[row['id']] ?? 1,
          ),
      ];
    }, const <Squad>[]);
  }

  /// Creates a squad and puts the caller in it as owner.
  ///
  /// Two statements rather than a function, unlike joining — there is no
  /// race here, because nobody else can be creating this squad.
  Future<Squad?> createSquad({
    required String name,
    required String inviteCode,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    return _guard(() async {
      final row = await _client
          .from('squads')
          .insert({
            'name': name.trim(),
            'owner_id': uid,
            'invite_code': inviteCode.toUpperCase(),
          })
          .select()
          .single();
      await _client.from('squad_members').insert({
        'squad_id': row['id'],
        'user_id': uid,
        'role': 'owner',
      });
      return Squad(
        id: row['id'] as String,
        name: row['name'] as String,
        ownerId: row['owner_id'] as String,
        inviteCode: row['invite_code'] as String,
        memberCount: 1,
      );
    }, null);
  }

  /// Joins by invite code.
  ///
  /// Goes through the `join_squad` RPC rather than a select-then-insert:
  /// the size cap has to be checked and the row written in one statement
  /// or two people joining a squad of eleven both succeed. It also
  /// resolves the code without a select policy that would expose every
  /// squad to every user. See the migration.
  Future<String?> joinSquad(String inviteCode) => _guard(() async {
        final id = await _client.rpc(
          'join_squad',
          params: {'p_invite_code': inviteCode.trim().toUpperCase()},
        );
        return id as String?;
      }, null);

  Future<void> leaveSquad(String squadId) async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      await _client
          .from('squad_members')
          .delete()
          .eq('squad_id', squadId)
          .eq('user_id', uid);
    }, null);
  }

  // ─── feed ────────────────────────────────────────────────────────

  /// A squad's recent activity, newest first, with actor names and
  /// reaction counts resolved.
  ///
  /// Names are joined at read time rather than stored on the event, so a
  /// rename is not retroactively wrong across a whole feed.
  Future<List<ActivityEvent>> feed(String squadId, {int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const [];
    return _guard(() async {
      final rows = await _client
          .from('activity_events')
          .select()
          .eq('squad_id', squadId)
          .order('created_at', ascending: false)
          .limit(limit);
      if (rows.isEmpty) return const <ActivityEvent>[];

      final ids = [for (final row in rows) (row as Map)['id'] as String];
      final actorIds = {
        for (final row in rows) (row as Map)['actor_id'] as String,
      }.toList();

      final profiles = await _client
          .from('public_profiles')
          .select('user_id, display_name')
          .inFilter('user_id', actorIds);
      final names = {
        for (final row in profiles)
          (row as Map)['user_id'] as String: row['display_name'] as String,
      };

      final reactions = await _client
          .from('activity_reactions')
          .select('event_id, user_id, reaction')
          .inFilter('event_id', ids);
      final counts = <String, Map<String, int>>{};
      final mine = <String, String>{};
      for (final row in reactions) {
        final map = row as Map;
        final eventId = map['event_id'] as String;
        final reaction = map['reaction'] as String;
        (counts[eventId] ??= <String, int>{})
            .update(reaction, (n) => n + 1, ifAbsent: () => 1);
        if (map['user_id'] == uid) mine[eventId] = reaction;
      }

      final events = <ActivityEvent>[];
      for (final row in rows) {
        final map = row;
        final kind = ActivityKind.fromToken(map['kind'] as String?);
        // An unknown kind is a newer client's event. Dropped rather than
        // rendered as something it is not.
        if (kind == null) continue;
        final id = map['id'] as String;
        events.add(ActivityEvent(
          id: id,
          squadId: map['squad_id'] as String,
          actorId: map['actor_id'] as String,
          kind: kind,
          createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
          value: map['value'] as int?,
          token: map['token'] as String?,
          actorName: names[map['actor_id']],
          reactions: counts[id] ?? const {},
          myReaction: mine[id],
        ));
      }
      return events;
    }, const <ActivityEvent>[]);
  }

  /// Writes an event into every squad the caller is in.
  ///
  /// **Silently does nothing when they are in none**, which is the
  /// common case and is the point: the roadmap's rule is that a user who
  /// never touches community sees no change, and that has to include not
  /// paying for a write nobody can read.
  Future<void> recordActivity({
    required ActivityKind kind,
    int? value,
    String? token,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (!await isAvailable()) return;
    await _guard(() async {
      final memberships = await _client
          .from('squad_members')
          .select('squad_id')
          .eq('user_id', uid);
      if (memberships.isEmpty) return;
      await _client.from('activity_events').insert([
        for (final row in memberships)
          {
            'squad_id': (row as Map)['squad_id'],
            'actor_id': uid,
            'kind': kind.token,
            if (value != null) 'value': value,
            if (token != null) 'token': token,
          },
      ]);
    }, null);
  }

  /// Sets or clears the caller's reaction to an event.
  ///
  /// Passing the reaction already set clears it — a tap on a lit button
  /// is how people expect to take it back, and a separate "remove"
  /// affordance for three small buttons is clutter.
  Future<void> react({
    required String eventId,
    required FeedReaction? reaction,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      if (reaction == null) {
        await _client
            .from('activity_reactions')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', uid);
        return;
      }
      await _client.from('activity_reactions').upsert({
        'event_id': eventId,
        'user_id': uid,
        'reaction': reaction.token,
      });
    }, null);
  }

  // ─── safety ──────────────────────────────────────────────────────

  /// Ids the caller has blocked.
  ///
  /// Only one direction is readable, by design: the policy lets a
  /// blocker see their own blocks and nobody see who blocked them. The
  /// symmetric *effect* is enforced server-side in every read policy, so
  /// the client never needs the other half.
  Future<Set<String>> blockedIds() async {
    final uid = _uid;
    if (uid == null) return const {};
    return _guard(() async {
      final rows = await _client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return {for (final row in rows) (row as Map)['blocked_id'] as String};
    }, const <String>{});
  }

  Future<void> block(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      await _client
          .from('blocks')
          .upsert({'blocker_id': uid, 'blocked_id': userId});
      // A block ends the friendship. Leaving the row would mean an
      // accepted friendship with somebody invisible to you, which is a
      // state no screen knows how to draw.
      final a = uid.compareTo(userId) <= 0 ? uid : userId;
      final b = uid.compareTo(userId) <= 0 ? userId : uid;
      await _client
          .from('friendships')
          .delete()
          .eq('user_a', a)
          .eq('user_b', b);
    }, null);
  }

  Future<void> unblock(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      await _client
          .from('blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', userId);
    }, null);
  }

  Future<void> report({
    required String userId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _guard(() async {
      await _client.from('user_reports').insert({
        'reporter_id': uid,
        'reported_id': userId,
        'reason': reason,
      });
    }, null);
  }
}

/// A profile as stored. Kept here rather than in the domain because it
/// is a row shape — the RULES are in `community_models.dart` and have no
/// opinion about columns.
class CommunityProfile {
  const CommunityProfile({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.visibility,
    this.avatarRef,
    this.moderationApproved = true,
  });

  final String userId;
  final String displayName;
  final String handle;
  final ProfileVisibility visibility;
  final String? avatarRef;
  final bool moderationApproved;

  factory CommunityProfile.fromJson(Map<String, dynamic> json) =>
      CommunityProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        visibility: ProfileVisibility.fromJson(json),
        avatarRef: json['avatar_ref'] as String?,
        // Anything other than an explicit 'approved' is treated as not
        // approved. A null from an older row, a typo, a new state a
        // later build adds — all of them should hide a profile rather
        // than publish it.
        moderationApproved: json['moderation_state'] == 'approved',
      );
}

// ─── Roadmap Phase 13 (C23 · C25 · R6) · leaderboards ──────────────
//
// On this class rather than a `LeaderboardRepository` of its own,
// because `_guard`, `_isMissingRelation` and the `_available` cache are
// already here and a second repository would be a second, subtly
// different answer to "is the schema applied?". Phase 12 made the same
// call for its four tables and the reasoning has not changed.
extension LeaderboardQueries on CommunityRepository {
  /// Writes this week's numbers for the signed-in user.
  ///
  /// **Creating the row is the opt-in and deleting it is the opt-out** —
  /// there is no flag, per `020`'s header. So this is only ever called
  /// from an explicit user action, never on a timer and never as a side
  /// effect of finishing a workout.
  ///
  /// The values are clamped with [clampWeek] before they are sent, so a
  /// user sees the same number the board will show rather than an error
  /// about a constraint they cannot read.
  Future<bool> publishWeek({
    required int xp,
    required int sessions,
    required int streak,
    required int consistency,
    DateTime? asOf,
  }) async {
    final uid = currentUserId;
    if (uid == null) return false;
    if (!await isAvailable()) return false;
    final week = weekStartUtc(asOf ?? DateTime.now());
    final safe = clampWeek(
      xp: xp,
      sessions: sessions,
      streak: streak,
      consistency: consistency,
    );
    return _guard(() async {
      await _client.from('leaderboard_stats').upsert({
        'user_id': uid,
        'week_start': _dateOnly(week),
        'weekly_xp': safe.xp,
        'sessions': safe.sessions,
        'streak_days': safe.streak,
        'consistency': safe.consistency,
      });
      return true;
    }, false);
  }

  /// Removes the caller from every board, past and present.
  ///
  /// Loses no progress: the numbers that matter live on the device, and
  /// that is exactly why the roadmap's "withdraw without losing
  /// progress" is satisfied by a delete.
  Future<void> leaveLeaderboards() async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!await isAvailable()) return;
    await _guard(() async {
      await _client.from('leaderboard_stats').delete().eq('user_id', uid);
      return null;
    }, null);
  }

  /// Whether the caller currently appears on any board.
  Future<bool> isOnLeaderboards() async {
    final uid = currentUserId;
    if (uid == null) return false;
    if (!await isAvailable()) return false;
    return _guard(() async {
      final rows = await _client
          .from('leaderboard_stats')
          .select('user_id')
          .eq('user_id', uid)
          .limit(1);
      return rows.isNotEmpty;
    }, false);
  }

  /// This week's board at [scope], ordered by [metric], best first.
  ///
  /// Names are resolved in a second query against `public_profiles`,
  /// which returns only the profiles RLS lets this caller see. **A row
  /// whose name does not come back keeps its rank and loses its name** —
  /// that is the pseudonymity the roadmap asks for, and it needs no
  /// field of its own.
  Future<List<LeaderboardEntry>> board({
    required LeaderboardScope scope,
    LeaderboardMetric metric = LeaderboardMetric.consistency,
    DateTime? asOf,
    int limit = 50,
  }) async {
    if (!await isAvailable()) return const [];
    final week = _dateOnly(weekStartUtc(asOf ?? DateTime.now()));
    return _guard(() async {
      final scoped = await _idsInScope(scope);
      // An empty scope is an empty board rather than a global one. A
      // user with no squad must not silently be shown the world.
      if (scoped != null && scoped.isEmpty) return const <LeaderboardEntry>[];

      var query = _client
          .from('leaderboard_stats')
          .select('user_id, weekly_xp, sessions, streak_days, consistency')
          .eq('week_start', week);
      if (scoped != null) query = query.inFilter('user_id', scoped.toList());

      final rows =
          await query.order(metric.column, ascending: false).limit(limit);
      final entries = <LeaderboardEntry>[];
      for (final row in rows) {
        final entry = LeaderboardEntry.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (entry != null) entries.add(entry);
      }
      if (entries.isEmpty) return entries;

      final names = await _namesFor(entries.map((e) => e.userId).toList());
      return [
        for (final e in entries)
          LeaderboardEntry(
            userId: e.userId,
            weeklyXp: e.weeklyXp,
            sessions: e.sessions,
            streakDays: e.streakDays,
            consistency: e.consistency,
            displayName: names[e.userId],
          ),
      ];
    }, const <LeaderboardEntry>[]);
  }

  /// The user ids a scope covers, or null for "everybody".
  Future<Set<String>?> _idsInScope(LeaderboardScope scope) async {
    final uid = currentUserId;
    if (uid == null) return <String>{};
    switch (scope) {
      case LeaderboardScope.global:
        return null;
      case LeaderboardScope.friends:
        final rows = await friendships();
        return {
          uid,
          for (final f in rows)
            if (f.isMutual && f.otherThan(uid) != null) f.otherThan(uid)!,
        };
      case LeaderboardScope.squad:
        final squads = await mySquads();
        if (squads.isEmpty) return <String>{};
        final members = await _client
            .from('squad_members')
            .select('user_id')
            .inFilter('squad_id', [for (final s in squads) s.id]);
        return {
          uid,
          for (final row in members) (row as Map)['user_id'] as String,
        };
    }
  }

  /// Display names for [ids], for whichever of them RLS will serve.
  Future<Map<String, String>> _namesFor(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('public_profiles')
        .select('user_id, display_name')
        .inFilter('user_id', ids);
    return {
      for (final row in rows)
        (row as Map)['user_id'] as String: row['display_name'] as String,
    };
  }

  /// Challenges whose window has not closed, soonest to end first.
  Future<List<Challenge>> challenges({DateTime? asOf}) async {
    if (!await isAvailable()) return const [];
    final now = (asOf ?? DateTime.now()).toUtc();
    return _guard(() async {
      final rows = await _client
          .from('challenges')
          .select()
          .gte('ends_at', now.toIso8601String())
          .order('ends_at');
      final out = <Challenge>[];
      for (final row in rows) {
        final challenge =
            Challenge.fromJson(Map<String, dynamic>.from(row as Map));
        if (challenge != null) out.add(challenge);
      }
      return out;
    }, const <Challenge>[]);
  }

  /// The caller's own entries, keyed by challenge id.
  Future<Map<String, ChallengeEntry>> myChallengeEntries() async {
    final uid = currentUserId;
    if (uid == null) return const {};
    if (!await isAvailable()) return const {};
    return _guard(() async {
      final rows = await _client
          .from('challenge_participants')
          .select()
          .eq('user_id', uid);
      final out = <String, ChallengeEntry>{};
      for (final row in rows) {
        final entry =
            ChallengeEntry.fromJson(Map<String, dynamic>.from(row as Map));
        if (entry != null) out[entry.challengeId] = entry;
      }
      return out;
    }, const <String, ChallengeEntry>{});
  }

  /// Joins [challenge], or does nothing if its window has closed.
  Future<bool> joinChallenge(Challenge challenge, {String? squadId}) async {
    final uid = currentUserId;
    if (uid == null) return false;
    if (!await isAvailable()) return false;
    // Checked here as well as by the screen, because a challenge can
    // close between the frame being drawn and the button being pressed,
    // and a join that earns nothing is worse than a refusal.
    if (!challenge.isOpen(DateTime.now())) return false;
    return _guard(() async {
      await _client.from('challenge_participants').upsert({
        'challenge_id': challenge.id,
        'user_id': uid,
        if (squadId != null) 'squad_id': squadId,
      });
      return true;
    }, false);
  }

  /// Leaves [challengeId]. Progress is discarded — a challenge is a
  /// commitment rather than a score, and half of one means nothing.
  Future<void> leaveChallenge(String challengeId) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!await isAvailable()) return;
    await _guard(() async {
      await _client
          .from('challenge_participants')
          .delete()
          .eq('challenge_id', challengeId)
          .eq('user_id', uid);
      return null;
    }, null);
  }

  /// Writes progress for a challenge the caller has joined, marking it
  /// complete the first time it reaches the target.
  Future<void> reportChallengeProgress({
    required Challenge challenge,
    required int progress,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    if (!await isAvailable()) return;
    final done = progress >= challenge.target;
    await _guard(() async {
      await _client
          .from('challenge_participants')
          .update({
            'progress': progress,
            // Only ever set, never cleared: finishing a challenge is not
            // something a later smaller number should undo.
            if (done) 'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('challenge_id', challenge.id)
          .eq('user_id', uid);
      return null;
    }, null);
  }

  /// The shared board for one challenge, furthest along first.
  Future<List<ChallengeEntry>> challengeBoard(String challengeId,
      {int limit = 50}) async {
    if (!await isAvailable()) return const [];
    return _guard(() async {
      final rows = await _client
          .from('challenge_participants')
          .select()
          .eq('challenge_id', challengeId)
          .order('progress', ascending: false)
          .limit(limit);
      final entries = <ChallengeEntry>[];
      for (final row in rows) {
        final entry =
            ChallengeEntry.fromJson(Map<String, dynamic>.from(row as Map));
        if (entry != null) entries.add(entry);
      }
      if (entries.isEmpty) return entries;
      final names = await _namesFor(entries.map((e) => e.userId).toList());
      return [
        for (final e in entries)
          ChallengeEntry(
            challengeId: e.challengeId,
            userId: e.userId,
            progress: e.progress,
            completedAt: e.completedAt,
            displayName: names[e.userId],
          ),
      ];
    }, const <ChallengeEntry>[]);
  }

  /// A `date` column wants a date, not an instant.
  String _dateOnly(DateTime day) =>
      day.toIso8601String().split('T').first; // i18n-ignore — ISO date
}

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) => CommunityRepository());

/// The signed-in user's id, as its own provider.
///
/// Separated from the repository so a screen that needs to know which
/// side of a friendship it is on does not have to construct a Supabase
/// client to find out — which is also what makes those screens testable
/// without booting Supabase. Null when signed out, which every consumer
/// already has to handle.
final currentCommunityUserIdProvider = Provider<String?>(
  (ref) => ref.watch(communityRepositoryProvider).currentUserId,
);

/// Whether the schema is applied. Watched by every community entry point
/// so an unapplied migration renders "not available yet" rather than a
/// dead button.
final communityAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(communityRepositoryProvider).isAvailable(),
);

final myProfileProvider = FutureProvider<CommunityProfile?>(
  (ref) => ref.watch(communityRepositoryProvider).myProfile(),
);

final myFriendshipsProvider = FutureProvider<List<Friendship>>(
  (ref) => ref.watch(communityRepositoryProvider).friendships(),
);

final mySquadsProvider = FutureProvider<List<Squad>>(
  (ref) => ref.watch(communityRepositoryProvider).mySquads(),
);

/// Whether the caller appears on any leaderboard. Watched by the opt-in
/// control, which is the only thing that changes it.
final onLeaderboardsProvider = FutureProvider<bool>(
  (ref) => ref.watch(communityRepositoryProvider).isOnLeaderboards(),
);

final openChallengesProvider = FutureProvider<List<Challenge>>(
  (ref) => ref.watch(communityRepositoryProvider).challenges(),
);

final myChallengeEntriesProvider = FutureProvider<Map<String, ChallengeEntry>>(
  (ref) => ref.watch(communityRepositoryProvider).myChallengeEntries(),
);
