import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _completedKey = 'sixpack.completed_days';

  static const Exercise _crunch10 = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 10,
    videoAsset: 'assets/videos/crunch_demo.mp4',
  );
  static const Exercise _crunch12 = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 12,
    videoAsset: 'assets/videos/crunch_demo.mp4',
  );
  static const Exercise _crunch15 = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 15,
    videoAsset: 'assets/videos/crunch_demo.mp4',
  );
  static const Exercise _plank20 = Exercise(
    id: 'plank',
    name: 'Plank',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 20,
    videoAsset: 'assets/videos/plank_demo.mp4',
  );
  static const Exercise _legRaise10 = Exercise(
    id: 'leg_raise',
    name: 'Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 10,
    videoAsset: 'assets/videos/leg_raise_demo.mp4',
  );

  static const List<WorkoutDay> _staticProgram = [
    WorkoutDay(dayNumber: 1, exercises: [_crunch10]),
    WorkoutDay(dayNumber: 2, exercises: [_crunch12, _plank20]),
    WorkoutDay(dayNumber: 3, exercises: [_crunch15, _legRaise10]),
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
