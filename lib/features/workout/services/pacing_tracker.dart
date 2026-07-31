import '../domain/coach_line.dart';

/// Tier-A.7 audit closure · shared pacing tracker.
///
/// CrunchAnalyzer historically owned the only "tempo coach" — it
/// measured per-rep duration and emitted "Biraz yavaşla" or "Hadi,
/// pes etme" when the user was too fast or too slow. Audit §8 Tier-A
/// item 7 asked to copy that mechanism to every other rep-counting
/// analyzer; this class is the shared primitive that makes those
/// additions one-liner per analyzer.
///
/// Usage from inside an analyzer's `analyze`:
///
/// ```dart
/// // after the rep state machine commits a rep:
/// final repDuration = lastRepTime == null
///     ? null
///     : now.difference(lastRepTime);
/// _lastRepTime = now;
/// if (repDuration != null) {
///   pacingFeedback = _pacing.evaluate(repDuration, now);
/// }
/// ```
///
/// The tracker keeps its own cooldown so analyzers can't accidentally
/// flood the TTS queue. The user only ever hears at most one pacing
/// line per [cooldown] window per analyzer.
class PacingTracker {
  PacingTracker({
    this.tooFast = const Duration(milliseconds: 1500),
    this.tooSlow = const Duration(milliseconds: 4500),
    this.cooldown = const Duration(seconds: 7),
    this.fastPhrase = CoachLine.slowDownControlled,
    this.slowPhrase = CoachLine.dontGiveUp,
  });

  /// Rep durations shorter than this trigger the "slow down" line.
  final Duration tooFast;

  /// Rep durations longer than this trigger the "keep going" line.
  final Duration tooSlow;

  /// Minimum gap between two emitted pacing lines.
  final Duration cooldown;

  /// The line to emit when [tooFast] fires.
  final CoachLine fastPhrase;

  /// The line to emit when [tooSlow] fires.
  final CoachLine slowPhrase;

  DateTime? _lastFeedbackTime;

  /// Returns a pacing phrase if the just-completed rep ([repDuration])
  /// is outside the expected tempo window AND the cooldown has elapsed.
  /// Returns null otherwise — caller passes the result straight through
  /// to `CrunchResult.pacingFeedback`.
  CoachLine? evaluate(Duration repDuration, DateTime now) {
    final last = _lastFeedbackTime;
    if (last != null && now.difference(last) < cooldown) return null;
    if (repDuration < tooFast) {
      _lastFeedbackTime = now;
      return fastPhrase;
    } else if (repDuration > tooSlow) {
      _lastFeedbackTime = now;
      return slowPhrase;
    }
    return null;
  }

  /// Resets the cooldown. Called from each analyzer's `reset()` so a
  /// new set starts the pacing clock fresh.
  void reset() {
    _lastFeedbackTime = null;
  }
}

/// Pre-tuned [PacingTracker] presets for the three tempo bands the
/// existing analyzers fall into. Strength is the default; cardio /
/// burpee shift the thresholds and copy to fit the natural rep
/// duration of those movements.
class PacingPresets {
  PacingPresets._();

  /// Default strength tempo: 1.5 s = "snappy", 4.5 s = "grinding."
  /// Matches CrunchAnalyzer's original tuning.
  static PacingTracker strength() => PacingTracker();

  /// Fast cardio: jumping jack, mountain climber, flutter kick,
  /// bicycle crunch. Reps fire every 0.3-1.5 s naturally; the
  /// tracker shouldn't yell "yavaşla" at correct-tempo work.
  static PacingTracker cardio() => PacingTracker(
        tooFast: const Duration(milliseconds: 350),
        tooSlow: const Duration(milliseconds: 1500),
        fastPhrase: CoachLine.dropTempoStayControlled,
        slowPhrase: CoachLine.raiseTempo,
      );

  /// Compound / multi-phase movements (burpee, russian twist) sit
  /// between strength and cardio.
  static PacingTracker compound() => PacingTracker(
        tooFast: const Duration(milliseconds: 1000),
        tooSlow: const Duration(milliseconds: 3000),
        fastPhrase: CoachLine.dontLoseControl,
        slowPhrase: CoachLine.keepTheRhythm,
      );
}
