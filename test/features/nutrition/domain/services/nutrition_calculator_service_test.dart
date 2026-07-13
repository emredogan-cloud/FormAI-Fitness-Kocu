import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/nutrition/domain/models/macro_target.dart';
import 'package:sixpack_ai/features/nutrition/domain/services/nutrition_calculator_service.dart';

/// Pure-math coverage for the daily macro calculator. Every expected
/// number below is hand-derived from the Mifflin-St Jeor + Atwater
/// pipeline documented in the service, so a regression in any constant
/// (activity multiplier, goal delta, kcal/g divisor, calorie floor)
/// fails a concrete assertion rather than a vague approximation.
void main() {
  const service = NutritionCalculatorService();

  MacroTarget calc({
    int weight = 70,
    int height = 175,
    int age = 30,
    String gender = 'male',
    String activityLevel = 'sedentary',
    String goal = 'tone',
  }) =>
      service.calculateDailyMacros(
        weight: weight,
        height: height,
        age: age,
        gender: gender,
        activityLevel: activityLevel,
        goal: goal,
      );

  group('exact anchor values lock the formula', () {
    test('male · cut · sedentary → BMR 1780, 1636 kcal, 164/123/55 g', () {
      // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780
      // TDEE = 1780 * 1.2 = 2136 ; cut delta -500 → 1636 kcal
      // P = 1636*.40/4=163.6→164 · C = 1636*.30/4=122.7→123
      // F = 1636*.30/9=54.53→55
      expect(
        calc(
          weight: 80,
          height: 180,
          age: 30,
          gender: 'male',
          activityLevel: 'sedentary',
          goal: 'cut',
        ),
        const MacroTarget(calories: 1636, protein: 164, carbs: 123, fat: 55),
      );
    });

    test('calorie floor clamps an extreme deficit to 1200 kcal', () {
      // BMR = 10*40 + 6.25*140 - 5*80 - 161 = 714
      // TDEE = 856.8 ; cut -500 = 356.8 → floored to 1200
      // P = 1200*.40/4=120 · C = 1200*.30/4=90 · F = 1200*.30/9=40
      expect(
        calc(
          weight: 40,
          height: 140,
          age: 80,
          gender: 'female',
          activityLevel: 'sedentary',
          goal: 'cut',
        ),
        const MacroTarget(calories: 1200, protein: 120, carbs: 90, fat: 40),
      );
    });
  });

  group('monotonic relationships', () {
    test('calories rise with activity level (same body)', () {
      final sedentary = calc(activityLevel: 'sedentary').calories;
      final light = calc(activityLevel: 'light').calories;
      final active = calc(activityLevel: 'active').calories;
      final veryActive = calc(activityLevel: 'very_active').calories;
      expect(sedentary, lessThan(light));
      expect(light, lessThan(active));
      expect(active, lessThan(veryActive));
    });

    test('calories rise from cut → tone → bulk (same body)', () {
      final cut = calc(goal: 'cut').calories;
      final tone = calc(goal: 'tone').calories;
      final bulk = calc(goal: 'bulk').calories;
      expect(cut, lessThan(tone));
      expect(tone, lessThan(bulk));
    });

    test('male BMR > other > female for identical body metrics', () {
      // -200 tone delta, sedentary, no floor in play → ordering survives.
      final male = calc(gender: 'male').calories;
      final other = calc(gender: 'nonbinary').calories;
      final female = calc(gender: 'female').calories;
      expect(male, greaterThan(other));
      expect(other, greaterThan(female));
    });
  });

  group('gender aliases resolve to the same correction', () {
    test('male == m == erkek (case/space-insensitive)', () {
      final canonical = calc(gender: 'male');
      expect(calc(gender: 'm'), canonical);
      expect(calc(gender: 'erkek'), canonical);
      expect(calc(gender: '  MALE  '), canonical);
    });

    test('female == f == kadın == kadin', () {
      final canonical = calc(gender: 'female');
      expect(calc(gender: 'f'), canonical);
      expect(calc(gender: 'kadın'), canonical);
      expect(calc(gender: 'kadin'), canonical);
    });
  });

  group('activity aliases resolve to the same multiplier', () {
    test('light == hafif == lightly_active', () {
      final canonical = calc(activityLevel: 'light');
      expect(calc(activityLevel: 'hafif'), canonical);
      expect(calc(activityLevel: 'lightly_active'), canonical);
    });

    test('active == moderate == aktif == moderately_active', () {
      final canonical = calc(activityLevel: 'active');
      expect(calc(activityLevel: 'moderate'), canonical);
      expect(calc(activityLevel: 'aktif'), canonical);
      expect(calc(activityLevel: 'moderately_active'), canonical);
    });

    test('very_active == athlete', () {
      expect(
          calc(activityLevel: 'athlete'), calc(activityLevel: 'very_active'));
    });

    test('unknown activity falls back to sedentary (most conservative)', () {
      expect(calc(activityLevel: 'zzz'), calc(activityLevel: 'sedentary'));
    });
  });

  group('goal aliases resolve to the same profile', () {
    test('cut == six_pack == sixpack == lose == lose_weight', () {
      final canonical = calc(goal: 'cut');
      expect(calc(goal: 'six_pack'), canonical);
      expect(calc(goal: 'sixpack'), canonical);
      expect(calc(goal: 'lose'), canonical);
      expect(calc(goal: 'lose_weight'), canonical);
    });

    test('bulk == hacim == hypertrophy == gain == gain_muscle', () {
      final canonical = calc(goal: 'bulk');
      expect(calc(goal: 'hacim'), canonical);
      expect(calc(goal: 'hypertrophy'), canonical);
      expect(calc(goal: 'gain'), canonical);
      expect(calc(goal: 'gain_muscle'), canonical);
    });

    test('unknown goal falls back to the tone profile', () {
      expect(calc(goal: 'zzz'), calc(goal: 'tone'));
    });
  });

  test('macro grams reconstruct the calorie target within rounding', () {
    // 4 kcal/g protein+carbs, 9 kcal/g fat. Per-gram rounding can drift
    // a few kcal each way, so allow a small tolerance.
    final t = calc(
      weight: 75,
      height: 178,
      age: 28,
      gender: 'male',
      activityLevel: 'active',
      goal: 'bulk',
    );
    final reconstructed = (t.protein * 4) + (t.carbs * 4) + (t.fat * 9);
    expect((reconstructed - t.calories).abs(), lessThanOrEqualTo(15));
  });
}
