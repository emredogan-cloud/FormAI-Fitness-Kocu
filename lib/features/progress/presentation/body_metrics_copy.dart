/// Roadmap Phase 9 (C1) · every sentence this feature says about a body,
/// in one file.
///
/// The domain layer returns verdicts and the widgets render them; the
/// mapping between the two lives here on purpose. The roadmap makes
/// emotional safety a first-class requirement for this phase, and a
/// tone review is only possible when there is one place to read.
///
/// Three rules the copy below holds to, and they are worth stating
/// because each of them is a thing a fitness app normally gets wrong:
///
///   1. **Direction is never valence.** Up is the goal for a bulking
///      user and the opposite for a cutting one. Nothing here says
///      "good" or "bad", and nothing colours a number red.
///   2. **A number is never repeated back at somebody in a bad state.**
///      "Moving away from your target" says so once, without quoting the
///      figure a second time.
///   3. **Absence is stated as absence.** One data point produces "log
///      once more", not "no change" — the second is a claim about a body
///      that the data cannot support.
library;

import 'package:intl/intl.dart';

import '../../../core/utils/unit_system.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/models/body_metric.dart';
import '../domain/trend_calculator.dart';

/// Localised name of a measure. Always used in the nominative, set off
/// by punctuation — never dropped inside a sentence, because Turkish
/// would need a case suffix that a placeholder cannot carry.
String measureLabel(AppLocalizations l10n, BodyMeasure measure) =>
    switch (measure) {
      BodyMeasure.weight => l10n.bodyMeasureWeight,
      BodyMeasure.waist => l10n.bodyMeasureWaist,
      BodyMeasure.chest => l10n.bodyMeasureChest,
      BodyMeasure.arm => l10n.bodyMeasureArm,
      BodyMeasure.thigh => l10n.bodyMeasureThigh,
      BodyMeasure.hip => l10n.bodyMeasureHip,
    };

/// Formats a stored metric value in the user's units, with its unit.
///
/// Weight goes through `unit_system.dart` because pounds are a different
/// number; a circumference converts to inches the same way.
///
/// **One decimal on weight, deliberately overriding `formatWeight`'s
/// default of none.** That default is right where it is used — a profile
/// card saying "82 kg" — and wrong here. This screen exists to show
/// small changes over time, and the device walk found it discarding
/// them: a user who typed 82.4 saw "82 kg", and re-opening the entry
/// sheet to edit that day pre-filled "82", so saving again would have
/// silently written away the tenth they had measured. `_trimZeros`
/// means a round value still reads "82 kg", so nothing gains a decimal
/// that does not need one.
String formatMeasure(
  double value,
  BodyMeasure measure, {
  required UnitSystem system,
  required String localeTag,
  bool withUnit = true,
}) {
  if (measure.isWeight) {
    return _localizeDigits(
      formatWeight(value, system: system, withUnit: withUnit, decimals: 1),
      localeTag,
    );
  }
  final converted = system == UnitSystem.metric ? value : cmToInches(value);
  final number = NumberFormat('0.#', localeTag).format(converted);
  if (!withUnit) return number;
  return '$number ${circumferenceUnitLabel(system)}';
}

/// `cm` or `in`. Not in ARB: they are the international symbols, the
/// same in both shipped languages, and the glossary already lists unit
/// symbols as never-translate.
String circumferenceUnitLabel(UnitSystem system) =>
    system == UnitSystem.metric ? 'cm' : 'in'; // i18n-ignore — unit symbol

/// Re-runs a number through the locale's formatter so a decimal
/// separator matches the language around it.
///
/// `formatWeight` is deliberately locale-independent — it is also used
/// for wire-adjacent values — so Turkish would otherwise read "80.4 kg"
/// where it writes "80,4 kg". Splits on the space rather than parsing:
/// the unit label is never localised and must survive untouched.
String _localizeDigits(String formatted, String localeTag) {
  final parts = formatted.split(' ');
  final parsed = double.tryParse(parts.first);
  if (parsed == null) return formatted;
  final number = NumberFormat('0.#', localeTag).format(parsed);
  return parts.length == 1 ? number : '$number ${parts.sublist(1).join(' ')}';
}

/// The plain-language readout for a measure's trend, or null when there
/// is nothing honest to say yet.
///
/// The magnitude is unsigned: the sentence already carries the
/// direction, and "down -2.4 kg" is the kind of double negative that
/// makes a person distrust the whole screen.
String? trendSentence(
  AppLocalizations l10n,
  BodyMeasure measure,
  TrendSummary? summary, {
  required UnitSystem system,
  required String localeTag,
}) {
  if (summary == null) return null;
  final days = summary.spanDays;
  final amount = formatMeasure(
    summary.totalChange.abs(),
    measure,
    system: system,
    localeTag: localeTag,
  );

  // Weight gets a sentence about the person; a tape measurement gets a
  // labelled line. Only because there is exactly one weight — naming a
  // circumference inside a Turkish sentence needs a case suffix.
  if (measure.isWeight) {
    return switch (summary.direction) {
      TrendDirection.falling => l10n.bodyMetricsWeightDown(amount, days),
      TrendDirection.rising => l10n.bodyMetricsWeightUp(amount, days),
      TrendDirection.flat => l10n.bodyMetricsWeightSteady(days),
    };
  }
  final label = measureLabel(l10n, measure);
  return switch (summary.direction) {
    TrendDirection.falling => l10n.bodyMetricsMeasureDown(label, amount, days),
    TrendDirection.rising => l10n.bodyMetricsMeasureUp(label, amount, days),
    TrendDirection.flat => l10n.bodyMetricsMeasureSteady(label, days),
  };
}

/// The reconciliation sentence for a stated target.
///
/// `movingAway` and `reached` take no figure. Reached does not need one;
/// moving away must not have one — quoting the distance back at
/// somebody who has just been told they went the wrong way is the
/// difference between a report and a rebuke.
String goalSentence(
  AppLocalizations l10n,
  GoalReconciliation reconciliation, {
  required UnitSystem system,
  required String localeTag,
}) {
  final remaining = formatMeasure(
    reconciliation.remaining.abs(),
    BodyMeasure.weight,
    system: system,
    localeTag: localeTag,
  );
  return switch (reconciliation.pace) {
    GoalPace.ahead => l10n.bodyMetricsGoalAhead(remaining),
    GoalPace.onTrack => l10n.bodyMetricsGoalOnTrack(remaining),
    GoalPace.behind => l10n.bodyMetricsGoalBehind(remaining),
    GoalPace.movingAway => l10n.bodyMetricsGoalMovingAway,
    GoalPace.reached => l10n.bodyMetricsGoalReached,
  };
}

/// "Week 5 of 12", counting past twelve when the user is past twelve.
String goalWeekLabel(AppLocalizations l10n, GoalReconciliation r) =>
    l10n.bodyMetricsGoalWeek(
      r.elapsedWeeks.floor() + 1,
      r.horizonWeeks.round(),
    );

/// A percentage with the sign where the language puts it — Turkish
/// writes `%82`, English `82%`. Orthography, not number formatting, and
/// the third time this codebase has needed its own key for it.
String percentLabel(AppLocalizations l10n, double fraction) =>
    l10n.adherencePercentValue((fraction * 100).round());
