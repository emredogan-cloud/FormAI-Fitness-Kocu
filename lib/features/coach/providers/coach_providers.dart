import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../progress/providers/streak_provider.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/data/session_log_repository.dart';
import '../../workout/domain/workout_mode.dart';
import '../../workout/providers/workout_provider.dart';
import '../domain/coach_brain.dart';
import '../domain/coach_context.dart';
import '../domain/llm_coach_brain.dart';
import '../domain/rule_based_coach_brain.dart';
import '../../../core/utils/app_copy.dart';

/// Long-term coach memory: a rolling summary of what past conversations
/// revealed about the user (preferences, constraints, recurring struggles).
/// Stored locally, sent with every LLM turn as compact "notes", refreshed
/// server-side (the `summarize` mode of coach-chat) every few turns — so the
/// coach remembers ACROSS sessions without ever resending old transcripts.
const String _kCoachMemoryKey = 'sixpack.coach_memory_v1';

final coachMemoryProvider = Provider<CoachMemoryStore>(
  (ref) => CoachMemoryStore(ref.watch(sharedPreferencesProvider)),
);

class CoachMemoryStore {
  CoachMemoryStore(this._prefs);
  final SharedPreferences _prefs;

  String read() => _prefs.getString(_kCoachMemoryKey) ?? '';
  Future<void> write(String summary) async {
    await _prefs.setString(_kCoachMemoryKey, summary.trim());
  }
}

/// Keys are the values stored in SharedPreferences; the labels are copy
/// — they reach the user inside the coach's nutrition reply. Resolved
/// through [AppCopy] because this provider has no widget tree.
String? _goalLabel(String? key) => switch (key) {
      'belly_burn' => AppCopy.strings.goalBellyBurnLower,
      'muscle_gain' => AppCopy.strings.goalMuscleGainLower,
      'fitness_look' => AppCopy.strings.goalFitnessLookLower,
      'strength' => AppCopy.strings.goalStrengthLower,
      'tone' => AppCopy.strings.goalToneLower,
      'bulk' => AppCopy.strings.goalBulkLower,
      'sixpack' => AppCopy.strings.goalSixpackLower,
      _ => null,
    };

String? _activityLabel(String? key) => switch (key) {
      'sedentary' => AppCopy.strings.activityDesk,
      'light' => AppCopy.strings.activityLight,
      'active' => AppCopy.strings.activityVeryActive,
      _ => null,
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
  final memory = ref.watch(coachMemoryProvider);
  return LlmCoachBrain(
    transport: (contextPrompt, recentTurns, message) =>
        _invokeCoachChat(contextPrompt, recentTurns, message, memory.read()),
  );
});

bool get _llmEnabled {
  try {
    if (!dotenv.isInitialized) return false;
    return (dotenv.env['COACH_LLM_ENABLED'] ?? '').toLowerCase() == 'true';
  } catch (_) {
    return false;
  }
}

/// Roadmap Phase 5 (AI work) · the locale sent with every coach request.
///
/// Reads [AppCopy], not the device: the persona must follow the app's
/// language, not the phone's, or a Turkish user on an English handset
/// gets an English coach inside a Turkish app. `AppCopy.locale` is set
/// by `main.dart`'s locale-resolution callback, so it is the app's
/// answer whether it came from an explicit choice or from the device.
///
/// Phase 6 is where this stopped being a constant. The server owns
/// persona selection, so a language added there ships without an app
/// release — which is why the parameter has been on the wire since a
/// phase before anything read it.
String get coachLocale => AppCopy.locale.languageCode;

/// Calls the `coach-chat` Supabase Edge Function (which holds the model key
/// server-side). Returns the reply text, or `null` on any non-2xx / shape
/// mismatch so [LlmCoachBrain] falls back. Errors bubble as exceptions from
/// `functions.invoke`; the brain's try/catch turns them into a fallback too.
/// [memory] is the rolling long-term summary — compact notes, not transcript.
Future<String?> _invokeCoachChat(
  String contextPrompt,
  List<CoachTurn> recentTurns,
  String message,
  String memory,
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
      if (memory.isNotEmpty) 'summary': memory,
      // The server keys its persona and its prompt scaffolding on this.
      'locale': coachLocale,
    },
  );
  final data = res.data;
  if (data is Map && data['reply'] is String) {
    return data['reply'] as String;
  }
  return null;
}

