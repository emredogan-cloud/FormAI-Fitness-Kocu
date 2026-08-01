import 'dart:io' show Platform;

import 'package:live_activities/live_activities.dart';

import '../utils/app_copy.dart';
import '../utils/app_logger.dart';

/// Phase 55 · iOS-only Live Activity engine for the workout flow.
///
/// Owns the lifecycle of a single Live Activity at a time:
///   • [startWorkout] — fired when the user taps "Start Workout".
///     Creates the activity with the first exercise + set 1.
///   • [updateWorkout] — fired on every transition (next set, next
///     exercise, rest entry/exit, prep entry/exit). The native
///     SwiftUI view diff'd against the new content state.
///   • [endWorkout] — fired when the session completes OR the user
///     bails out via the back button.
///
/// All public methods are no-ops on non-iOS — Android Live-Activity
/// equivalents (notification-channel "media-style" pinned cards) are
/// out of scope for Phase 55. The service stays callable from
/// shared code regardless of the active platform.
///
/// Keys in the `Map<String, dynamic>` payload below MUST mirror the
/// `WorkoutAttributes.ContentState` Codable in
/// `ios/FormAILiveActivity/WorkoutAttributes.swift`. Bumping a key
/// here without bumping it there would silently fall back to the
/// last good payload (the SwiftUI decode would throw and ActivityKit
/// would refuse the update).
class WorkoutLiveActivityService {
  WorkoutLiveActivityService._();
  static final WorkoutLiveActivityService instance =
      WorkoutLiveActivityService._();

  /// MUST match `group.app.formai.shared` in:
  ///   • Runner target → Signing & Capabilities → App Groups
  ///   • FormAILiveActivity target → Signing & Capabilities → App Groups
  /// Any drift = a silently-empty Live Activity.
  static const String _appGroupId = 'group.app.formai.shared';

  /// URL scheme registered in `Info.plist` (Phase 54). Forwarded into
  /// the activity payload so the SwiftUI view can construct deep
  /// links via `Link(destination: URL(string: ...))`.
  static const String _urlScheme = 'formai';

  final LiveActivities _plugin = LiveActivities();
  bool _initialised = false;
  String? _activeActivityId;

  /// Wires the App Group + URL scheme bridges. Cheap and idempotent —
  /// safe to call from `_BootGate._init` once SharedPreferences is
  /// ready. Failures are non-fatal: a missing App Group entitlement
  /// just means activities won't be created until it's added in Xcode.
  Future<void> init() async {
    if (!Platform.isIOS) return;
    if (_initialised) return;
    try {
      await _plugin.init(
        appGroupId: _appGroupId,
        urlScheme: _urlScheme,
      );
      _initialised = true;
      AppLogger.info(
        'WorkoutLiveActivityService initialised',
        category: 'live_activity',
      );
    } catch (e, st) {
      AppLogger.warning(
        'LiveActivities.init failed: $e',
        category: 'live_activity',
        data: {'stack': st.toString()},
      );
    }
  }

  /// Returns the live activity id (or null if creation failed). The
  /// caller doesn't usually need to keep this — it's stashed
  /// internally so [updateWorkout] / [endWorkout] resolve against
  /// the active activity.
  Future<String?> startWorkout({
    required int dayNumber,
    required String exerciseName,
    required int setIndex,
    required int totalSets,
    required int totalExercises,
    required int currentExerciseIndex,
    required Duration elapsed,
    required bool isResting,
    int restSecondsRemaining = 0,
  }) async {
    if (!Platform.isIOS) return null;
    if (!_initialised) await init();
    // End any stale activity before creating a fresh one — guards
    // against a crashed prior session leaving an orphaned card on
    // the Lock Screen.
    await endWorkout();
    try {
      final id = await _plugin.createActivity(
        'workout-$dayNumber-${DateTime.now().millisecondsSinceEpoch}',
        _payload(
          dayNumber: dayNumber,
          exerciseName: exerciseName,
          setIndex: setIndex,
          totalSets: totalSets,
          currentExerciseIndex: currentExerciseIndex,
          totalExercises: totalExercises,
          elapsed: elapsed,
          isResting: isResting,
          restSecondsRemaining: restSecondsRemaining,
        ),
        removeWhenAppIsKilled: true,
      );
      _activeActivityId = id;
      return id;
    } catch (e, st) {
      AppLogger.warning(
        'createActivity failed: $e',
        category: 'live_activity',
        data: {'stack': st.toString()},
      );
      return null;
    }
  }

  /// Pushes a new content state. No-op when no activity is live —
  /// callers don't have to defend the call site against the
  /// "ended early" race.
  Future<void> updateWorkout({
    required int dayNumber,
    required String exerciseName,
    required int setIndex,
    required int totalSets,
    required int totalExercises,
    required int currentExerciseIndex,
    required Duration elapsed,
    required bool isResting,
    int restSecondsRemaining = 0,
  }) async {
    if (!Platform.isIOS) return;
    final id = _activeActivityId;
    if (id == null) return;
    try {
      await _plugin.updateActivity(
        id,
        _payload(
          dayNumber: dayNumber,
          exerciseName: exerciseName,
          setIndex: setIndex,
          totalSets: totalSets,
          currentExerciseIndex: currentExerciseIndex,
          totalExercises: totalExercises,
          elapsed: elapsed,
          isResting: isResting,
          restSecondsRemaining: restSecondsRemaining,
        ),
      );
    } catch (e, st) {
      AppLogger.warning(
        'updateActivity failed: $e',
        category: 'live_activity',
        data: {'stack': st.toString()},
      );
    }
  }

  /// Idempotent — safe to call from both the natural completion path
  /// and the user-bails path without risk of doubling up.
  Future<void> endWorkout() async {
    if (!Platform.isIOS) return;
    final id = _activeActivityId;
    if (id == null) return;
    try {
      await _plugin.endActivity(id);
    } catch (e, st) {
      AppLogger.warning(
        'endActivity failed: $e',
        category: 'live_activity',
        data: {'stack': st.toString()},
      );
    } finally {
      _activeActivityId = null;
    }
  }

  Map<String, dynamic> _payload({
    required int dayNumber,
    required String exerciseName,
    required int setIndex,
    required int totalSets,
    required int currentExerciseIndex,
    required int totalExercises,
    required Duration elapsed,
    required bool isResting,
    required int restSecondsRemaining,
  }) {
    final progress = totalExercises == 0
        ? 0.0
        : ((currentExerciseIndex) / totalExercises).clamp(0.0, 1.0);
    return <String, dynamic>{
      'day_number': dayNumber,
      'exercise_name': exerciseName,
      'set_label': AppCopy.strings.liveActivitySetLabel(setIndex, totalSets),
      'set_index': setIndex,
      'total_sets': totalSets,
      'exercise_index': currentExerciseIndex,
      'total_exercises': totalExercises,
      'progress': progress,
      'elapsed_seconds': elapsed.inSeconds,
      'is_resting': isResting,
      'rest_seconds_remaining': restSecondsRemaining,
      'deep_link': 'formai://workout/today',
    };
  }
}
