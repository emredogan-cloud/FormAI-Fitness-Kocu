import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_preferences.dart';
import '../utils/app_logger.dart';

/// Roadmap Phase 6 (R3.1) · the locales this build actually ships.
///
/// Order matters twice. `first` is the fallback for a device locale we
/// don't support, and it is the order the language picker renders in.
/// Turkish leads because it is the home market and the reviewed,
/// native-authored copy; English is the translation.
const List<Locale> kSupportedLocales = [Locale('tr'), Locale('en')];

/// The name of a language, written in that language.
///
/// Deliberately not flags: a flag is a country, and neither language
/// here belongs to one country. A user scanning the picker in a language
/// they don't read still recognises their own endonym — which is the
/// whole job of this string, and why it is not an ARB key.
String localeEndonym(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English'; // i18n-ignore — endonym, never translated
    case 'tr':
    default:
      return 'Türkçe'; // i18n-ignore — endonym, never translated
  }
}

/// What the app would resolve to if the user had never chosen.
///
/// Reads the platform directly rather than `Localizations.localeOf`,
/// which returns the *active* locale and therefore the user's override
/// when there is one. The settings sheet found this on a device: with
/// English selected on a Turkish phone, the "Device language" row read
/// "Currently English" — describing the choice it exists to undo.
///
/// Same matching rule as `main.dart`'s resolver: language code only,
/// falling back to the first supported locale.
Locale deviceLocale() {
  final platform = WidgetsBinding.instance.platformDispatcher.locales;
  for (final candidate in platform) {
    for (final supported in kSupportedLocales) {
      if (supported.languageCode == candidate.languageCode) return supported;
    }
  }
  return kSupportedLocales.first;
}

/// Roadmap Phase 6 (R3.2) · the user's language preference.
///
/// `null` means *follow the device* — the default for a fresh install,
/// and a real state rather than a stand-in for Turkish. It has to be
/// distinguishable, because "this user has never chosen" and "this user
/// chose Turkish" behave differently: the first tracks a device whose
/// language may change, the second does not.
///
/// Persistence mirrors [themeModeProvider]: the write lives inside the
/// notifier so UI callers can fire-and-forget `set(...)`. The value is
/// stored as a language-code token, not an index — see the theme
/// provider's note on why enum indices are a bad key.
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  /// Same `sixpack.` prefix as the rest of the persisted settings.
  static const String storageKey = 'sixpack.locale';

  /// Written when the user is explicitly following the device rather
  /// than when they have simply never chosen. Storing the token instead
  /// of clearing the key keeps "reset to device" durable — a cleared
  /// key would be re-adopted from the account on the next launch.
  static const String _system = 'system';

  @override
  Locale? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return decode(raw);
  }

  /// [locale] `null` restores device-follow.
  Future<void> set(Locale? locale) async {
    // Same idempotence guard as the theme notifier: a picker that
    // re-selects the active value must not push a fresh notification
    // through a tree that is mid-rebuild.
    if (state?.languageCode == locale?.languageCode) return;
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(storageKey, locale?.languageCode ?? _system);
    await _pushToAccount(locale);
  }

  /// Carries the choice across a reinstall.
  ///
  /// Best-effort in both directions. The device copy is authoritative
  /// for the running app — a user who cannot reach Supabase still gets
  /// the language they picked — so every failure here is swallowed.
  ///
  /// `Supabase.instance` itself is inside the try: it throws when the
  /// client was never initialised, which is the state the boot-error
  /// shell runs in and the state every widget test runs in.
  Future<void> _pushToAccount(Locale? locale) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('user_metrics').upsert(
        {'user_id': userId, 'locale': locale?.languageCode ?? _system},
        onConflict: 'user_id',
      );
    } catch (e) {
      // A breadcrumb, not a Sentry issue. Offline, signed out, or a
      // client that was never initialised are all normal conditions
      // here — the language still changed, which is what the user
      // asked for. Only the reinstall carry-over is lost.
      AppLogger.warning(
        'Locale sync to account skipped: $e',
        category: 'locale',
      );
    }
  }

  static Locale? decode(String? raw) {
    if (raw == null || raw == _system) return null;
    for (final locale in kSupportedLocales) {
      if (locale.languageCode == raw) return locale;
    }
    // A locale this build no longer ships (or a corrupted value):
    // follow the device rather than pin a language that doesn't exist.
    return null;
  }
}

/// Adopts the account's language on a device that has never chosen one.
///
/// The reinstall case: a user picks English, reinstalls, and lands on a
/// Turkish-locale phone. Without this they get Turkish and have to pick
/// again — the choice did not survive, which is the one thing the
/// account copy exists to guarantee.
///
/// A local choice always wins, so this never overrides anything. Called
/// once per session from the app shell; failure is silent by design.
Future<void> adoptAccountLocale(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  // Any stored value — including the explicit `system` token — means
  // this device has an opinion. Only a device that has never been asked
  // defers to the account.
  if (prefs.getString(LocaleNotifier.storageKey) != null) return;
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await Supabase.instance.client
        .from('user_metrics')
        .select('locale')
        .eq('user_id', userId)
        .maybeSingle();
    final remote = row?['locale'] as String?;
    if (remote == null) return;
    final locale = LocaleNotifier.decode(remote);
    if (locale == null) return;
    await ref.read(localeProvider.notifier).set(locale);
  } catch (e) {
    AppLogger.warning(
      'Locale adoption from account skipped: $e',
      category: 'locale',
    );
  }
}
