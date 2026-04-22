import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_preferences.dart';
import '../data/workout_repository.dart';
import '../domain/services/workout_generator_service.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';

/// Catalogue of region-tagged plans surfaced on the dashboard's filter
/// strip. Currently a static list; promote to AsyncNotifier when plans
/// move behind a Supabase-backed catalogue.
final workoutPlansProvider = Provider<List<WorkoutPlan>>((ref) {
  return WorkoutRepository.allPlans;
});

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
    this.isPreparing = false,
    this.prepSecondsRemaining = 0,
  });

  final List<WorkoutDay> days;
  final WorkoutDay? activeDay;
  final int activeExerciseIndex;
  final int currentReps;
  final int currentSet;
  final bool isResting;
  final int restSecondsRemaining;
  final bool isSessionComplete;

  /// True for the 3-second "HAZIRLAN!" countdown that precedes every
  /// exercise (workout start + after every inter-exercise rest). The
  /// camera screen swaps in a prep overlay and the analyzer skips frames
  /// while this is true.
  final bool isPreparing;
  final int prepSecondsRemaining;

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
    bool? isPreparing,
    int? prepSecondsRemaining,
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
      isPreparing: isPreparing ?? this.isPreparing,
      prepSecondsRemaining: prepSecondsRemaining ?? this.prepSecondsRemaining,
    );
  }
}

class WorkoutSessionNotifier extends AsyncNotifier<WorkoutSessionState> {
  late WorkoutRepository _repository;
  Timer? _restTimer;
  Timer? _prepTimer;

  /// Set when [_enterRest] is called for an inter-EXERCISE rest (vs an
  /// inter-SET rest within the same exercise). Read by the rest timer
  /// completion to decide whether to launch a HAZIRLAN! prep countdown.
  bool _restPrecedesExerciseChange = false;

  static const Duration _prepDuration = Duration(seconds: 3);

