/// Roadmap Phase 13 (C23 · R6) · leagues, ranking and the rules that keep
/// a leaderboard from being cruel.
///
/// Pure Dart. No Flutter, no Supabase, no localization — every function
/// here is a decision the product makes, stated so a test can hold it
/// still. The same split Phase 12 used: RLS is the boundary, this is the
/// explanation, and neither is sufficient alone.
library;

/// The length of the programme consistency is measured against.
///
/// The app ships one 30-day programme and the Progress tab already
/// reports "N of 30 days"; the leaderboard's consistency column is the
/// same ratio, so it reads the same constant rather than restating 30.
const int kProgrammeDays = 30;

/// Days that count as one league season.
///
/// The roadmap asks for weekly leaderboard resets inside monthly
/// seasons, so a bad week is never permanent.
const int kSeasonDays = 28;

/// The most XP a single day can honestly carry.
///
/// **This number also lives in `020_leaderboards.sql`** as the
/// `leaderboard_xp_plausible` bound and the trigger's jump limit. They
/// must agree: this copy is what the UI explains to a user, that copy is
/// what the database actually enforces, and a disagreement means the app
/// promises something the server rejects. `league_test.dart` asserts the
/// SQL still says 500.
const int kDailyXpCap = 500;

/// Seven honest days. The weekly CHECK constraint in `020`.
const int kWeeklyXpCap = kDailyXpCap * 7;

/// Three sessions a day is already generous; the constraint exists to
/// make the physically implausible impossible, not to police enthusiasm.
const int kMaxWeeklySessions = 21;

/// The five tiers, weakest first. Order is the comparison.
enum LeagueTier {
  bronze('bronze'),
  silver('silver'),
  gold('gold'),
  platinum('platinum'),
  diamond('diamond');

  const LeagueTier(this.token);

  /// The stable string stored in `league_assignments.tier` and sent to
  /// analytics. Never a localized label.
  final String token;

  static LeagueTier? fromToken(String? token) {
    for (final tier in LeagueTier.values) {
      if (tier.token == token) return tier;
    }
    // Null rather than bronze: an unknown tier is a newer server's, and
    // showing somebody Bronze because we did not recognise Emerald would
    // be inventing a demotion.
    return null;
  }

  LeagueTier? get next => index + 1 < LeagueTier.values.length
      ? LeagueTier.values[index + 1]
      : null;

  LeagueTier? get previous => index > 0 ? LeagueTier.values[index - 1] : null;
}

/// What happened to a user at the end of a league week.
enum LeagueOutcome { promoted, held, relegated }

/// How many of a league's members move each week.
///
/// A league is capped at [kLeagueSize]; the top [kPromotionSlots] go up
/// and the bottom [kRelegationSlots] go down. The middle is deliberately
/// the largest group — most weeks, for most people, nothing happens, and
/// a system where something always happens stops meaning anything.
const int kLeagueSize = 30;
const int kPromotionSlots = 5;
const int kRelegationSlots = 5;

/// Where a user finishes, given their 1-based rank in a league of
/// [size] people.
///
/// # Nobody is relegated out of the bottom, and nobody is promoted out
/// of the top
///
/// Bronze has nowhere to fall and Diamond has nowhere to climb, so both
/// return [LeagueOutcome.held] rather than a move with no destination.
/// The alternative — reporting "relegated" and leaving the user in
/// Bronze — is a message that contradicts what they can see.
///
/// # An empty or single-person league holds
///
/// Ranking one person is not a competition. Early in the app's life this
/// is the common case, and promoting somebody for being alone would make
/// the tier mean nothing on the day it mattered most.
LeagueOutcome outcomeFor({
  required LeagueTier tier,
  required int rank,
  required int size,
}) {
  if (size < 2 || rank < 1 || rank > size) return LeagueOutcome.held;
  if (rank <= kPromotionSlots && tier.next != null) {
    return LeagueOutcome.promoted;
  }
  if (rank > size - kRelegationSlots && tier.previous != null) {
    return LeagueOutcome.relegated;
  }
  return LeagueOutcome.held;
}

/// The tier a user lands in after [outcome].
LeagueTier tierAfter(LeagueTier tier, LeagueOutcome outcome) =>
    switch (outcome) {
      LeagueOutcome.promoted => tier.next ?? tier,
      LeagueOutcome.relegated => tier.previous ?? tier,
      LeagueOutcome.held => tier,
    };

