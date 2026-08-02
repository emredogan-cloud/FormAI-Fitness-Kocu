/// Roadmap Phase 10 (C4, C39) · every sentence the outcome report says.
///
/// Separated from `outcome_report.dart` for the same reason
/// `body_metrics_copy.dart` is separated from `trend_calculator.dart`:
/// **the tone of this artifact is the hard part**, and it should be
/// readable end to end without arithmetic in between. Somebody reviewing
/// whether this report is kind can read one file.
///
/// The rules it holds to, all of which are the report's whole point:
///
///   * **No body-shape judgement, anywhere.** The roadmap asks for this
///     explicitly. A delta is stated as two ends — "Waist — 92 cm to
///     89 cm" — rather than as a signed difference, because a signed
///     difference is one formatting decision away from reading like a
///     score.
///   * **A change smaller than the instrument is "unchanged".** Not
///     "0.1 kg". Reporting a number that is inside the scale's own error
///     is reporting the error.
///   * **The absence of a section is never framed as a failure.** "You
///     didn't log a measurement this month, so there's nothing to
///     compare. The sessions above happened either way."
library;

import '../../../core/utils/unit_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/outcome_report.dart';
import '../providers/badge_unlocks_provider.dart';
import 'badge_copy.dart';
import 'body_metrics_copy.dart';

/// The window, as a subtitle. Both dates already formatted.
String reportWindow(AppLocalizations l10n, String start, String end) =>
    l10n.outcomeReportSubtitle(start, end);

/// "Waist — 92 cm to 89 cm", or "Waist — unchanged".
///
/// Both ends are stated in the user's own unit system, converted exactly
/// once at this boundary. [BodyDelta] carries storage units and knows
/// nothing about pounds.
String deltaSentence(
  AppLocalizations l10n,
  BodyDelta delta, {
  required UnitSystem system,
  required String localeTag,
}) {
  final measure = measureLabel(l10n, delta.measure);
  if (delta.isNoise) return l10n.outcomeReportDeltaSteady(measure);
  String at(double value) => formatMeasure(
        value,
        delta.measure,
        system: system,
        localeTag: localeTag,
      );
  return l10n.outcomeReportDeltaChange(
      measure, at(delta.first), at(delta.last));
}

/// One line of the milestone timeline.
///
/// Returns null for a badge whose id is not in the catalogue, so an id
/// that outlives its copy drops the row rather than rendering a token at
/// a person.
String? milestoneSentence(AppLocalizations l10n, Milestone milestone) {
  switch (milestone.kind) {
    case MilestoneKind.firstWorkout:
      return l10n.outcomeReportMilestoneFirstWorkout;
    case MilestoneKind.streak:
      return l10n.outcomeReportMilestoneStreak((milestone.value ?? 0).round());
    case MilestoneKind.personalBestReps:
      return l10n.outcomeReportMilestoneBest((milestone.value ?? 0).round());
    case MilestoneKind.weightLogged:
      return l10n.outcomeReportMilestoneWeight;
    case MilestoneKind.halfway:
      return l10n.outcomeReportMilestoneHalfway;
    case MilestoneKind.programComplete:
      return l10n.outcomeReportMilestoneComplete;
    case MilestoneKind.badge:
      final badge = _badge(milestone.token);
      if (badge == null) return null;
      return l10n.outcomeReportMilestoneBadgeNamed(badge.title(l10n));
  }
}

/// The emoji that fronts a timeline row. Not copy — a glyph, and the
/// same one in every language.
String milestoneGlyph(Milestone milestone) {
  switch (milestone.kind) {
    case MilestoneKind.firstWorkout:
      return '🎬'; // i18n-ignore — glyph
    case MilestoneKind.streak:
      return '🔥'; // i18n-ignore — glyph
    case MilestoneKind.personalBestReps:
      return '⚡'; // i18n-ignore — glyph
    case MilestoneKind.weightLogged:
      return '⚖️'; // i18n-ignore — glyph
    case MilestoneKind.halfway:
      return '⛰️'; // i18n-ignore — glyph
    case MilestoneKind.programComplete:
      return '🏁'; // i18n-ignore — glyph
    case MilestoneKind.badge:
      return _badge(milestone.token)?.emoji ?? '🏅'; // i18n-ignore — glyph
  }
}

/// The catalogue entry for an id, or null when an id has outlived its
/// definition. Returning null rather than throwing is what lets a stale
/// persisted id drop a timeline row instead of taking down the report.
BadgeDefinition? _badge(String? id) {
  if (id == null) return null;
  for (final badge in kBadgeCatalog) {
    if (badge.id == id) return badge;
  }
  return null;
}
