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

  // ── Calibration verdicts, spoken during a live set ─────────────────
  /// Mean landmark confidence too low to analyse.
  calibrateAdjustPosition,

  /// Shoulder span too small in frame — the user is too far away.
  calibrateComeCloser,

  // ── Timed-set beats ────────────────────────────────────────────────
  /// Halfway through a timed hold. Only on sets of 10 s or more, where
  /// "halfway" is a milestone rather than a distraction.
  timerHalfway,

  /// Ten seconds left in a timed hold.
  timerFinalTen,

  /// Five seconds left in a timed hold.
  timerFinalFive,

  // ── Rest-window beats ──────────────────────────────────────────────
  /// Halfway through a rest window of 30 s or more.
  restHalfway,

  /// Ten seconds until the next set begins.
  restFinalTen,

  // ── Mid-set coaching rotation ──────────────────────────────────────
  /// One pool per exercise category, rotated in order.
  ///
  /// Pools are 4 lines each so the user hears any given line at most
  /// once per ~72s of work — long enough to feel like coaching rather
  /// than a recorded loop.
  midSetCardioKeepRhythm,
  midSetCardioSteadyTempo,
  midSetCardioSoftKnees,
  midSetCardioBreatheSteady,
  midSetLegsControlDescent,
  midSetLegsHeelsDown,
  midSetLegsBraceCore,
  midSetLegsExhaleUp,
  midSetChestDontRush,
  midSetChestBreathePattern,
  midSetChestScapulaTight,
  midSetChestBodyStraight,
  midSetBackSqueezeScapula,
  midSetBackFullRange,
  midSetBackPullWithElbows,
  midSetBackArchShouldersBack,
  midSetShouldersNoSwing,
  midSetShouldersRelaxTraps,
  midSetShouldersProtectLowBack,
  midSetShouldersPauseAtTop,
  midSetArmsFixElbow,
  midSetArmsLowerSlowly,
  midSetArmsRelaxWrist,
  midSetArmsHoldAtTop,
  midSetCoreBraceAndBreathe,
  midSetCoreLowBackDown,
  midSetCoreSlowUp,
  midSetCoreExhaleOnCrunch,
  midSetFullBodyUseEverything,
  midSetFullBodyKeepBreathing,
  midSetFullBodyYoureInControl,
  midSetFullBodyStayLoose,

  // ── Rest-window rotation ───────────────────────────────────────────
  /// Recovery-flavoured lines for the rest window. Four entries so a
  /// 90 s inter-exercise rest lands three of them without repeating.
  /// Never a push — the user is supposed to be recovering.
  restBreatheDeep,
  restDropShoulders,
  restDrinkWater,
  restNextSetSoon,

  // ── Tracking guidance rotation ─────────────────────────────────────
  /// Rotated so a user with persistent camera trouble hears actionable
  /// variety rather than the same nag three times.
  trackingStepCloser,
  trackingAdjustPosition,
  trackingStepBack,
}
