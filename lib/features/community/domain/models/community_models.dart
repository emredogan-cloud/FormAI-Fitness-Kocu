/// Roadmap Phase 12 (R6, C22, C24, C47) · identity, friends and squads,
/// as data and rules.
///
/// **Everything here is pure.** No Supabase, no providers, no
/// `DateTime.now()`. The roadmap calls the RLS layer "the highest-risk
/// area in the roadmap"; the second-highest is this file, because a
/// visibility rule that is only enforced in a policy is a rule nobody
/// can read, and one that is only enforced in a widget is a rule an
/// attacker skips. They are written twice on purpose — the policy is the
/// boundary, this is the explanation — and they are tested here because
/// this is the half that can be.
library;

/// Which of a profile's fields the viewer may see.
///
/// Three independent booleans rather than one `public | friends |
/// private` enum, matching the columns in `019_social_profiles.sql`. A
/// single enum forces somebody who wants their level shown but their
/// session count hidden to pick between two things they do not want, and
/// the roadmap asks for "granular field-level visibility control".
class ProfileVisibility {
  const ProfileVisibility({
    this.isPublic = false,
    this.showBadges = false,
    this.showStats = false,
  });

  /// The default, and the default matters: creating a profile is not
  /// publishing one.
  static const ProfileVisibility private = ProfileVisibility();

  final bool isPublic;
  final bool showBadges;
  final bool showStats;

  ProfileVisibility copyWith({
    bool? isPublic,
    bool? showBadges,
    bool? showStats,
  }) =>
      ProfileVisibility(
        isPublic: isPublic ?? this.isPublic,
        showBadges: showBadges ?? this.showBadges,
        showStats: showStats ?? this.showStats,
      );

  Map<String, dynamic> toJson() => {
        'is_public': isPublic,
        'show_badges': showBadges,
        'show_stats': showStats,
      };

  factory ProfileVisibility.fromJson(Map<String, dynamic> json) =>
      ProfileVisibility(
        isPublic: json['is_public'] == true,
        showBadges: json['show_badges'] == true,
        showStats: json['show_stats'] == true,
      );
}

/// What a particular viewer is allowed to see of a particular profile.
///
/// The resolution has an order and the order is the point: **a block
/// beats everything**, then ownership, then publication. Getting that
/// order wrong is how a blocked user keeps seeing a profile because they
/// were also a friend.
class ResolvedProfileView {
  const ResolvedProfileView({
    required this.canSeeProfile,
    required this.canSeeBadges,
    required this.canSeeStats,
  });

  static const ResolvedProfileView hidden = ResolvedProfileView(
    canSeeProfile: false,
    canSeeBadges: false,
    canSeeStats: false,
  );

  final bool canSeeProfile;
  final bool canSeeBadges;
  final bool canSeeStats;

  /// Resolves what [viewerId] may see of [ownerId]'s profile.
  ///
  /// [blockedEitherWay] is a single flag rather than two because a block
  /// is symmetric by design: the roadmap requires it to "fully sever
  /// visibility both ways", so the blocker disappears from the blocked
  /// user's view as well as the reverse. Passing one direction would let
  /// somebody keep watching a profile that had blocked them.
  ///
  /// [moderationApproved] gates everything except the owner's own view.
  /// A name awaiting review is visible to the person who typed it and to
  /// nobody else — otherwise moderation is a delay rather than a gate.
  static ResolvedProfileView resolve({
    required String viewerId,
    required String ownerId,
    required ProfileVisibility visibility,
    required bool blockedEitherWay,
    bool moderationApproved = true,
  }) {
    // 1. A block beats every other rule, including ownership of a
    //    friendship and including publication.
    if (blockedEitherWay) return hidden;

    // 2. The owner always sees their own profile whole, including while
    //    it is pending moderation — otherwise they cannot see what they
    //    submitted or fix what was rejected.
    if (viewerId == ownerId) {
      return const ResolvedProfileView(
        canSeeProfile: true,
        canSeeBadges: true,
        canSeeStats: true,
      );
    }

    // 3. Everyone else needs publication AND clearance.
    if (!visibility.isPublic || !moderationApproved) return hidden;

    return ResolvedProfileView(
      canSeeProfile: true,
      canSeeBadges: visibility.showBadges,
      canSeeStats: visibility.showStats,
    );
  }
}

