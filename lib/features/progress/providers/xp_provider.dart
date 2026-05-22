import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../data/level_titles.dart';
import '../domain/level_curve.dart';

/// Progress redesign Phase 3.C · the read-side projection of lifetime XP.
///
/// `lifetimeXpProvider` is a Notifier so the awarding listener can
/// trigger explicit `add(delta)` writes that the rest of the UI sees
/// without having to invalidate `appPreferencesProvider` (which would
/// thrash unrelated consumers). Derived providers — level, title,
/// per-level progress — fan out from there.
class LifetimeXpNotifier extends Notifier<int> {
  @override
  int build() {
    // Seed from persisted prefs on first read. Subsequent updates flow
    // through `add(int)` which mutates both prefs and state in one shot.
    return ref.watch(appPreferencesProvider).lifetimeXp;
  }

  /// Credit [delta] to the user's lifetime XP. Negative deltas are
  /// silently dropped at the persistence layer ([AppPreferences.addLifetimeXp]).
  /// Fire-and-forget the persistence write — the in-memory state
  /// updates synchronously so UI sees the new total this frame, and
  /// the prefs write catches up asynchronously.
  void add(int delta) {
    if (delta <= 0) return;
    final next = state + delta;
    state = next;
    // Persist on the next microtask so callers don't have to await.
    ref.read(appPreferencesProvider).addLifetimeXp(delta);
  }
}

final lifetimeXpProvider =
    NotifierProvider<LifetimeXpNotifier, int>(LifetimeXpNotifier.new);

/// Per-level progress trio (level, xp-in-level, xp-to-next, pct). Hero
/// pip + level chip both read this.
final levelProgressProvider = Provider<LevelProgress>((ref) {
  final xp = ref.watch(lifetimeXpProvider);
  return progressForXp(xp);
});

/// Convenience derived providers so call sites don't have to dig into
/// `LevelProgress` for a single field.
final currentLevelProvider = Provider<int>(
  (ref) => ref.watch(levelProgressProvider).level,
);

final currentTitleProvider = Provider<LevelTier>(
  (ref) => tierForLevel(ref.watch(currentLevelProvider)),
);
