import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/coach/domain/coach_context.dart';
import 'package:sixpack_ai/features/coach/domain/rule_based_coach_brain.dart';

/// The coach must be genuinely context-aware (not a fixed script) AND honest
/// (no fabricated free-form intelligence). These pin both properties so the
/// contract a future LLM brain must preserve is explicit.
void main() {
  const brain = RuleBasedCoachBrain();

  CoachContext ctx({
    String? name = 'Deniz',
    int hour = 10,
    int streak = 0,
    int completed = 0,
    int total = 30,
    int? today = 1,
    int todayEx = 5,
    bool todayDone = false,
    String? goal = 'Daha fit görünmek',
    int? height = 175,
    int? weight = 72,
  }) =>
      CoachContext(
        hour: hour,
        name: name,
        goalLabel: goal,
        heightCm: height,
        weightKg: weight,
        streakDays: streak,
        completedDays: completed,
        totalDays: total,
        todayDayNumber: today,
        todayExerciseCount: todayEx,
        todayIsCompleted: todayDone,
      );

  test('greeting is contextual — name + today status + time of day', () {
    final g = brain.greeting(ctx(hour: 8));
    expect(g, contains('Deniz'));
    expect(g, contains('Günaydın'));
    expect(g, contains('1. gün'));
  });

  test('greeting reflects a completed day', () {
    final g = brain.greeting(ctx(todayDone: true));
    expect(g.toLowerCase(), contains('bitirdin'));
  });

  test('"today" intent describes the real day + exercise count', () async {
    final r = await brain.respond(
        ctx(today: 3, todayEx: 7), [], 'bugün ne yapmalıyım?');
    expect(r, contains('3. gün'));
    expect(r, contains('7 egzersiz'));
  });

  test('"progress" intent reports real numbers', () async {
    final r = await brain.respond(
        ctx(completed: 6, total: 30, streak: 4), [], 'nasıl gidiyorum?');
    expect(r, contains('6/30'));
    expect(r, contains('4 günlük'));
  });

  test('"nutrition" intent uses BMI + goal', () async {
    final r = await brain.respond(ctx(height: 180, weight: 81), [], 'beslenme');
    expect(r, contains('BMI'));
    expect(r, contains('Daha fit görünmek'));
    expect(r.toLowerCase(), contains('tıbbi tavsiye değildir'));
  });

  test('injury intent defers to a professional + disclaimer', () async {
    final r = await brain.respond(ctx(), [], 'dizimde ağrı var');
    expect(r.toLowerCase(), contains('uzman'));
    expect(r.toLowerCase(), contains('tıbbi tavsiye'));
  });

  test('unmatched input is HONEST — lists real capabilities, no faked reply',
      () async {
    final r = await brain.respond(ctx(), [], 'bana bir fıkra anlat');
    expect(r, contains('antrenman'));
    expect(r, contains('beslenme'));
    // must not pretend to answer the off-topic request
    expect(r.toLowerCase(), isNot(contains('fıkra')));
  });

  test('toPromptContext (LLM seam) carries the real state', () {
    final p = ctx(name: 'Ada', goal: 'Güçlenmek', streak: 5).toPromptContext();
    expect(p, contains('Ada'));
    expect(p, contains('Güçlenmek'));
    expect(p, contains('Seri: 5 gün'));
    expect(p, contains('BMI'));
  });

  test('toPromptContext carries today\'s exercises + last logged session', () {
    const c = CoachContext(
      hour: 10,
      todayDayNumber: 5,
      todayExerciseCount: 2,
      todayExerciseNames: ['Şınav', 'Squat'],
      lastSessionLine:
          'Son kaydedilen antrenman: 4. gün — toplam 84 tekrar, 12 dk',
    );
    final p = c.toPromptContext();
    expect(p, contains('Şınav, Squat'));
    expect(p, contains('84 tekrar'));
  });
}
