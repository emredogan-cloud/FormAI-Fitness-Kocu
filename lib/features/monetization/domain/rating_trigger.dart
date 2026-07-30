/// Roadmap Phase 1 (R2.2) · the contextual moments at which FormAI may
/// ask the user to rate it.
///
/// Phase 136 shipped a single trigger — Pro user, third completed
/// workout — which reached roughly 5% of the user base. The Testers
/// Community report observed the consequence from the outside: users
/// who wanted to rate had no path, and the population whose reviews
/// matter most to a new listing (free users) was never asked at all.
///
/// This enum replaces that single hardcoded moment with a set of
/// peak-positive-emotion triggers, each firing at most once, all of
/// them behind a shared cooldown so the *set* can grow without the
/// user's experience degrading into nagging.
///
/// Ordering matters: [eligibleTriggers] returns triggers in declaration
/// order, and the first eligible one wins. Rarer, higher-emotion
/// moments are declared first so a user who crosses two thresholds in
/// the same session is asked at the better moment.
library;

enum RatingTrigger {
  /// The 30-day program is done. The single strongest moment in the
  /// product — the user has completed what they signed up for.
  programComplete(
    token: 'program_complete',
    minCompletedDays: 30,
  ),

  /// A full week of consecutive training. Habit formation is visible
  /// to the user themselves at this point.
  streakSeven(
    token: 'streak_seven',
    minStreak: 7,
  ),

  /// Third completed workout — the Phase 136 moment, now available to
  /// every user rather than Pro subscribers only.
  thirdWorkout(
    token: 'third_workout',
    minCompletedDays: 3,
  ),

  /// A badge just unlocked. Fires only when the caller passes
  /// [RatingContext.badgeJustUnlocked], so it rides the celebration
  /// the user is already feeling.
  badgeUnlocked(
    token: 'badge_unlocked',
    requiresBadgeUnlock: true,
  ),

  /// The very first completed workout. Lowest bar, declared last so
  /// it only wins when nothing richer is available.
  firstWorkout(
    token: 'first_workout',
    minCompletedDays: 1,
  );

  const RatingTrigger({
    required this.token,
    this.minCompletedDays = 0,
    this.minStreak = 0,
    this.requiresBadgeUnlock = false,
  });

  /// Stable English identifier. Persisted in the fired-trigger ledger
  /// and sent to analytics — never localised, never renamed.
  final String token;

  final int minCompletedDays;
  final int minStreak;
  final bool requiresBadgeUnlock;

  /// Whether this trigger's own precondition is satisfied. Says nothing
  /// about cooldowns or the fired-ledger — [RatingContext] owns that.
  bool matches(RatingContext ctx) {
    if (requiresBadgeUnlock && !ctx.badgeJustUnlocked) return false;
    if (ctx.completedDays < minCompletedDays) return false;
    if (ctx.currentStreak < minStreak) return false;
    return true;
  }
}

/// The signals a rating decision is made from. A plain value object so
/// the decision logic is pure and exhaustively unit-testable without a
/// widget tree, a clock, or SharedPreferences.
class RatingContext {
  const RatingContext({
    required this.completedDays,
    required this.currentStreak,
    this.badgeJustUnlocked = false,
  });

  final int completedDays;
  final int currentStreak;
  final bool badgeJustUnlocked;

  /// Every trigger whose precondition this context satisfies, in
  /// declaration order (highest-emotion first).
  List<RatingTrigger> get eligibleTriggers => RatingTrigger.values
      .where((t) => t.matches(this))
      .toList(growable: false);
}

/// Pure decision function: given the context, what has already fired,
/// how many prompts we have shown, and when we last showed one — which
/// trigger (if any) should fire now?
///
/// Returns `null` when the user should not be asked. Extracted from the
/// service so the entire policy is testable in isolation; the service
/// only supplies state and presents UI.
RatingTrigger? selectRatingTrigger({
  required RatingContext context,
  required Set<String> firedTokens,
  required int promptCount,
  required DateTime? lastPromptAt,
  required DateTime now,
  required int maxLifetimePrompts,
  required Duration cooldown,
}) {
  if (promptCount >= maxLifetimePrompts) return null;
  if (lastPromptAt != null && now.difference(lastPromptAt) < cooldown) {
    return null;
  }
  for (final trigger in context.eligibleTriggers) {
    if (!firedTokens.contains(trigger.token)) return trigger;
  }
  return null;
}
