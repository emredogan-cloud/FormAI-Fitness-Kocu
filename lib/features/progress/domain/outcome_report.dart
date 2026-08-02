/// Roadmap Phase 10 (C4, C39) · the 30-day outcome report, as data.
///
/// The store listing promises "measurable results". This file is what
/// makes that literally true: it aggregates everything the app has
/// already logged — sessions, reps, minutes, body measurements, streaks,
/// badges, XP — into one typed value that a screen, a share image and an
/// LLM prompt can all read from without any of them re-deriving it.
///
/// **It is pure, and it returns verdicts rather than sentences.** No
/// `BuildContext`, no providers, no `DateTime.now()` — the moment is
/// passed in. Copy lives in `outcome_report_copy.dart`, for the same
/// reason the trend maths and `body_metrics_copy.dart` are separate: the
/// tone of this artifact is the hard part and it should be readable in
/// one sitting, in one file, without arithmetic in the way.
///
/// Three rules the maths holds to, all inherited from Phase 9:
///
///   * **A missing section is missing, not zero.** Null means "the app
///     cannot honestly report this", and every field that can be unknown
///     is nullable rather than defaulted. A report that says a user
///     gained 0 kg when they never weighed themselves is a lie with a
///     number in it.
///   * **Direction is never valence.** [BodyDelta] carries a signed
///     change and nothing else. It does not know whether down is good.
///   * **Nothing is extrapolated.** Every figure is a count or a
///     difference over data that exists. There is no projection here,
///     which is also what keeps the artifact inside the store's rules on
///     quantified outcome promises.
library;

import '../../workout/models/session_log_model.dart';
import 'models/body_metric.dart';
import 'trend_calculator.dart';

/// One measure's movement across the reported window.
class BodyDelta {
  const BodyDelta({
    required this.measure,
    required this.first,
    required this.last,
    required this.firstDay,
    required this.lastDay,
  });

  final BodyMeasure measure;

  /// Values in STORAGE units — kilograms and centimetres. Conversion to
  /// the user's system happens at render time, exactly once, the same
  /// way the rest of the app does it.
  final double first;
  final double last;

  final DateTime firstDay;
  final DateTime lastDay;

  /// Signed. Negative is a decrease. It is not "progress" or "a loss" —
  /// which of those it is depends on a goal this class does not know.
  double get change => last - first;

  int get spanDays => lastDay.difference(firstDay).inDays;

  /// True when the movement is smaller than the measurement noise of the
  /// instrument. A bathroom scale is not accurate to 50 g and a tape
  /// measure is not accurate to a millimetre, so reporting either as
  /// change would be reporting the error bar.
  bool get isNoise => change.abs() < (measure.isWeight ? 0.2 : 0.5);
}

/// What kind of thing happened. The token, never the sentence.
enum MilestoneKind {
  firstWorkout,
  streak,
  badge,
  personalBestReps,
  weightLogged,
  halfway,
  programComplete,
}

/// One dated event in the journey, in the order it happened.
class Milestone {
  const Milestone({
    required this.at,
    required this.kind,
    this.token,
    this.value,
  });

  final DateTime at;
  final MilestoneKind kind;

  /// Stable identifier for the thing, when there is one — a badge id.
  /// Never a label: labels move when the app is translated.
  final String? token;

  /// The number the milestone is about, when there is one — a streak
  /// length, a rep count.
  final num? value;
}

/// Everything the report renders, computed once.
class OutcomeReport {
  const OutcomeReport({
    required this.windowStart,
    required this.windowEnd,
    required this.programLength,
    required this.daysCompleted,
    required this.sessionCount,
    required this.totalActiveTime,
    required this.totalReps,
    required this.totalSets,
    required this.estimatedKcal,
    required this.longestStreak,
    required this.currentStreak,
    required this.badgeIds,
    required this.lifetimeXp,
    required this.level,
    required this.weight,
    required this.measurements,
    required this.adherence,
    required this.milestones,
    required this.firstSessionAt,
    required this.lastSessionAt,
    required this.cameraFreeSessions,
  });

  final DateTime windowStart;
  final DateTime windowEnd;

  final int programLength;
  final int daysCompleted;
  final int sessionCount;

  final Duration totalActiveTime;
  final int totalReps;
  final int totalSets;

  /// Derived from completed days at the app's standing per-day figure,
  /// not from a per-exercise MET model. It is an estimate and the copy
  /// says so; inventing precision here would be the same mistake as a
  /// projection.
  final int estimatedKcal;

  final int longestStreak;
  final int currentStreak;

  /// Unlocked badge ids, in catalogue order.
  final List<String> badgeIds;

