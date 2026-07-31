/// Roadmap Phase 5 · every line an analyzer can ask the coach to say.
///
/// The analyzers used to return the sentence itself — `formWarning =
/// 'Boynunu düz tut!'` — which put twenty pieces of spoken Turkish copy
/// inside the pose-geometry layer, where it was both untranslatable and
/// (until the gate was widened) invisible to the tool that looks for
/// exactly that.
///
/// An analyzer's job is to decide *what it saw*. Choosing the words for
/// it is a presentation concern: see
/// `presentation/coach_line_copy.dart`, which is also the only place
/// that needs an `AppLocalizations`.
///
/// One value per distinct line, deliberately. Merging two faults that
/// happen to share phrasing today would silently fuse them for every
/// future translator, and "keep your hips level" in a plank is not the
/// same coaching as "get your hips up" in a push-up even when a language
/// happens to render them alike.
enum CoachLine {
  // ── Form corrections ───────────────────────────────────────────────
  /// Crunch/sit-up: chin tucked toward the chest, straining the neck.
  neckStraight,

  /// Plank: hips sagging out of the straight line.
  plankHipsLevel,

  /// Push-up: hips dropped below the shoulder-to-ankle line.
  pushUpHipsUp,

  /// Squat: torso pitching forward instead of sitting back.
  squatChestUp,

  /// Glute bridge: stopping short of full hip extension.
  gluteBridgeSqueeze,

  /// Curl: elbow drifting away from the torso.
  elbowTucked,

  /// Overhead press: not reaching full lockout.
  armsFullyExtended,

  /// Lateral raise: lifting past shoulder height.
  armsShoulderHeight,

  // ── Pacing ─────────────────────────────────────────────────────────
  /// Strength tempo, too fast: rushing through the range of motion.
  slowDownFeelIt,

  /// Strength tempo, too fast (tracker preset wording).
  slowDownControlled,

  /// Any tempo, too slow: the user is struggling and needs a push.
  dontGiveUp,

  /// Cardio tempo, too fast.
  dropTempoStayControlled,

  /// Cardio tempo, too slow.
  raiseTempo,

  /// Compound tempo, too fast.
  dontLoseControl,

  /// Compound tempo, too slow.
  keepTheRhythm,

  // ── Encouragement during a silent hold ─────────────────────────────
  /// Rotating hold encouragement 1 of 3.
  doingGreat,

  /// Rotating hold encouragement 2 of 3.
  holdOn,

  /// Rotating hold encouragement 3 of 3.
  goodRhythm,

  // ── Contextual phase coaching ──────────────────────────────────────
  /// Burpee: the user has begun descending; coach the next phase.
  burpeeGetDown,
}
