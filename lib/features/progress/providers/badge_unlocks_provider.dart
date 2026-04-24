import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

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

const int _kKcalPerCompletedDay = 250;

/// Catalogue of every badge the app awards. Keep IDs short and stable;
/// the celebration dialog uses [label] + [subtitle] for the user-facing
/// copy so this list can grow without a localisation rotation.
const List<BadgeDefinition> kBadgeCatalog = [
  BadgeDefinition(
    id: 'first_step',
    label: 'İlk Adım',
    subtitle: 'İlk gününü tamamladın!',
    emoji: '🎯',
  ),
  BadgeDefinition(
    id: 'disciplined',
    label: 'Disiplinli',
    subtitle: '3 günlük seri yakaladın!',
    emoji: '🛡️',
  ),
  BadgeDefinition(
    id: 'first_week',
    label: 'İlk Hafta',
    subtitle: '7 günü tamamladın!',
    emoji: '📅',
  ),
  BadgeDefinition(
    id: 'steady',
    label: 'Sabit',
    subtitle: '7 günlük seriyi yakaladın!',
    emoji: '🔥',
  ),
  BadgeDefinition(
    id: 'halfway',
    label: 'Yarıyol',
    subtitle: '14 gün — yarıya geldin!',
    emoji: '⛰️',
  ),
  BadgeDefinition(
    id: 'calorie_hunter',
    label: 'Kalori Avcısı',
    subtitle: 'Haftada 1500 kcal yaktın!',
    emoji: '⚡',
  ),
  BadgeDefinition(
    id: 'hiit_master',
    label: 'HIIT Ustası',
    subtitle: '5 kardiyo gününü tamamladın!',
    emoji: '⚡',
  ),
  BadgeDefinition(
    id: 'core_master',
    label: 'Core Master',
    subtitle: '5 karın odaklı günü bitirdin!',
    emoji: '🎯',
  ),
  BadgeDefinition(
    id: 'strength_stone',
    label: 'Güç Taşı',
    subtitle: '5 güç gününü tamamladın!',
    emoji: '🏋️',
  ),
  BadgeDefinition(
    id: 'nutrition_hero',
    label: 'Beslenme Kahramanı',
    subtitle: '7 günlük beslenme serisi!',
    emoji: '🥗',
  ),
  BadgeDefinition(
    id: 'thirty_day_champion',
    label: '30 Gün Şampiyonu',
    subtitle: 'Tüm 30 günlük programı bitirdin!',
    emoji: '🏆',
  ),
  BadgeDefinition(
    id: 'form_legend',
    label: 'Formun Efsanesi',
    subtitle: '30 gün antrenman + 30 gün beslenme!',
    emoji: '👑',
  ),
];

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.emoji,
  });

  final String id;
  final String label;
  final String subtitle;
  final String emoji;
}

BadgeDefinition? badgeById(String id) {
  for (final b in kBadgeCatalog) {
    if (b.id == id) return b;
  }
  return null;
}

/// Resolves the user's current unlock set from the live workout session
/// + nutrition-streak signals. Pure derivation — no side effects, no
/// caching here (the underlying providers handle that).
final unlockedBadgesProvider = Provider<Set<String>>((ref) {
  final session = ref.watch(workoutSessionProvider).value;
  final days = session?.days ?? const <WorkoutDay>[];
  final completedCount = days.where((d) => d.isCompleted).length;
  final streak = _streakOf(days);
  final weeklyKcal = completedCount * _kKcalPerCompletedDay;
  final cardioDaysCompleted = _cardioDaysCompleted(days);
  final coreDaysCompleted = _daysCompletedByMuscle(days, 'core');
  final strengthDaysCompleted = _daysCompletedByStrength(days);
  final nutritionStreak = ref.watch(appPreferencesProvider).nutritionStreak;

  final unlocked = <String>{};
  if (completedCount >= 1) unlocked.add('first_step');
  if (streak >= 3) unlocked.add('disciplined');
  if (completedCount >= 7) unlocked.add('first_week');
  if (streak >= 7) unlocked.add('steady');
  if (completedCount >= 14) unlocked.add('halfway');
  if (weeklyKcal >= 1500) unlocked.add('calorie_hunter');
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

int _streakOf(List<WorkoutDay> days) {
  var streak = 0;
  for (final day in days) {
    if (day.isCompleted) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

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
