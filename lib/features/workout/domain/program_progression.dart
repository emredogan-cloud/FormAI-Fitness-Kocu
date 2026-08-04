/// Roadmap Phase 14 (C40, P5, R5) · the day-31 problem.
///
/// A 30-day program has a 30-day lifespan. On day 31 the app currently
/// has nothing to say, and "nothing to say" is the moment a subscription
/// stops renewing. This file is the rule set for what comes next, and it
/// is pure so that the decision can be tested rather than demonstrated.
///
/// # Why the recommendation is grounded in what happened
///
/// The roadmap wants four continuation paths and a coach that "detects
/// when a program is too easy or too hard". Both of those need the same
/// input — **what fraction of the program the user actually completed**
/// — and that number is already in the app: `WorkoutDay.isCompleted`
/// across the 30 days.
///
/// So the recommendation is not a preference and not a survey. Somebody
/// who finished 28 of 30 days is told something different from somebody
/// who finished 11, because those are different situations and offering
/// both of them "advance to the next level" is how the second one quits.
///
/// # Why advancement is never automatic
///
/// [recommend] returns a recommendation, not a decision. Every path
/// stays offered; one is marked. The roadmap's own words for the
/// difficulty tiers are that they must be "explained honestly so users
/// self-select correctly" — a program that silently got harder is
/// indistinguishable, from the inside, from a body that got weaker.
library;

/// The three tiers the generator already understands. The tokens match
/// `WorkoutGeneratorService`'s `fitnessLevel` strings exactly, so a tier
/// can be handed straight back to it.
enum DifficultyTier {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced');

  const DifficultyTier(this.token);

  final String token;

  /// The next tier up, or null at the top. Null is a real state and the
  /// caller has to answer it — an advanced user who finishes strongly is
  /// offered a change of focus, not a fourth tier that does not exist.
  DifficultyTier? get next => switch (this) {
        beginner => intermediate,
        intermediate => advanced,
        advanced => null,
      };

  /// Parsed from stored preferences, which have carried free text since
  /// long before this enum existed.
  static DifficultyTier fromToken(String? token) => switch (token) {
        'intermediate' => intermediate,
        'advanced' => advanced,
        _ => beginner,
      };
}

/// The four ways forward the roadmap names.
enum ContinuationPath {
  /// Same tier, more work. The default answer, and the only one that is
  /// right for somebody who half-finished.
  repeatWithProgression,

  /// Up one tier.
  advanceTier,

  /// Same tier, different goal — sixpack, bulk, tone.
  switchFocus,

  /// Fewer sessions a week, held indefinitely. Not a failure state: the
  /// roadmap asks for it explicitly, and a user who has reached the
  /// shape they wanted needs somewhere to stand that is not "start
  /// another 30 days".
  maintenance,
}

/// How well the program that just ended fitted the person who ran it.
enum ProgramFit { tooHard, wellMatched, tooEasy }

/// What the finished program actually did.
class ProgramOutcome {
  const ProgramOutcome({
    required this.completedDays,
    required this.totalDays,
    required this.tier,
    this.medianSessionRatio,
  });

  final int completedDays;
  final int totalDays;
  final DifficultyTier tier;

  /// Median of (actual session duration / planned duration), when the
  /// app has enough sessions to have a median. Null is the normal case
  /// early on and every rule here works without it.
  final double? medianSessionRatio;

  /// 0.0 when the program had no days — which is a corrupt plan rather
  /// than a perfect score, and the ordering of the rules below depends
  /// on it not being 1.0.
  double get completionRate => totalDays <= 0 ? 0 : completedDays / totalDays;

  bool get isComplete => totalDays > 0 && completedDays >= totalDays;
}

/// A recommendation, plus everything a screen needs to explain it.
class ContinuationRecommendation {
  const ContinuationRecommendation({
    required this.path,
    required this.tier,
    required this.overload,
    required this.fit,
  });

  /// The marked path. Every other path stays offered.
  final ContinuationPath path;

  /// The tier the recommended path would run at. Equal to the outcome's
  /// tier for every path except [ContinuationPath.advanceTier].
  final DifficultyTier tier;

  /// Volume multiplier for the next program, as a factor on reps.
  /// 1.0 means "the same program again", which is the right answer for
  /// somebody who found it hard.
  final double overload;

