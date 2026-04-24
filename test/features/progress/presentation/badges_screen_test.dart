import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/presentation/badges_screen.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';

class _StubWorkoutSessionNotifier extends WorkoutSessionNotifier {
  _StubWorkoutSessionNotifier(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

Future<Widget> _host(WorkoutSessionState seed) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workoutSessionProvider.overrideWith(
        () => _StubWorkoutSessionNotifier(seed),
      ),
    ],
    child: const MaterialApp(
      home: BadgesScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
      'renders a gallery of badges for a brand-new user without '
      'layout overflow', (tester) async {
    final widget = await _host(const WorkoutSessionState());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Rozetler'), findsOneWidget);
    // Only the first ~4 rows are laid out in the default viewport;
    // checking the summary card + the first visible tier is enough
    // to prove the gallery rendered without overflow.
    expect(find.text('İlk Adım'), findsOneWidget);
    expect(find.textContaining('kazanıldı'), findsOneWidget);
  });

  testWidgets(
      'flips the progress badges to unlocked when the program is '
      'completed', (tester) async {
    final days = List<WorkoutDay>.generate(
      30,
      (i) => WorkoutDay(
        dayNumber: i + 1,
        exercises: const [],
        isCompleted: true,
      ),
    );
    final widget = await _host(WorkoutSessionState(days: days));
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    // "Açıldı" pill is rendered per-unlocked badge. Multiple unlocks
    // should yield multiple pills.
    expect(find.text('Açıldı'), findsWidgets);
  });
}
