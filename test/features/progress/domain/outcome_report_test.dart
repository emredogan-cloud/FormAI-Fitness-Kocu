import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/domain/outcome_report.dart';
import 'package:sixpack_ai/features/progress/domain/trend_calculator.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';

/// Roadmap Phase 10 (C4, C39) · the outcome report's arithmetic.
///
/// The assertions here are mostly about what the report REFUSES to
/// claim. It is the artifact that makes the store listing's "measurable
/// results" true, which means every number in it has to be a count or a
/// difference over data that exists — never a default, never a
/// projection, never a figure that reads as a body-change verdict when
/// the app has never seen the body.
void main() {
  final asOf = DateTime(2026, 8, 2);
  DateTime daysAgo(int n) => asOf.subtract(Duration(days: n));

  const adherence = AdherenceSummary(
    weekCompleted: 3,
    weekPlanned: 4,
    rollingThirtyDay: 0.75,
    longestStreak: 6,
    currentStreak: 2,
  );

  ExerciseLog exercise({int sets = 3, int reps = 30}) => ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Push-up',
        targetMuscle: 'chest',
        isCardio: false,
        plannedSets: sets,
        plannedReps: reps ~/ sets,
        actualSets: sets,
        actualReps: reps,
        durationSeconds: 120,
      );

  SessionLog session(
    int day,
    int daysBack, {
    int reps = 30,
    int seconds = 600,
    SessionSource source = SessionSource.camera,
  }) =>
      SessionLog(
        dayNumber: day,
        completedAtIso: daysAgo(daysBack).toIso8601String(),
        durationSeconds: seconds,
        exerciseLogs: [exercise(reps: reps)],
        source: source,
      );

  BodyMetric weight(int daysBack, double kg) =>
      BodyMetric(recordedOn: BodyMetric.dayOf(daysAgo(daysBack)), weightKg: kg);

  OutcomeReport build({
    Map<int, SessionLog> logs = const {},
    List<BodyMetric> metrics = const [],
    List<String> badges = const [],
    AdherenceSummary summary = adherence,
    Duration window = const Duration(days: 30),
  }) =>
      OutcomeReportBuilder.build(
        sessionLogs: logs,
        bodyMetrics: metrics,
        unlockedBadgeIds: badges,
        adherence: summary,
        lifetimeXp: 1200,
        level: 4,
        programLength: 30,
        kcalPerCompletedDay: 250,
        asOf: asOf,
        window: window,
      );

  group('a report with nothing in it', () {
    test('is generated rather than thrown, and says so', () {
      final report = build();

      expect(report.sessionCount, 0);
      expect(report.isSubstantive, isFalse);
      expect(report.hasBodyData, isFalse);
      expect(report.milestones, isEmpty);
      expect(report.firstSessionAt, isNull);
      expect(report.lastSessionAt, isNull);
    });

    test(
        'reports no body change rather than a change of zero — a user who '
        'never weighed themselves did not stay the same weight', () {
      final report = build(logs: {1: session(1, 5)});

      expect(report.weight, isNull);
      expect(report.measurements, isEmpty);
      expect(report.hasBodyData, isFalse);
    });

    test('one session is a receipt, not a report', () {
      expect(build(logs: {1: session(1, 3)}).isSubstantive, isFalse);
      expect(
        build(logs: {1: session(1, 3), 2: session(2, 2)}).isSubstantive,
        isTrue,
      );
    });
  });

  group('the totals', () {
    test('add up across sessions inside the window', () {
      final report = build(logs: {
        1: session(1, 20, reps: 40, seconds: 600),
        2: session(2, 10, reps: 55, seconds: 900),
        3: session(3, 1, reps: 60, seconds: 720),
      });

      expect(report.sessionCount, 3);
      expect(report.totalReps, 155);
      expect(report.totalSets, 9);
      expect(report.totalActiveTime, const Duration(seconds: 2220));
      expect(report.estimatedKcal, 750);
    });

    test('exclude sessions older than the window', () {
      final report = build(logs: {
        1: session(1, 90, reps: 999),
        2: session(2, 5, reps: 40),
      });

      expect(report.sessionCount, 1);
      expect(report.totalReps, 40, reason: 'the 90-day-old session is outside');
      // …but the journey itself still starts where it started.
      expect(report.firstSessionAt!.day, daysAgo(90).day);
    });

    test('a log with an unparseable timestamp is dropped, not defaulted', () {
      final report = build(logs: {
        1: const SessionLog(
          dayNumber: 1,
          completedAtIso: '',
          durationSeconds: 600,
          exerciseLogs: [],
        ),
        2: session(2, 5, reps: 40),
      });

      expect(report.sessionCount, 1);
      expect(report.totalReps, 40);
    });

    test('camera-free sessions are counted, and counted as sessions', () {
      final report = build(logs: {
        1: session(1, 5),
        2: session(2, 3, source: SessionSource.manual),
        3: session(3, 1, source: SessionSource.manual),
      });

      expect(report.sessionCount, 3);
      expect(report.cameraFreeSessions, 2);
    });
  });

  group('body deltas', () {
    test('need two readings — one is not a change', () {
      expect(build(metrics: [weight(3, 82.0)]).weight, isNull);
      expect(build(metrics: [weight(20, 84.0), weight(3, 82.0)]).weight,
          isNotNull);
    });

    test('are signed, and carry no verdict', () {
      final down = build(metrics: [weight(20, 84.0), weight(3, 82.0)]).weight!;
      final up = build(metrics: [weight(20, 82.0), weight(3, 84.0)]).weight!;

      expect(down.change, closeTo(-2.0, 0.001));
      expect(up.change, closeTo(2.0, 0.001));
      // Nothing on the type says which of these is good news.
      expect(down.spanDays, 17);
    });

    test(
        'use the first and last reading, not a smoothed line — the report '
        'has to agree with the entry list above it', () {
      final report = build(metrics: [
        weight(20, 84.0),
        weight(12, 79.0), // a low outlier a smoother would pull up
        weight(3, 82.0),
      ]);

      expect(report.weight!.first, 84.0);
      expect(report.weight!.last, 82.0);
    });

    test('a movement inside the instrument noise is flagged as such', () {
      final noise = build(metrics: [weight(20, 82.0), weight(3, 82.1)]).weight!;
      final real = build(metrics: [weight(20, 82.0), weight(3, 82.6)]).weight!;

      expect(noise.isNoise, isTrue);
      expect(real.isNoise, isFalse);
    });

    test('readings older than the window do not become the starting point', () {
      final report = build(metrics: [
        weight(200, 95.0),
        weight(20, 84.0),
        weight(3, 82.0),
      ]);

      expect(report.weight!.first, 84.0,
          reason: 'a 200-day-old weight is not this month');
    });

    test('tape measurements are reported only where two exist', () {
      final report = build(metrics: [
        BodyMetric(
          recordedOn: BodyMetric.dayOf(daysAgo(20)),
          waistCm: 92,
          chestCm: 104,
        ),
        BodyMetric(recordedOn: BodyMetric.dayOf(daysAgo(3)), waistCm: 89),
      ]);

      expect(report.measurements.map((m) => m.measure), [BodyMeasure.waist]);
      expect(report.measurements.single.change, closeTo(-3, 0.001));
      expect(report.hasBodyData, isTrue);
    });
  });

  group('the milestone timeline', () {
    test('is chronological, oldest first', () {
      final report = build(
        logs: {1: session(1, 20), 2: session(2, 10), 3: session(3, 2)},
        metrics: [weight(15, 84.0), weight(3, 82.0)],
        badges: const ['first_step'],
      );

      for (var i = 1; i < report.milestones.length; i++) {
        expect(
          report.milestones[i].at.isBefore(report.milestones[i - 1].at),
          isFalse,
          reason: 'milestone $i is out of order',
        );
      }
    });

    test('opens with the first workout, at the time it happened', () {
      final report = build(logs: {1: session(1, 20), 2: session(2, 2)});

      final first = report.milestones.first;
      expect(first.kind, MilestoneKind.firstWorkout);
      expect(first.at.day, daysAgo(20).day);
    });

    test('names the best session by reps, resolving ties to the earliest', () {
      final report = build(logs: {
        1: session(1, 20, reps: 60),
        2: session(2, 10, reps: 60),
        3: session(3, 2, reps: 30),
      });

      final best = report.milestones
          .firstWhere((m) => m.kind == MilestoneKind.personalBestReps);
      expect(best.value, 60);
      expect(best.at.day, daysAgo(20).day,
          reason: 'the first time a number was hit is the moment worth naming');
    });

    test('a streak of one is not a streak', () {
      const lonely = AdherenceSummary(
        weekCompleted: 1,
        weekPlanned: 4,
        rollingThirtyDay: null,
        longestStreak: 1,
        currentStreak: 1,
      );
      final report =
          build(logs: {1: session(1, 5), 2: session(2, 1)}, summary: lonely);

      expect(
        report.milestones.where((m) => m.kind == MilestoneKind.streak),
        isEmpty,
      );
    });

    test('program completion is claimed only when every day is done', () {
      bool completed(int days) => build(logs: {
            for (var d = 1; d <= days; d++) d: session(d, 30 - d),
          }).milestones.any((m) => m.kind == MilestoneKind.programComplete);

      expect(completed(29), isFalse);
      expect(completed(30), isTrue);
    });

    test('badges are carried as ids, never as labels', () {
      final report = build(
        logs: {1: session(1, 5), 2: session(2, 1)},
        badges: const ['first_step', 'disciplined'],
      );

      final badges = report.milestones
          .where((m) => m.kind == MilestoneKind.badge)
          .map((m) => m.token)
          .toList();
      expect(badges, ['first_step', 'disciplined']);
    });
  });

  group('completion', () {
    test('counts program days, not sessions inside the window', () {
      final report = build(logs: {
        1: session(1, 200), // outside the 30-day window, still a day done
        2: session(2, 5),
      });

      expect(report.sessionCount, 1);
      expect(report.daysCompleted, 2);
      expect(report.completionFraction, closeTo(2 / 30, 0.001));
    });

    test('never exceeds 1 even if the ledger somehow overruns', () {
      final report = build(logs: {
        for (var d = 1; d <= 40; d++) d: session(d, 1),
      });

      expect(report.completionFraction, 1.0);
    });
  });
}
