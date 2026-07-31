import '../../../l10n/app_localizations.dart';
import '../domain/framing_validator.dart';

/// Roadmap Phase 5 · the words for a [FramingIssue].
///
/// This copy used to live on `FramingResult.hint` in the domain layer,
/// which put user-facing Turkish inside a file whose own contract is
/// "pure functions over a Pose — no camera, no widgets". It also sat
/// outside the hardcoded-string gate, which only scans `/presentation/`:
/// the single most-read line on the calibration screen was invisible to
/// the tool built to catch exactly that.
///
/// Splitting it keeps the domain deciding *what is wrong* and the
/// presentation layer deciding *what to say about it* — the same split
/// applied to `PracticeRepStage.trackedJoints`.
///
/// The original getter earned its place with a comment: "kept beside the
/// enum so a new issue can't ship without copy". That property is
/// preserved here rather than dropped — the switch below is exhaustive
/// with no `default`, so adding a `FramingIssue` value fails the build
/// until it has a line.
extension FramingIssueCopy on FramingIssue {
  /// Guidance for this issue.
  ///
  /// Deliberately phrased as an instruction to the *setup*, never as a
  /// judgement of the user — "step back a bit", not "you are too close".
  /// A user who reads the framing hint as criticism stops adjusting and
  /// starts apologising, and the calibration never completes.
  String hint(AppLocalizations l10n) => switch (this) {
        FramingIssue.noPose => l10n.framingHintNoPose,
        FramingIssue.partiallyVisible => l10n.framingHintPartiallyVisible,
        FramingIssue.tooFar => l10n.framingHintTooFar,
        FramingIssue.tooClose => l10n.framingHintTooClose,
        FramingIssue.wrongOrientation => l10n.framingHintWrongOrientation,
        FramingIssue.none => l10n.framingHintReady,
      };
}