  final int lifetimeXp;
  final int level;

  /// Null when the user never logged a weight, or logged it once. One
  /// reading is not a change.
  final BodyDelta? weight;

  /// The tape measurements that moved, same rule. Empty is a valid and
  /// common state.
  final List<BodyDelta> measurements;

  final AdherenceSummary adherence;

  /// Chronological, oldest first.
  final List<Milestone> milestones;

  final DateTime? firstSessionAt;
  final DateTime? lastSessionAt;

  /// How many of [sessionCount] were counted by hand rather than by the
  /// camera. Reported because a camera-free user's report should look
  /// exactly like anyone else's, and the only way to be sure it does is
  /// to be able to see the split.
  final int cameraFreeSessions;

  double get completionFraction =>
      programLength <= 0 ? 0 : (daysCompleted / programLength).clamp(0.0, 1.0);

  /// True when the report has enough in it to be worth showing at all.
  ///
  /// One session is a receipt, not a report. The screen offers an empty
  /// state instead, which is the same call the body-metrics screen makes
  /// about a single weight reading.
  bool get isSubstantive => sessionCount >= 2;

  /// True in the few days after each 30-day block since the first
  /// session — the window in which a monthly recap is worth surfacing.
  ///
  /// Keyed to the user's OWN start date rather than the calendar month,
  /// because "your month" means the thirty days they trained, not the
  /// thirty days the wall calendar happened to contain. Somebody who
  /// started on the 20th gets their recap on the 20th.
  ///
  /// A three-day window rather than a single day: the recap surfaces on
  /// a card the user has to open the app to see, and a one-day window
  /// means anybody who skips a day never sees one.
  bool get isRecapDue {
    final first = firstSessionAt;
    if (first == null || !isSubstantive) return false;
    final days = windowEnd.difference(_dayOf(first)).inDays;
    return days >= 30 && days % 30 < 3;
  }

  static DateTime _dayOf(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  /// True when there is nothing measured about the body in it. The
  /// report is still worth generating — sessions, minutes and streaks
  /// are outcomes too — but the layout drops a whole section, and the
  /// narrative must not imply a body change it cannot see.
  bool get hasBodyData => weight != null || measurements.isNotEmpty;
}

/// Builds an [OutcomeReport] from the app's own logs.
///
/// Every input is passed in rather than read from a provider, so the
/// whole thing is testable without a `ProviderContainer` and cannot
/// accidentally depend on wall-clock time.
abstract final class OutcomeReportBuilder {
  static OutcomeReport build({
    required Map<int, SessionLog> sessionLogs,
    required List<BodyMetric> bodyMetrics,
    required List<String> unlockedBadgeIds,
    required AdherenceSummary adherence,
    required int lifetimeXp,
    required int level,
    required int programLength,
    required int kcalPerCompletedDay,
    required DateTime asOf,
    Duration window = const Duration(days: 30),
  }) {
    final windowStart = _dayOf(asOf.subtract(window));
    final windowEnd = _dayOf(asOf);

    // Logs are keyed by program day, which is not chronological order —
    // a user can complete day 5 before day 4 is marked. Sort by the
    // timestamp, and drop the ones that have none rather than guessing.
    final dated = <({DateTime at, SessionLog log})>[];
    for (final log in sessionLogs.values) {
      final at = DateTime.tryParse(log.completedAtIso);
      if (at == null) continue;
      dated.add((at: at.toLocal(), log: log));
    }
    dated.sort((a, b) => a.at.compareTo(b.at));

    final inWindow = dated
        .where((e) => !_dayOf(e.at).isBefore(windowStart))
        .toList(growable: false);

    var totalSeconds = 0;
    var totalReps = 0;
    var totalSets = 0;
    var cameraFree = 0;
    for (final entry in inWindow) {
      totalSeconds += entry.log.durationSeconds;
      totalReps += entry.log.totalReps;
      for (final exercise in entry.log.exerciseLogs) {
        totalSets += exercise.actualSets;
      }
      if (entry.log.source == SessionSource.manual) cameraFree++;
    }

    final weight = _deltaFor(BodyMeasure.weight, bodyMetrics, windowStart);
    final measurements = <BodyDelta>[
      for (final measure in BodyMeasure.values)
        if (!measure.isWeight)
          if (_deltaFor(measure, bodyMetrics, windowStart) case final d?) d,
    ];

    return OutcomeReport(
      windowStart: windowStart,
      windowEnd: windowEnd,
      programLength: programLength,
      daysCompleted: sessionLogs.keys.where((day) => day > 0).length,
      sessionCount: inWindow.length,
      totalActiveTime: Duration(seconds: totalSeconds),
      totalReps: totalReps,
      totalSets: totalSets,
      estimatedKcal: inWindow.length * kcalPerCompletedDay,
      longestStreak: adherence.longestStreak,
      currentStreak: adherence.currentStreak,
      badgeIds: List.unmodifiable(unlockedBadgeIds),
      lifetimeXp: lifetimeXp,
      level: level,
      weight: weight,
      measurements: List.unmodifiable(measurements),
      adherence: adherence,
      milestones: _milestones(
        dated: dated,
        bodyMetrics: bodyMetrics,
        unlockedBadgeIds: unlockedBadgeIds,
        adherence: adherence,
        programLength: programLength,
      ),
      firstSessionAt: dated.isEmpty ? null : dated.first.at,
      lastSessionAt: dated.isEmpty ? null : dated.last.at,
      cameraFreeSessions: cameraFree,
    );
  }

