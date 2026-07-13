import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/coach/domain/coach_brain.dart';
import 'package:sixpack_ai/features/coach/domain/coach_context.dart';
import 'package:sixpack_ai/features/coach/domain/llm_coach_brain.dart';

/// The LLM brain must ALWAYS produce a real answer: use the model when it
/// works, and degrade to the honest rule brain on any failure. These pin that
/// contract so the coach can never go blank or hang forever.
void main() {
  CoachContext ctx() => const CoachContext(
        hour: 10,
        name: 'Deniz',
        goalLabel: 'Daha fit görünmek',
        heightCm: 175,
        weightKg: 72,
        streakDays: 3,
        completedDays: 4,
        totalDays: 30,
        todayDayNumber: 5,
        todayExerciseCount: 6,
        todayIsCompleted: false,
      );

  test('uses the model reply when the transport succeeds', () async {
    final brain = LlmCoachBrain(
      transport: (_, __, ___) async => '  Harika gidiyorsun Deniz! ',
    );
    final r = await brain.respond(ctx(), const [], 'selam');
    expect(r, 'Harika gidiyorsun Deniz!'); // trimmed
  });

  test('falls back to the rule brain when the transport throws', () async {
    final brain = LlmCoachBrain(
      transport: (_, __, ___) async => throw Exception('offline'),
    );
    final r = await brain.respond(ctx(), const [], 'nasıl gidiyorum?');
    // Rule brain's progress answer carries real numbers.
    expect(r, contains('4/30'));
  });

  test('falls back when the transport returns null or empty', () async {
    final nullBrain = LlmCoachBrain(transport: (_, __, ___) async => null);
    final emptyBrain = LlmCoachBrain(transport: (_, __, ___) async => '   ');
    expect(await nullBrain.respond(ctx(), const [], 'beslenme'),
        contains('tıbbi tavsiye değildir'));
    expect(await emptyBrain.respond(ctx(), const [], 'beslenme'),
        contains('tıbbi tavsiye değildir'));
  });

  test('falls back when the transport times out', () async {
    final brain = LlmCoachBrain(
      timeout: const Duration(milliseconds: 30),
      transport: (_, __, ___) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return 'too late';
      },
    );
    final r = await brain.respond(ctx(), const [], 'dizimde ağrı var');
    // The rule brain's injury guardrail wins.
    expect(r.toLowerCase(), contains('uzman'));
  });

  test('only the most recent turns are sent to the model (compression)',
      () async {
    late int sentCount;
    final brain = LlmCoachBrain(
      maxTurnsSent: 4,
      transport: (_, turns, __) async {
        sentCount = turns.length;
        return 'ok';
      },
    );
    final history = List.generate(
      10,
      (i) => CoachTurn(fromCoach: i.isEven, text: 'turn $i'),
    );
    await brain.respond(ctx(), history, 'yeni mesaj');
    expect(sentCount, 4); // capped, not 10
  });

  test('greeting + suggestions stay local (no transport call)', () async {
    var called = false;
    final brain = LlmCoachBrain(
      transport: (_, __, ___) async {
        called = true;
        return 'x';
      },
    );
    final g = brain.greeting(ctx());
    expect(g, contains('Deniz'));
    expect(brain.suggestions(ctx()), isNotEmpty);
    expect(called, isFalse);
  });
}
