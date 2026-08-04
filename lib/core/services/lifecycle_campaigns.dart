/// Roadmap Phase 14 (C50) · re-engagement, and the cap that keeps it
/// from becoming spam.
///
/// # The cap is the feature
///
/// The roadmap asks for win-back journeys at 7/14/30 days, milestone
/// celebrations, content-drop announcements and streak-risk alerts, and
/// then asks for something harder: "a global frequency cap across all
/// notification types so campaigns cannot spam", with an opt-out rate
/// that stays at or below 8%.
///
/// Those two lists fight each other. A 14-day-lapsed user is
/// simultaneously eligible for a win-back, a streak-risk alert and
/// whatever content landed while they were away — three notifications
/// for one person on one day, each individually justified. So the
/// decision to send is made in one place, against the whole history,
/// and it is pure so the fight can be tested rather than observed in
/// production.
///
/// # Why the daily reminder is not capped
///
/// The cap governs notifications the APP decides to send. The daily
/// reminder is not one: the user turned it on and picked its time, and
/// suppressing an appointment somebody made is a different kind of bug
/// from suppressing an ad. That is a property of the notification —
/// who chose it — rather than an exemption granted to a name, which is
/// the distinction this codebase has twice been burned by blurring.
///
/// # Why nothing here mentions guilt
///
/// "Seni özledik", never "3 gündür antrenman yapmadın" — the roadmap is
/// explicit and it is right. A person who lapsed for two weeks knows.
/// Copy lives in ARB; this file decides only *whether* and *which*.
library;

/// The campaigns Phase 14 defines.
///
/// Tokens are English and stable because they are analytics dimensions
/// — the same rule [SmartReminderCondition] follows.
enum LifecycleCampaign {
  /// A week without a session. Early enough that the habit is bruised
  /// rather than gone.
  winBack7('win_back_7'),

  winBack14('win_back_14'),

  /// The last one. A user 30 days gone who does not come back is not
  /// reachable by a fourth notification, and sending one anyway is how
  /// an app earns an uninstall instead of a dormant install.
  winBack30('win_back_30'),

  /// A streak the user is about to lose. The only campaign that is
  /// time-critical rather than time-boxed.
  streakRisk('streak_risk'),

  /// Something they achieved. The one campaign that is never bad news.
  milestone('milestone'),

  /// New content in an area they train.
  contentDrop('content_drop');

  const LifecycleCampaign(this.token);

  final String token;

  /// How long before this campaign may repeat.
  ///
  /// The win-backs are effectively one-shot — their trigger windows do
  /// not recur without the user coming back and lapsing again — so the
  /// cooldown is what stops a user hovering at the boundary from being
  /// pinged daily.
  Duration get cooldown => switch (this) {
        winBack7 || winBack14 || winBack30 => const Duration(days: 30),
        streakRisk => const Duration(days: 7),
        milestone => const Duration(days: 3),
        contentDrop => const Duration(days: 14),
      };
}

/// One notification the app decided to send.
class CampaignSend {
  const CampaignSend(this.campaign, this.at);

  final LifecycleCampaign campaign;
  final DateTime at;
}

/// At most this many app-initiated notifications in any trailing week.
///
/// Two, not three: a user who did not respond to two is not going to
/// respond to a third, and the cost of the third is the opt-out the
/// success criteria cap at 8%.
const int kMaxCampaignsPerWeek = 2;

/// And never two within this window, whatever the weekly count allows.
///
/// Without it, both of the week's allowance can land on the same
/// afternoon — which is the exact experience the cap exists to prevent,
/// passing a weekly check.
const Duration kMinCampaignGap = Duration(hours: 48);

/// Days lapsed at which each win-back fires.
const int kWinBack7Days = 7;
const int kWinBack14Days = 14;
const int kWinBack30Days = 30;

/// A streak is at risk once this long has passed without a session.
///
/// 40 hours rather than 24: a streak counted by calendar day is not
/// broken until midnight, and a ping sent at hour 25 is telling somebody
/// they are about to lose something they still have all day to keep.
const Duration kStreakRiskAfter = Duration(hours: 40);

/// Whether [campaign] may be sent now, given everything already sent.
///
/// [history] is every app-initiated send, of any campaign. Entries older
/// than the widest cooldown may be pruned by the caller; nothing here
/// requires them.
bool canSend({
  required LifecycleCampaign campaign,
  required List<CampaignSend> history,
  required DateTime now,
}) {
  for (final send in history) {
    if (send.at.isAfter(now)) continue;
    final since = now.difference(send.at);
    // Its own cooldown.
    if (send.campaign == campaign && since < campaign.cooldown) return false;
    // The global floor between any two.
    if (since < kMinCampaignGap) return false;
  }
  final week = now.subtract(const Duration(days: 7));
  final recent =
      history.where((s) => s.at.isAfter(week) && !s.at.isAfter(now)).length;
  return recent < kMaxCampaignsPerWeek;
}

/// What the app has to say to this user right now, or null.
///
/// Ordered by what matters most to the person rather than to the
/// business: something they achieved, then something they are about to
/// lose, then coming back, then new content. A milestone that lost a
/// coin-flip to a win-back would be a celebration replaced by a nudge.
LifecycleCampaign? dueCampaign({
  required DateTime now,
  required DateTime? lastWorkoutAt,
  required int streakDays,
  bool hasUnseenMilestone = false,
  bool hasUnseenContent = false,
}) {
  if (hasUnseenMilestone) return LifecycleCampaign.milestone;

  // Never worked out at all. Onboarding owns that user; a win-back for
  // somebody who has not yet been won is the wrong message entirely.
  if (lastWorkoutAt == null) return null;

  final since = now.difference(lastWorkoutAt);
  if (since.isNegative) return null;

  if (streakDays > 0 &&
      since >= kStreakRiskAfter &&
      since.inDays < kWinBack7Days) {
    return LifecycleCampaign.streakRisk;
  }

  // Widest window first, so a 30-day-lapsed user gets the 30 rather
  // than the 7. Reading these in ascending order is a bug that only
  // appears for the users who lapsed longest.
  final days = since.inDays;
  if (days >= kWinBack30Days) return LifecycleCampaign.winBack30;
  if (days >= kWinBack14Days) return LifecycleCampaign.winBack14;
  if (days >= kWinBack7Days) return LifecycleCampaign.winBack7;

  if (hasUnseenContent) return LifecycleCampaign.contentDrop;
  return null;
}

/// The campaign to actually schedule: what is due, if the cap allows it.
///
/// A single entry point so no call site can ask [dueCampaign] and forget
/// to ask [canSend] — which is the shape of every notification bug that
/// ends in an uninstall.
LifecycleCampaign? nextCampaign({
  required DateTime now,
  required DateTime? lastWorkoutAt,
  required int streakDays,
  required List<CampaignSend> history,
  bool hasUnseenMilestone = false,
  bool hasUnseenContent = false,
}) {
  final due = dueCampaign(
    now: now,
    lastWorkoutAt: lastWorkoutAt,
    streakDays: streakDays,
    hasUnseenMilestone: hasUnseenMilestone,
    hasUnseenContent: hasUnseenContent,
  );
  if (due == null) return null;
  return canSend(campaign: due, history: history, now: now) ? due : null;
}
