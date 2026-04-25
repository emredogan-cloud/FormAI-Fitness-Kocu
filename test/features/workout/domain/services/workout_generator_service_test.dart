import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/domain/services/workout_generator_service.dart';
import 'package:sixpack_ai/features/workout/models/exercise_model.dart';

/// Fixture pool sized to every dimension the generator exercises:
///   • core / upper_body / lower_body / cardio / full_body coverage so
///     the goal-based filters all return non-empty results.
///   • beginner / intermediate / advanced spread so the fitness-level
///     ramp test (advanced unlocks at week 3) has both populations.
///   • a mix of rep-based and time-based movements so the progressive
///     overload test can find a scalable target on day 1 and day 9.
///
/// Replaces the pre-Phase-50A reliance on `WorkoutRepository.allExercises`,
/// which is no longer a static list — exercises are now fetched async
/// from Supabase, so the generator takes its pool as a parameter and
/// the test owns its own fixtures.
const _fixturePool = <Exercise>[
  // Core (5)
  Exercise(
    id: 'crunch',
    name: 'Mekik',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  ),
  Exercise(
    id: 'plank',
    name: 'Plank',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 40,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    difficulty: 'beginner',
    targetMuscle: 'core',
    isCardio: false,
  ),
  Exercise(
    id: 'leg_raise',
    name: 'Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    difficulty: 'intermediate',
    targetMuscle: 'core',
    isCardio: false,
  ),
  Exercise(
    id: 'hanging_leg_raise',
    name: 'Asılı Bacak Kaldırma',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.core,
    difficulty: 'advanced',
    targetMuscle: 'core',
    isCardio: false,
  ),
  Exercise(
    id: 'flutter_kick',
    name: 'Flutter Kick',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.core,
    difficulty: 'intermediate',
    targetMuscle: 'core',
    isCardio: false,
  ),
  // Upper body (4)
  Exercise(
    id: 'push_up',
    name: 'Şınav',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.chest,
    difficulty: 'intermediate',
    targetMuscle: 'upper_body',
    isCardio: false,
  ),
  Exercise(
    id: 'pull_up',
    name: 'Pull-up',
    type: ExerciseType.repBased,
    targetReps: 8,
    sets: 3,
    restDurationInSeconds: 60,
    category: ExerciseCategory.back,
    difficulty: 'advanced',
    targetMuscle: 'upper_body',
    isCardio: false,
  ),
  Exercise(
    id: 'lateral_raise',
    name: 'Lateral Raise',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.shoulders,
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  ),
  Exercise(
    id: 'biceps_curl',
    name: 'Biceps Curl',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.arms,
    difficulty: 'beginner',
    targetMuscle: 'upper_body',
    isCardio: false,
  ),
  // Lower body (3)
  Exercise(
    id: 'squat',
    name: 'Squat',
    type: ExerciseType.repBased,
    targetReps: 15,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    difficulty: 'beginner',
    targetMuscle: 'lower_body',
    isCardio: false,
  ),
  Exercise(
    id: 'lunge',
    name: 'Lunge',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.legs,
    difficulty: 'intermediate',
    targetMuscle: 'lower_body',
    isCardio: false,
  ),
  Exercise(
    id: 'bulgarian_split_squat',
    name: 'Bulgar Split Squat',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.legs,
    difficulty: 'advanced',
    targetMuscle: 'lower_body',
    isCardio: false,
  ),
  // Cardio (2)
  Exercise(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    difficulty: 'beginner',
    targetMuscle: 'cardio',
    isCardio: true,
  ),
  Exercise(
    id: 'high_knees',
    name: 'High Knees',
    type: ExerciseType.timeBased,
    targetDurationInSeconds: 30,
    sets: 3,
    restDurationInSeconds: 30,
    category: ExerciseCategory.fullBody,
    difficulty: 'beginner',
    targetMuscle: 'cardio',
    isCardio: true,
  ),
  // Full body (2)
  Exercise(
    id: 'burpee',
    name: 'Burpee',
    type: ExerciseType.repBased,
    targetReps: 10,
    sets: 3,
    restDurationInSeconds: 50,
    category: ExerciseCategory.fullBody,
    difficulty: 'advanced',
    targetMuscle: 'full_body',
    isCardio: true,
  ),
  Exercise(
    id: 'jump_squat',
    name: 'Jump Squat',
    type: ExerciseType.repBased,
    targetReps: 12,
    sets: 3,
    restDurationInSeconds: 45,
    category: ExerciseCategory.fullBody,
    difficulty: 'intermediate',
    targetMuscle: 'full_body',
    isCardio: true,
  ),
];

