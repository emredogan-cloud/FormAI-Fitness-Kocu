import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_preferences.dart';

/// Phase 53 · user-selectable theme mode (System / Light / Dark) backed
/// by SharedPreferences so the choice survives restart and ProviderScope
/// rebuilds.
///
/// The provider exposes a `Notifier<ThemeMode>` rather than a plain
/// `StateProvider` so the persistence write happens inside the notifier
/// — UI consumers (Profile tab segmented button) can fire-and-forget
/// `set(...)` without thinking about prefs.
///
/// `ThemeMode.system` is the default for fresh installs because:
///   1. It's what most users expect from a 2026 app.
///   2. It mirrors whatever OS-level preference the user has already
///      tuned, so the app feels "native" before they ever visit the
///      Profile tab.
final themeModeProvider =
    NotifierProvider<_ThemeModeNotifier, ThemeMode>(_ThemeModeNotifier.new);

class _ThemeModeNotifier extends Notifier<ThemeMode> {
  /// Storage key. Same `sixpack.` prefix the rest of AppPreferences uses
  /// so a future grep can find every persisted setting in one sweep.
  static const String _storageKey = 'sixpack.theme_mode';

  /// Stored as a string token rather than the enum index so a future
  /// reorder of `ThemeMode` (extremely unlikely, but framework enums
  /// have churned before) doesn't silently rewrite every user's choice.
  static const String _system = 'system';
  static const String _light = 'light';
  static const String _dark = 'dark';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_storageKey);
    return _decode(raw);
  }

  Future<void> set(ThemeMode mode) async {
    // Phase 53 hotfix · idempotent guard. Without it, any caller that
    // re-selects the already-active mode (for example, the
    // SegmentedButton firing onSelectionChanged on a programmatic
    // `selected:` update during the rebuild storm Light mode triggered)
    // would reassign `state` and propagate a fresh notification down
    // the tree — fuel for an infinite rebuild loop. Comparing first
    // makes the loop self-terminating.
    if (state == mode) return;
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, _encode(mode));
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case _light:
        return ThemeMode.light;
      case _dark:
        return ThemeMode.dark;
      case _system:
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _light;
      case ThemeMode.dark:
        return _dark;
      case ThemeMode.system:
        return _system;
    }
  }
}

/// Stable Turkish label for the active mode. Used by the Profile tab's
/// helper copy under the segmented button.
String themeModeLabelTr(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Açık';
    case ThemeMode.dark:
      return 'Koyu';
    case ThemeMode.system:
      return 'Sistem';
  }
}

/// Lightweight extension function that lives next to the provider so
/// callers don't have to import [SharedPreferences] just to read the
/// raw string. Currently unused — exported to give a future migration
/// (e.g. moving the value into a remote-synced UserSettings table) a
/// hook to write through.
@Deprecated(
  'Reserved for future remote-sync; prefer themeModeProvider for reads.',
)
Future<String?> readPersistedThemeMode(SharedPreferences prefs) async {
  return prefs.getString('sixpack.theme_mode');
}
