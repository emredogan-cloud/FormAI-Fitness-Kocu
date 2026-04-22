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
  static const String _planCacheKey = 'sixpack.user_custom_plan_v2';

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
}
