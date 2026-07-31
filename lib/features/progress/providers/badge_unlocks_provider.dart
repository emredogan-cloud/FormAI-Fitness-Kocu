import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_preferences.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';
import 'streak_provider.dart';

/// Phase 48 · single source of truth for which badges the user has
/// unlocked right now.
///
/// The badge tile UI in `gelisim_tab.dart` and `badges_screen.dart`
/// each compute their own unlock predicates inline from the same
/// underlying signals (workout completion count, streak, weekly
/// kilocalories, nutrition streak). This provider extracts those
/// predicates so a `ref.listen` can fire a celebration the moment a
/// new badge crosses its threshold — without the listener having to
/// re-implement the rules itself.
///
/// Returned as an immutable `Set<String>` of stable badge IDs (NOT
/// Turkish labels — those would shift if we ever localise). Subscribers
/// diff `previous` vs `next` to detect first-time unlocks.

/// Catalogue of every badge the app awards. Keep IDs short and stable —
/// they are persisted and keyed on by the XP calculator.
///
/// Roadmap Phase 5 · this list holds no copy. The name and the
/// celebration line come from `presentation/badge_copy.dart`; the
/// gallery's goal text lives in ARB alongside them.
const List<BadgeDefinition> kBadgeCatalog = [
  BadgeDefinition(
    id: 'first_step',
    emoji: '🎯',
  ),
  BadgeDefinition(
    id: 'disciplined',
    emoji: '🛡️',
  ),
  BadgeDefinition(
    id: 'first_week',
    emoji: '📅',
  ),
  BadgeDefinition(
    id: 'steady',
    emoji: '🔥',
  ),
  BadgeDefinition(
    id: 'halfway',
    emoji: '⛰️',
  ),
  // Roadmap Phase 1 (R2.3) · awarded for participating in feedback.
  // Attached to submitting feedback, never to leaving a rating or a
  // review — see [FeedbackRewardService] for the policy rationale.
  BadgeDefinition(
    id: 'voice_heard',
    emoji: '💬',
  ),
  BadgeDefinition(
    id: 'calorie_hunter',
    emoji: '⚡',
  ),
  BadgeDefinition(
    id: 'hiit_master',
    emoji: '⚡',
  ),
  BadgeDefinition(
    id: 'core_master',
    emoji: '🎯',
  ),
  BadgeDefinition(
    id: 'strength_stone',
    emoji: '🏋️',
  ),
  BadgeDefinition(
    id: 'nutrition_hero',
    emoji: '🥗',
  ),
  BadgeDefinition(
    id: 'thirty_day_champion',
    emoji: '🏆',
  ),
  BadgeDefinition(
    id: 'form_legend',
    emoji: '👑',
  ),
];

class BadgeDefinition {
  const BadgeDefinition({required this.id, required this.emoji});

  /// Stable, persisted identifier. Written to storage, read back by
  /// `unlockedBadgesProvider`, and keyed on by `xpForBadge` — never
  /// change one of these for an existing badge.
  final String id;

  final String emoji;
}

BadgeDefinition? badgeById(String id) {
  for (final b in kBadgeCatalog) {
    if (b.id == id) return b;
  }
  return null;
}

/// Phase 48.1 · global `RouteObserver` shared between the GoRouter
/// navigator (registered as an `observer` on the GoRouter instance)
/// and `DashboardScreen` (subscribed via `RouteAware` to receive
/// `didPopNext` when the user returns from a pushed route like the
/// workout camera). Held as a `Provider` so tests can override it
/// with a no-op. Generic argument is `PageRoute` because GoRoute's
/// MaterialPageRoute is a PageRoute, and only PageRoutes participate
/// in this observer.
final routeObserverProvider = Provider<RouteObserver<PageRoute<dynamic>>>(
  (ref) => RouteObserver<PageRoute<dynamic>>(),
);