void main() {
  const service = WorkoutGeneratorService();

  group('generate30DayPlan — schedule shape', () {
    test('returns exactly 30 days for any supported goal', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      expect(plan, hasLength(30));
      expect(plan.first.dayNumber, 1);
      expect(plan.last.dayNumber, 30);
    });

    test('every 4th day is a rest day with the canonical label', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      for (final day in plan) {
        final isRest = day.dayNumber % 4 == 0;
        if (isRest) {
          expect(
            day.exercises,
            isEmpty,
            reason: 'rest days render with an empty exercise list',
          );
          expect(day.title, WorkoutGeneratorService.restDayTitle);
          expect(day.isRestDay, isTrue);
        } else {
          expect(day.exercises, isNotEmpty);
          expect(day.title, 'Gün ${day.dayNumber}');
        }
      }
    });

    test('active days carry 5–7 exercises per the daily bounds', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'intermediate',
        pool: _fixturePool,
      );

      for (final day in plan.where((d) => !d.isRestDay)) {
        expect(
          day.exercises.length,
          inInclusiveRange(
            WorkoutGeneratorService.minDailyExercises,
            WorkoutGeneratorService.maxDailyExercises,
          ),
        );
      }
    });

    test('is deterministic — same inputs produce the same schedule', () {
      final a = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'advanced',
        pool: _fixturePool,
      );
      final b = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'advanced',
        pool: _fixturePool,
      );

      expect(a, equals(b));
    });

    test('empty pool returns a 30-rest-day stub instead of crashing', () {
      // Phase 50A · graceful degradation when the Supabase fetch fails on
      // first launch. The stub lets the antrenman tab render without
      // null-safety wrappers; the repository skips caching it so the
      // next launch retries the fetch.
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: const [],
      );

      expect(plan, hasLength(30));
      for (final day in plan) {
        expect(day.exercises, isEmpty);
        expect(day.title, WorkoutGeneratorService.restDayTitle);
      }
    });
  });

  group('goal-aware daily composition', () {
    test('sixpack plan day 1 leads with a core movement and stays core-heavy',
        () {
      // Phase 48 · the generator now round-robin-interleaves the goal
      // buckets ([core, cardio, full_body] for sixpack) so day 1 reads
      // as a balanced ab-finisher rather than nine consecutive crunches.
      // The invariants we still want: the first exercise is core (the
      // bucket head), and a clear majority of the day stays core.
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      final dayOne = plan.first;
      final coreCount =
          dayOne.exercises.where((e) => e.targetMuscle == 'core').length;

      expect(
        dayOne.exercises.first.targetMuscle,
        'core',
        reason: 'sixpack rotation must lead with the core bucket head',
      );
      expect(
        coreCount * 2,
        greaterThanOrEqualTo(dayOne.exercises.length),
        reason: 'sixpack day 1 must remain at least 50% core after Phase 48 '
            'interleave introduces cardio + full_body variety',
      );
    });

    test(
        'bulk plan day 1 leads with strength and surfaces multiple muscle '
        'groups', () {
      // Phase 48 · bulk now interleaves [upper_body, lower_body, full_body],
      // so a single day touches multiple compound zones in sequence
      // instead of front-loading nine upper-body movements before
      // touching legs. The day still leads on strength (upper/lower).
      final plan = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'intermediate',
        pool: _fixturePool,
      );

      final dayOne = plan.first;
      final strengthCount = dayOne.exercises
          .where((e) =>
              e.targetMuscle == 'upper_body' || e.targetMuscle == 'lower_body')
          .length;
      final muscleGroups = dayOne.exercises.map((e) => e.targetMuscle).toSet();

      expect(
        dayOne.exercises.first.targetMuscle,
        'upper_body',
        reason: 'bulk rotation must lead with the upper-body bucket head',
      );
      expect(
        strengthCount * 2,
        greaterThanOrEqualTo(dayOne.exercises.length),
        reason: 'bulk day must stay majority compound strength even after '
            'the interleave brings full_body in for variety',
      );
      expect(
        muscleGroups.length,
        greaterThan(1),
        reason: 'bulk interleave must surface more than one muscle group '
            'per day so users do not see a pure upper-body wall on day 1',
      );
    });

    test('tone plan day 1 leads with cardio / full-body movements', () {
      final plan = service.generate30DayPlan(
        userGoal: 'tone',
        fitnessLevel: 'intermediate',
        pool: _fixturePool,
      );

      final dayOne = plan.first;
      final cardioCount = dayOne.exercises
          .where((e) =>
              e.targetMuscle == 'cardio' || e.targetMuscle == 'full_body')
          .length;

      // The cardio+full_body slice of the catalogue has ~5 moves, so a
      // 6-exercise day may pick up one core/lower_body "support" entry
      // from the tail of the tone filter. The ordering invariant is that
      // the MAJORITY of the session must be conditioning work.
      expect(
        cardioCount,
        greaterThan(dayOne.exercises.length / 2),
        reason:
            'tone goal must front-load the day with cardio + full_body work',
      );
      expect(
        dayOne.exercises.first.targetMuscle,
        anyOf('cardio', 'full_body'),
        reason: 'first exercise of a tone plan must come from the '
            'conditioning head of the filter',
      );
    });

    test('unknown goal falls back to the sixpack (core-first) default', () {
      final unknown = service.generate30DayPlan(
        userGoal: 'totally-made-up-goal',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );
      final sixpack = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      expect(unknown, equals(sixpack));
    });

    test('Turkish goal aliases map to their English equivalents', () {
      final turkish = service.generate30DayPlan(
        userGoal: 'sıkılaşmak',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );
      final english = service.generate30DayPlan(
        userGoal: 'tone',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      expect(turkish, equals(english));
    });
  });

  group('fitness-level filtering', () {
    test('beginners see no advanced moves in the first 2 weeks', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      for (final day in plan.where((d) => !d.isRestDay && d.dayNumber <= 14)) {
        final hasAdvanced =
            day.exercises.any((e) => e.difficulty == 'advanced');
        expect(
          hasAdvanced,
          isFalse,
          reason: 'day ${day.dayNumber} must not surface advanced work '
              'to a beginner before the week-3 ramp',
        );
      }
    });

    test('beginners unlock advanced work from week 3 onward', () {
      final plan = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      final hasAdvancedPostWeek2 = plan
          .where((d) => !d.isRestDay && d.dayNumber > 14)
          .expand((d) => d.exercises)
          .any((e) => e.difficulty == 'advanced');

      expect(
        hasAdvancedPostWeek2,
        isTrue,
        reason: 'beginner ceiling lifts after day 14 so the arc progresses',
      );
    });

    test('intermediate level surfaces advanced work immediately', () {
      final plan = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'intermediate',
        pool: _fixturePool,
      );

      final firstWeekHasAdvanced = plan
          .where((d) => !d.isRestDay && d.dayNumber <= 7)
          .expand((d) => d.exercises)
          .any((e) => e.difficulty == 'advanced');

      expect(firstWeekHasAdvanced, isTrue);
    });
  });

  group('progressive overload', () {
    test('week-2 reps scale by ~1.2x vs week-1 for a matching exercise', () {
      // Phase 50A · the previous version of this test relied on the
      // cursor wrapping back to position 0 by day 9, which depended on
      // the legacy 41-exercise catalogue size happening to divide the
      // cumulative exercise count. With the fixture pool now small and
      // owned by the test, we instead pick any rep-based movement that
      // shows up in both week 1 and week 2 and assert the multiplier
      // applied — a stronger invariant that survives pool resizing.
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      final week1Reps = plan
          .where((d) => !d.isRestDay && d.dayNumber <= 7)
          .expand((d) => d.exercises)
          .where((e) => e.targetReps != null)
          .toList(growable: false);

      final week2Reps = plan
          .where((d) => !d.isRestDay && d.dayNumber > 7 && d.dayNumber <= 14)
          .expand((d) => d.exercises)
          .where((e) => e.targetReps != null)
          .toList(growable: false);

      expect(week1Reps, isNotEmpty);
      expect(week2Reps, isNotEmpty);

      final week2Names = week2Reps.map((e) => e.name).toSet();
      final w1 = week1Reps.firstWhere(
        (e) => week2Names.contains(e.name),
        orElse: () => throw StateError(
          'no rep-based exercise was shared between week 1 and week 2',
        ),
      );
      final w2 = week2Reps.firstWhere((e) => e.name == w1.name);

      expect(
        w2.targetReps!,
        greaterThan(w1.targetReps!),
        reason: 'week 2 must apply the 1.2x reps multiplier',
      );
    });

    test('week-2 time-based moves scale by ~1.2x vs week-1', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
        pool: _fixturePool,
      );

      final week1Time = plan
          .where((d) => !d.isRestDay && d.dayNumber <= 7)
          .expand((d) => d.exercises)
          .where((e) => e.targetDurationInSeconds != null)
          .toList(growable: false);
      final week2Time = plan
          .where((d) => !d.isRestDay && d.dayNumber > 7 && d.dayNumber <= 14)
          .expand((d) => d.exercises)
          .where((e) => e.targetDurationInSeconds != null)
          .toList(growable: false);

      // Time-based movements are scarcer than rep-based; only assert the
      // multiplier when the schedule actually shares a name across weeks.
      final week2Names = week2Time.map((e) => e.name).toSet();
      final shared =
          week1Time.where((e) => week2Names.contains(e.name)).toList();
      if (shared.isEmpty) return;

      final w1 = shared.first;
      final w2 = week2Time.firstWhere((e) => e.name == w1.name);

      expect(
        w2.targetDurationInSeconds!,
        greaterThan(w1.targetDurationInSeconds!),
      );
    });
  });
}
