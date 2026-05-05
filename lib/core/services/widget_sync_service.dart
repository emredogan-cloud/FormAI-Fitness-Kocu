import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/workout/models/workout_day_model.dart';
import '../../features/workout/providers/workout_provider.dart';
import '../utils/app_logger.dart';
import 'app_preferences.dart';

/// Phase 55 · home-screen widget bridge.
///
/// Pushes a small snapshot of the user's daily state into the shared
/// platform store the native widget reads from:
///   • iOS  → `UserDefaults(suiteName: _appGroupId)`
///   • Android → `SharedPreferences("HomeWidgetPreferences")`
///
/// Then rings the platform `updateWidget` hook so the OS asks the
/// widget extension for a fresh timeline. Native code (SwiftUI in
/// `ios/FormAIWidget/AppWidget.swift`, Kotlin in
/// `android/app/src/main/kotlin/.../widget/FormAIHomeWidgetProvider.kt`)
/// reads these keys verbatim — bumping a key here means bumping the
/// matching constant in both native files.
class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  // ---------------------------------------------------------------------------
  // Configuration constants. Mirrored in native sources — DO NOT rename
  // unilaterally.
  // ---------------------------------------------------------------------------

  /// Shared App Group container used by both the main app and the
  /// widget extension on iOS. Must match the `Signing & Capabilities →
  /// App Groups` entry in Xcode for both targets.
  static const String _appGroupId = 'group.app.formai.shared';

  /// Android provider class FQN. Must match the AndroidManifest
  /// receiver entry. Passed via `qualifiedAndroidName` so the
  /// `home_widget` plugin uses it verbatim — the `androidName`
  /// channel arg is prepended with `context.packageName` on the
  /// native side, which double-prefixed the package and produced
  /// `ClassNotFoundException: com.formai.app.com.formai.app.widget.FormAIHomeWidgetProvider`.
  static const String _androidProvider =
      'com.formai.app.widget.FormAIHomeWidgetProvider';

  /// iOS widget bundle name registered via `@main` in the
  /// FormAIWidget target's `WidgetBundle`.
  static const String _iosWidgetName = 'FormAIWidget';

  // Keys read by the native widget code.
  static const String _kTaskName = 'today_task_name';
  static const String _kSubtitle = 'today_task_subtitle';
  static const String _kProgressPct = 'progress_percent';
  static const String _kStreak = 'streak_count';
  static const String _kCompletedDays = 'completed_days';
  static const String _kTotalDays = 'total_days';
  static const String _kDeepLink = 'deep_link';
  static const String _kUpdatedAtMs = 'updated_at_ms';

  bool _initialised = false;

  /// Wires the App Group on iOS. Cheap and idempotent — safe to call
  /// from `_BootGate` once SharedPreferences is ready. Failures are
  /// non-fatal: a missing App Group entitlement just means the widget
  /// won't update until the user adds it in Xcode.
  Future<void> init() async {
    if (_initialised) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      _initialised = true;
      AppLogger.info('WidgetSyncService initialised', category: 'widget');
    } catch (e, st) {
      AppLogger.warning(
        'HomeWidget.setAppGroupId failed: $e',
        category: 'widget',
        data: {'stack': st.toString()},
      );
    }
  }

  /// Pushes a fresh snapshot to the platform widget store and rings
  /// the OS update hook. Errors are swallowed — a failed widget
  /// update should never bubble up into the workout flow.
  Future<void> push({
    required String taskName,
    required String subtitle,
    required int progressPercent,
    required int streakCount,
    required int completedDays,
    required int totalDays,
    String deepLink = 'formai://workout/today',
  }) async {
    try {
      await Future.wait<void>([
        HomeWidget.saveWidgetData<String>(_kTaskName, taskName),
        HomeWidget.saveWidgetData<String>(_kSubtitle, subtitle),
        HomeWidget.saveWidgetData<int>(_kProgressPct, progressPercent),
        HomeWidget.saveWidgetData<int>(_kStreak, streakCount),
        HomeWidget.saveWidgetData<int>(_kCompletedDays, completedDays),
        HomeWidget.saveWidgetData<int>(_kTotalDays, totalDays),
        HomeWidget.saveWidgetData<String>(_kDeepLink, deepLink),
        HomeWidget.saveWidgetData<int>(
          _kUpdatedAtMs,
          DateTime.now().millisecondsSinceEpoch,
        ),
      ]);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidProvider,
        iOSName: _iosWidgetName,
      );
    } catch (e, st) {
      AppLogger.warning(
        'HomeWidget update failed: $e',
        category: 'widget',
        data: {'stack': st.toString()},
      );
    }
  }
}

/// Phase 55 · Riverpod-side glue. Materialise this provider once from
/// the app shell (`ref.watch(widgetSyncListenerProvider)`) — its
/// `ref.listen` against `workoutSessionProvider` then drives a fresh
/// push every time the user's state changes.
///
/// We intentionally read the *resolved* `WorkoutSessionState` (not
/// `AsyncValue`) so a transient loading state doesn't blank the widget
/// — if the new value is null, we simply skip the push and the widget
/// keeps showing the last good snapshot.
final widgetSyncListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<WorkoutSessionState>>(
    workoutSessionProvider,
    (prev, next) {
      final session = next.value;
      if (session == null) return;
      final completed = session.days.where((d) => d.isCompleted).length;
      const totalDays = 30;
      final percent =
          totalDays == 0 ? 0 : ((completed / totalDays) * 100).round();
      final streak = _streakOf(session.days);
      final activeDay = session.activeDay;
      final activeIndex = session.activeExerciseIndex;
      final exercise = (activeDay != null &&
              activeIndex >= 0 &&
              activeIndex < activeDay.exercises.length)
          ? activeDay.exercises[activeIndex]
          : null;

      final taskName = activeDay == null
          ? 'Hazır mısın?'
          : 'Gün ${activeDay.dayNumber} · ${_dayLabel(activeDay)}';
      final subtitle = exercise == null
          ? '%$percent · $streak gün seri'
          : '${activeIndex + 1}/${activeDay!.exercises.length} · ${exercise.name}';

      WidgetSyncService.instance.push(
        taskName: taskName,
        subtitle: subtitle,
        progressPercent: percent,
        streakCount: streak,
        completedDays: completed,
        totalDays: totalDays,
      );
    },
    fireImmediately: true,
  );

  // Phase 55 · also nudge the widget when the user's nutrition streak
  // changes (handled via SharedPreferences). Cheap to watch — the
  // provider only re-runs when the AppPreferences instance flips.
  ref.watch(appPreferencesProvider);
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

String _dayLabel(WorkoutDay day) {
  if (day.isRestDay) return 'Dinlenme';
  if (day.exercises.isEmpty) return 'Antrenman';
  return day.exercises.first.targetMuscle.replaceAll('_', ' ');
}
