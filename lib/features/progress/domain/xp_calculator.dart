/// Progress redesign Phase 3.A · pure-function XP awards.
///
/// Three signal types feed the user's lifetime XP:
///
///   1. **Workout completion** — base award per real session log. We
///      deliberately don't pay per-rep (the user explicitly ruled it
///      out as too grindy / casino-like).
///   2. **Streak milestones** — discrete bonuses for crossing 3 / 7 /
///      14 / 21 / 30 / 50 / 75 / 100-day thresholds. Awards scale up at
///      higher milestones because each one is exponentially harder.
///   3. **Badge unlocks** — flat 100 XP per badge, doubled for the two
///      "rare" endgame badges that gate identity arrivals.
///
/// All three are *additive* and *idempotent* — the awarding listener at
/// `xp_award_listener.dart` is responsible for crediting only the
/// portions not already in the persistence ledgers.
library;

import '../../workout/models/session_log_model.dart';

/// XP credited for one completed [SessionLog]. Constant for now;
/// scaling to actual session intensity is a Phase 4+ refinement.
int xpForWorkout(SessionLog log) => 50;

/// Streak milestone thresholds (in days) that pay XP.
const List<int> kStreakXpMilestones = [
  3,
  7,
  14,
  21,
  30,
  50,
  75,
  100,
  150,
  200,
  365
];

/// XP paid for each milestone, indexed by [kStreakXpMilestones]. Scales
/// roughly with rarity: a 7-day streak is twice the prize of a 3-day,
/// 30-day is 5x the 7-day, 100-day is the prestige tier.
const Map<int, int> _streakMilestoneXp = {
  3: 50,
  7: 100,
  14: 200,
  21: 300,
  30: 500,
  50: 750,
  75: 900,
  100: 1000,
  150: 1500,
  200: 2000,
  365: 5000,
};

/// Returns the milestone thresholds whose XP should be paid when the
/// streak crosses from [oldStreak] to [newStreak]. Order is ascending
/// — the awarding listener walks them in sequence so a single update
/// crossing multiple thresholds (e.g. user came back after a break and
/// hits day 7 in one shot) credits each tier exactly once.
List<int> streakMilestonesCrossed(int oldStreak, int newStreak) {
  if (newStreak <= oldStreak) return const [];
  return kStreakXpMilestones
      .where((m) => m > oldStreak && m <= newStreak)
      .toList(growable: false);
}

/// XP for a specific milestone threshold. Returns 0 for unknown values
/// so a future change to [kStreakXpMilestones] doesn't crash the
/// awarder — it just won't pay for the new tier until this map updates.
int xpForStreakMilestone(int milestone) => _streakMilestoneXp[milestone] ?? 0;

/// Badge XP. Most badges pay [_kBadgeXpDefault]; the two endgame
/// badges (`thirty_day_champion` and `form_legend`) pay [_kBadgeXpRare]
/// because they're the prestige unlocks the entire 30-day arc was
/// designed around.
const int _kBadgeXpDefault = 100;
const int _kBadgeXpRare = 200;
const Set<String> _rareBadgeIds = {'thirty_day_champion', 'form_legend'};

int xpForBadge(String badgeId) =>
    _rareBadgeIds.contains(badgeId) ? _kBadgeXpRare : _kBadgeXpDefault;
