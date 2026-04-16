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

  bool get isFirstTime => _prefs.getBool(_firstTimeKey) ?? true;

  Future<void> completeOnboarding({String? goal}) async {
    if (goal != null) await _prefs.setString(_goalKey, goal);
    await _prefs.setBool(_firstTimeKey, false);
  }

  String? get goal => _prefs.getString(_goalKey);

  Future<void> resetOnboarding() async {
    await _prefs.remove(_firstTimeKey);
    await _prefs.remove(_goalKey);
  }
}
