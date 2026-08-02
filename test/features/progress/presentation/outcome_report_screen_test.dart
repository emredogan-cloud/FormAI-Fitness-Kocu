import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/domain/outcome_report.dart';
import 'package:sixpack_ai/features/progress/domain/trend_calculator.dart';
import 'package:sixpack_ai/features/progress/presentation/outcome_report_screen.dart';
import 'package:sixpack_ai/features/progress/providers/outcome_report_provider.dart';
import 'package:sixpack_ai/features/workout/models/session_log_model.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 10 (C4, C39) · the outcome report screen.
///
/// The roadmap asks for "report rendering with missing sections", and
/// that is most of this file — because the sections that go missing are
/// exactly where a report starts lying. A month with no weight readings
/// must not render a body change; a month with one session must not
/// render a report at all.
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

  SessionLog session(int day, int daysBack, {int reps = 30}) => SessionLog(
        dayNumber: day,
        completedAtIso: daysAgo(daysBack).toIso8601String(),
        durationSeconds: 600,
        exerciseLogs: [
          ExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Push-up',
            targetMuscle: 'chest',
            isCardio: false,
            plannedSets: 3,
            plannedReps: reps ~/ 3,
            actualSets: 3,
            actualReps: reps,
            durationSeconds: 200,
          ),
        ],
      );

  OutcomeReport report({
    Map<int, SessionLog> logs = const {},
    List<BodyMetric> metrics = const [],
    List<String> badges = const [],
  }) =>
      OutcomeReportBuilder.build(
        sessionLogs: logs,
        bodyMetrics: metrics,
        unlockedBadgeIds: badges,
        adherence: adherence,
        lifetimeXp: 1200,
        level: 4,
        programLength: 30,
        kcalPerCompletedDay: 250,
        asOf: asOf,
      );

  Future<void> pump(
    WidgetTester tester,
    OutcomeReport? value, {
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          outcomeReportProvider.overrideWith((ref) => value),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: locale,
          home: const OutcomeReportScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    // Bounded pumps, never `pumpAndSettle`: the loading branch is a
    // `CircularProgressIndicator`, which never settles.
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  testWidgets('a still-loading report is a spinner, never a half-built one',
      (tester) async {
    await pump(tester, null);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('antrenman'), findsNothing);
  });

  testWidgets('one session offers the not-yet state rather than a report',
      (tester) async {
    await pump(tester, report(logs: {1: session(1, 3)}));

    expect(find.text('Henüz yeterli kayıt yok'), findsOneWidget);
    expect(find.text('Neler yaptın'), findsNothing);
  });

  testWidgets('the effort section states the totals it actually has',
      (tester) async {
    await pump(
        tester,
        report(logs: {
          1: session(1, 20, reps: 40),
          2: session(2, 10, reps: 50),
        }));

    expect(find.text('Neler yaptın'), findsOneWidget);
    expect(find.text('2 antrenman'), findsOneWidget);
    expect(find.text('90 tekrar'), findsOneWidget);
    expect(find.text('20 dakika'), findsOneWidget);
  });

  testWidgets(
      'the energy figure is marked as an estimate — an unhedged calorie '
      'count is a claim the app cannot support', (tester) async {
    await pump(tester, report(logs: {1: session(1, 20), 2: session(2, 10)}));

    expect(find.text('~500 kcal'), findsOneWidget);
    expect(find.textContaining('tahmin'), findsOneWidget);
  });

  group('the body section', () {
    testWidgets(
        'says there is nothing to compare rather than reporting no change',
        (tester) async {
      await pump(tester, report(logs: {1: session(1, 20), 2: session(2, 10)}));

      expect(
          find.textContaining('karşılaştıracak bir şey yok'), findsOneWidget);
      // The absence must not read as a lapse.
      expect(find.textContaining('yine de oldu'), findsOneWidget);
    });

    testWidgets('states both ends of a change, never a signed difference',
        (tester) async {
      await pump(
        tester,
        report(
          logs: {1: session(1, 20), 2: session(2, 10)},
          metrics: [
            BodyMetric(
                recordedOn: BodyMetric.dayOf(daysAgo(20)), weightKg: 84.0),
            BodyMetric(
                recordedOn: BodyMetric.dayOf(daysAgo(3)), weightKg: 82.0),
          ],
        ),
      );

      expect(find.textContaining('84 kg'), findsOneWidget);
      expect(find.textContaining('82 kg'), findsOneWidget);
      // No arithmetic on screen, and nothing that reads as a score.
      expect(find.textContaining('-2'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a change inside the scale\'s own error reads as unchanged',
        (tester) async {
      await pump(
        tester,
        report(
          logs: {1: session(1, 20), 2: session(2, 10)},
          metrics: [
            BodyMetric(
                recordedOn: BodyMetric.dayOf(daysAgo(20)), weightKg: 82.0),
            BodyMetric(
                recordedOn: BodyMetric.dayOf(daysAgo(3)), weightKg: 82.1),
          ],
        ),
      );

      expect(find.textContaining('değişmedi'), findsOneWidget);
      expect(find.textContaining('82,1'), findsNothing);
    });
  });

  group('the timeline', () {
    testWidgets('opens with the first session', (tester) async {
      await pump(
          tester,
          report(logs: {
            1: session(1, 20),
            2: session(2, 10),
          }));

      expect(find.text('Hikâye'), findsOneWidget);
      expect(find.text('İlk antrenmanın'), findsOneWidget);
    });

    testWidgets('names a badge, never renders its id at a person',
        (tester) async {
      await pump(
        tester,
        report(
          logs: {1: session(1, 20), 2: session(2, 10)},
          badges: const ['first_step'],
        ),
      );

      expect(find.textContaining('first_step'), findsNothing);
      expect(find.textContaining('kazanıldı'), findsOneWidget);
    });

    testWidgets('drops a row whose badge has outlived its copy',
        (tester) async {
      await pump(
        tester,
        report(
          logs: {1: session(1, 20), 2: session(2, 10)},
          badges: const ['a_badge_that_no_longer_exists'],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
          find.textContaining('a_badge_that_no_longer_exists'), findsNothing);
    });
  });

  testWidgets(
      'the camera-free footnote appears only when it is about '
      'something', (tester) async {
    await pump(tester, report(logs: {1: session(1, 20), 2: session(2, 10)}));
    expect(find.textContaining('kendin saydın'), findsNothing);

    // Unmounted between the two: re-pumping a ProviderScope whose only
    // change is the value inside an override reuses the element tree.
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(
      tester,
      report(logs: {
        1: session(1, 20),
        2: SessionLog(
          dayNumber: 2,
          completedAtIso: daysAgo(10).toIso8601String(),
          durationSeconds: 600,
          exerciseLogs: const [],
          source: SessionSource.manual,
        ),
      }),
    );
    expect(find.textContaining('kendin saydın'), findsOneWidget);
  });

  testWidgets('resolves in English with no Turkish left in it', (tester) async {
    await pump(
      tester,
      report(logs: {1: session(1, 20), 2: session(2, 10)}),
      locale: const Locale('en'),
    );

    expect(find.text('Your 30 days'), findsOneWidget);
    expect(find.text('What you did'), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.textContaining('antrenman'), findsNothing);
  });

  testWidgets('survives a 1.3 text scale on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          outcomeReportProvider.overrideWith(
            (ref) => report(logs: {
              1: session(1, 20, reps: 1240),
              2: session(2, 10, reps: 980),
            }),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('tr')],
            home: const OutcomeReportScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }

    expect(tester.takeException(), isNull);
  });
}
