import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../progress/providers/streak_provider.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../domain/coach_brain.dart';
import '../domain/coach_context.dart';
import '../domain/llm_coach_brain.dart';
import '../domain/rule_based_coach_brain.dart';

const Map<String, String> _goalLabels = {
  'belly_burn': 'Göbek eritmek',
  'muscle_gain': 'Kas yapmak',
  'fitness_look': 'Daha fit görünmek',
  'strength': 'Güçlenmek',
  'tone': 'Sıkılaşmak',
  'bulk': 'Hacim kazanmak',
  'sixpack': 'Six-pack',
};
const Map<String, String> _activityLabels = {
  'sedentary': 'Masa başı',
  'light': 'Hafif hareketli',
  'active': 'Çok aktif',
};

/// The brain behind the coach. When `COACH_LLM_ENABLED=true` in the `.env`
/// (set it once the `coach-chat` Edge Function is deployed with an
/// `ANTHROPIC_API_KEY` secret — see FOUNDER_MASTER_GUIDE_APPENDIX), this
/// returns the real [LlmCoachBrain]; otherwise it returns the honest offline
/// [RuleBasedCoachBrain]. The LLM brain ALSO falls back to the rule brain on
/// any network/model failure, so the flag only decides whether we attempt the
/// model at all — the coach is never blank either way.
final coachBrainProvider = Provider<CoachBrain>((ref) {
  const rule = RuleBasedCoachBrain();
  if (!_llmEnabled) return rule;
  return const LlmCoachBrain(transport: _supabaseCoachTransport);
});

bool get _llmEnabled {
  try {
    if (!dotenv.isInitialized) return false;
    return (dotenv.env['COACH_LLM_ENABLED'] ?? '').toLowerCase() == 'true';
  } catch (_) {
    return false;
  }
}

/// Calls the `coach-chat` Supabase Edge Function (which holds the model key
/// server-side). Returns the reply text, or `null` on any non-2xx / shape
/// mismatch so [LlmCoachBrain] falls back. Errors bubble as exceptions from
/// `functions.invoke`; the brain's try/catch turns them into a fallback too.
Future<String?> _supabaseCoachTransport(
  String contextPrompt,
  List<CoachTurn> recentTurns,
  String message,
) async {
  final res = await Supabase.instance.client.functions.invoke(
    'coach-chat',
    body: {
      'context': contextPrompt,
      'turns': recentTurns
          .map((t) => {
                'role': t.fromCoach ? 'assistant' : 'user',
                'text': t.text,
              })
          .toList(),
      'message': message,
    },
  );
  final data = res.data;
  if (data is Map && data['reply'] is String) {
    return data['reply'] as String;
  }
  return null;
}

/// Aggregates everything the coach knows from the existing app state. Reads
/// defensively (all fields nullable) so a partially-onboarded or offline
/// user still gets a coherent coach.
final coachContextProvider = Provider<CoachContext>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final metrics = prefs.userMetrics ?? const {};
  final session = ref.watch(workoutSessionProvider).value;

  int completed = 0;
  int? todayDay;
  int todayExercises = 0;
  bool todayDone = false;
  if (session != null) {
    completed = session.days.where((d) => d.isCompleted).length;
    final active = session.activeDay;
    if (active != null) {
      todayDay = active.dayNumber;
      todayExercises = active.exercises.length;
      todayDone = active.isCompleted;
    }
  }

  final goalKey =
      (metrics['goal'] ?? metrics['targetPhysique'] ?? prefs.goal) as String?;
  final activityKey = metrics['activityLevel'] as String?;

  return CoachContext(
    hour: DateTime.now().hour,
    name: metrics['name'] as String?,
    goalLabel: goalKey == null ? null : (_goalLabels[goalKey] ?? goalKey),
    age: (metrics['age'] as num?)?.toInt(),
    heightCm: (metrics['heightCm'] as num?)?.toInt(),
    weightKg: (metrics['weightKg'] as num?)?.toInt(),
    activityLabel: activityKey == null ? null : _activityLabels[activityKey],
    hasEquipment: prefs.hasEquipment,
    streakDays: ref.watch(currentStreakProvider),
    level: ref.watch(currentLevelProvider),
    xp: ref.watch(lifetimeXpProvider),
    badgeCount: ref.watch(unlockedBadgesProvider).length,
    completedDays: completed,
    totalDays: session?.days.length ?? 30,
    todayDayNumber: todayDay,
    todayExerciseCount: todayExercises,
    todayIsCompleted: todayDone,
  );
});

/// The live conversation + a `sending` flag so the UI can show a typing
/// indicator while the brain thinks. Seeded lazily with the brain's greeting
/// (instant, local). `send()` appends the user turn, awaits the reply, then
/// appends it — the LLM round-trip is fully async.
final coachChatProvider =
    NotifierProvider<CoachChatNotifier, CoachChatState>(CoachChatNotifier.new);

class CoachChatState {
  const CoachChatState({required this.turns, this.sending = false});
  final List<CoachTurn> turns;
  final bool sending;

  CoachChatState copyWith({List<CoachTurn>? turns, bool? sending}) =>
      CoachChatState(
        turns: turns ?? this.turns,
        sending: sending ?? this.sending,
      );
}

class CoachChatNotifier extends Notifier<CoachChatState> {
  bool _disposed = false;

  @override
  CoachChatState build() {
    ref.onDispose(() => _disposed = true);
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    return CoachChatState(
      turns: [CoachTurn(fromCoach: true, text: brain.greeting(ctx))],
    );
  }

  List<CoachSuggestion> get suggestions {
    final brain = ref.read(coachBrainProvider);
    return brain.suggestions(ref.read(coachContextProvider));
  }

  Future<void> send(String message) async {
    final text = message.trim();
    if (text.isEmpty || state.sending) return;
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    // Capture the prior history BEFORE appending the user turn — that's what
    // the brain reasons over.
    final history = state.turns;
    state = state.copyWith(
      turns: [...history, CoachTurn(fromCoach: false, text: text)],
      sending: true,
    );
    final reply = await brain.respond(ctx, history, text);
    // The screen may have been popped mid-flight; don't touch disposed state.
    if (_disposed) return;
    state = state.copyWith(
      turns: [...state.turns, CoachTurn(fromCoach: true, text: reply)],
      sending: false,
    );
  }
}