/// The Monday of [moment]'s ISO week, in UTC, as a date-only value.
///
/// **The single most likely source of bugs in this phase**, and the
/// roadmap says so: users in different timezones must land in the same
/// bucket or they are not competing with each other. UTC rather than
/// local, and a date rather than a timestamp, so "which week is this"
/// never depends on the hour.
///
/// `020_leaderboards.sql` stores exactly this value in
/// `leaderboard_stats.week_start`.
DateTime weekStartUtc(DateTime moment) {
  final utc = moment.toUtc();
  final midnight = DateTime.utc(utc.year, utc.month, utc.day);
  // DateTime.weekday is 1 = Monday.
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}

/// Which scopes a leaderboard can be read at.
///
/// Order is deliberate — it is the order the tabs appear in, and
/// [defaultScope] is the first one.
enum LeaderboardScope { squad, friends, global }

/// **Beginner protection is a design requirement, not a nicety.**
///
/// The roadmap is explicit: a first-week user must never open a
/// leaderboard and see themselves last out of 40,000. So the default is
/// never global, and this constant is where that decision lives rather
/// than being an initializer buried in a widget.
const LeaderboardScope defaultScope = LeaderboardScope.squad;

/// How a rank should be told to the person who holds it.
///
/// A position is only kind when it is small. Past [kRankTellsPosition]
/// the honest and the humane answer is the same one — a percentile —
/// because "you are 12,406th" and "you are in the top 40%" describe the
/// same fact and only one of them is a reason to come back tomorrow.
const int kRankTellsPosition = 100;

sealed class RankPresentation {
  const RankPresentation();
}

/// "4th" — shown when the number is small enough to be encouraging.
class RankPosition extends RankPresentation {
  const RankPosition(this.rank);
  final int rank;

  @override
  bool operator ==(Object other) => other is RankPosition && other.rank == rank;
  @override
  int get hashCode => rank.hashCode;
}

/// "top 12%" — shown when a position would only be discouraging.
class RankPercentile extends RankPresentation {
  const RankPercentile(this.percentile);

  /// 1-100. Always at least 1: "top 0%" is not a thing, and rounding a
  /// genuine leader down to zero reads as a bug.
  final int percentile;

  @override
  bool operator ==(Object other) =>
      other is RankPercentile && other.percentile == percentile;
  @override
  int get hashCode => percentile.hashCode;
}

/// Nothing to say — an empty board, or a rank that makes no sense.
class RankUnranked extends RankPresentation {
  const RankUnranked();

  @override
  bool operator ==(Object other) => other is RankUnranked;
  @override
  int get hashCode => 0;
}

/// Decides how to tell somebody where they placed.
RankPresentation presentRank({required int rank, required int total}) {
  if (total < 1 || rank < 1 || rank > total) return const RankUnranked();
  if (rank <= kRankTellsPosition) return RankPosition(rank);
  final percentile = ((rank / total) * 100).ceil();
  return RankPercentile(percentile.clamp(1, 100));
}

/// What a challenge measures.
enum ChallengeKind {
  consistency('consistency'),
  sessions('sessions'),
  streak('streak'),
  xp('xp');

  const ChallengeKind(this.token);
  final String token;

  static ChallengeKind? fromToken(String? token) {
    for (final kind in ChallengeKind.values) {
      if (kind.token == token) return kind;
    }
    // An unknown kind is a newer server's challenge. Skipped rather than
    // guessed, same rule as ActivityKind.
    return null;
  }
}

/// Clamped completion of a challenge, 0.0-1.0.
///
/// Clamped at the top because a challenge is finished exactly once:
/// 140% of a target is not more finished than 100%, and a progress bar
/// that overshoots looks broken.
double challengeFraction({required int progress, required int target}) {
  if (target <= 0) return 0;
  final fraction = progress / target;
  return fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
}

/// Whether a challenge is open for joining at [now].
///
/// A challenge that has ended is not joinable even if it is still on
/// screen, because the alternative is a join that silently earns
/// nothing.
bool challengeIsOpen({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final moment = now.toUtc();
  return !moment.isBefore(startsAt.toUtc()) && moment.isBefore(endsAt.toUtc());
}

/// Caps a client-reported week to what the server will actually accept.
///
/// The client applies this before writing so a user sees the same number
/// the leaderboard will show. **It is not the enforcement** — `020`'s
/// CHECK constraints and trigger are, because a cap applied only in the
/// client is a suggestion. Applying it here as well is what stops an
/// honest heavy week from being rejected with an error the user cannot
/// act on.
({int xp, int sessions, int streak, int consistency}) clampWeek({
  required int xp,
  required int sessions,
  required int streak,
  required int consistency,
}) =>
    (
      xp: xp.clamp(0, kWeeklyXpCap),
      sessions: sessions.clamp(0, kMaxWeeklySessions),
      streak: streak.clamp(0, 3650),
      consistency: consistency.clamp(0, 100),
    );
