import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../referral/providers/referral_provider.dart';
import '../data/community_repository.dart';
import '../domain/models/community_models.dart';

/// Roadmap Phase 12 (C47) · turns a redeemed referral into a friendship.
///
/// The person-to-person link already exists the moment a code is
/// redeemed — `referrals` records exactly who invited whom — so the
/// roadmap's ask here is not to build a connection but to notice that
/// one is already there and offer to make it mutual.
///
/// # It is an offer, never an action
///
/// Redeeming a code is a transaction about a reward. Silently creating
/// a friendship out of it would be a second thing the user did not ask
/// for, on a surface where they were thinking about something else. So
/// the request is only ever sent from a tap on a dialog that says
/// plainly what it will do.
///
/// # Everything about it fails quiet
///
/// No profile, no schema, no referrer row, an already-pending request,
/// a block in either direction — every one of those ends with no dialog
/// and no error. This is an opportunistic extra on top of a flow that
/// has already succeeded, and interrupting a successful redemption with
/// a failure about a different feature would be the wrong trade.
Future<void> maybeOfferReferralFriend(
  BuildContext context,
  WidgetRef ref,
) async {
  final repository = ref.read(communityRepositoryProvider);
  if (!await repository.isAvailable()) return;

  // A friend request comes *from* somebody. Without a profile there is
  // no one to accept, so the offer would be a dead end.
  final me = await repository.myProfile();
  if (me == null) return;

  final referrerId =
      await ref.read(referralServiceProvider).redeemedReferrerId();
  if (referrerId == null) return;

  final viewerId = ref.read(currentCommunityUserIdProvider);
  if (viewerId == null || viewerId == referrerId) return;

  // The domain rules already know every reason a request cannot be
  // sent; asking them here is what keeps this file from being a second
  // opinion on the same question.
  final existing = await repository.friendships();
  final blocked = await repository.blockedIds();
  final reason = FriendRules.cannotRequest(
    fromUserId: viewerId,
    toUserId: referrerId,
    blockedEitherWay: blocked.contains(referrerId),
    existing: existing
        .where((f) => f.involves(viewerId) && f.involves(referrerId))
        .firstOrNull,
  );
  if (reason != null) return;

  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: NeonSurface.card,
      title: Text(
        l10n.referralFriendTitle,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      // Deliberately does not name the referrer. Their profile may be
      // private, and resolving a name here to show somebody who has not
      // agreed to be seen would be the exact leak the visibility flags
      // exist to prevent.
      content: Text(
        l10n.referralFriendBody,
        style: const TextStyle(color: NeonSurface.muted, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.referralFriendDecline),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.referralFriendSend,
            style: const TextStyle(color: NeonSurface.lime),
          ),
        ),
      ],
    ),
  );
  if (accepted != true) return;

  await repository.requestFriend(referrerId);
}
