import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/data/workout_repository.dart';
import 'package:sixpack_ai/features/workout/domain/services/workout_generator_service.dart';
import 'package:sixpack_ai/features/workout/models/workout_day_model.dart';

void main() {
  // `WorkoutRepository.allExercises` initialises video URLs from
  // `dotenv.env['SUPABASE_URL']`. Without an initialised dotenv the
  // first access throws `NotInitializedError`; `loadFromString` with
  // `isOptional: true` seeds an empty-but-initialised map so the
  // generator can read through `dotenv.env[...]` without crashing.
  setUpAll(() {
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  const service = WorkoutGeneratorService();

  group('generate30DayPlan — schedule shape', () {
    test('returns exactly 30 days for any supported goal', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
      );

      expect(plan, hasLength(30));
      expect(plan.first.dayNumber, 1);
      expect(plan.last.dayNumber, 30);
    });

    test('every 4th day is a rest day with the canonical label', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
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
      );
      final b = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'advanced',
      );

      expect(a, equals(b));
    });
  });

  group('goal-aware daily composition', () {
    test('sixpack plan day 1 leans on core exercises', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
      );

      final dayOne = plan.first;
      final coreCount =
          dayOne.exercises.where((e) => e.targetMuscle == 'core').length;

      expect(
        coreCount,
        dayOne.exercises.length,
        reason: 'sixpack goal starts rotation at the core-first filtered pool',
      );
    });

    test('bulk plan day 1 uses strength (upper/lower body) exercises', () {
      final plan = service.generate30DayPlan(
        userGoal: 'bulk',
        fitnessLevel: 'intermediate',
      );

      final dayOne = plan.first;
      final strengthCount = dayOne.exercises
          .where((e) =>
              e.targetMuscle == 'upper_body' || e.targetMuscle == 'lower_body')
          .length;

      expect(
        strengthCount,
        dayOne.exercises.length,
        reason: 'bulk goal foregrounds compound strength movements, '
            'deprioritising cardio until later in the rotation',
      );
    });

    test('tone plan day 1 leads with cardio / full-body movements', () {
      final plan = service.generate30DayPlan(
        userGoal: 'tone',
        fitnessLevel: 'intermediate',
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
      );
      final sixpack = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
      );

      expect(unknown, equals(sixpack));
    });

    test('Turkish goal aliases map to their English equivalents', () {
      final turkish = service.generate30DayPlan(
        userGoal: 'sıkılaşmak',
        fitnessLevel: 'beginner',
      );
      final english = service.generate30DayPlan(
        userGoal: 'tone',
        fitnessLevel: 'beginner',
      );

      expect(turkish, equals(english));
    });
  });

  group('fitness-level filtering', () {
    test('beginners see no advanced moves in the first 2 weeks', () {
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
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
      final plan = service.generate30DayPlan(
        userGoal: 'sixpack',
        fitnessLevel: 'beginner',
      );

      WorkoutDay findDay(int dn) => plan.firstWhere((d) => d.dayNumber == dn);

      // Day 1 and day 9 both fall at the start of a 5-exercise day per
      // `_dailyExerciseCount` (dayNumber % 3), so the first slot is the
      // same base exercise — the only difference is the week multiplier.
      final week1Day = findDay(1);
      final week2Day = findDay(9);
      expect(week1Day.exercises, isNotEmpty);
      expect(week2Day.exercises, isNotEmpty);

      final w1 = week1Day.exercises.first;
      final w2 = week2Day.exercises.first;
      expect(
        w1.name,
        w2.name,
        reason: 'sanity-check: deterministic rotation picks the same move',
      );

      if (w1.targetReps != null && w2.targetReps != null) {
        expect(
          w2.targetReps!,
          greaterThan(w1.targetReps!),
          reason: 'week 2 must apply the 1.2x reps multiplier',
        );
      }
      if (w1.targetDurationInSeconds != null &&
          w2.targetDurationInSeconds != null) {
        expect(
          w2.targetDurationInSeconds!,
          greaterThan(w1.targetDurationInSeconds!),
        );
      }
    });
  });

  group('repository exposure', () {
    test(
        'WorkoutRepository.allExercises is non-empty so the generator '
        'always has a pool to rotate through', () {
      expect(WorkoutRepository.allExercises, isNotEmpty);
    });
  });
}