  @override
  Future<WorkoutSessionState> build() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = WorkoutRepository(prefs);
    final days = await _loadProgram();
    final activeDay = _firstIncomplete(days);
    ref.onDispose(_cancelRestTimer);
    ref.onDispose(_cancelPrepTimer);
    return WorkoutSessionState(days: days, activeDay: activeDay);
  }

  /// Resolves the user's stored goal + activity level (set during the
  /// onboarding wizard) and hands them to the repository's cache-or-
  /// generate pipeline.
  ///
  /// Two sources are tried for the goal before giving up:
  ///
  ///   1. `userMetrics['targetPhysique']` — the full wizard payload
  ///      saved by onboarding / profile-edit.
  ///   2. `prefs.goal` — the flat `sixpack.goal` string written by
  ///      `completeOnboarding`. This is the fallback for legacy installs
  ///      that onboarded before the metrics-save was wired in (otherwise
  ///      those users would be stuck on the sixpack default forever even
  ///      though they picked bulk or tone).
  ///
  /// If both are absent, the repository/generator's own defaults
  /// (sixpack + beginner) kick in — never an empty 30-day list.
  Future<List<WorkoutDay>> _loadProgram() async {
    final appPrefs = ref.read(appPreferencesProvider);
    final metrics = appPrefs.userMetrics ?? const <String, dynamic>{};
    final userGoal = (metrics['targetPhysique'] as String?) ?? appPrefs.goal;
    final fitnessLevel = metrics['activityLevel'] as String?;
    return _repository.loadOrGenerateProgram(
      generator: ref.read(workoutGeneratorProvider),
      userGoal: userGoal,
      fitnessLevel: fitnessLevel,
    );
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
    _cancelPrepTimer();
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
    _startPrep();
  }

  /// Starts an ad-hoc session from a dashboard/plan-detail entry point.
  /// Stamps a synthetic [WorkoutDay] with `dayNumber: 0` so the completion
  /// logic below knows NOT to persist this run as a real program-day
  /// completion — ad-hoc plans don't move the 30-day needle.
  void initializeWorkout(List<Exercise> exercises) {
    final current = state.value;
    if (current == null || exercises.isEmpty) return;
    _cancelRestTimer();
    _cancelPrepTimer();
    final adHocDay = WorkoutDay(dayNumber: 0, exercises: exercises);
    state = AsyncData(current.copyWith(
      activeDay: adHocDay,
      activeExerciseIndex: 0,
      currentReps: 0,
      currentSet: 1,
      isResting: false,
      restSecondsRemaining: 0,
      isSessionComplete: false,
    ));
    _startPrep();
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
        isExerciseChange: false,
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
        isExerciseChange: true,
      );
      return;
    }

    // dayNumber == 0 indicates an ad-hoc plan started via
    // `initializeWorkout` — those runs don't persist to the 30-day program
    // completion ledger, so skip markDayCompleted + loadProgram for them.
    final isAdHoc = day.dayNumber <= 0;
    if (!isAdHoc) {
      await _repository.markDayCompleted(day.dayNumber);
    }
    final refreshed = isAdHoc ? current.days : await _loadProgram();
    final updatedDay = isAdHoc
        ? day.copyWith(isCompleted: true)
        : refreshed.firstWhere(
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
    if (_restPrecedesExerciseChange) {
      _startPrep();
    }
    _restPrecedesExerciseChange = false;
  }

  Future<void> resetProgress() async {
    await _repository.resetProgress();
    final days = await _loadProgram();
    _cancelRestTimer();
    state = AsyncData(WorkoutSessionState(
      days: days,
      activeDay: _firstIncomplete(days),
    ));
  }

  void _enterRest(
    WorkoutSessionState base,
    int seconds, {
    required bool isExerciseChange,
  }) {
    _cancelRestTimer();
    _restPrecedesExerciseChange = isExerciseChange;
    final clamped = seconds <= 0 ? 0 : seconds;
    state = AsyncData(base.copyWith(
      isResting: clamped > 0,
      restSecondsRemaining: clamped,
    ));
    if (clamped <= 0) {
      // Zero-second rest is effectively immediate transition — fire prep
      // straight away so the user still gets the HAZIRLAN! countdown.
      if (_restPrecedesExerciseChange) {
        _startPrep();
      }
      _restPrecedesExerciseChange = false;
      return;
    }

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
        if (_restPrecedesExerciseChange) {
          _startPrep();
        }
        _restPrecedesExerciseChange = false;
      } else {
        state = AsyncData(current.copyWith(restSecondsRemaining: remaining));
      }
    });
  }

  /// Kicks off the 3-second HAZIRLAN! countdown. Each tick decrements
  /// `prepSecondsRemaining`; the final tick flips `isPreparing` back to
  /// false so the analyzer wakes up for the new exercise.
  void _startPrep() {
    _cancelPrepTimer();
    final current = state.value;
    if (current == null || current.activeExercise == null) return;
    final initial = _prepDuration.inSeconds;
    state = AsyncData(current.copyWith(
      isPreparing: true,
      prepSecondsRemaining: initial,
    ));
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final cur = state.value;
      if (cur == null || !cur.isPreparing) {
        timer.cancel();
        return;
      }
      final remaining = cur.prepSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        _prepTimer = null;
        state = AsyncData(cur.copyWith(
          isPreparing: false,
          prepSecondsRemaining: 0,
        ));
      } else {
        state = AsyncData(cur.copyWith(prepSecondsRemaining: remaining));
      }
    });
  }

  void _cancelRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  void _cancelPrepTimer() {
    _prepTimer?.cancel();
    _prepTimer = null;
  }

  /// Skips rest days: they never flow through `markDayCompleted`, so
  /// including them would cause the session to "resume" on a day with
  /// no exercises.
  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day;
    }
    return null;
  }
}

final workoutSessionProvider =
    AsyncNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
  WorkoutSessionNotifier.new,
);