/// Where a friendship is.
///
/// `declined` is kept rather than deleted so a declined request cannot
/// be re-sent immediately — the row is the record that the answer was
/// no. Un-declining is deleting the row, which is an explicit act.
enum FriendshipStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  const FriendshipStatus(this.token);

  final String token;

  static FriendshipStatus fromToken(String? token) {
    for (final status in FriendshipStatus.values) {
      if (status.token == token) return status;
    }
    return FriendshipStatus.pending;
  }
}

/// One friendship, as one row.
///
/// **One row per pair, not two.** The mirrored-rows schema makes every
/// query trivially "where user_id = me" and makes a half-written
/// friendship possible, because two rows are two writes and the second
/// can fail. The ordered pair is atomic by construction, which is why
/// [userA] is always the lexicographically smaller id — the same
/// invariant the migration enforces with `check (user_a < user_b)`.
class Friendship {
  Friendship({
    required String userA,
    required String userB,
    required this.requesterId,
    required this.status,
  })  : userA = userA.compareTo(userB) <= 0 ? userA : userB,
        userB = userA.compareTo(userB) <= 0 ? userB : userA,
        assert(userA != userB, 'a friendship needs two people');

  final String userA;
  final String userB;

  /// Who asked. NOT derivable from the ordering, which is why it is its
  /// own field: "accept" is offered only to the other party.
  final String requesterId;

  final FriendshipStatus status;

  bool involves(String userId) => userId == userA || userId == userB;

  /// The other party, or null when [userId] is not in this friendship.
  String? otherThan(String userId) {
    if (userId == userA) return userB;
    if (userId == userB) return userA;
    return null;
  }

  /// True when [userId] is the one being asked, and the answer is still
  /// outstanding.
  ///
  /// The requester seeing an "Accept" button on their own request is the
  /// bug this exists to prevent, and it is a one-character mistake to
  /// make in a widget.
  bool canRespond(String userId) =>
      status == FriendshipStatus.pending &&
      involves(userId) &&
      userId != requesterId;

  /// True when the two are actually friends. Convenience, and named as a
  /// question so call sites read as one.
  bool get isMutual => status == FriendshipStatus.accepted;
}

/// The rules for adding somebody.
abstract final class FriendRules {
  /// Why a request cannot be sent, or null when it can.
  ///
  /// Returns a REASON rather than a bool so the UI can say which wall it
  /// hit. Every branch here is also enforced by a policy or a constraint
  /// in `019_social_profiles.sql`; this is the half that can explain
  /// itself.
  static FriendRequestBlockReason? cannotRequest({
    required String fromUserId,
    required String toUserId,
    required bool blockedEitherWay,
    Friendship? existing,
  }) {
    if (fromUserId == toUserId) return FriendRequestBlockReason.self;
    if (blockedEitherWay) return FriendRequestBlockReason.blocked;
    if (existing == null) return null;
    return switch (existing.status) {
      FriendshipStatus.accepted => FriendRequestBlockReason.alreadyFriends,
      FriendshipStatus.pending => FriendRequestBlockReason.alreadyPending,
      // A declined request is not re-sendable while the row stands. The
      // person said no; the app does not let somebody ask again by
      // tapping twice.
      FriendshipStatus.declined => FriendRequestBlockReason.previouslyDeclined,
    };
  }
}

enum FriendRequestBlockReason {
  self,
  blocked,
  alreadyFriends,
  alreadyPending,
  previouslyDeclined,
}

/// A squad, and its one hard limit.
class Squad {
  const Squad({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.memberCount,
  });

