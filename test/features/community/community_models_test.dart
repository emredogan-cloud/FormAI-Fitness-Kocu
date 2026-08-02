import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';

/// Roadmap Phase 12 (R6, C22, C24) · the rules, unit-tested.
///
/// The roadmap asks for "unit: friendship state machine, squad
/// membership rules, visibility resolution" and separately calls the
/// security layer the highest-risk area in the whole plan. These rules
/// are written twice on purpose — once as RLS in
/// `019_social_profiles.sql`, once here — and this is the half that can
/// be executed, so it carries the adversarial cases.
void main() {
  const me = 'user-a';
  const them = 'user-b';

  group('visibility resolution', () {
    ResolvedProfileView resolve({
      String viewer = them,
      ProfileVisibility visibility = ProfileVisibility.private,
      bool blocked = false,
      bool approved = true,
    }) =>
        ResolvedProfileView.resolve(
          viewerId: viewer,
          ownerId: me,
          visibility: visibility,
          blockedEitherWay: blocked,
          moderationApproved: approved,
        );

    test('a fresh profile is invisible to everybody but its owner', () {
      expect(resolve().canSeeProfile, isFalse);
      expect(resolve(viewer: me).canSeeProfile, isTrue);
    });

    test('creating a profile is not publishing one', () {
      // Every flag on ProfileVisibility() defaults false. If that ever
      // changes, a user who merely picked a display name becomes public.
      const fresh = ProfileVisibility();
      expect(fresh.isPublic, isFalse);
      expect(fresh.showBadges, isFalse);
      expect(fresh.showStats, isFalse);
    });

    test('publication is not the same as publishing every field', () {
      final view = resolve(
        visibility: const ProfileVisibility(isPublic: true, showBadges: true),
      );

      expect(view.canSeeProfile, isTrue);
      expect(view.canSeeBadges, isTrue);
      expect(view.canSeeStats, isFalse, reason: 'stats were never switched on');
    });

    // The ordering test. A block has to beat every other rule, and the
    // way this goes wrong in real products is that friendship or
    // publication is checked first and wins.
    test('a block beats publication', () {
      const wideOpen = ProfileVisibility(
        isPublic: true,
        showBadges: true,
        showStats: true,
      );

      expect(resolve(visibility: wideOpen).canSeeProfile, isTrue);
      expect(
          resolve(visibility: wideOpen, blocked: true).canSeeProfile, isFalse);
      expect(
          resolve(visibility: wideOpen, blocked: true).canSeeBadges, isFalse);
      expect(resolve(visibility: wideOpen, blocked: true).canSeeStats, isFalse);
    });

    test(
        'a block beats even the owner — the flag is symmetric, so this '
        'is what a blocked-by-me profile looks like to me', () {
      expect(resolve(viewer: me, blocked: true).canSeeProfile, isFalse);
    });

    test(
        'a name awaiting moderation is visible to nobody but the person '
        'who typed it', () {
      const published = ProfileVisibility(isPublic: true, showBadges: true);

      expect(resolve(visibility: published, approved: false).canSeeProfile,
          isFalse);
      expect(
        resolve(viewer: me, visibility: published, approved: false)
            .canSeeProfile,
        isTrue,
        reason: 'otherwise they cannot see what they submitted or fix a '
            'rejection',
      );
    });
  });

  group('the friendship pair', () {
    test('normalises to one representation whichever way it is built', () {
      final forward = Friendship(
        userA: 'zebra',
        userB: 'apple',
        requesterId: 'zebra',
        status: FriendshipStatus.pending,
      );
      final backward = Friendship(
        userA: 'apple',
        userB: 'zebra',
        requesterId: 'zebra',
        status: FriendshipStatus.pending,
      );

      expect(forward.userA, 'apple');
      expect(forward.userB, 'zebra');
      expect(backward.userA, forward.userA);
      expect(backward.userB, forward.userB);
    });

    test(
        'the requester survives the reordering — it is not derivable '
        'from the pair', () {
      final f = Friendship(
        userA: 'zebra',
        userB: 'apple',
        requesterId: 'zebra',
        status: FriendshipStatus.pending,
      );

      expect(f.requesterId, 'zebra');
      expect(f.userA, 'apple', reason: 'reordered, but the asker did not');
    });

    test('names the other party, and only for a party', () {
      final f = Friendship(
        userA: me,
        userB: them,
        requesterId: me,
        status: FriendshipStatus.accepted,
      );

      expect(f.otherThan(me), them);
      expect(f.otherThan(them), me);
      expect(f.otherThan('stranger'), isNull);
    });
  });

  group('who may respond to a request', () {
    Friendship pending({String requester = me}) => Friendship(
          userA: me,
          userB: them,
          requesterId: requester,
          status: FriendshipStatus.pending,
        );

    test('the person asked may — the person who asked may not', () {
      expect(pending().canRespond(them), isTrue);
      expect(pending().canRespond(me), isFalse,
          reason: 'an Accept button on your own outgoing request is the '
              'bug this method exists to prevent');
    });

    test('a stranger may not', () {
      expect(pending().canRespond('stranger'), isFalse);
    });

    test('an answered request cannot be answered again', () {
      for (final status in [
        FriendshipStatus.accepted,
        FriendshipStatus.declined,
      ]) {
        final f = Friendship(
          userA: me,
          userB: them,
          requesterId: me,
          status: status,
        );
        expect(f.canRespond(them), isFalse,
            reason: 'status was ${status.name}');
      }
    });
  });

  group('sending a request', () {
    FriendRequestBlockReason? check({
      String to = them,
      bool blocked = false,
      Friendship? existing,
    }) =>
        FriendRules.cannotRequest(
          fromUserId: me,
          toUserId: to,
          blockedEitherWay: blocked,
          existing: existing,
        );

    test('is allowed between two strangers who have not blocked', () {
      expect(check(), isNull);
    });

    test('is refused to yourself', () {
      expect(check(to: me), FriendRequestBlockReason.self);
    });

    test('is refused across a block, in either direction', () {
      expect(check(blocked: true), FriendRequestBlockReason.blocked);
    });

    test('a block outranks an existing friendship', () {
      final friends = Friendship(
        userA: me,
        userB: them,
        requesterId: me,
        status: FriendshipStatus.accepted,
      );

      expect(check(blocked: true, existing: friends),
          FriendRequestBlockReason.blocked,
          reason: 'the order matters: blocked, then already-friends');
    });

    test('a declined request is not re-sendable while the row stands', () {
      final declined = Friendship(
        userA: me,
        userB: them,
        requesterId: me,
        status: FriendshipStatus.declined,
      );

      expect(check(existing: declined),
          FriendRequestBlockReason.previouslyDeclined,
          reason: 'they said no; tapping twice is not a second question');
    });

    test('names which wall it hit, so the UI can say', () {
      expect(
        check(
          existing: Friendship(
            userA: me,
            userB: them,
            requesterId: me,
            status: FriendshipStatus.pending,
          ),
        ),
        FriendRequestBlockReason.alreadyPending,
      );
    });
  });

  group('squad membership', () {
    Squad squad({int members = 4, String owner = me}) => Squad(
          id: 'squad-1',
          name: 'Morning crew',
          ownerId: owner,
          inviteCode: 'ABC123',
          memberCount: members,
        );

    test('twelve is the cap', () {
      expect(Squad.maxMembers, 12);
      expect(squad(members: 11).isFull, isFalse);
      expect(squad(members: 12).isFull, isTrue);
    });

    test('a full squad refuses a new member and says why', () {
      expect(
        squad(members: 12).cannotJoin(userId: them, alreadyMember: false),
        SquadJoinBlockReason.full,
      );
    });

    test('an existing member is refused before the cap is consulted', () {
      expect(
        squad(members: 12).cannotJoin(userId: them, alreadyMember: true),
        SquadJoinBlockReason.alreadyMember,
        reason: 'a member of a full squad is already in, not shut out',
      );
    });

    test('a squad with room lets somebody in', () {
      expect(squad().cannotJoin(userId: them, alreadyMember: false), isNull);
    });

    test('ownership is by id, not by position', () {
      expect(squad().isOwner(me), isTrue);
      expect(squad().isOwner(them), isFalse);
    });
  });

  group('tokens are tokens', () {
    test('an unknown activity kind is null, never a default', () {
      expect(ActivityKind.fromToken('workout_completed'),
          ActivityKind.workoutCompleted);
      expect(ActivityKind.fromToken('something_a_newer_build_writes'), isNull,
          reason: 'rendering it as a workout would be inventing news');
      expect(ActivityKind.fromToken(null), isNull);
    });

    test('an unknown reaction is null too', () {
      expect(FeedReaction.fromToken('fire'), FeedReaction.fire);
      expect(FeedReaction.fromToken('shrug'), isNull);
    });

    test(
        'a friendship status falls back to pending, which is the safe '
        'end of that scale', () {
      expect(FriendshipStatus.fromToken('accepted'), FriendshipStatus.accepted);
      expect(FriendshipStatus.fromToken('who_knows'), FriendshipStatus.pending,
          reason: 'an unknown status must never read as accepted');
    });
  });
}
