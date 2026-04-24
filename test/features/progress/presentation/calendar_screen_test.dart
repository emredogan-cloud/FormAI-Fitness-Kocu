import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/progress/presentation/calendar_screen.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';

/// Stub AsyncNotifier so the calendar screen doesn't hit the real
/// Supabase-backed workout repository during widget tests.
class _StubWorkoutSessionNotifier extends WorkoutSessionNotifier {
  _StubWorkoutSessionNotifier(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

Widget _host(WorkoutSessionState seed) {
  return ProviderScope(
    overrides: [
      workoutSessionProvider.overrideWith(
        () => _StubWorkoutSessionNotifier(seed),
      ),
    ],
    child: const MaterialApp(
      home: CalendarScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets('renders the current month without layout overflow', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WorkoutSessionState()));
    // Give the AsyncNotifier a microtask to emit its seeded state.
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Takvimim'), findsOneWidget);
    // Weekday header renders at the top of the scroll view.
    expect(find.text('Pt'), findsOneWidget);
    expect(find.text('Pa'), findsOneWidget);
  });

  testWidgets('still renders when the workout session has a 30-day plan', (
    tester,
  ) async {
    final days = List<WorkoutDay>.generate(
      30,
      (i) => WorkoutDay(
        dayNumber: i + 1,
        exercises: const [],
        isCompleted: i < 5,
      ),
    );
    await tester.pumpWidget(_host(WorkoutSessionState(days: days)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
