import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/workout_repository.dart';
import '../../models/exercise_model.dart';
import '../../models/workout_day_model.dart';

/// Rule-based 30-day plan generator. Consumes the flat [Exercise] pool
/// exposed on [WorkoutRepository.allExercises] and shapes it into a
/// 30-entry schedule honouring:
///
///   • a rest day every 4th day (4, 8, 12, 16, 20, 24, 28) with an empty
///     `exercises` list and the "Dinlenme Günü" title;
///   • goal-aware filtering (`sixpack` / `bulk` / `tone`);
///   • fitness-level filtering with a beginner ramp (no advanced work in
///     the first two weeks for beginners);
///   • 5–7 exercises per active day, rotating through the filtered pool
///     so the same day doesn't keep repeating the same five movements;
///   • progressive overload — every 7-day block multiplies reps and
///     time-under-tension by 1.2× relative to week 1.
///
/// The service is deterministic: given the same inputs it always returns
/// the same schedule. That makes the output trivial to diff across
/// versions and avoids "but mine looked different" reports when two users
/// compare plans.
class WorkoutGeneratorService {
  const WorkoutGeneratorService();

  /// Base rest-day label. Kept as a single constant so localisation later
  /// is a one-line change.
  static const String restDayTitle = 'Dinlenme Günü';

  /// Base multiplier applied per 7-day block. Week 1 uses 1.0, week 2 uses
  /// 1.2, week 3 uses 1.44, and so on — published reps/seconds come from
  /// `rounding(baseValue * multiplier)`.
  static const double weeklyOverloadMultiplier = 1.2;

  /// Lower and upper bounds on exercises per active day. The generator
  /// picks a value in this range as a function of the day number so the
  /// shape of the plan stays varied without introducing randomness.
  static const int minDailyExercises = 5;
  static const int maxDailyExercises = 7;

  List<WorkoutDay> generate30DayPlan({
    required String userGoal,
    required String fitnessLevel,
  }) {
    final goal = _normaliseGoal(userGoal);
    final level = _normaliseLevel(fitnessLevel);
    final pool = WorkoutRepository.allExercises;
    final goalFiltered = _filterByGoal(pool, goal);

    // Phase 48 · structured generator log so the dashboard's "all-Core
    // workouts" report is debuggable without a debugger attached. Tags
    // the inputs so we can verify whether the wizard payload reached the
    // generator (the prior bug was an empty `userGoal` collapsing the
    // sixpack default into a pure-core feed). PII-safe: no user metrics.
    AppLogger.info(
      'WorkoutGenerator · resolved inputs',
      category: 'workout',
      data: {
        'userGoal_raw': userGoal,
        'fitnessLevel_raw': fitnessLevel,
        'goal_normalised': goal.name,
        'level_normalised': level.name,
        'pool_size': pool.length,
        'goal_filtered_size': goalFiltered.length,
      },
    );

    final days = <WorkoutDay>[];
    var cursor = 0;

    for (var dayNumber = 1; dayNumber <= 30; dayNumber++) {
      // Rest days — every 4th day the user gets recovery. Empty exercise
      // list is the UI signal for "nothing to run here"; `title` carries
      // the label so the listing card can render "Dinlenme Günü".
      if (dayNumber % 4 == 0) {
        days.add(WorkoutDay(
          dayNumber: dayNumber,
          exercises: const [],
          title: restDayTitle,
        ));
        continue;
      }

      final weekIndex = (dayNumber - 1) ~/ 7;
      final levelFiltered = _filterByLevel(goalFiltered, level, weekIndex);

      // If a filter combination collapses the pool to empty (shouldn't
      // happen with the current catalogue, but could if the catalogue
      // shrinks), fall back to the widest working set so the day is
      // never empty/malformed.
      final dailyPool = levelFiltered.isNotEmpty
          ? levelFiltered
          : (goalFiltered.isNotEmpty ? goalFiltered : pool);

      final exerciseCount = _dailyExerciseCount(dayNumber);
      final multiplier =
          math.pow(weeklyOverloadMultiplier, weekIndex).toDouble();

      final dayExercises = <Exercise>[];
      for (var i = 0; i < exerciseCount; i++) {
        final base = dailyPool[(cursor + i) % dailyPool.length];
        dayExercises.add(_applyOverload(base, multiplier));
      }
      cursor = (cursor + exerciseCount) % dailyPool.length;

      days.add(WorkoutDay(
        dayNumber: dayNumber,
        exercises: dayExercises,
        title: 'Gün $dayNumber',
      ));
    }

    return days;
  }

  // ==========================================================================
  // Private helpers
  // ==========================================================================

  /// Accepts both the onboarding enum `.name` strings (tone / bulk /
  /// sixpack) and the English phrasing used in this phase's spec
  /// (six_pack / hacim / sıkılaşmak) so any caller works without forcing
  /// a convention on the other.
  _Goal _normaliseGoal(String raw) {
    final v = raw.trim().toLowerCase().replaceAll('-', '_');
    if (v == 'sixpack' || v == 'six_pack' || v == 'six pack' || v == 'core') {
      return _Goal.sixpack;
    }
    if (v == 'bulk' || v == 'hacim' || v == 'hypertrophy' || v == 'muscle') {
      return _Goal.bulk;
    }
    if (v == 'tone' ||
        v == 'sıkılaşmak' ||
        v == 'sikilasmak' ||
        v == 'toning' ||
        v == 'cut') {
      return _Goal.tone;
    }
    // Unknown input → default to a balanced core-centric plan, which is
    // the app's primary positioning ("30 günde karın kası").
    return _Goal.sixpack;
  }