/// One-shot Form line for the ONBOARDING conversation (RC-1 P7). Sends a
/// single instruction to the live coach and returns Form's reply, or `null`
/// when the LLM is disabled, offline, slow (8 s), or fails in any way — the
/// caller keeps its scripted copy as the fallback, so onboarding NEVER
/// stalls on the network (an App-Review-critical property).
Future<String?> onboardingCoachReply(String instruction) async {
  if (!_llmEnabled) return null;
  try {
    final reply = await _invokeCoachChat(
      // Prompt scaffolding, not UI copy — it is never rendered, which is
      // why it carries no ARB key. It is still per-locale: the persona
      // answers in the app's language, and a Turkish instruction inside
      // an English conversation pulls the reply back toward Turkish.
      _onboardingContextPrompt(),
      const [],
      instruction,
      '',
    ).timeout(const Duration(seconds: 8));
    final trimmed = reply?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  } catch (_) {
    return null;
  }
}

/// The context line handed to the coach for the onboarding chat.
///
/// Not an ARB key: nothing here reaches a screen. It is selected by
/// locale rather than translated for it — an instruction written in the
/// language you want back is worth more than an accurate translation.
String _onboardingContextPrompt() {
  switch (coachLocale) {
    case 'en':
      return 'Context: the app\'s introductory onboarding chat. The user ' // i18n-ignore
          'is meeting you for the first time. Reply once, briefly and ' // i18n-ignore
          'warmly.'; // i18n-ignore
    case 'tr':
    default:
      return 'Bağlam: uygulamanın tanışma (onboarding) sohbeti. Kullanıcı seni yeni ' // i18n-ignore
          'tanıyor. Tek mesajlık, kısa ve samimi bir yanıt ver.'; // i18n-ignore
  }
}

