import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/workout/domain/program_progression.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';
import 'package:sixpack_ai/features/workout/presentation/program_continuation_screen.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 14 (C40, P5) · day 31, on a real widget tree.
///
/// **This screen cannot be reached on a device without thirty days of
/// real workouts**, and no fixture can put them there — the completion
/// ledger is written by the session notifier as sessions finish. So the
/// mutation half of the feature is pinned here rather than by a device
/// walk, and the phase report says so rather than implying a screenshot
/// covered it.
///
/// What these assert is the part a screenshot could not show anyway:
/// which preference each path writes, and that choosing one never
/// writes another's.
class _StubSession extends WorkoutSessionNotifier {
  _StubSession(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

const _exercise = Exercise(
  id: 'ex1',
  name: 'Şınav',
  type: ExerciseType.repBased,
  difficulty: 'beginner',
  targetMuscle: 'chest',
  isCardio: false,
  sets: 3,
  targetReps: 12,
  restDurationInSeconds: 30,
  category: ExerciseCategory.chest,
);

WorkoutSessionState _finished({
  required int completed,
  int total = 30,
  bool isStub = false,
}) {
  final days = [
    for (var i = 1; i <= total; i++)
      WorkoutDay(
        dayNumber: i,
        title: 'Gün $i',
        exercises: const [_exercise],
        isCompleted: i <= completed,
      ),
  ];
  return WorkoutSessionState(days: days, isStub: isStub);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  WorkoutSessionState seed, {
  String activityLevel = 'sedentary',
  String goal = 'sixpack',
  double carriedOverload = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({
    'sixpack.user_metrics': jsonEncode({
      'activityLevel': activityLevel,
      'targetPhysique': goal,
    }),
    'sixpack.program_cycle_overload': carriedOverload,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workoutSessionProvider.overrideWith(() => _StubSession(seed)),
    ],
  );
  addTearDown(container.dispose);
  // Materialise the session before the screen reads it — the screen
  // uses `ref.read(...).value`, which is null until the notifier has
  // built.
  await container.read(workoutSessionProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: ProgramContinuationScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('every path is offered and exactly one is marked',
      (tester) async {
    final container = await _pump(tester, _finished(completed: 27));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Repeat, advance, switch, maintain — four, because a beginner has
    // a tier above them.
    expect(find.text(l10n.continueRepeatTitle), findsOneWidget);
    expect(
      find.text(l10n.continueAdvanceTitle(l10n.tierIntermediate)),
      findsOneWidget,
    );
    expect(find.text(l10n.continueSwitchTitle), findsOneWidget);
    expect(find.text(l10n.continueMaintenanceTitle), findsOneWidget);
    expect(find.text(l10n.continueRecommended), findsOneWidget,
        reason: 'exactly one path carries the badge');
    container.dispose();
  });

  testWidgets('an advanced user is offered no tier that does not exist',
      (tester) async {
    await _pump(tester, _finished(completed: 29), activityLevel: 'active');
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining(l10n.tierAdvanced), findsNothing);
    // The dead end this phase exists to remove: they are offered a
    // change of focus instead, and it is the marked one.
    expect(find.text(l10n.continueSwitchTitle), findsOneWidget);
    expect(find.text(l10n.continueRecommended), findsOneWidget);
  });

  testWidgets('somebody who struggled is offered the SAME load, and told so',
      (tester) async {
    await _pump(tester, _finished(completed: 11));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.continueRepeatSameTitle), findsOneWidget);
    expect(find.text(l10n.continueRepeatTitle), findsNothing,
        reason: '"repeat with more volume" is the wrong sentence for 11/30');
    expect(find.text(l10n.fitTooHard), findsOneWidget);
  });

  testWidgets('a strong finisher is told the program suited them',
      (tester) async {
    await _pump(tester, _finished(completed: 28));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.fitWellMatched), findsOneWidget);
    expect(find.text(l10n.continueRepeatTitle), findsOneWidget);
  });

  testWidgets('a stub program renders nothing rather than a false reading',
      (tester) async {
    // 0 of 30 on a placeholder is not a failed program, and
    // recommending off it would tell somebody their sync problem was a
    // fitness problem.
    await _pump(tester, _finished(completed: 0, isStub: true));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.continueRepeatSameTitle), findsNothing);
    expect(find.text(l10n.continueMaintenanceTitle), findsNothing);
  });

  group('what choosing writes', () {
    testWidgets('repeat carries the overload forward and holds the tier',
        (tester) async {
      final container = await _pump(tester, _finished(completed: 20));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.continueRepeatTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final prefs = container.read(appPreferencesProvider);
      expect(prefs.programCycleOverload, closeTo(kModestOverload, 1e-9));
      expect(prefs.isMaintenanceMode, isFalse);
      expect(prefs.userMetrics!['activityLevel'], 'sedentary',
          reason: 'repeating must not silently change the tier');
    });

    testWidgets('advancing writes the tier and RESETS the carried volume',
        (tester) async {
      // Two increases at once is the thing `recommend()` refuses to do
      // in one step, and the screen must not undo that by stacking a
      // previously-carried overload on top of a harder tier.
      final container = await _pump(
        tester,
        _finished(completed: 28),
        carriedOverload: 1.16,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(
        l10n.continueAdvanceTitle(l10n.tierIntermediate),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final prefs = container.read(appPreferencesProvider);
      expect(prefs.userMetrics!['activityLevel'], 'intermediate');
      expect(prefs.programCycleOverload, 1.0);
    });

    testWidgets('maintenance sets the flag and adds no volume', (tester) async {
      final container = await _pump(
        tester,
        _finished(completed: 30),
        carriedOverload: 1.08,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.continueMaintenanceTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final prefs = container.read(appPreferencesProvider);
      expect(prefs.isMaintenanceMode, isTrue);
      expect(prefs.programCycleOverload, 1.0,
          reason: 'holding what you built is not the moment to add volume');
    });

    testWidgets('switching focus offers only the goals you are not on',
        (tester) async {
      await _pump(tester, _finished(completed: 25), goal: 'sixpack');
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.continueSwitchTitle));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text(l10n.goalBulkLabel), findsOneWidget);
      expect(find.text(l10n.goalToneLabel), findsOneWidget);
      expect(find.text(l10n.goalSixpackLabel), findsNothing,
          reason: 'switching to the focus you already have is not a choice');
    });
  });
}