  /// Accepts the difficulty strings published by Phase 16 (beginner /
  /// intermediate / advanced) plus the onboarding `ActivityLevel`
  /// names (sedentary / light / active) so the wizard's stored value can
  /// be passed straight through without a translation layer.
  _Level _normaliseLevel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'advanced' || v == 'active' || v == 'ileri') {
      return _Level.advanced;
    }
    if (v == 'intermediate' || v == 'light' || v == 'orta') {
      return _Level.intermediate;
    }
    return _Level.beginner;
  }

  List<Exercise> _filterByGoal(List<Exercise> pool, _Goal goal) {
    // Phase 48 · round-robin interleave. The previous concatenation
    // strategy meant the first ~9 exercises pulled by the day-cursor
    // were all the same muscle group (e.g. for `sixpack`, days 1-2 came
    // out as pure-core "fallback Abs" feeds). Interleaving across the
    // goal's bucket list guarantees every day sees variety from the
    // first cursor position.
    switch (goal) {
      case _Goal.sixpack:
        // Primary emphasis on core, but cardio + full_body sprinkled in
        // every day so even Day 1 reads as a balanced ab-finisher rather
        // than nine consecutive crunches.
        final core = pool.where((e) => e.targetMuscle == 'core').toList();
        final cardio = pool.where((e) => e.targetMuscle == 'cardio').toList();
        final fullBody =
            pool.where((e) => e.targetMuscle == 'full_body').toList();
        return _roundRobinMerge([core, cardio, fullBody]);
      case _Goal.bulk:
        // Hypertrophy focus → upper-body and lower-body compound work,
        // alternating muscles each pick so a single day naturally rotates
        // upper / lower / full-body without manual splits.
        final upper =
            pool.where((e) => e.targetMuscle == 'upper_body').toList();
        final lower =
            pool.where((e) => e.targetMuscle == 'lower_body').toList();
        final fullBody =
            pool.where((e) => e.targetMuscle == 'full_body').toList();
        return _roundRobinMerge([upper, lower, fullBody]);
      case _Goal.tone:
        // Fat-burn / toning → cardio-led but with core + lower-body
        // intermixed so each day moves the heart rate up while still
        // hitting the target zones.
        final cardio = pool.where((e) => e.targetMuscle == 'cardio').toList();
        final fullBody =
            pool.where((e) => e.targetMuscle == 'full_body').toList();
        final core = pool.where((e) => e.targetMuscle == 'core').toList();
        final lower =
            pool.where((e) => e.targetMuscle == 'lower_body').toList();
        return _roundRobinMerge([cardio, fullBody, core, lower]);
    }
  }

  /// Deterministic round-robin merge: takes the first item of each list,
  /// then the second of each, and so on, until every list is drained.
  /// Empty buckets are skipped silently. Order within a bucket is
  /// preserved (catalogue order — beginner movements first), so the
  /// output is reproducible across runs.
  List<Exercise> _roundRobinMerge(List<List<Exercise>> buckets) {
    final out = <Exercise>[];
    final maxLen = buckets.fold<int>(
      0,
      (acc, b) => b.length > acc ? b.length : acc,
    );
    for (var i = 0; i < maxLen; i++) {
      for (final bucket in buckets) {
        if (i < bucket.length) out.add(bucket[i]);
      }
    }
    return out;
  }

  List<Exercise> _filterByLevel(
    List<Exercise> pool,
    _Level level,
    int weekIndex,
  ) {
    switch (level) {
      case _Level.beginner:
        // Beginners get no advanced work during the first 2 weeks. After
        // day 14 the ceiling is raised so the 30-day arc still surfaces
        // some top-tier movements as the user progresses.
        final allowAdvanced = weekIndex >= 2;
        return pool
            .where((e) => allowAdvanced || e.difficulty != 'advanced')
            .toList();
      case _Level.intermediate:
        return List<Exercise>.from(pool);
      case _Level.advanced:
        return List<Exercise>.from(pool);
    }
  }

  /// Returns 5, 6, or 7 depending on the day number. Deterministic
  /// modulo rotation keeps consecutive days from feeling identical.
  int _dailyExerciseCount(int dayNumber) {
    final span = maxDailyExercises - minDailyExercises + 1; // = 3
    return minDailyExercises + (dayNumber % span);
  }

  Exercise _applyOverload(Exercise base, double multiplier) {
    if (multiplier == 1.0) return base;
    final scaledReps = base.targetReps == null
        ? null
        : math.max(1, (base.targetReps! * multiplier).round());
    final scaledDuration = base.targetDurationInSeconds == null
        ? null
        : math.max(1, (base.targetDurationInSeconds! * multiplier).round());
    return base.copyWith(
      targetReps: scaledReps,
      targetDurationInSeconds: scaledDuration,
    );
  }
}

enum _Goal { sixpack, bulk, tone }

enum _Level { beginner, intermediate, advanced }

/// Thin Riverpod wrapper so UI layers can resolve the generator without
/// reaching into `const WorkoutGeneratorService()` directly. Stateless,
/// so a `Provider` is the right primitive — no async setup, no caching.
final workoutGeneratorProvider = Provider<WorkoutGeneratorService>((ref) {
  return const WorkoutGeneratorService();
});
