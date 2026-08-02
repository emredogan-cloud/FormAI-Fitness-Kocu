import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/models/community_models.dart';

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

  /// Postgres's undefined_table. Matched on the code rather than the
  /// message, which is localised on some deployments.
  static bool _isMissingRelation(PostgrestException e) =>
      e.code == '42P01' ||
      (e.message.contains('relation') && e.message.contains('does not exist'));

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

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) => CommunityRepository());

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
