/// Roadmap Phase 9 (C1) · the maths behind "is this working?".
///
/// Pure: no Flutter, no l10n, no providers, no clock of its own — every
/// function takes the `asOf` day it should reason from. That is what
/// makes the plateau and reconciliation cases testable at all, since
/// both are defined over weeks and neither can be exercised by a test
/// that has to wait for them.
///
/// **No copy lives here, only verdicts.** The functions return enums;
/// the presentation layer maps a verdict to a sentence. Weight is
/// charged, so the wording of every state gets reviewed in one place
/// rather than being scattered through arithmetic.
library;

import 'dart:math' as math;

import 'models/body_metric.dart';

/// One observation, plus the smoothed value at that day.
class TrendPoint {
  const TrendPoint({
    required this.day,
    required this.value,
    required this.smoothed,
  });

  final DateTime day;

  /// What the user actually logged.
  final double value;

  /// The trailing-window average at this day — the line the chart draws
  /// through the noise. See [TrendSeries.from] for why trailing.
  final double smoothed;
}

/// Which way a series is moving, without saying whether that is good.
///
/// Direction is not valence. Gaining is the goal for a bulking user and
/// the opposite for a cutting one, and the same waist number means
/// different things to each. Nothing in this file decides which; the
/// presentation layer knows the user's goal and colours it there — or,
/// per the emotional-safety requirement, declines to colour it at all.
enum TrendDirection { rising, falling, flat }

/// What a series is doing over a window, as a number and a verdict.
class TrendSummary {
  const TrendSummary({
    required this.direction,
    required this.changePerWeek,
    required this.totalChange,
    required this.spanDays,
    required this.pointCount,
    required this.isPlateau,
  });

  final TrendDirection direction;

  /// Least-squares slope, in units per week. Signed: negative is down.
  ///
  /// A regression rather than (last − first) / weeks, because the two
  /// endpoints of a body-weight series are the two least trustworthy
  /// numbers in it — one bad morning at either end would otherwise
  /// define the whole verdict.
  final double changePerWeek;

  /// Smoothed last minus smoothed first over the window. This is the
  /// number a readout quotes ("2.4 kg in the last 30 days"), because it
  /// is the one the user can check against their own memory.
  final double totalChange;

  final int spanDays;
  final int pointCount;

  /// True when the series has been genuinely still for long enough that
  /// stillness is information rather than noise. See [kPlateauMinDays].
  final bool isPlateau;
}

/// How actual movement compares with the user's own stated target.
///
/// Never against an app-generated projection: this app is not permitted
/// to promise a numeric outcome, and `target_weight_kg` is a number the
/// user typed. See `target_weight_provider.dart`.
enum GoalPace {
  /// Moving toward the target faster than the elapsed time implies.
  ahead,

  /// Moving toward it at roughly the pace the arc implies.
  onTrack,

  /// Moving the right way, slower than the arc implies.
  behind,

  /// Moving away from the target.
  movingAway,

  /// Already at or past the target.
  reached,
}

class GoalReconciliation {
  const GoalReconciliation({
    required this.pace,
    required this.startValue,
    required this.currentValue,
    required this.targetValue,
    required this.elapsedWeeks,
    required this.horizonWeeks,
    required this.progressFraction,
    required this.expectedFraction,
    required this.remaining,
  });

  final GoalPace pace;
  final double startValue;
  final double currentValue;
  final double targetValue;

  /// Whole weeks between the first logged entry and `asOf`, uncapped —
  /// a user past week 12 keeps counting, because pretending the clock
  /// stopped is its own dishonesty.
  final double elapsedWeeks;

  /// The arc the onboarding report set up, in weeks.
  final double horizonWeeks;

  /// How much of the distance to the target has been covered, 0–1+.
  /// Negative when moving away.
  final double progressFraction;

  /// How much the elapsed time implies should have been, 0–1.
  final double expectedFraction;

  /// Signed distance still to go, in the measure's own units.
  final double remaining;
}

/// The onboarding report's arc, in weeks. `act_4_revelation_steps.dart`
/// paints "12 HAFTA" / "12 WEEKS" as the far end of the trajectory; this
/// is the same twelve, and it is the only thing this file borrows from
/// that screen — the projection there is qualitative on purpose.
const double kProjectionHorizonWeeks = 12;

/// Trailing window for the smoothed line, in days.
///
/// Seven because a body-weight series is dominated by a weekly rhythm —
/// people eat differently at weekends — and a seven-day window cancels
/// exactly that period. It is also the smallest window that survives a
/// user who logs once a week.
const int kSmoothingWindowDays = 7;

