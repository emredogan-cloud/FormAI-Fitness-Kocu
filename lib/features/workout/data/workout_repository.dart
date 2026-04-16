import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';

class WorkoutRepository {
  WorkoutRepository(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _completedKey = 'sixpack.completed_days';
  static const String _progressTable = 'user_progress';

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
    final completed = await _completedDays();
    return _staticProgram
        .map((day) =>
            day.copyWith(isCompleted: completed.contains(day.dayNumber)))
        .toList(growable: false);
  }

  Future<void> markDayCompleted(int dayNumber) async {
    final merged = _localCompleted()..add(dayNumber);
    await _saveLocal(merged);

    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from(_progressTable).upsert(
        {
          'user_id': user.id,
          'day_number': dayNumber,
          'is_completed': true,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,day_number',
      );
    } catch (_) {
      // Offline or network error — local cache will re-sync on next load.
    }
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_completedKey);
  }

  Future<Set<int>> _completedDays() async {
    final local = _localCompleted();
    final user = _client.auth.currentUser;
    if (user == null) return local;

    try {
      final rows = await _client
          .from(_progressTable)
          .select('day_number, is_completed')
          .eq('user_id', user.id)
          .eq('is_completed', true);
      final remote = <int>{
        for (final row in rows)
          if (row['day_number'] is int) row['day_number'] as int,
      };
      final merged = {...local, ...remote};
      if (merged.length != local.length) {
        await _saveLocal(merged);
      }
      return merged;
    } catch (_) {
      return local;
    }
  }

  Set<int> _localCompleted() {
    final raw = _prefs.getStringList(_completedKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> _saveLocal(Set<int> days) async {
    await _prefs.setStringList(
      _completedKey,
      days.map((e) => e.toString()).toList(),
    );
  }
}
