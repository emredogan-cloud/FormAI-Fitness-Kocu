import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/domain/trend_calculator.dart';

void main() {
  // A fixed "today" so every week-scale assertion below is reproducible.
  final today = DateTime(2026, 8, 2);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  BodyMetric weightOn(int daysBack, double kg) =>
      BodyMetric(recordedOn: daysAgo(daysBack), weightKg: kg);

  BodyMetric waistOn(int daysBack, double cm) =>
      BodyMetric(recordedOn: daysAgo(daysBack), waistCm: cm);

  group('TrendSeries.from · shape', () {
    test('no entries produce an empty series, not a crash', () {
      final series = TrendSeries.from(const [], BodyMeasure.weight);
      expect(series.isEmpty, isTrue);
      expect(series.latest, isNull);
      expect(series.first, isNull);
    });

    test('entries that do not carry the measure are skipped entirely', () {
      final series = TrendSeries.from(
        [waistOn(3, 88), waistOn(1, 87)],
        BodyMeasure.weight,
      );
      expect(series.isEmpty, isTrue,
          reason: 'a waist-only log says nothing about weight');
    });

    test('a single point smooths to itself', () {
      final series = TrendSeries.from([weightOn(0, 80)], BodyMeasure.weight);
      expect(series.points, hasLength(1));
      expect(series.points.single.value, 80);
      expect(series.points.single.smoothed, 80);
    });

    test('points come out ascending however they went in', () {
      final series = TrendSeries.from(
        [weightOn(1, 79), weightOn(9, 82), weightOn(5, 81)],
        BodyMeasure.weight,
      );
      expect(
        series.points.map((p) => p.value).toList(),
        [82, 81, 79],
      );
    });
  });

  group('TrendSeries.from · the smoother', () {
    test('a trailing window averages only what came before it', () {
      // Three consecutive days: 80, 82, 84. The middle point may only
      // see itself and the first; the last sees all three.
      final series = TrendSeries.from(
        [weightOn(2, 80), weightOn(1, 82), weightOn(0, 84)],
        BodyMeasure.weight,
      );
      expect(series.points[0].smoothed, 80);
      expect(series.points[1].smoothed, 81);
      expect(series.points[2].smoothed, 82);
    });

    test(
        'a gap wider than the window means the later point is not dragged '
        'back toward data it says nothing about', () {
      // 90 kg three months ago, then 80 kg today. An N-point moving
      // average would report the latest smoothed value as 85.
      final series = TrendSeries.from(
        [weightOn(90, 90), weightOn(0, 80)],
        BodyMeasure.weight,
      );
      expect(series.points.last.smoothed, 80);
    });

    test('the last point never changes once drawn (the window is trailing)',
        () {
      final upToTuesday = TrendSeries.from(
        [weightOn(2, 80), weightOn(1, 82)],
        BodyMeasure.weight,
      );
      final withWednesday = TrendSeries.from(
        [weightOn(2, 80), weightOn(1, 82), weightOn(0, 90)],
        BodyMeasure.weight,
      );
      expect(
        withWednesday.points[1].smoothed,
        upToTuesday.points[1].smoothed,
        reason: 'a centred window would rewrite history behind the user',
      );
    });

    test('daily weekend noise is absorbed by a seven-day window', () {
      // A flat 80 kg with a +2 kg Saturday. The smoothed line should
      // stay far closer to 80 than the raw point does.
      final entries = [
        for (var i = 6; i >= 0; i--) weightOn(i, i == 1 ? 82.0 : 80.0),
      ];
      final series = TrendSeries.from(entries, BodyMeasure.weight);
      final spike = series.points[5];
      expect(spike.value, 82);
      expect(spike.smoothed, closeTo(80.33, 0.01));
    });
  });

  group('summarize · not enough data', () {
    test('an empty series summarizes to null', () {
      final series = TrendSeries.from(const [], BodyMeasure.weight);
      expect(series.summarize(asOf: today, days: 30), isNull);
    });

    test(
        'one point summarizes to null rather than to zero change — '
        '"you have not moved" is a claim, and one point cannot make it', () {
      final series = TrendSeries.from([weightOn(0, 80)], BodyMeasure.weight);
      expect(series.summarize(asOf: today, days: 30), isNull);
    });

    test('points outside the window do not count toward the minimum', () {
      final series = TrendSeries.from(
        [weightOn(100, 90), weightOn(0, 80)],
        BodyMeasure.weight,
      );
      expect(series.summarize(asOf: today, days: 30), isNull);
    });
  });

  group('summarize · direction and rate', () {
    test('a steady loss reports a negative weekly rate and falls', () {
      // 1 kg down per week for four weeks, logged weekly.
      final series = TrendSeries.from(
        [
          weightOn(28, 84),
          weightOn(21, 83),
          weightOn(14, 82),
          weightOn(7, 81),
          weightOn(0, 80),
        ],
        BodyMeasure.weight,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.direction, TrendDirection.falling);
      expect(summary.changePerWeek, closeTo(-1.0, 0.01));
      expect(summary.totalChange, closeTo(-4.0, 0.01));
      expect(summary.spanDays, 28);
      expect(summary.pointCount, 5);
    });

    test('a steady gain rises', () {
      final series = TrendSeries.from(
        [
          weightOn(21, 70),
          weightOn(14, 70.5),
          weightOn(7, 71),
          weightOn(0, 71.5),
        ],
        BodyMeasure.weight,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.direction, TrendDirection.rising);
      expect(summary.changePerWeek, closeTo(0.5, 0.01));
    });

    test(
        'the slope is a regression, so one bad morning at the end does not '
        'define the verdict', () {
      // Four weeks of clean loss, then a single +3 kg reading today.
      final series = TrendSeries.from(
        [
          weightOn(28, 84),
          weightOn(21, 83),
          weightOn(14, 82),
          weightOn(7, 81),
          weightOn(0, 83),
        ],
        BodyMeasure.weight,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.direction, TrendDirection.falling,
          reason: 'last-minus-first would have called this flat or rising');
    });

    test('a reversal inside the window is reported as its net slope', () {
      // Down 2 kg then back up 2 kg: no net movement.
      final series = TrendSeries.from(
        [
          weightOn(28, 80),
          weightOn(21, 79),
          weightOn(14, 78),
          weightOn(7, 79),
          weightOn(0, 80),
        ],
        BodyMeasure.weight,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.changePerWeek, closeTo(0, 0.05));
      expect(summary.direction, TrendDirection.flat);
    });
  });

  group('summarize · plateau', () {
    test('three weeks of stillness with four logs is a plateau', () {
      final series = TrendSeries.from(
        [
          weightOn(21, 80.0),
          weightOn(14, 80.1),
          weightOn(7, 79.9),
          weightOn(0, 80.0),
        ],
        BodyMeasure.weight,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.isPlateau, isTrue);
      expect(summary.direction, TrendDirection.flat);
    });

    test('two weeks of stillness is not — that is inside one bad week', () {
      final series = TrendSeries.from(
        [
          weightOn(14, 80.0),
          weightOn(9, 80.1),
          weightOn(4, 79.9),
          weightOn(0, 80.0),
        ],
        BodyMeasure.weight,
      );
      expect(series.summarize(asOf: today, days: 30)!.isPlateau, isFalse);
    });

    test('two points three weeks apart is not a plateau', () {
      final series = TrendSeries.from(
        [weightOn(21, 80), weightOn(0, 80)],
        BodyMeasure.weight,
      );
      expect(series.summarize(asOf: today, days: 30)!.isPlateau, isFalse);
    });

    test('real movement over three weeks is not a plateau', () {
      final series = TrendSeries.from(
        [
          weightOn(21, 83),
          weightOn(14, 82),
          weightOn(7, 81),
          weightOn(0, 80),
        ],
        BodyMeasure.weight,
      );
      expect(series.summarize(asOf: today, days: 30)!.isPlateau, isFalse);
    });

    test('a waist uses the circumference threshold, not the weight one', () {
      // 0.2 cm/week: still for a tape measure, moving for a scale.
      final series = TrendSeries.from(
        [
          waistOn(21, 88.0),
          waistOn(14, 88.2),
          waistOn(7, 88.4),
          waistOn(0, 88.6),
        ],
        BodyMeasure.waist,
      );
      final summary = series.summarize(asOf: today, days: 30)!;
      expect(summary.changePerWeek, closeTo(0.2, 0.01));
      expect(summary.direction, TrendDirection.flat);
      expect(summary.isPlateau, isTrue);
    });
  });

  group('reconcile · refusals', () {
    final losing = TrendSeries.from(
      [weightOn(28, 84), weightOn(14, 82), weightOn(0, 80)],
      BodyMeasure.weight,
    );

    test('no target means no reconciliation, and that is a valid state', () {
      expect(losing.reconcile(asOf: today, target: null), isNull);
    });

    test('no data means no reconciliation', () {
      final empty = TrendSeries.from(const [], BodyMeasure.weight);
      expect(empty.reconcile(asOf: today, target: 75), isNull);
    });

    test(
        'a target equal to the starting weight is refused rather than '
        'divided by — it would render as NaN on a card about a body', () {
      expect(losing.reconcile(asOf: today, target: 84), isNull);
    });
  });

  group('reconcile · pace', () {
    test('ahead of the twelve-week arc', () {
      // Four weeks in (1/3 of the arc), 4 of 9 kg covered (44%).
      final series = TrendSeries.from(
        [weightOn(28, 84), weightOn(14, 82), weightOn(0, 80)],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.pace, GoalPace.ahead);
      expect(r.elapsedWeeks, closeTo(4, 0.01));
      expect(r.progressFraction, closeTo(4 / 9, 0.01));
      expect(r.expectedFraction, closeTo(1 / 3, 0.01));
      expect(r.remaining, closeTo(-5, 0.01));
    });

    test('behind it', () {
      // Eight weeks in (2/3), 0.5 of 9 kg covered (5.5%).
      final series = TrendSeries.from(
        [weightOn(56, 84), weightOn(28, 83.7), weightOn(0, 83.5)],
        BodyMeasure.weight,
      );
      expect(series.reconcile(asOf: today, target: 75)!.pace, GoalPace.behind);
    });

    test('moving away from it', () {
      final series = TrendSeries.from(
        [weightOn(28, 84), weightOn(0, 86)],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.pace, GoalPace.movingAway);
      expect(r.progressFraction, lessThan(0));
    });

    test('reached, including overshoot', () {
      final series = TrendSeries.from(
        [weightOn(56, 84), weightOn(0, 74)],
        BodyMeasure.weight,
      );
      expect(series.reconcile(asOf: today, target: 75)!.pace, GoalPace.reached);
    });

    test('nobody is behind on day one', () {
      final series = TrendSeries.from(
        [BodyMetric(recordedOn: today, weightKg: 84)],
        BodyMeasure.weight,
      );
      // Two entries on the same day is impossible through the
      // repository, so build the one-point case and assert it holds.
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.pace, GoalPace.onTrack);
      expect(r.elapsedWeeks, 0);
    });

    test('a quarter under the line is still on track, not a failure', () {
      // Six weeks in (50% expected), 40% covered → 0.8 of expected.
      final series = TrendSeries.from(
        [weightOn(42, 85), weightOn(21, 83), weightOn(0, 81)],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.progressFraction, closeTo(0.4, 0.01));
      expect(r.expectedFraction, closeTo(0.5, 0.01));
      expect(r.pace, GoalPace.onTrack);
    });

    test('a gain goal reads the same way with the signs reversed', () {
      // Bulking: 70 → 76. Four weeks in, 2 of 6 kg covered (33%).
      final series = TrendSeries.from(
        [weightOn(28, 70), weightOn(14, 71), weightOn(0, 72)],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 76)!;
      expect(r.progressFraction, closeTo(1 / 3, 0.01));
      expect(r.pace, GoalPace.onTrack);
      expect(r.remaining, closeTo(4, 0.01));
    });

    test('losing weight against a gain goal is moving away', () {
      final series = TrendSeries.from(
        [weightOn(28, 70), weightOn(0, 68)],
        BodyMeasure.weight,
      );
      expect(
        series.reconcile(asOf: today, target: 76)!.pace,
        GoalPace.movingAway,
      );
    });

    test('the clock keeps running past week twelve', () {
      final series = TrendSeries.from(
        [weightOn(120, 84), weightOn(0, 80)],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.elapsedWeeks, greaterThan(12));
      expect(r.expectedFraction, 1.0,
          reason: 'the arc caps, the elapsed time does not');
    });

    test('reconciliation reads the smoothed value, not the raw one', () {
      // Clean loss, then one heavy day. The raw last value is above the
      // start; the smoothed one is not.
      final series = TrendSeries.from(
        [
          weightOn(28, 84),
          weightOn(21, 82),
          weightOn(14, 80),
          weightOn(7, 79),
          weightOn(0, 85),
        ],
        BodyMeasure.weight,
      );
      final r = series.reconcile(asOf: today, target: 75)!;
      expect(r.currentValue, 85,
          reason: 'a lone point outside the window smooths to itself');
      expect(r.pace, GoalPace.movingAway);
    });
  });

  group('since', () {
    final series = TrendSeries.from(
      [weightOn(40, 85), weightOn(20, 83), weightOn(5, 81)],
      BodyMeasure.weight,
    );

    test('includes the boundary day itself', () {
      expect(series.since(daysAgo(20)), hasLength(2));
    });

    test('a cutoff after every point yields nothing', () {
      expect(series.since(daysAgo(1)), isEmpty);
    });

    test('a cutoff carrying a time component still matches its own day', () {
      expect(
        series.since(daysAgo(20).add(const Duration(hours: 23))),
        hasLength(2),
      );
    });
  });
}
