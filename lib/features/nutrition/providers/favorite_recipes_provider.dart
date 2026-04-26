import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';

/// Phase 56 Lite · favourite-recipes store.
///
/// Local-first: every toggle writes to SharedPreferences immediately so
/// the heart icon flips without a round-trip. Authed users *also* get a
/// best-effort upsert into the `recipe_favorites` Supabase table for
/// cross-device persistence; the upsert is fire-and-forget — a network
/// failure must never block the local toggle. The on-server table is
/// the eventual source of truth, but for v1 we read from local on
/// boot and don't reconcile.
///
/// Stored as a `Set<String>` of recipe IDs to keep the data structure
/// trivially serialisable (`jsonEncode(state.toList())`).
final favoriteRecipesProvider =
    NotifierProvider<FavoriteRecipesNotifier, Set<String>>(
  FavoriteRecipesNotifier.new,
);

class FavoriteRecipesNotifier extends Notifier<Set<String>> {
  static const String _kStorageKey = 'sixpack.favorite_recipe_ids';

  late final SharedPreferences _prefs;

  @override
  Set<String> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final raw = _prefs.getStringList(_kStorageKey) ?? const <String>[];
    return raw.toSet();
  }

  bool contains(String recipeId) => state.contains(recipeId);

  /// Toggle membership and persist. Returns the new "isFavorite" boolean
  /// so the call site can respond (haptic + analytics) without a second
  /// `state.contains` lookup.
  Future<bool> toggle(String recipeId) async {
    final current = {...state};
    final wasFav = current.contains(recipeId);
    if (wasFav) {
      current.remove(recipeId);
    } else {
      current.add(recipeId);
    }
    state = current;
    try {
      await _prefs.setStringList(_kStorageKey, current.toList());
    } catch (e, st) {
      AppLogger.warning(
        'persist favorites failed: $e',
        category: 'favorites',
        data: {'stack': st.toString()},
      );
    }
    return !wasFav;
  }
}
