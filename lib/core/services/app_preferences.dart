import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the initialized SharedPreferences instance so
/// the router can read flags synchronously at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});

class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _firstTimeKey = 'sixpack.is_first_time';
  static const String _goalKey = 'sixpack.goal';
  static const String _userMetricsKey = 'sixpack.user_metrics';
  // Must match WorkoutRepository._planKey. Duplicated here because
  // saveUserMetrics needs to drop the cached 30-day plan when the goal
  // changes, and a cross-import would create an awkward core → feature
  // dependency just for one string constant.
  static const String _planCacheKey = 'sixpack.user_custom_plan_v3';
  static const String _nutritionStreakKey = 'sixpack.nutrition_streak';
  // Phase 46 · progressive disclosure. The four nutrition wizard
  // questions (diet / allergies / meal-frequency / prep-time) were
  // lifted out of the main onboarding flow so the initial 13-step
  // wizard could shrink to 9. They are asked the first time the user
  // opens the Beslenme tab instead; this flag is set to `true` once
  // that deferred flow completes so the sheet never re-prompts.
  static const String _nutritionPrefsCompletedKey =
      'sixpack.nutrition_prefs_completed';
  // Phase 48 · daily-reminder toggle persisted so the account-settings
  // switch can render its "on" / "off" position across app restarts.
  // The real scheduling still lives in NotificationService; this flag
  // is just the source of truth for the switch and gates whether we
  // actually ask the OS to schedule.
  static const String _dailyReminderEnabledKey =
      'sixpack.daily_reminder_enabled';

  bool get isFirstTime => _prefs.getBool(_firstTimeKey) ?? true;

  Future<void> completeOnboarding({String? goal}) async {
    if (goal != null) await _prefs.setString(_goalKey, goal);
    await _prefs.setBool(_firstTimeKey, false);
  }

  String? get goal => _prefs.getString(_goalKey);

  Future<void> saveUserMetrics(Map<String, dynamic> metrics) async {
    final previousGoal = _prefs.getString(_goalKey);
    await _prefs.setString(_userMetricsKey, jsonEncode(metrics));
    final goal = metrics['targetPhysique'] as String?;
    if (goal != null) await _prefs.setString(_goalKey, goal);
    // If the user picked a new goal, the cached 30-day plan was
    // generated against the old one — drop it so the next program load
    // regenerates against what they just picked.
    if (goal != null && goal != previousGoal) {
      await _prefs.remove(_planCacheKey);
    }
  }

  Map<String, dynamic>? get userMetrics {
    final raw = _prefs.getString(_userMetricsKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> resetOnboarding() async {
    await _prefs.remove(_firstTimeKey);
    await _prefs.remove(_goalKey);
    await _prefs.remove(_userMetricsKey);
  }

  /// Current nutrition streak in whole days. Zero-default so a fresh
  /// install just shows "0 Gün" until the cron job backfills real
  /// values. Phase 25.2 ships the UI only — see
  /// [nutritionStreakProvider] for the read-side.
  int get nutritionStreak => _prefs.getInt(_nutritionStreakKey) ?? 0;

  Future<void> setNutritionStreak(int value) async {
    await _prefs.setInt(_nutritionStreakKey, value);
  }

  /// True once the user has answered the four deferred nutrition
  /// questions surfaced on first Beslenme-tab view. False-by-default
  /// so fresh installs trigger the sheet exactly once.
  bool get hasCompletedNutritionPrefs =>
      _prefs.getBool(_nutritionPrefsCompletedKey) ?? false;

  Future<void> completeNutritionOnboarding() async {
    await _prefs.setBool(_nutritionPrefsCompletedKey, true);
  }

  /// Whether the user has the daily training-reminder push enabled.
  /// Defaults to `false` so a fresh install never schedules a notification
  /// without an explicit opt-in (Apple/Google policy).
  bool get dailyReminderEnabled =>
      _prefs.getBool(_dailyReminderEnabledKey) ?? false;

  Future<void> setDailyReminderEnabled(bool value) async {
    await _prefs.setBool(_dailyReminderEnabledKey, value);
  }
}
