import 'dart:async';

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
    this.currentSet = 1,
    this.isResting = false,
    this.restSecondsRemaining = 0,
    this.isSessionComplete = false,
  });

  final List<WorkoutDay> days;
  final WorkoutDay? activeDay;
  final int activeExerciseIndex;
  final int currentReps;
  final int currentSet;
  final bool isResting;
  final int restSecondsRemaining;
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

  /// Exercise the user will land on AFTER the current rest finishes.
  /// During rest between sets it stays on the same exercise; during rest
  /// between exercises it points at the next entry in the day.
  Exercise? get upcomingExercise {
    final day = activeDay;
    if (day == null) return null;
    if (!isResting) return activeExercise;
    final exercise = activeExercise;
    if (exercise == null) return null;
    if (currentSet > exercise.sets) {
      final nextIndex = activeExerciseIndex + 1;
      if (nextIndex >= day.exercises.length) return null;
      return day.exercises[nextIndex];
    }
    return exercise;
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
    int? currentSet,
    bool? isResting,
    int? restSecondsRemaining,
    bool? isSessionComplete,
  }) {
    return WorkoutSessionState(
      days: days ?? this.days,
      activeDay: activeDay ?? this.activeDay,
      activeExerciseIndex: activeExerciseIndex ?? this.activeExerciseIndex,
      currentReps: currentReps ?? this.currentReps,
      currentSet: currentSet ?? this.currentSet,
      isResting: isResting ?? this.isResting,
      restSecondsRemaining: restSecondsRemaining ?? this.restSecondsRemaining,
      isSessionComplete: isSessionComplete ?? this.isSessionComplete,
    );
  }
}

class WorkoutSessionNotifier extends AsyncNotifier<WorkoutSessionState> {
  late WorkoutRepository _repository;
  Timer? _restTimer;

  @override
  Future<WorkoutSessionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = WorkoutRepository(prefs);
    final days = await _repository.loadProgram();
    final activeDay = _firstIncomplete(days);
    ref.onDispose(_cancelRestTimer);
    return WorkoutSessionState(days: days, activeDay: activeDay);
  }

  void setCurrentReps(int reps) {
    final current = state.value;
    if (current == null || current.isResting) return;
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
    _cancelRestTimer();
    final day = current.days.firstWhere(
      (d) => d.dayNumber == dayNumber,
      orElse: () => current.days.first,
    );
    state = AsyncData(current.copyWith(
      activeDay: day,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: false,
    ));
  }

  /// Called when a single set finishes (reps target hit OR time elapsed).
  /// Advances the set/exercise pointer and starts the rest timer between
  /// pieces of work. Marking the day complete only happens after the LAST
  /// set of the LAST exercise, so the user can't accidentally skip ahead.
  Future<void> completeCurrentExercise() async {
    final current = state.value;
    final day = current?.activeDay;
    final exercise = current?.activeExercise;
    if (current == null || day == null || exercise == null) return;
    if (current.isResting) return;

    final isLastSet = current.currentSet >= exercise.sets;
    if (!isLastSet) {
      _enterRest(
        current.copyWith(
          currentReps: 0,
          currentSet: current.currentSet + 1,
        ),
        exercise.restDurationInSeconds,
      );
      return;
    }

    final nextIndex = current.activeExerciseIndex + 1;
    if (nextIndex < day.exercises.length) {
      final nextExercise = day.exercises[nextIndex];
      _enterRest(
        current.copyWith(
          activeExerciseIndex: nextIndex,
          currentReps: 0,
          currentSet: 1,
        ),
        nextExercise.restDurationInSeconds,
      );
      return;
    }

    await _repository.markDayCompleted(day.dayNumber);
    final refreshed = await _repository.loadProgram();
    final updatedDay = refreshed.firstWhere(
      (d) => d.dayNumber == day.dayNumber,
      orElse: () => day.copyWith(isCompleted: true),
    );
    _cancelRestTimer();
    state = AsyncData(current.copyWith(
      days: refreshed,
      activeDay: updatedDay,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: true,
    ));
  }

  void skipRest() {
    final current = state.value;
    if (current == null || !current.isResting) return;
    _cancelRestTimer();
    state = AsyncData(current.copyWith(
      isResting: false,
      restSecondsRemaining: 0,
    ));
  }

  Future<void> resetProgress() async {
    await _repository.resetProgress();
    final days = await _repository.loadProgram();
    _cancelRestTimer();
    state = AsyncData(WorkoutSessionState(
      days: days,
      activeDay: _firstIncomplete(days),
    ));
  }

  void _enterRest(WorkoutSessionState base, int seconds) {
    _cancelRestTimer();
    final clamped = seconds <= 0 ? 0 : seconds;
    state = AsyncData(base.copyWith(
      isResting: clamped > 0,
      restSecondsRemaining: clamped,
    ));
    if (clamped <= 0) return;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.value;
      if (current == null || !current.isResting) {
        timer.cancel();
        return;
      }
      final remaining = current.restSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        _restTimer = null;
        state = AsyncData(current.copyWith(
          isResting: false,
          restSecondsRemaining: 0,
        ));
      } else {
        state = AsyncData(current.copyWith(restSecondsRemaining: remaining));
      }
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
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