/// Phase 48.1 · the set of badge IDs we have already shown a
/// celebration dialog for. Initialised to `null`; the dashboard seeds
/// it with the *current* unlocked set on first build so the app
/// doesn't replay yesterday's celebrations on every cold start.
/// Persisted in-memory only — a full app restart re-seeds, which is
/// acceptable since the user already saw the dialog the first time.
final celebratedBadgesProvider =
    NotifierProvider<CelebratedBadgesNotifier, Set<String>?>(
  CelebratedBadgesNotifier.new,
);

class CelebratedBadgesNotifier extends Notifier<Set<String>?> {
  @override
  Set<String>? build() => null;

  void setAll(Set<String> ids) {
    state = Set<String>.from(ids);
  }

  void add(String id) {
    final current = state ?? const <String>{};
    state = {...current, id};
  }
}

/// Resolves the user's current unlock set from the live workout session
/// + nutrition-streak signals. Pure derivation — no side effects, no
/// caching here (the underlying providers handle that).
final unlockedBadgesProvider = Provider<Set<String>>((ref) {
  final session = ref.watch(workoutSessionProvider).value;
  final days = session?.days ?? const <WorkoutDay>[];
  final completedCount = days.where((d) => d.isCompleted).length;
  // Real calendar-day streak — 'disciplined' (≥3) and especially
  // 'steady' (≥7) were unreachable under the old leading-program-run
  // count, which the every-4th-day rest slot capped at 3.
  final streak = ref.watch(currentStreakProvider);
  // Unified "Kalori Avcısı" definition: LIFETIME completions ×
  // kcalPerCompletedDay (same predicate as badges_screen + gelisim).
  final totalKcal = completedCount * AppConstants.kcalPerCompletedDay;
  final cardioDaysCompleted = _cardioDaysCompleted(days);
  final coreDaysCompleted = _daysCompletedByMuscle(days, 'core');
  final strengthDaysCompleted = _daysCompletedByStrength(days);
  final prefs = ref.watch(appPreferencesProvider);
  final nutritionStreak = prefs.nutritionStreak;
  // Roadmap Phase 1 · prefs-backed signal, same shape as
  // `nutritionStreak` above. One submitted message is enough — the
  // badge recognises participation, not volume.
  final feedbackCount = prefs.feedbackSubmittedCount;

  final unlocked = <String>{};
  if (completedCount >= 1) unlocked.add('first_step');
  if (feedbackCount >= 1) unlocked.add('voice_heard');
  if (streak >= 3) unlocked.add('disciplined');
  if (completedCount >= 7) unlocked.add('first_week');
  if (streak >= 7) unlocked.add('steady');
  if (completedCount >= 14) unlocked.add('halfway');
  if (totalKcal >= 1500) unlocked.add('calorie_hunter');
  if (cardioDaysCompleted >= 5) unlocked.add('hiit_master');
  if (coreDaysCompleted >= 5) unlocked.add('core_master');
  if (strengthDaysCompleted >= 5) unlocked.add('strength_stone');
  if (nutritionStreak >= 7) unlocked.add('nutrition_hero');
  if (completedCount >= 30) unlocked.add('thirty_day_champion');
  if (completedCount >= 30 && nutritionStreak >= 30) {
    unlocked.add('form_legend');
  }
  return unlocked;
});

int _cardioDaysCompleted(List<WorkoutDay> days) {
  return days.where((d) {
    if (!d.isCompleted) return false;
    if (d.exercises.isEmpty) return false;
    final cardioHits = d.exercises.where((e) => e.isCardio).length;
    return cardioHits >= (d.exercises.length / 2).ceil();
  }).length;
}

int _daysCompletedByMuscle(List<WorkoutDay> days, String muscle) {
  return days.where((d) {
    if (!d.isCompleted) return false;
    if (d.exercises.isEmpty) return false;
    return d.exercises.any((e) => e.targetMuscle == muscle);
  }).length;
}

int _daysCompletedByStrength(List<WorkoutDay> days) {
  return days.where((d) {
    if (!d.isCompleted) return false;
    if (d.exercises.isEmpty) return false;
    return d.exercises.any((e) =>
        e.targetMuscle == 'upper_body' || e.targetMuscle == 'lower_body');
  }).length;
}
