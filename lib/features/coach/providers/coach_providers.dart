import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../progress/providers/streak_provider.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../domain/coach_brain.dart';
import '../domain/coach_context.dart';
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

/// The brain behind the coach. Swap this override for an `LlmCoachBrain`
/// (same interface) to go live with a real model — nothing else changes.
final coachBrainProvider =
    Provider<CoachBrain>((ref) => const RuleBasedCoachBrain());

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

/// The live conversation. Seeded lazily with the brain's greeting on first
/// read; `send()` appends the user turn + the brain's reply. In-memory for
/// now (a session-scoped chat); the LLM design adds server-side memory.
final coachChatProvider =
    NotifierProvider<CoachChatNotifier, List<CoachTurn>>(CoachChatNotifier.new);

class CoachChatNotifier extends Notifier<List<CoachTurn>> {
  @override
  List<CoachTurn> build() {
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    return [CoachTurn(fromCoach: true, text: brain.greeting(ctx))];
  }

  List<CoachSuggestion> get suggestions {
    final brain = ref.read(coachBrainProvider);
    return brain.suggestions(ref.read(coachContextProvider));
  }

  void send(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    final userTurn = CoachTurn(fromCoach: false, text: text);
    final reply =
        CoachTurn(fromCoach: true, text: brain.respond(ctx, state, text));
    state = [...state, userTurn, reply];
  }
}
