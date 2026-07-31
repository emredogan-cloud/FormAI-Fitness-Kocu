import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'app_preferences.dart';

/// Roadmap Phase 4 (C7) · the remote-control layer.
///
/// Every phase after this one wants the same three things: ship a feature
/// to a slice of users, turn it off without an app update when it
/// misbehaves, and run an experiment. That is one piece of
/// infrastructure, and this is it.
///
/// The design constraint that shapes everything here is the phase's own
/// hardest success criterion: **the app must be 100% functional with the
/// flags service unreachable.** A remote-config layer that can brick the
/// app when a network call fails has made reliability worse, not better,
/// and it fails in exactly the conditions users are least forgiving —
/// on a train, in a basement gym, on a hotel wifi captive portal.
///
/// So:
///
///   * Every flag has a **hardcoded default compiled into the binary**.
///     A flag is a *deviation* from shipped behaviour, never a
///     prerequisite for it.
///   * [isEnabled] is synchronous and total. It cannot throw, cannot
///     await, and cannot return null. Call sites read it like a
///     constant, because from their point of view it is one.
///   * Remote values are cached to disk, so the second launch after a
///     successful fetch is correct even with no network at all.
///   * A malformed remote payload is discarded wholesale rather than
///     partially applied — a half-parsed config is more dangerous than
///     no config.

/// A single flag: stable key + the value used when nothing better is
/// known.
///
/// Defaults are chosen so that **an app with no network behaves like the
/// app we tested**. Anything shipped on in this release defaults on;
/// anything staged or experimental defaults off.
enum FeatureFlag {
  /// Master switch for Phase 4's staged capability unlocks. Off means
  /// every capability is available immediately — i.e. exactly the
  /// pre-Phase-4 product. This is the kill switch for the whole
  /// disclosure schedule.
  progressiveDisclosure('progressive_disclosure', defaultValue: true),

  /// The "Keşfet" capability map.
  discoveryHub('discovery_hub', defaultValue: true),

  /// Contextual dashboard tips (C28).
  contextualTips('contextual_tips', defaultValue: true),

  /// Coach-delivered unlock celebrations. Separable from the schedule
  /// itself so the celebrations can be muted without re-locking or
  /// re-unlocking anything.
  unlockCelebrations('unlock_celebrations', defaultValue: true),

  /// The in-workout coach-mark layer (Phase 3b).
  inSessionTutorial('in_session_tutorial', defaultValue: true),

  /// The guided practice rep inside the camera tutorial (Phase 3b).
  practiceRep('practice_rep', defaultValue: true),

  /// Contextual rating prompts (Phase 1). A kill switch here matters:
  /// store-prompt behaviour is the kind of thing that has to be
  /// stoppable the same day it is questioned.
  ratingPrompts('rating_prompts', defaultValue: true),

  /// In-app surveys / NPS (Phase 1).
  surveyPrompts('survey_prompts', defaultValue: true),

  /// The camera-free workout path (Phase 3, C21).
  cameraFreeMode('camera_free_mode', defaultValue: true),

  /// Onboarding-length experiment (C36 · P3). Off until the experiment
  /// is deliberately started — an A/B test that switches itself on at
  /// install time is an A/B test nobody agreed to run.
  onboardingLengthExperiment(
    'onboarding_length_experiment',
    defaultValue: false,
  );

  const FeatureFlag(this.key, {required this.defaultValue});

  /// Stable remote key. Never rename one — it is the primary key of the
  /// `feature_flags` row and the cache entry.
  final String key;

  /// Value used when there is no remote value, the fetch failed, the
  /// cache is empty, or the payload was malformed.
  final bool defaultValue;

  static FeatureFlag? fromKey(String key) {
    for (final flag in FeatureFlag.values) {
      if (flag.key == key) return flag;
    }
    return null;
  }
}

/// Resolves flag values. Reads never block and never fail.
class FeatureFlags {
  FeatureFlags(this._prefs);

  final SharedPreferences _prefs;

