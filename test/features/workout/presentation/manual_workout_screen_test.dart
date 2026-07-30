import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';
import 'package:sixpack_ai/features/workout/presentation/manual_workout_screen.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';

/// Roadmap Phase 3 (C21) · the camera-free workout surface.
///
/// The contract being pinned: this screen is a different UI over the
/// SAME session state machine. It must drive `workoutSessionProvider`
/// rather than keep its own rep count, because that equivalence is what
/// makes a camera-free user's progress, XP, streak and badges identical
/// to a camera user's.
class _StubSession extends WorkoutSessionNotifier {
  _StubSession(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

Exercise _exercise({
  String name = 'Şınav',
  int sets = 3,
  int targetReps = 12,
}) {
  return Exercise(
    id: 'ex1',
    name: name,
    type: ExerciseType.repBased,
    difficulty: 'beginner',
    targetMuscle: 'chest',
    isCardio: false,
    sets: sets,
    targetReps: targetReps,
    restDurationInSeconds: 45,
  );
}

WorkoutSessionState _state({
  int currentReps = 0,
  int currentSet = 1,
  bool isResting = false,
  int restSecondsRemaining = 0,
  bool noExercises = false,
}) {
  final day = WorkoutDay(
    dayNumber: 1,
    title: 'Gün 1',
    exercises: noExercises ? const [] : [_exercise()],
  );
  return WorkoutSessionState(
    days: [day],
    activeDay: day,
    activeExerciseIndex: 0,
    currentReps: currentReps,
    currentSet: currentSet,
    isResting: isResting,
    restSecondsRemaining: restSecondsRemaining,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  WorkoutSessionState seed, {
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workoutSessionProvider.overrideWith(() => _StubSession(seed)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const MaterialApp(
          home: ManualWorkoutScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('renders the exercise, set label and target', (tester) async {
    await _pump(tester, _state());

    expect(tester.takeException(), isNull);
    expect(find.text('Şınav'), findsOneWidget);
    expect(find.text('SET 1 / 3'), findsOneWidget);
    expect(find.text('Hedef: 12 tekrar'), findsOneWidget);
  });

  testWidgets(
      'states plainly that form analysis is off — an app that '
      'silently drops its headline feature erodes trust', (tester) async {
    await _pump(tester, _state());
    expect(find.textContaining('Kamerasız mod'), findsOneWidget);
    expect(find.textContaining('İlerlemen normal şekilde'), findsOneWidget);
  });

  testWidgets('the rep counter reflects provider state, not local state',
      (tester) async {
    await _pump(tester, _state(currentReps: 7));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('+ and − drive the shared session provider', (tester) async {
    final container = await _pump(tester, _state(currentReps: 5));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(container.read(workoutSessionProvider).value!.currentReps, 6);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(container.read(workoutSessionProvider).value!.currentReps, 4);
  });

  testWidgets('reps never go negative', (tester) async {
    final container = await _pump(tester, _state(currentReps: 0));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(container.read(workoutSessionProvider).value!.currentReps, 0);
  });

  testWidgets('the rest state replaces the active view', (tester) async {
    await _pump(
      tester,
      _state(isResting: true, restSecondsRemaining: 30),
    );
    expect(find.text('DİNLEN'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('SETİ TAMAMLA'), findsNothing);
  });

  testWidgets(
      'a finished day shows a completion empty state, not a blank '
      'screen', (tester) async {
    await _pump(tester, _state(noExercises: true));
    expect(find.text('Bugünlük bu kadar'), findsOneWidget);
  });

  testWidgets('a route back to camera mode is always offered', (tester) async {
    await _pump(tester, _state());
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('rep controls are reachable by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _state(currentReps: 3));
    expect(find.bySemanticsLabel('Bir tekrar ekle'), findsOneWidget);
    expect(find.bySemanticsLabel('Bir tekrar çıkar'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tamamlanan tekrar: 3')),
      findsAtLeastNWidgets(1),
    );
    handle.dispose();
  });

  testWidgets(
      'rep buttons exceed the 48dp minimum — they are tapped '
      'mid-exercise, not at rest', (tester) async {
    await _pump(tester, _state());
    final size = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('survives a 1.3 text scale on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, _state(currentReps: 12), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
