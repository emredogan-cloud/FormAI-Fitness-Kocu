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

    test('the STORED vocabulary is read, not just these three names', () {
      // `userMetrics['activityLevel']` holds `ActivityLevel.name` —
      // sedentary / light / active — and never the tier names. The
      // first draft of `fromToken` matched only its own three, which
      // reported every `active` user as a beginner, and the first draft
      // of this test agreed with it because it was written from the
      // same assumption.
      expect(DifficultyTier.fromToken('active'), DifficultyTier.advanced);
      expect(DifficultyTier.fromToken('light'), DifficultyTier.intermediate);
      expect(DifficultyTier.fromToken('sedentary'), DifficultyTier.beginner);
      // The Turkish spellings the app has written at various points.
      expect(DifficultyTier.fromToken('İleri'), DifficultyTier.advanced);
      expect(DifficultyTier.fromToken('Orta'), DifficultyTier.intermediate);
    });

    test('an unreadable stored level is a beginner, never an advanced', () {
      // Down is the safe direction: a beginner given an advanced
      // program is hurt, an advanced user given a beginner one is bored.
      expect(DifficultyTier.fromToken(null), DifficultyTier.beginner);
      expect(DifficultyTier.fromToken(''), DifficultyTier.beginner);
      expect(DifficultyTier.fromToken('hyperborean'), DifficultyTier.beginner);
      expect(DifficultyTier.fromToken('advanced'), DifficultyTier.advanced);
    });

    test('every token the generator accepts is a token this reads', () {
      // The two vocabularies must not drift: the generator decides what
      // plan gets built and this decides what tier the app believes the
      // user is on. Same shape as the overload-constant test below.
      final source = File(
        'lib/features/workout/domain/services/workout_generator_service.dart',
      ).readAsStringSync();
      final level =
          RegExp(r'_Level _normaliseLevel[\s\S]*?\n  \}').firstMatch(source);
      expect(level, isNotNull,
          reason: '_normaliseLevel is gone or renamed — this test derives '
              'the accepted vocabulary from it');
      final tokens = RegExp(r"v == '([^']+)'")
          .allMatches(level!.group(0)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(tokens, isNotEmpty);
      for (final token in tokens) {
        final mine = DifficultyTier.fromToken(token);
        // `beginner` is the fallback, so it proves nothing on its own —
        // assert the two NON-default buckets agree, which is where a
        // silent disagreement would actually cost something.
        if (token == 'advanced' || token == 'active' || token == 'ileri') {
          expect(mine, DifficultyTier.advanced, reason: token);
        } else if (token == 'intermediate' ||
            token == 'light' ||
            token == 'orta') {
          expect(mine, DifficultyTier.intermediate, reason: token);
        } else {
          expect(mine, DifficultyTier.beginner, reason: token);
        }
      }
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

  group('what a REPEAT carries, whatever was recommended', () {
    test('a strong finisher who declines the tier still earns the step', () {
      // The defect a widget test found. `recommend()` returns 1.0 for a
      // tier advance ON PURPOSE — the tier is the increase — and reading
      // that number for the repeat card handed a 28/30 finisher the
      // identical program back under a card promising more volume.
      final strong = outcome(28);
      expect(recommend(strong).path, ContinuationPath.advanceTier);
      expect(recommend(strong).overload, 1.0);
      expect(repeatOverloadFor(strong), kStrongOverload);
    });

    test('the two agree everywhere the recommendation is not a tier', () {
      for (final tier in DifficultyTier.values) {
        for (var days = 0; days <= 30; days++) {
          final o = outcome(days, tier: tier);
          final r = recommend(o);
          if (r.path == ContinuationPath.advanceTier) continue;
          expect(repeatOverloadFor(o), closeTo(r.overload, 1e-9),
              reason: '$days days at ${tier.name}');
        }
      }
    });

    test('somebody who struggled is still offered no extra volume', () {
      expect(repeatOverloadFor(outcome(11)), 1.0);
      expect(repeatOverloadFor(outcome(0)), 1.0);
    });
  });

  group('carrying volume between programs', () {
    test('a step is added, never multiplied', () {
      // Multiplying is what `weeklyOverloadIncrement`'s header was
      // written about. 1.08 twice is 1.16 here, not 1.1664.
      expect(nextCycleOverload(1.0, kStrongOverload),
          closeTo(kStrongOverload, 1e-9));
      expect(nextCycleOverload(kStrongOverload, kStrongOverload),
          closeTo(1.16, 1e-9));
    });

    test('it cannot climb past the ceiling', () {
      var carried = 1.0;
      for (var cycle = 0; cycle < 40; cycle++) {
        carried = nextCycleOverload(carried, kStrongOverload);
      }
      expect(carried, kMaxCycleOverload);
    });

    test('a no-overload step leaves it exactly where it was', () {
      // What somebody who half-finished gets. Repeating a program you
      // struggled with must not quietly raise the volume.
      expect(nextCycleOverload(1.08, 1.0), closeTo(1.08, 1e-9));
      expect(nextCycleOverload(1.0, 1.0), 1.0);
    });

    test('a corrupt stored value is read as no overload', () {
      // The pref is a double somebody could have written anything into.
      expect(nextCycleOverload(0.2, kModestOverload),
          closeTo(kModestOverload, 1e-9));
      expect(nextCycleOverload(-5, 1.0), 1.0);
    });

    test('the ceiling is below what one program already ramps to', () {
      // `weeklyOverloadIncrement` reaches +32% inside a single program
      // and its header calls that the defensible limit. The BETWEEN-
      // program carry has to be smaller than that, or two mechanisms
      // that were each argued separately combine into one nobody did.
      expect(kMaxCycleOverload - 1.0, lessThan(0.32));
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
