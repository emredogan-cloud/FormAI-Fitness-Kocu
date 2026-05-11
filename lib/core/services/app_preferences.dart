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
  // Phase 52 · monotonic high-water mark of `streak`. Bumped from
  // `WorkoutSessionNotifier` whenever the live streak crosses its
  // previous best. Read by the AI Coach card so a user who lost their
  // streak (live = 0) but used to have one (max > 0) sees the
  // "comeback" greeting instead of the cold-start default.
  static const String _maxStreakKey = 'sixpack.max_streak';
  // Phase 58 · ISO-8601 timestamp of the most recent workout
  // completion. The smart notification scheduler reads this to decide
  // whether the user has already done today's workout, which then
  // picks the appropriate reminder body (Condition A / B / C). Stored
  // as ISO-8601 so the date check is timezone-aware.
  static const String _lastWorkoutAtKey = 'sixpack.last_workout_at';

  // Phase 126 · first-time AI-presence scene flags. Each of the three
  // cinematic AI scenes (dashboard welcome / nutrition intro / first-
  // workout celebration) fires exactly once per install. The mark-seen
  // happens *before* the route push so a backgrounded scene doesn't
  // replay on app resume — see [FirstTimeAiScenes.showIfNeeded].
  static const String _seenFirstDashboardAiKey =
      'sixpack.seen_first_dashboard_ai';
  static const String _seenFirstNutritionAiKey =
      'sixpack.seen_first_nutrition_ai';
  static const String _seenFirstWorkoutCompleteAiKey =
      'sixpack.seen_first_workout_complete_ai';

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

  /// Phase 52 · highest streak this user has ever reached. Defaults to
  /// 0 so a fresh install reads "no past streak". Updated through
  /// [bumpMaxStreakIfHigher] so callers can't accidentally regress the
  /// high-water mark when the live streak resets.
  int get maxStreak => _prefs.getInt(_maxStreakKey) ?? 0;

  /// Bumps [maxStreak] to [candidate] when it represents a new
  /// personal best. No-op when the candidate is equal or lower than
  /// the stored max — protects the high-water mark on streak resets,
  /// which is exactly the signal the "comeback" greeting keys off.
  Future<void> bumpMaxStreakIfHigher(int candidate) async {
    if (candidate <= maxStreak) return;
    await _prefs.setInt(_maxStreakKey, candidate);
  }

  /// Phase 58 · the wall-clock moment the user last completed a
  /// workout. Returns null on a fresh install (no prior completion)
  /// so callers can disambiguate "no workouts yet" from "haven't
  /// worked out today".
  DateTime? get lastWorkoutAt {
    final raw = _prefs.getString(_lastWorkoutAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastWorkoutAt(DateTime when) async {
    await _prefs.setString(_lastWorkoutAtKey, when.toIso8601String());
  }

  /// Phase 58 · derived: did the user already finish a workout today?
  /// "Today" is the device's local calendar day, which matches what
  /// the rest of the app displays. Uses date-only comparison (not
  /// duration) because a user who trained at 23:50 yesterday should
  /// still see the "Antrenman Vakti" prompt at 09:00 today, not
  /// "Yakıt Gerekli".
  bool get isWorkoutDoneToday {
    final last = lastWorkoutAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  // ─── Phase 126 · first-time AI-presence scene gates ───────────────

  bool get seenFirstDashboardAi =>
      _prefs.getBool(_seenFirstDashboardAiKey) ?? false;

  Future<void> markSeenFirstDashboardAi() async {
    await _prefs.setBool(_seenFirstDashboardAiKey, true);
  }

  bool get seenFirstNutritionAi =>
      _prefs.getBool(_seenFirstNutritionAiKey) ?? false;

  Future<void> markSeenFirstNutritionAi() async {
    await _prefs.setBool(_seenFirstNutritionAiKey, true);
  }

  bool get seenFirstWorkoutCompleteAi =>
      _prefs.getBool(_seenFirstWorkoutCompleteAiKey) ?? false;

  Future<void> markSeenFirstWorkoutCompleteAi() async {
    await _prefs.setBool(_seenFirstWorkoutCompleteAiKey, true);
  }
}