  /// The roadmap's cap, and a product decision rather than a technical
  /// one: small groups outperform global feeds for accountability, and
  /// twelve is small enough that a silent member is noticed.
  static const int maxMembers = 12;

  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final int memberCount;

  bool get isFull => memberCount >= maxMembers;

  bool isOwner(String userId) => userId == ownerId;

  /// Why [userId] cannot join, or null when they can.
  ///
  /// The client checks this to render an honest button; the server
  /// re-checks it inside `join_squad()`, where the count and the insert
  /// happen in one statement so two people joining a squad of eleven
  /// cannot both succeed. **This check is the courtesy, that one is the
  /// guarantee** — never the other way round.
  SquadJoinBlockReason? cannotJoin({
    required String userId,
    required bool alreadyMember,
  }) {
    if (alreadyMember) return SquadJoinBlockReason.alreadyMember;
    if (isFull) return SquadJoinBlockReason.full;
    return null;
  }
}

enum SquadJoinBlockReason { alreadyMember, full }

/// What happened. The token, never the sentence — copy lives in ARB, the
/// rule the recipe tags learned in Phase 7.
enum ActivityKind {
  workoutCompleted('workout_completed'),
  badgeEarned('badge_earned'),
  levelUp('level_up'),
  streakMilestone('streak_milestone');

  const ActivityKind(this.token);

  final String token;

  static ActivityKind? fromToken(String? token) {
    for (final kind in ActivityKind.values) {
      if (kind.token == token) return kind;
    }
    // Null rather than a default: an unknown kind is a newer client's
    // event, and rendering it as a workout would be inventing news.
    return null;
  }
}

/// A stat a shared profile card may carry.
///
/// The card's contents are a pure function of the owner's visibility
/// flags — see [profileCardStats] — rather than an inline condition at
/// the share button, because "what may leave the device as an image" is
/// exactly the kind of rule that should be readable and tested in one
/// place instead of inferred from a widget.
enum ProfileCardStat { level, workouts, streak, badges }

/// Which stats [visibility] permits on a shared card, in card order.
///
/// A user who turned stats off has said they do not want their numbers
/// out there. An image is the one surface where that cannot be taken
/// back afterwards, so it is the last place to make an exception. An
/// empty result is valid: name, handle and branding is still a card.
List<ProfileCardStat> profileCardStats(ProfileVisibility visibility) => [
      if (visibility.showStats) ...[
        ProfileCardStat.level,
        ProfileCardStat.workouts,
        ProfileCardStat.streak,
      ],
      if (visibility.showBadges) ProfileCardStat.badges,
    ];

/// One event in a squad's feed.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.squadId,
    required this.actorId,
    required this.kind,
    required this.createdAt,
    this.value,
    this.token,
    this.actorName,
    this.reactions = const {},
    this.myReaction,
  });

  final String id;
  final String squadId;
  final String actorId;
  final ActivityKind kind;
  final DateTime createdAt;

  /// The one number the copy needs — a day number, a streak length, a
  /// level.
  final int? value;

  /// A stable badge id when [kind] is [ActivityKind.badgeEarned]. Ids
  /// are persisted; labels are not.
  final String? token;

  /// Resolved at read time from `public_profiles`, never stored on the
  /// event — so a rename is not retroactively wrong across a whole feed.
  final String? actorName;

  /// reaction token → count.
  final Map<String, int> reactions;

  /// What this viewer already reacted, if anything. Drives the toggle.
  final String? myReaction;
}

/// The reactions a feed offers. Deliberately three, deliberately no free
/// text: the roadmap notes reactions deliver "most of the social
/// reinforcement with a fraction of the moderation risk", and there is
/// no text column in `activity_reactions` to moderate.
enum FeedReaction {
  cheer('cheer'),
  strong('strong'),
  fire('fire');

  const FeedReaction(this.token);

  final String token;

  static FeedReaction? fromToken(String? token) {
    for (final reaction in FeedReaction.values) {
      if (reaction.token == token) return reaction;
    }
    return null;
  }
}