  final ProgramFit fit;

  bool get raisesDifficulty =>
      overload > 1.0 || path == ContinuationPath.advanceTier;
}

/// Completion at or above this earns the next tier.
///
/// 0.8 rather than 1.0 because a 30-day program with a missed weekend is
/// a completed program, and rather than 0.6 because the tier above is
/// genuinely harder and arriving there under-prepared is the failure
/// this whole file exists to avoid.
const double kAdvanceThreshold = 0.8;

/// Below this the program was not completed in any meaningful sense, and
/// the next one must not be harder.
const double kStruggleThreshold = 0.5;

/// Matches `WorkoutGeneratorService.weeklyOverloadIncrement`.
///
/// Deliberately the same number: the generator already knows how to make
/// a week 8% harder, and inventing a second progression rate here would
/// mean the app promised one thing and built another. If that constant
/// moves, this one moves with it — `program_progression_test.dart` pins
/// them together for exactly that reason.
const double kStrongOverload = 1.08;

/// Half a step, for somebody who finished most of it.
const double kModestOverload = 1.04;

/// Sessions consistently finishing this much faster than planned is the
/// signal that the work is too light, independent of completion.
const double kTooEasyRatio = 0.7;

/// Sessions consistently overrunning by this much are a load problem,
/// not an enthusiasm one.
const double kTooHardRatio = 1.4;

/// How well the program fitted.
///
/// Completion is the primary signal because it is always present.
/// Duration only *upgrades* the reading to [ProgramFit.tooEasy] — a
/// user who finished everything quickly was under-loaded — and only
/// *downgrades* to [ProgramFit.tooHard] when completion was not strong
/// enough to contradict it. Somebody who completes 95% of a program is
/// not on a too-hard program however long the sessions ran.
ProgramFit assessFit(ProgramOutcome outcome) {
  final rate = outcome.completionRate;
  final ratio = outcome.medianSessionRatio;
  if (rate < kStruggleThreshold) return ProgramFit.tooHard;
  if (rate >= kAdvanceThreshold) {
    if (ratio != null && ratio <= kTooEasyRatio) return ProgramFit.tooEasy;
    return ProgramFit.wellMatched;
  }
  if (ratio != null && ratio >= kTooHardRatio) return ProgramFit.tooHard;
  return ProgramFit.wellMatched;
}

/// What to put in front of somebody on day 31.
ContinuationRecommendation recommend(ProgramOutcome outcome) {
  final fit = assessFit(outcome);
  final rate = outcome.completionRate;

  // Struggled. Same tier, same load, and the honest reason is that
  // repeating a program you half-finished is how it gets finished.
  if (rate < kStruggleThreshold) {
    return ContinuationRecommendation(
      path: ContinuationPath.repeatWithProgression,
      tier: outcome.tier,
      overload: 1.0,
      fit: fit,
    );
  }

  if (rate >= kAdvanceThreshold) {
    final next = outcome.tier.next;
    // At the top there is no tier to advance to, so the interesting
    // change is what you train, not how hard. Offering "advanced" to
    // somebody already advanced is the dead end this phase is about.
    if (next == null) {
      return ContinuationRecommendation(
        path: ContinuationPath.switchFocus,
        tier: outcome.tier,
        overload: kStrongOverload,
        fit: fit,
      );
    }
    return ContinuationRecommendation(
      path: ContinuationPath.advanceTier,
      tier: next,
      // A tier change is already a step up. Stacking the volume bump on
      // top of it is two increases at once, and when the next month goes
      // badly neither of them can be blamed.
      overload: 1.0,
      fit: fit,
    );
  }

  return ContinuationRecommendation(
    path: ContinuationPath.repeatWithProgression,
    tier: outcome.tier,
    overload: kModestOverload,
    fit: fit,
  );
}

/// [baseReps] under [overload], never fewer than the original.
///
/// Rounds up, so an 8% bump on 10 reps is 11 rather than 10. A
/// progression that rounds to no change at all is invisible, and the
/// roadmap's requirement is *visible* progressive overload.
int progressedReps(int baseReps, double overload) {
  if (baseReps <= 0) return baseReps;
  if (overload <= 1.0) return baseReps;
  final raised = (baseReps * overload).ceil();
  return raised > baseReps ? raised : baseReps + 1;
}
