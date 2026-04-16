import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _completedKey = 'sixpack.completed_days';

  static const List<WorkoutDay> _staticProgram = [
    WorkoutDay(
      dayNumber: 1,
      exercises: [
        Exercise(
          id: 'crunch',
          name: 'Mekik',
          type: ExerciseType.repBased,
          targetReps: 10,
        ),
      ],
    ),
    WorkoutDay(
      dayNumber: 2,
      exercises: [
        Exercise(
          id: 'crunch',
          name: 'Mekik',
          type: ExerciseType.repBased,
          targetReps: 12,
        ),
        Exercise(
          id: 'plank',
          name: 'Plank',
          type: ExerciseType.timeBased,
          targetDurationInSeconds: 20,
        ),
      ],
    ),
    WorkoutDay(
      dayNumber: 3,
      exercises: [
        Exercise(
          id: 'crunch',
          name: 'Mekik',
          type: ExerciseType.repBased,
          targetReps: 15,
        ),
        Exercise(
          id: 'leg_raise',
          name: 'Bacak Kaldırma',
          type: ExerciseType.repBased,
          targetReps: 10,
        ),
      ],
    ),
  ];

  Future<List<WorkoutDay>> loadProgram() async {
    final completed = _completedSet();
    return _staticProgram
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
  }

  Future<void> markDayCompleted(int dayNumber) async {
    final completed = _completedSet()..add(dayNumber);
    await _prefs.setStringList(
      _completedKey,
      completed.map((e) => e.toString()).toList(),
    );
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_completedKey);
  }

  Set<int> _completedSet() {
    final raw = _prefs.getStringList(_completedKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }
}
