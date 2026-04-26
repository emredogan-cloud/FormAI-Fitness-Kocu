import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/nutrition/providers/nutrition_provider.dart';
import '../../features/workout/providers/workout_provider.dart';
import '../utils/app_logger.dart';
import 'app_preferences.dart';
import 'notification_service.dart';

/// Phase 58 · re-schedules the daily reminder whenever the user's
/// progress changes, so the next-fire body reflects today's state.
///
/// Why a Riverpod listener and not an in-process callback at fire
/// time: `flutter_local_notifications` on its own can't execute Dart
/// at the moment a notification surfaces — it just hands the OS a
/// pre-baked title + body. The pragmatic alternative is "pre-bake
/// the right body whenever state changes", which is what this
/// listener does. Result: in normal use (user opens the app at
/// least once between scheduling and fire time), the notification
/// body matches the user's most-recent state. Edge case: a user who
/// completes a workout and immediately closes the app without ever
/// re-opening sees the previous body — acceptable trade-off given we
/// avoided shipping a new background-isolate dependency.
///
/// Watches three signals:
///   1. `lastWorkoutAt` (via `appPreferencesProvider`) — flips the
///      "isWorkoutDoneToday" branch.
///   2. `consumedMacrosProvider.calories` — flips the "nutrition
///      logged" branch.
///   3. `dailyReminderEnabled` — pause/resume the schedule entirely.
///
/// Each signal change runs `_evaluateAndSchedule`, which picks the
/// right [SmartReminderCondition] and calls
/// `NotificationService.scheduleDailyReminder` with that variant.
final smartReminderListenerProvider = Provider<void>((ref) {
  // Default reminder time when the user enables reminders without
  // picking one. The Profile tab's `_pickReminderTime` flow saves a
  // chosen time but doesn't yet persist it; for v1 we hard-code 19:00
  // (the time-picker's default initialTime). Future: read from a
  // `reminderTime` SharedPreferences key when the picker persists.
  const defaultReminderTime = TimeOfDay(hour: 19, minute: 0);

  Future<void> evaluate() async {
    final prefs = ref.read(appPreferencesProvider);
    if (!prefs.dailyReminderEnabled) return;
    final workoutDone = prefs.isWorkoutDoneToday;
    final calories = ref.read(consumedMacrosProvider).calories;
    final nutritionLogged = calories > 0;
    final SmartReminderCondition condition;
    if (!workoutDone) {
      condition = SmartReminderCondition.noWorkout;
    } else if (!nutritionLogged) {
      condition = SmartReminderCondition.workoutNoFood;
    } else {
      condition = SmartReminderCondition.bothDone;
    }
    AppLogger.info(
      'Smart reminder re-eval',
      category: 'notifications',
      data: {
        'workout_done': workoutDone,
        'nutrition_logged': nutritionLogged,
        'condition': condition.name,
      },
    );
    await NotificationService.instance.scheduleDailyReminder(
      defaultReminderTime,
      condition: condition,
    );
  }

  // Watch each upstream signal. Riverpod dedupes — when none of the
  // tracked values change, no re-evaluation runs. We deliberately
  // pull `dailyReminderEnabled` through a fresh `read` inside
  // `evaluate` so the listener also handles the off→on transition
  // (the user enables reminders mid-session) without a separate
  // listen on the prefs object.
  ref.listen<AsyncValue<WorkoutSessionState>>(
    workoutSessionProvider,
    (_, __) => evaluate(),
  );
  ref.listen<int>(
    consumedMacrosProvider.select((m) => m.calories),
    (_, __) => evaluate(),
  );

  // Initial evaluation on first materialisation so the schedule is
  // up-to-date the moment the app launches (workouts that completed
  // before the listener attached are already reflected).
  evaluate();
});
