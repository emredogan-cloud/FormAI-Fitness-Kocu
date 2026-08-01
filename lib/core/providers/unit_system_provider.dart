import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_preferences.dart';
import '../utils/unit_system.dart';

/// Phase 6 polish · the user's measurement units.
///
/// `unit_system.dart` has converted correctly and been unit-tested since
/// Phase 5, but nothing exposed it: the UI was metric-only and a US user
/// reading `178 cm` saw a bug rather than a gap. This is the switch.
///
/// **Storage is always metric.** The conversion happens at the render
/// boundary and nowhere else — every stored height is centimetres and
/// every stored weight is kilograms, in SharedPreferences, in Supabase,
/// and in every calculation the app performs. That is what makes the
/// toggle lossless: flipping it twice is a no-op because nothing was
/// rewritten, and a user who switches to imperial and back has not lost
/// the tenth of a kilo that a round-trip through pounds would cost.
final unitSystemProvider =
    NotifierProvider<UnitSystemNotifier, UnitSystem>(UnitSystemNotifier.new);

class UnitSystemNotifier extends Notifier<UnitSystem> {
  /// Same `sixpack.` prefix as the rest of the persisted settings.
  static const String storageKey = 'sixpack.unit_system';

  @override
  UnitSystem build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(storageKey);
    return UnitSystem.fromToken(raw);
  }

  Future<void> set(UnitSystem system) async {
    // Same idempotence guard as the theme and locale notifiers: a
    // segmented button re-selecting the active value must not push a
    // notification through a tree that is mid-rebuild.
    if (state == system) return;
    state = system;
    await ref.read(sharedPreferencesProvider).setString(
          storageKey,
          system.token,
        );
  }
}