/// A plateau needs three weeks. Two is inside the noise of a single
/// bad week; four is long enough that the user has already drawn their
/// own conclusion and the coaching arrives too late to be useful.
const int kPlateauMinDays = 21;

/// …and at least this many observations inside it, so two points three
/// weeks apart cannot be called a plateau.
const int kPlateauMinPoints = 4;

/// Below this weekly rate, a weight series is not moving. 0.15 kg/week
/// is under a tenth of the day-to-day noise in body weight, so anything
/// slower is indistinguishable from standing still.
const double kWeightPlateauPerWeek = 0.15;

/// Circumference equivalent. A tape measure resolves about half a
/// centimetre in untrained hands, so a quarter-centimetre a week is the
/// same "cannot tell this from zero" threshold.
const double kCircumferencePlateauPerWeek = 0.25;

double plateauThresholdFor(BodyMeasure measure) =>
    measure.isWeight ? kWeightPlateauPerWeek : kCircumferencePlateauPerWeek;

/// One measure's history, smoothed and queryable.
class TrendSeries {
  const TrendSeries._(this.measure, this.points);

  final BodyMeasure measure;

  /// Ascending by day. Empty when the user has never logged [measure].
  final List<TrendPoint> points;

  bool get isEmpty => points.isEmpty;

  /// Builds the series for [measure] out of raw entries.
  ///
  /// **The smoother is a trailing time window, not an N-point average.**
  /// Body-metric logging is irregular by nature — someone logs daily for
  /// a fortnight, goes on holiday, comes back. An N-point average treats
  /// those fourteen days and the two weeks of silence as equal
  /// neighbours and drags the post-holiday value backwards into a period
  /// it says nothing about. A ±days window is the only smoother that
  /// reads a gap as a gap.
  ///
  /// Trailing rather than centred because a centred window makes today's
  /// smoothed value depend on data that does not exist yet, so every
  /// point would silently change for a week after it was drawn. A chart
  /// whose history rewrites itself is not one anybody can trust.
  factory TrendSeries.from(
    List<BodyMetric> entries,
    BodyMeasure measure, {
    int windowDays = kSmoothingWindowDays,
  }) {
    final raw = <({DateTime day, double value})>[];
    for (final entry in entries) {
      final value = entry.valueOf(measure);
      if (value != null) raw.add((day: entry.recordedOn, value: value));
    }
    raw.sort((a, b) => a.day.compareTo(b.day));

    final points = <TrendPoint>[];
    for (var i = 0; i < raw.length; i++) {
      final windowStart = raw[i].day.subtract(Duration(days: windowDays - 1));
      var sum = 0.0;
      var count = 0;
      // Walk backwards from i — the window only ever reaches into the
      // past, so this is O(window) rather than O(n) per point.
      for (var j = i; j >= 0; j--) {
        if (raw[j].day.isBefore(windowStart)) break;
        sum += raw[j].value;
        count++;
      }
      points.add(TrendPoint(
        day: raw[i].day,
        value: raw[i].value,
        smoothed: sum / count,
      ));
    }
    return TrendSeries._(measure, points);
  }

  /// The points logged on or after [from].
  List<TrendPoint> since(DateTime from) {
    final cutoff = BodyMetric.dayOf(from);
    return points.where((p) => !p.day.isBefore(cutoff)).toList();
  }

  /// The most recent raw observation, or null.
  TrendPoint? get latest => points.isEmpty ? null : points.last;

  /// The oldest observation, or null.
  TrendPoint? get first => points.isEmpty ? null : points.first;

  /// What the series has done over the last [days], or null when there
  /// is not enough of it to say anything.
  ///
  /// Two points is the minimum for a direction and the minimum for a
  /// slope; with one, the honest answer is "not yet", and returning a
  /// zero-change summary instead would render as "you have not moved",
  /// which is a claim about a body rather than about the data.
  ///
  /// Two points on consecutive days is also refused. Body weight swings
  /// by more overnight than a good week moves it, so a one-day span is
  /// noise wearing a trend's clothes — and the readout it produces
  /// ("over the last 1 days") is broken English on top of being a
  /// meaningless claim.
  TrendSummary? summarize({
    required DateTime asOf,
    required int days,
  }) {
    final window = since(BodyMetric.dayOf(asOf).subtract(Duration(days: days)));
    if (window.length < 2) return null;
    if (window.last.day.difference(window.first.day).inDays < 2) return null;

    final threshold = plateauThresholdFor(measure);
    final perWeek = _slopePerWeek(window);
    final total = window.last.smoothed - window.first.smoothed;
    final span = window.last.day.difference(window.first.day).inDays;

    final direction = perWeek.abs() < threshold
        ? TrendDirection.flat
        : (perWeek > 0 ? TrendDirection.rising : TrendDirection.falling);

    return TrendSummary(
      direction: direction,
      changePerWeek: perWeek,
      totalChange: total,
      spanDays: span,
      pointCount: window.length,
      isPlateau: span >= kPlateauMinDays &&
          window.length >= kPlateauMinPoints &&
          perWeek.abs() < threshold,
    );
  }