  /// First and last reading of one measure inside the window.
  ///
  /// Deliberately NOT smoothed, unlike the trend chart. A chart is about
  /// the shape of a month; this is about two facts a user typed, and
  /// smoothing them would make the report disagree with the entry list
  /// it sits above.
  static BodyDelta? _deltaFor(
    BodyMeasure measure,
    List<BodyMetric> metrics,
    DateTime windowStart,
  ) {
    final points = <({DateTime day, double value})>[];
    for (final metric in metrics) {
      final value = metric.valueOf(measure);
      if (value == null) continue;
      final day = _dayOf(metric.recordedOn);
      if (day.isBefore(windowStart)) continue;
      points.add((day: day, value: value));
    }
    if (points.length < 2) return null;
    points.sort((a, b) => a.day.compareTo(b.day));
    return BodyDelta(
      measure: measure,
      first: points.first.value,
      last: points.last.value,
      firstDay: points.first.day,
      lastDay: points.last.day,
    );
  }

  /// The journey as a list of dated events.
  ///
  /// **Badges have no unlock timestamp anywhere in the app** — they are
  /// derived predicates over the current state, not rows with a date. So
  /// they are placed at the last session rather than given an invented
  /// date, and the timeline copy says "earned" rather than "earned on".
  /// Storing unlock dates is a migration, and this phase does not need
  /// one to be useful.
  static List<Milestone> _milestones({
    required List<({DateTime at, SessionLog log})> dated,
    required List<BodyMetric> bodyMetrics,
    required List<String> unlockedBadgeIds,
    required AdherenceSummary adherence,
    required int programLength,
  }) {
    final out = <Milestone>[];
    if (dated.isEmpty) return out;

    out.add(Milestone(
      at: dated.first.at,
      kind: MilestoneKind.firstWorkout,
      value: dated.first.log.dayNumber,
    ));

    // The best single session by reps. Ties resolve to the earliest,
    // because the first time somebody hit a number is the moment worth
    // naming.
    ({DateTime at, int reps})? best;
    for (final entry in dated) {
      final reps = entry.log.totalReps;
      if (reps <= 0) continue;
      if (best == null || reps > best.reps) best = (at: entry.at, reps: reps);
    }
    if (best != null && best.reps > 0) {
      out.add(Milestone(
        at: best.at,
        kind: MilestoneKind.personalBestReps,
        value: best.reps,
      ));
    }

    if (adherence.longestStreak >= 2) {
      out.add(Milestone(
        at: dated.last.at,
        kind: MilestoneKind.streak,
        value: adherence.longestStreak,
      ));
    }

    final halfway = programLength ~/ 2;
    for (final entry in dated) {
      if (entry.log.dayNumber >= halfway && halfway > 0) {
        out.add(Milestone(at: entry.at, kind: MilestoneKind.halfway));
        break;
      }
    }

    final weights = bodyMetrics
        .where((m) => m.weightKg != null)
        .toList(growable: false)
      ..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));
    if (weights.isNotEmpty) {
      out.add(Milestone(
        at: _dayOf(weights.first.recordedOn),
        kind: MilestoneKind.weightLogged,
        value: weights.first.weightKg,
      ));
    }

    for (final id in unlockedBadgeIds) {
      out.add(Milestone(
        at: dated.last.at,
        kind: MilestoneKind.badge,
        token: id,
      ));
    }

    final completedDays = dated.map((e) => e.log.dayNumber).toSet();
    if (programLength > 0 && completedDays.length >= programLength) {
      out.add(
          Milestone(at: dated.last.at, kind: MilestoneKind.programComplete));
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return List.unmodifiable(out);
  }

  static DateTime _dayOf(DateTime when) =>
      DateTime(when.year, when.month, when.day);
}
