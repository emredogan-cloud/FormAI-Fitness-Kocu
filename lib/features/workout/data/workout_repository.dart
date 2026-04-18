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

  // ==========================================================================
  // CORE (Karın & Stabilite)
  // ==========================================================================

  static const Exercise _crunch = Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    videoAsset: 'assets/videos/crunch_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Mekik. Yere uzan, ellerini başının arkasına koy ve başla.',
  );

  static const Exercise _situp = Exercise(
    id: 'situp',
    name: 'Sit-up',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 35,
    videoAsset: 'assets/videos/crunch_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Sit-up. Tüm gövdeni yukarı kaldır, dizlerine kadar gel.',
  );

  static const Exercise _plank = Exercise(
    id: 'plank',
    name: 'Plank',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 40,
    sets: 3,
    restDurationInSeconds: 45,
    videoAsset: 'assets/videos/plank_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Plank. Dirseklerin üzerinde sabit kal, kalçanı düz tut.',
  );

  static const Exercise _legRaise = Exercise(
    id: 'leg_raise',
    name: 'Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    videoAsset: 'assets/videos/leg_raise_demo.mp4',
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Bacak Kaldırma. Bacaklarını 90 dereceye kaldır.',
  );

  static const Exercise _hangingLegRaise = Exercise(
    id: 'hanging_leg_raise',
    name: 'Asılı Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Asılı Bacak Kaldırma. Bara tutun ve bacaklarını yukarı çek.',
  );

  static const Exercise _russianTwist = Exercise(
    id: 'russian_twist',
    name: 'Rus Dönüşü',
    type: ExerciseType.repBased,
    targetReps: 20,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Rus Dönüşü. Otur, hafif geri yaslan ve gövdeni sağa sola döndür.',
  );

  static const Exercise _mountainClimber = Exercise(
    id: 'mountain_climber',
    name: 'Mountain Climber',
    type: ExerciseType.repBased,
    targetReps: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Mountain Climber. Plank pozisyonunda dizlerini hızla göğsüne çek.',
  );

  static const Exercise _bicycleCrunch = Exercise(
    id: 'bicycle_crunch',
    name: 'Bisiklet Mekiği',
    type: ExerciseType.repBased,
    targetReps: 16,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Bisiklet Mekiği. Karşıt dirsek ve dizini birleştir.',
  );

  static const Exercise _flutterKick = Exercise(
    id: 'flutter_kick',
    name: 'Flutter Kick',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    startCommand:
        'Sıradaki hareket: Flutter Kick. Sırt üstü uzan ve bacaklarını kısa, hızlı tempoda değiştir.',
  );

  // ==========================================================================
  // GÖĞÜS (Chest)
  // ==========================================================================

  static const Exercise _pushUp = Exercise(
    id: 'push_up',
    name: 'Şınav',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Şınav. Şınav pozisyonu al, eller omuz hizasında ve başla.',
  );

  static const Exercise _inclinePushUp = Exercise(
    id: 'incline_push_up',
    name: 'Yokuş Yukarı Şınav',
    type: ExerciseType.repBased,
    targetReps: 14,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Yokuş Yukarı Şınav. Ellerin yüksek bir yüzeye dayalı, şınava başla.',
  );

  static const Exercise _declinePushUp = Exercise(
    id: 'decline_push_up',
    name: 'Yokuş Aşağı Şınav',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Yokuş Aşağı Şınav. Ayaklarını yüksek tut, kontrollü in ve çık.',
  );

  static const Exercise _chestDip = Exercise(
    id: 'chest_dip',
    name: 'Göğüs Dip',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Göğüs Dip. Paralel barlarda göğsünü öne eğerek aşağı in.',
  );

  static const Exercise _benchPress = Exercise(
    id: 'bench_press',
    name: 'Dambıl Bench Press',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Dambıl Bench Press. Bench üzerinde uzan ve dambılları yukarı it.',
  );

  static const Exercise _chestFly = Exercise(
    id: 'chest_fly',
    name: 'Chest Fly',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.chest,
    startCommand:
        'Sıradaki hareket: Chest Fly. Kollarını yana aç ve göğüs üstünde kontrollü kapat.',
  );

  // ==========================================================================
  // PROGRAM
  // ==========================================================================

  static const List<WorkoutDay> _staticProgram = [
    WorkoutDay(
      dayNumber: 1,
      exercises: [_crunch, _plank, _legRaise],
    ),
    WorkoutDay(
      dayNumber: 2,
      exercises: [_situp, _bicycleCrunch, _plank],
    ),
    WorkoutDay(
      dayNumber: 3,
      exercises: [_crunch, _russianTwist, _legRaise],
    ),
    WorkoutDay(
      dayNumber: 4,
      exercises: [_pushUp, _inclinePushUp, _chestFly],
    ),
    WorkoutDay(
      dayNumber: 5,
      exercises: [_mountainClimber, _flutterKick, _plank],
    ),
    WorkoutDay(
      dayNumber: 6,
      exercises: [_benchPress, _chestDip, _declinePushUp],
    ),
    WorkoutDay(
      dayNumber: 7,
      exercises: [
        _crunch,
        _bicycleCrunch,
        _hangingLegRaise,
        _flutterKick,
      ],
    ),
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
