/// FormAI · Roadmap B — technique form score.
///
/// Maps a finished analysis of a video into a 0-100 "technique" number for
/// the result card and history trend.
///
/// IMPORTANT — this is a TRANSPARENT HEURISTIC, not a validated accuracy
/// metric. It linearly combines two explainable signals:
///   • range-of-motion completeness (did the user hit full depth/extension?)
///   • clean-frame ratio (how rarely did a form fault fire?)
/// There is no machine-learned scoring model behind it. Calibrating these
/// weights against labelled good/bad-form footage is **DEFERRED — REQUIRES
/// PHYSICAL VALIDATION** (real video + ground-truth labels). The weights
/// below are an initial, deliberately simple split documented so the number
/// shown to a user is always explainable.
class FormScore {
  const FormScore._();

  /// Fraction of the total score attributable to range-of-motion.
  static const double romWeight = 60.0;

  /// Fraction attributable to keeping form faults rare.
  static const double cleanWeight = 40.0;

  /// Compute a 0-100 score.
  ///
  /// [reps]                  counted reps in the clip.
  /// [faultFrames]           frames on which any form fault fired.
  /// [totalAnalysedFrames]   frames fed through the analyzer.
  /// [romCompleteness]       mean (achieved ROM / target ROM), 0..1.
  ///
  /// Returns 0 when there is nothing to score (no reps or no frames) rather
  /// than a misleading non-zero number.
  static int compute({
    required int reps,
    required int faultFrames,
    required int totalAnalysedFrames,
    required double romCompleteness,
  }) {
    if (reps <= 0 || totalAnalysedFrames <= 0) return 0;
    final rom = romCompleteness.clamp(0.0, 1.0);
    final faultRate = (faultFrames / totalAnalysedFrames).clamp(0.0, 1.0);
    final score = rom * romWeight + (1.0 - faultRate) * cleanWeight;
    return score.round().clamp(0, 100);
  }
}
