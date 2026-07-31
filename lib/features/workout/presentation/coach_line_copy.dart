import '../../../l10n/app_localizations.dart';
import '../domain/coach_line.dart';

/// Roadmap Phase 5 · the words for a [CoachLine].
///
/// The only place in the app that turns an analyzer's verdict into a
/// sentence. Everything upstream — five analyzer files, the pacing
/// tracker, the rep counters — now traffics in [CoachLine] and never
/// touches an `AppLocalizations`.
///
/// Exhaustive with no `default`: a new [CoachLine] fails the build until
/// it has copy. That matters more here than in most switches, because
/// the failure mode of a missing line is silence — the coach simply
/// doesn't speak, and nothing in the app looks broken while the feature
/// the user paid for quietly stops working.
extension CoachLineCopy on CoachLine {
  /// The spoken and on-screen text for this line.
  ///
  /// Corrections address the movement, never the person: "keep your neck
  /// straight", not "your neck is wrong". A user hearing a fault called
  /// out mid-rep is already at their physical limit, and copy that lands
  /// as criticism is copy that gets the voice coach switched off.
  String text(AppLocalizations l10n) => switch (this) {
        CoachLine.neckStraight => l10n.coachNeckStraight,
        CoachLine.plankHipsLevel => l10n.coachPlankHipsLevel,
        CoachLine.pushUpHipsUp => l10n.coachPushUpHipsUp,
        CoachLine.squatChestUp => l10n.coachSquatChestUp,
        CoachLine.gluteBridgeSqueeze => l10n.coachGluteBridgeSqueeze,
        CoachLine.elbowTucked => l10n.coachElbowTucked,
        CoachLine.armsFullyExtended => l10n.coachArmsFullyExtended,
        CoachLine.armsShoulderHeight => l10n.coachArmsShoulderHeight,
        CoachLine.slowDownFeelIt => l10n.coachSlowDownFeelIt,
        CoachLine.slowDownControlled => l10n.coachSlowDownControlled,
        CoachLine.dontGiveUp => l10n.coachDontGiveUp,
        CoachLine.dropTempoStayControlled => l10n.coachDropTempoStayControlled,
        CoachLine.raiseTempo => l10n.coachRaiseTempo,
        CoachLine.dontLoseControl => l10n.coachDontLoseControl,
        CoachLine.keepTheRhythm => l10n.coachKeepTheRhythm,
        CoachLine.doingGreat => l10n.coachDoingGreat,
        CoachLine.holdOn => l10n.coachHoldOn,
        CoachLine.goodRhythm => l10n.coachGoodRhythm,
        CoachLine.burpeeGetDown => l10n.coachBurpeeGetDown,
      };
}
