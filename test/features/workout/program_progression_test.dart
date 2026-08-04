import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/workout/domain/program_progression.dart';

/// Roadmap Phase 14 (C40, P5) · the day-31 rules.
void main() {
  ProgramOutcome outcome(
    int completed, {
    int total = 30,
    DifficultyTier tier = DifficultyTier.beginner,
    double? ratio,
  }) =>
      ProgramOutcome(
        completedDays: completed,
        totalDays: total,
        tier: tier,
        medianSessionRatio: ratio,
      );

  group('tiers', () {
    test('the tokens are the generator\'s own fitnessLevel strings', () {
      // A tier that cannot be handed back to WorkoutGeneratorService is
      // a tier the app can recommend and not deliver.
      expect(DifficultyTier.beginner.token, 'beginner');
      expect(DifficultyTier.intermediate.token, 'intermediate');
      expect(DifficultyTier.advanced.token, 'advanced');
    });

    test('advanced has no next tier', () {
      expect(DifficultyTier.beginner.next, DifficultyTier.intermediate);
      expect(DifficultyTier.intermediate.next, DifficultyTier.advanced);
      expect(DifficultyTier.advanced.next, isNull);
    });

    test('an unreadable stored level is a beginner, never an advanced', () {
      // Preferences have carried free text since before this enum. The
      // safe direction is down: a beginner given an advanced program is
      // hurt, an advanced user given a beginner one is bored.
      expect(DifficultyTier.fromToken(null), DifficultyTier.beginner);
      expect(DifficultyTier.fromToken('İleri'), DifficultyTier.beginner);
      expect(DifficultyTier.fromToken('advanced'), DifficultyTier.advanced);
    });
  });

  group('completion rate', () {
    test('an empty program scores zero, not one', () {
      // Vacuous truth here would read as a perfect run and recommend a
      // tier advance off a plan that never existed.
      final empty = outcome(0, total: 0);
      expect(empty.completionRate, 0);
      expect(empty.isComplete, isFalse);
      expect(recommend(empty).path, ContinuationPath.repeatWithProgression);
      expect(recommend(empty).overload, 1.0);
    });

    test('more completed days than the plan has still reads as complete', () {
      expect(outcome(31).isComplete, isTrue);
    });
  });

  group('the recommendation', () {
    test('a strong beginner is offered the next tier', () {
      final r = recommend(outcome(27, tier: DifficultyTier.beginner));
      expect(r.path, ContinuationPath.advanceTier);
      expect(r.tier, DifficultyTier.intermediate);
    });

    test('advancing a tier does not also raise the volume', () {
      // Two increases at once, and a bad month afterwards cannot be
      // attributed to either.
      final r = recommend(outcome(30, tier: DifficultyTier.beginner));
      expect(r.path, ContinuationPath.advanceTier);
      expect(r.overload, 1.0);
      expect(r.raisesDifficulty, isTrue,
          reason: 'a tier change is a difficulty change even at 1.0 volume');
    });

    test('a strong advanced user is offered a change of focus', () {
      // There is no fourth tier, and this is the dead end the phase is
      // about — the app must have something to say here.
      final r = recommend(outcome(29, tier: DifficultyTier.advanced));
      expect(r.path, ContinuationPath.switchFocus);
      expect(r.tier, DifficultyTier.advanced);
    });

    test('a solid-but-not-strong run repeats with a modest bump', () {
      final r = recommend(outcome(20)); // 0.67
      expect(r.path, ContinuationPath.repeatWithProgression);
      expect(r.tier, DifficultyTier.beginner);
      expect(r.overload, kModestOverload);
    });

    test('somebody who struggled gets the SAME program, not a harder one', () {
      // The single most important rule in the file. 11 of 30 days is a
      // person who is about to quit, and the fix is not more volume.
      final r = recommend(outcome(11));
      expect(r.path, ContinuationPath.repeatWithProgression);
      expect(r.overload, 1.0);
      expect(r.raisesDifficulty, isFalse);
    });

    test('nothing ever recommends maintenance', () {
      // It stays offered by the screen and is never the marked path:
      // recommending that somebody stop progressing is not a call an
      // algorithm gets to make from a completion count.
      for (var days = 0; days <= 30; days++) {
        for (final tier in DifficultyTier.values) {
          expect(recommend(outcome(days, tier: tier)).path,
              isNot(ContinuationPath.maintenance));
        }
      }
    });

    test('the threshold boundaries land on the generous side', () {
      expect(recommend(outcome(15)).overload, kModestOverload,
          reason: '0.5 exactly is not struggling');
      expect(recommend(outcome(24)).path, ContinuationPath.advanceTier,
          reason: '0.8 exactly earns the tier');
      expect(
          recommend(outcome(23)).path, ContinuationPath.repeatWithProgression);
    });
  });

  group('fit', () {
    test('a half-finished program was too hard', () {
      expect(assessFit(outcome(10)).name, ProgramFit.tooHard.name);
    });

    test('finishing everything quickly is too easy', () {
      expect(assessFit(outcome(30, ratio: 0.6)), ProgramFit.tooEasy);
    });

    test('finishing everything slowly is not too hard', () {
      // Completion contradicts duration. Somebody who did every session
      // is not on a program that beat them, however long they took.
      expect(assessFit(outcome(29, ratio: 1.8)), ProgramFit.wellMatched);
    });

    test('overrunning sessions on a middling run reads as too hard', () {
      expect(assessFit(outcome(20, ratio: 1.5)), ProgramFit.tooHard);
    });

    test('no duration data still yields a reading', () {
      // The common case for months. Every rule has to work without it.
      expect(assessFit(outcome(28)), ProgramFit.wellMatched);
      expect(assessFit(outcome(18)), ProgramFit.wellMatched);
      expect(assessFit(outcome(4)), ProgramFit.tooHard);
    });
  });

  group('progressive overload is visible', () {
    test('a bump always changes the number', () {
      // The roadmap asks for VISIBLE progressive overload. 8% of 10 is
      // 10.8, and a rule that rounded to nearest would print 11 while
      // 8% of 6 printed 6 — a progression the user cannot see.
      for (var reps = 1; reps <= 30; reps++) {
        expect(progressedReps(reps, kStrongOverload), greaterThan(reps),
            reason: '$reps reps did not move');
        expect(progressedReps(reps, kModestOverload), greaterThan(reps),
            reason: '$reps reps did not move');
      }
    });

    test('no bump means no change', () {
      expect(progressedReps(12, 1.0), 12);
      expect(progressedReps(12, 0.5), 12);
    });

    test('zero and negative reps are left alone', () {
      expect(progressedReps(0, kStrongOverload), 0);
      expect(progressedReps(-3, kStrongOverload), -3);
    });
  });

  test('the overload constant matches the generator\'s own', () {
    // The generator already knows how to make a week 8% harder. Two
    // progression rates would mean the screen promises one thing and the
    // plan builds another — the same reason `league_test.dart` reads the
    // leaderboard SQL to check the caps.
    final source = File(
      'lib/features/workout/domain/services/workout_generator_service.dart',
    ).readAsStringSync();
    final match =
        RegExp(r'weeklyOverloadIncrement\s*=\s*([\d.]+)').firstMatch(source);
    expect(match, isNotNull,
        reason: 'weeklyOverloadIncrement is gone or renamed — this file '
            'derives its progression rate from it');
    final increment = double.parse(match!.group(1)!);
    expect(kStrongOverload, closeTo(1 + increment, 1e-9),
        reason: 'the generator moved its overload and this file did not');
  });
}
