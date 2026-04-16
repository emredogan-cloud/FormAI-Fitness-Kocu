import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/workout_repository.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';

class WorkoutSessionState {
  const WorkoutSessionState({
    this.days = const [],
    this.activeDay,
    this.activeExerciseIndex = 0,
    this.currentReps = 0,
    this.isSessionComplete = false,
  });

  final List<WorkoutDay> days;
  final WorkoutDay? activeDay;
  final int activeExerciseIndex;
  final int currentReps;
  final bool isSessionComplete;

  Exercise? get activeExercise {
    final day = activeDay;
    if (day == null) return null;
    if (activeExerciseIndex < 0 ||
        activeExerciseIndex >= day.exercises.length) {
      return null;
    }
    return day.exercises[activeExerciseIndex];
  }

  int? get repsRemaining {
    final target = activeExercise?.targetReps;
    if (target == null) return null;
    final remaining = target - currentReps;
    return remaining < 0 ? 0 : remaining;
  }

  WorkoutSessionState copyWith({
    List<WorkoutDay>? days,
    WorkoutDay? activeDay,
    int? activeExerciseIndex,
    int? currentReps,
    bool? isSessionComplete,
  }) {
    return WorkoutSessionState(
      days: days ?? this.days,
      activeDay: activeDay ?? this.activeDay,
      activeExerciseIndex: activeExerciseIndex ?? this.activeExerciseIndex,
      currentReps: currentReps ?? this.currentReps,
      isSessionComplete: isSessionComplete ?? this.isSessionComplete,
    );
  }
}

class WorkoutSessionNotifier extends AsyncNotifier<WorkoutSessionState> {
  late WorkoutRepository _repository;

  @override
  Future<WorkoutSessionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = WorkoutRepository(prefs);
    final days = await _repository.loadProgram();
    final activeDay = _firstIncomplete(days);
    return WorkoutSessionState(days: days, activeDay: activeDay);
  }

  void setCurrentReps(int reps) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(currentReps: reps));
  }

  void acknowledgeSessionComplete() {
    final current = state.value;
    if (current == null || !current.isSessionComplete) return;
    state = AsyncData(current.copyWith(isSessionComplete: false));
  }

  Future<void> startDay(int dayNumber) async {
    final current = state.value;
    if (current == null) return;
    final day = current.days.firstWhere(
      (d) => d.dayNumber == dayNumber,
      orElse: () => current.days.first,
    );
    state = AsyncData(current.copyWith(
      activeDay: day,
      activeExerciseIndex: 0,
      currentReps: 0,
      isSessionComplete: false,
    ));
  }

  Future<void> completeCurrentExercise() async {
    final current = state.value;
    final day = current?.activeDay;
    if (current == null || day == null) return;

    final nextIndex = current.activeExerciseIndex + 1;
    if (nextIndex >= day.exercises.length) {
      await _repository.markDayCompleted(day.dayNumber);
      final refreshed = await _repository.loadProgram();
      final updatedDay = refreshed.firstWhere(
        (d) => d.dayNumber == day.dayNumber,
        orElse: () => day.copyWith(isCompleted: true),
      );
      state = AsyncData(current.copyWith(
        days: refreshed,
        activeDay: updatedDay,
        activeExerciseIndex: 0,
        currentReps: 0,
        isSessionComplete: true,
      ));
    } else {
      state = AsyncData(current.copyWith(
        activeExerciseIndex: nextIndex,
        currentReps: 0,
      ));
    }
  }

  Future<void> resetProgress() async {
    await _repository.resetProgress();
    final days = await _repository.loadProgram();
    state = AsyncData(WorkoutSessionState(
      days: days,
      activeDay: _firstIncomplete(days),
    ));
  }

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (!day.isCompleted) return day;
    }
    return null;
  }
}

final workoutSessionProvider =
    AsyncNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
  WorkoutSessionNotifier.new,
);