/// Asks the server to fold the given turns into an updated rolling summary.
/// Returns null on any failure — memory refresh is strictly best-effort and
/// must never surface an error to the user.
Future<String?> _invokeCoachSummarize(
  List<CoachTurn> turns,
  String priorSummary,
) async {
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'coach-chat',
      body: {
        'mode': 'summarize',
        'turns': turns
            .map((t) => {
                  'role': t.fromCoach ? 'assistant' : 'user',
                  'text': t.text,
                })
            .toList(),
        if (priorSummary.isNotEmpty) 'summary': priorSummary,
        // The summariser is per-locale too, and this one matters more
        // than it looks: its output is stored and fed back as the
        // coach's memory. Summarise an English conversation with the
        // Turkish summariser and every later English reply is grounded
        // in Turkish notes.
        'locale': coachLocale,
      },
    );
    final data = res.data;
    if (data is Map && data['summary'] is String) {
      return data['summary'] as String;
    }
  } catch (_) {
    // Best-effort by design.
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
  List<String> todayNames = const [];
  if (session != null) {
    completed = session.days.where((d) => d.isCompleted).length;
    final active = session.activeDay;
    if (active != null) {
      todayDay = active.dayNumber;
      todayExercises = active.exercises.length;
      todayDone = active.isCompleted;
      todayNames = active.exercises.map((e) => e.name).toList(growable: false);
    }
  }

  // Camera/workout ground truth: the most recent logged session (real reps,
  // real duration, per-exercise) so the coach talks about what the user
  // actually DID, not just the plan.
  String? lastSession;
  final logs = ref.watch(sessionLogsProvider).value;
  if (logs != null && logs.isNotEmpty) {
    final latest = logs.values.reduce(
        (a, b) => a.completedAtIso.compareTo(b.completedAtIso) >= 0 ? a : b);
    final mins = (latest.durationSeconds / 60).round();
    final names = latest.exerciseLogs
        .map((e) => '${e.exerciseName} ${e.actualReps} tekrar') // i18n-ignore
        .take(6)
        .join(', ');
    lastSession =
        'Son kaydedilen antrenman: ${latest.dayNumber}. gün — ' // i18n-ignore
        'toplam ${latest.totalReps} tekrar, $mins dk ($names)'; // i18n-ignore
  }

  final goalKey =
      (metrics['goal'] ?? metrics['targetPhysique'] ?? prefs.goal) as String?;
  final activityKey = metrics['activityLevel'] as String?;

  return CoachContext(
    hour: DateTime.now().hour,
    name: metrics['name'] as String?,
    goalLabel: goalKey == null ? null : (_goalLabel(goalKey) ?? goalKey),
    age: (metrics['age'] as num?)?.toInt(),
    heightCm: (metrics['heightCm'] as num?)?.toInt(),
    weightKg: (metrics['weightKg'] as num?)?.toInt(),
    activityLabel: activityKey == null ? null : _activityLabel(activityKey),
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
    todayExerciseNames: todayNames,
    lastSessionLine: lastSession,
    // Roadmap Phase 3 · "post-calibration, the coach receives a
    // firstCameraSession flag so its next message can reference the
    // moment". Derived rather than stored: setup done + nothing logged
    // yet IS the state, and a separate flag would be one more thing that
    // can disagree with reality.
    firstCameraSession: prefs.cameraTutorialCompleted &&
        prefs.preferredWorkoutMode == WorkoutMode.camera &&
        (logs == null || logs.isEmpty),
    workoutMode: prefs.preferredWorkoutMode.token,
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

  /// Persisted transcript (last [_kMaxSavedTurns]) so the conversation
  /// survives app restarts — a coach that greets you from scratch every
  /// launch doesn't feel like it knows you. Keys off SharedPreferences,
  /// same store as the rolling memory.
  static const String _kTurnsKey = 'sixpack.coach_turns_v1';
  static const int _kMaxSavedTurns = 30;

  @override
  CoachChatState build() {
    ref.onDispose(() => _disposed = true);
    final restored = _restoreTurns();
    if (restored.isNotEmpty) return CoachChatState(turns: restored);
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    return CoachChatState(
      turns: [
        CoachTurn(
            fromCoach: true,
            text: brain.greeting(AppCopy.strings, ctx),
            at: DateTime.now()),
      ],
    );
  }

  List<CoachTurn> _restoreTurns() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_kTurnsKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => CoachTurn(
                fromCoach: m['c'] == true,
                text: (m['t'] ?? '') as String,
                at: m['a'] is String
                    ? DateTime.tryParse(m['a'] as String)
                    : null,
              ))
          .where((t) => t.text.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const []; // corrupt payload → fresh greeting, never a crash
    }
  }

  void _persistTurns() {
    try {
      final turns = state.turns;
      final tail = turns.length > _kMaxSavedTurns
          ? turns.sublist(turns.length - _kMaxSavedTurns)
          : turns;
      final raw = jsonEncode([
        for (final t in tail)
          {'c': t.fromCoach, 't': t.text, 'a': t.at?.toIso8601String()},
      ]);
      ref.read(sharedPreferencesProvider).setString(_kTurnsKey, raw);
    } catch (_) {
      // Persistence is best-effort; the live conversation is unaffected.
    }
  }

  List<CoachSuggestion> get suggestions {
    final brain = ref.read(coachBrainProvider);
    return brain.suggestions(AppCopy.strings, ref.read(coachContextProvider));
  }

  /// User turns since the rolling memory was last refreshed.
  int _turnsSinceMemory = 0;

  Future<void> send(String message) async {
    final text = message.trim();
    if (text.isEmpty || state.sending) return;
    final brain = ref.read(coachBrainProvider);
    final ctx = ref.read(coachContextProvider);
    // Capture the prior history BEFORE appending the user turn — that's what
    // the brain reasons over.
    final history = state.turns;
    state = state.copyWith(
      turns: [
        ...history,
        CoachTurn(fromCoach: false, text: text, at: DateTime.now()),
      ],
      sending: true,
    );
    final reply = await brain.respond(AppCopy.strings, ctx, history, text);
    // The screen may have been popped mid-flight; don't touch disposed state.
    if (_disposed) return;
    state = state.copyWith(
      turns: [
        ...state.turns,
        CoachTurn(fromCoach: true, text: reply, at: DateTime.now()),
      ],
      sending: false,
    );
    _persistTurns();
    _maybeRefreshMemory();
  }

  /// Every few user turns, fold the conversation into the rolling long-term
  /// summary (server-side, cheap) and persist it. Fire-and-forget: failures
  /// are invisible, success means the NEXT conversation starts with memory.
  void _maybeRefreshMemory() {
    if (!_llmEnabled) return;
    _turnsSinceMemory++;
    if (_turnsSinceMemory < 3) return;
    _turnsSinceMemory = 0;
    final store = ref.read(coachMemoryProvider);
    final turns = state.turns;
    _invokeCoachSummarize(turns, store.read()).then((summary) {
      if (summary != null && summary.isNotEmpty) store.write(summary);
    });
  }
}