  /// Reconciles real movement against the user's own [target].
  ///
  /// Returns null when there is no target, no data, or when start and
  /// target are the same value — "you have zero distance to cover" is
  /// not a progress statement, and dividing by it produces infinities
  /// that render as `NaN%` on a card about somebody's body.
  GoalReconciliation? reconcile({
    required DateTime asOf,
    required double? target,
    double horizonWeeks = kProjectionHorizonWeeks,
  }) {
    if (target == null) return null;
    final start = first;
    final current = latest;
    if (start == null || current == null) return null;

    final needed = target - start.value;
    if (needed.abs() < 0.05) return null;

    // The smoothed value, not the raw one: a reconciliation that flips
    // between "ahead" and "behind" because of one heavy dinner is
    // exactly the sort of thing that makes a person stop logging.
    final achieved = current.smoothed - start.value;
    final progress = achieved / needed;

    final elapsedDays =
        BodyMetric.dayOf(asOf).difference(start.day).inDays.toDouble();
    final elapsedWeeks = math.max(0.0, elapsedDays / 7.0);
    final expected =
        horizonWeeks <= 0 ? 1.0 : math.min(1.0, elapsedWeeks / horizonWeeks);

    final GoalPace pace;
    if (progress >= 1.0) {
      pace = GoalPace.reached;
    } else if (progress < 0) {
      pace = GoalPace.movingAway;
    } else if (expected <= 0) {
      // Day one. Nobody is behind on day one.
      pace = GoalPace.onTrack;
    } else if (progress >= expected * 1.1) {
      pace = GoalPace.ahead;
    } else if (progress >= expected * 0.75) {
      // A quarter under the line is still on track. The band is
      // deliberately wide and deliberately asymmetric: real bodies do
      // not move linearly, and a card that says "behind" on week three
      // of a twelve-week arc is punishing someone for arithmetic.
      pace = GoalPace.onTrack;
    } else {
      pace = GoalPace.behind;
    }

    return GoalReconciliation(
      pace: pace,
      startValue: start.value,
      currentValue: current.smoothed,
      targetValue: target,
      elapsedWeeks: elapsedWeeks,
      horizonWeeks: horizonWeeks,
      progressFraction: progress,
      expectedFraction: expected,
      remaining: target - current.smoothed,
    );
  }

  /// Least-squares slope over the smoothed values, in units per week.
  ///
  /// Guards the degenerate case where every point shares a day — which
  /// cannot happen through the repository (one entry per day) but can
  /// through a hand-built list in a test, and would otherwise divide by
  /// zero and paint a NaN.
  static double _slopePerWeek(List<TrendPoint> window) {
    final originDay = window.first.day;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (final point in window) {
      final x = point.day.difference(originDay).inDays.toDouble();
      final y = point.smoothed;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    final n = window.length.toDouble();
    final denominator = n * sumXX - sumX * sumX;
    if (denominator.abs() < 1e-9) return 0;
    return ((n * sumXY - sumX * sumY) / denominator) * 7.0;
  }
}

/// Roadmap Phase 9 (C3) · how reliably the user turns up.
///
/// Deliberately separate from the body measures. Adherence is about
/// behaviour, which the user controls; weight is about outcome, which
/// they only influence. Conflating them into one "score" is what makes
/// a fitness app feel like it is grading a person rather than reporting
/// their week.
class AdherenceSummary {
  const AdherenceSummary({
    required this.plannedSessions,
    required this.completedSessions,
    required this.weeklyConsistency,
    required this.rollingThirtyDay,
    required this.longestStreak,
    required this.currentStreak,
  });

  final int plannedSessions;
  final int completedSessions;

  /// Completed ÷ planned for the current week, 0–1. Null when the week
  /// planned nothing — a rest week is not 0 % adherence, and rendering
  /// it as such would invent a failure out of the program's own design.
  final double? weeklyConsistency;

  /// Completed ÷ planned over the trailing 30 days, 0–1, on the same
  /// terms.
  final double? rollingThirtyDay;

  final int longestStreak;
  final int currentStreak;
}