  static const String _cacheKey = 'sixpack.feature_flags_cache_v1';
  static const String _fetchedAtKey = 'sixpack.feature_flags_fetched_at';
  static const String _table = 'feature_flags';

  /// How long a fetched payload is trusted before another fetch is
  /// attempted. The phase requires a flag flip to take effect "within 5
  /// minutes, no app update"; this is that number.
  static const Duration ttl = Duration(minutes: 5);

  Map<String, bool> _overrides = const {};
  bool _loadedFromDisk = false;
  bool _fetchInFlight = false;

  /// The current value of [flag]. Synchronous, total, never throws.
  bool isEnabled(FeatureFlag flag) {
    if (!_loadedFromDisk) _loadCache();
    return _overrides[flag.key] ?? flag.defaultValue;
  }

  /// Every resolved value, for diagnostics and the debug surface.
  Map<String, bool> snapshot() => {
        for (final flag in FeatureFlag.values) flag.key: isEnabled(flag),
      };

  /// True when the cached payload is older than [ttl] (or absent), i.e.
  /// a refresh is due.
  bool get isStale {
    final raw = _prefs.getString(_fetchedAtKey);
    final at = raw == null ? null : DateTime.tryParse(raw);
    if (at == null) return true;
    return DateTime.now().difference(at) >= ttl;
  }

  void _loadCache() {
    _loadedFromDisk = true;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return;
    final parsed = parsePayload(raw);
    if (parsed != null) _overrides = parsed;
  }

  /// Parses a cached/remote payload into overrides, or returns `null` if
  /// it is not usable.
  ///
  /// Unknown keys are dropped rather than rejected: the server is
  /// allowed to know about flags a given client version doesn't, which
  /// is what makes it safe to add a flag server-side before the release
  /// that reads it. A structurally broken payload returns null so the
  /// caller keeps the previous known-good values instead of applying
  /// half of a bad one.
  static Map<String, bool>? parsePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final out = <String, bool>{};
      decoded.forEach((key, value) {
        if (key is! String) return;
        if (value is! bool) return;
        if (FeatureFlag.fromKey(key) == null) return;
        out[key] = value;
      });
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Applies [values] in memory and to the disk cache. Exposed for the
  /// fetch path and for tests; callers outside this file should prefer
  /// [refresh].
  Future<void> applyRemote(Map<String, bool> values) async {
    _loadedFromDisk = true;
    _overrides = Map.unmodifiable(values);
    await _prefs.setString(_cacheKey, jsonEncode(values));
    await _prefs.setString(
      _fetchedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Fetches flags if the cache is stale. Safe to call from anywhere,
  /// including app start: it swallows every failure, never blocks a
  /// caller on the network, and leaves the previous values in place when
  /// anything goes wrong.
  ///
  /// [force] skips the TTL check — used by the debug surface so a flip
  /// can be observed immediately rather than up to 5 minutes later.
  Future<void> refresh({bool force = false}) async {
    if (_fetchInFlight) return;
    if (!force && !isStale) return;
    _fetchInFlight = true;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select('key, enabled')
          .timeout(const Duration(seconds: 8));

      final values = <String, bool>{};
      for (final row in rows) {
        final key = row['key'];
        final enabled = row['enabled'];
        if (key is! String || enabled is! bool) continue;
        if (FeatureFlag.fromKey(key) == null) continue;
        values[key] = enabled;
      }
      await applyRemote(values);
      AppLogger.info(
        'feature flags refreshed (${values.length} remote values)',
        category: 'flags',
      );
    } catch (e) {
      // Deliberately not an error: being unable to reach the flag
      // service is a normal condition, and the app is fully functional
      // without it. Logging it as an error would train us to ignore
      // errors.
      AppLogger.info(
        'feature flag refresh skipped ($e) — using cached/default values',
        category: 'flags',
      );
    } finally {
      _fetchInFlight = false;
    }
  }
}

final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FeatureFlags(prefs);
});

/// Convenience for widgets: `ref.watch(featureFlagProvider(FeatureFlag.x))`.
final featureFlagProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  return ref.watch(featureFlagsProvider).isEnabled(flag);
});
