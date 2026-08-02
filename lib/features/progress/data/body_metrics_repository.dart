import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/models/body_metric.dart';

/// Roadmap Phase 9 (C1) · offline-first store for [BodyMetric].
///
/// Mirrors `WorkoutRepository`'s pending-sync pattern, which is the one
/// this codebase has already proven: the device copy is authoritative
/// while the app runs, every write attempts Supabase with a short
/// timeout, and anything that does not land queues by day and replays on
/// the next load.
///
/// **Why the merge rule is not a union.** `WorkoutRepository` merges
/// completion days with a set union, which is correct because a day is
/// either done or not — there is no third value to disagree about. A
/// body metric CARRIES a value, so the same day can exist locally and
/// remotely saying different things, and "just union them" silently
/// picks whichever the language happened to iterate last. The rule here
/// is explicit: **a day in the pending queue is local, everything else
/// is remote.** A day the user typed on this device and has not yet
/// pushed must survive the merge that is about to overwrite it; a day
/// that already synced may have been re-logged from another device, and
/// that edit is newer than the copy sitting in this cache.
///
/// Nothing here ever writes a stale value back over a fresh one, which
/// is the failure mode that would matter most: a weight chart that
/// resurrects a number the user already corrected is worse than one
/// that briefly lacks it.
class BodyMetricsRepository {
  BodyMetricsRepository(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _entriesKey = 'sixpack.body_metrics_v1';
  static const String _pendingKey = 'sixpack.body_metrics_pending_v1';
  static const String _backfilledKey = 'sixpack.body_metrics_backfilled';
  static const String _table = 'body_metrics';

  /// Matches `WorkoutRepository`: on a wedged link, fall back to the
  /// local copy after 10 s rather than the SDK's ~30 s. A body-metrics
  /// screen that hangs for half a minute reads as broken.
  static const Duration _netTimeout = Duration(seconds: 10);

  /// Everything known about this user, oldest first.
  ///
  /// Every call is also a chance to replay dropped writes — cheap when
  /// the queue is empty, automatic recovery when it is not.
  Future<List<BodyMetric>> loadAll() async {
    await _flushPending();

    final local = _localEntries();
    final user = _client.auth.currentUser;
    if (user == null) return _sorted(local.values);

    try {
      final rows = await _client
          .from(_table)
          .select('recorded_on, weight_kg, waist_cm, chest_cm, '
              'arm_cm, thigh_cm, hip_cm, note')
          .eq('user_id', user.id)
          .timeout(_netTimeout);

      final pending = _pending();
      final merged = <String, BodyMetric>{...local};
      for (final row in rows) {
        try {
          final entry = BodyMetric.fromJson(row);
          // The rule this class exists to state out loud: a day the user
          // typed here and has not pushed yet wins; anything else, the
          // server is at least as fresh as we are.
          if (pending.contains(entry.recordedOnIso)) continue;
          merged[entry.recordedOnIso] = entry;
        } catch (e) {
          AppLogger.warning(
            'BodyMetricsRepository · dropping malformed remote row: $e',
            category: 'progress',
          );
        }
      }
      if (merged.length != local.length || !_sameValues(merged, local)) {
        await _writeAll(merged);
      }
      return _sorted(merged.values);
    } catch (_) {
      return _sorted(local.values);
    }
  }

  /// Saves [entry], replacing any prior entry for the same day.
  ///
  /// Returns the entry as stored. Throws [ArgumentError] on an entry
  /// carrying no measurement — that is a caller bug, not a user error,
  /// and the entry sheet is what stops a user reaching it.
  Future<BodyMetric> save(BodyMetric entry) async {
    if (entry.isEmpty) {
      throw ArgumentError.value(
        entry,
        'entry',
        'a body metric with no measurement is a date, not an observation',
      );
    }

    // The day-0 backfill runs BEFORE the new entry is written so it can
    // ask "is this the first thing this user has ever logged?" honestly.
    await _backfillFromOnboarding(entry);

    final entries = _localEntries();
    entries[entry.recordedOnIso] = entry;
    await _writeAll(entries);

    final user = _client.auth.currentUser;
    if (user == null || !await _upsert(user.id, entry)) {
      await _queue(entry.recordedOnIso);
    }
    return entry;
  }

  /// Removes the entry for [day], locally and remotely.
  ///
  /// Correcting a day is a re-log, which replaces — this is for the
  /// other case, where the value went onto the wrong day entirely. It
  /// is here rather than deferred because weight is charged: an app
  /// that shows someone a number they know is wrong and offers no way
  /// to remove it is the specific failure the roadmap's emotional-safety
  /// requirement is about.
  Future<void> delete(DateTime day) async {
    final key = BodyMetric(recordedOn: BodyMetric.dayOf(day)).recordedOnIso;
    final entries = _localEntries()..remove(key);
    await _writeAll(entries);
    await _unqueue(key);

    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', user.id)
          .eq('recorded_on', key)
          .timeout(_netTimeout);
    } catch (_) {
      // A delete that does not reach the server is re-applied by the
      // next successful one. It is deliberately NOT queued: replaying a
      // delete after the user has since re-logged that day would erase
      // the newer entry, and a stale row that reappears on one device is
      // a smaller harm than a fresh one silently destroyed.
      AppLogger.warning(
        'BodyMetricsRepository · remote delete failed for $key',
        category: 'progress',
      );
    }
  }

  /// Wipes everything. Called by the account-level data reset so a
  /// "start over" cannot leave a chart plotting a body the user asked
  /// the app to forget.
  Future<void> clearAll() async {
    await _prefs.remove(_entriesKey);
    await _prefs.remove(_pendingKey);
    await _prefs.remove(_backfilledKey);
  }

  // ─── day-0 backfill ──────────────────────────────────────────────

  /// Seeds the weight captured at onboarding as the user's first data
  /// point, so their very first log produces a LINE rather than a dot.
  ///
  /// Three guards, each for a real case:
  ///   * runs once ever, flagged, so a user who deletes the seed does
  ///     not get it back on their next log;
  ///   * only when nothing else is stored, so it can never appear in
  ///     the middle of an existing series;
  ///   * only when the install day is strictly before the day being
  ///     logged, so someone who onboards and weighs in the same morning
  ///     gets one honest point instead of two identical ones a
  ///     millisecond apart.
  ///
  /// It is a weight-only seed. Onboarding never asked for a waist.
  Future<void> _backfillFromOnboarding(BodyMetric incoming) async {
    if (incoming.weightKg == null) return;
    if (_prefs.getBool(_backfilledKey) ?? false) return;
    if (_localEntries().isNotEmpty) return;

    final prefs = AppPreferences(_prefs);
    final onboardingWeight =
        (prefs.userMetrics?['weightKg'] as num?)?.toDouble();
    if (onboardingWeight == null) return;

    final installDay = BodyMetric.dayOf(prefs.installedAt);
    if (!installDay.isBefore(incoming.recordedOn)) {
      // Same day (or a clock that has gone backwards). Mark it done —
      // the seed's whole purpose is served by the entry being saved.
      await _prefs.setBool(_backfilledKey, true);
      return;
    }

    final seed = BodyMetric(recordedOn: installDay, weightKg: onboardingWeight);
    final entries = _localEntries();
    entries[seed.recordedOnIso] = seed;
    await _writeAll(entries);
    await _prefs.setBool(_backfilledKey, true);

    final user = _client.auth.currentUser;
    if (user == null || !await _upsert(user.id, seed)) {
      await _queue(seed.recordedOnIso);
    }
  }

  // ─── network ─────────────────────────────────────────────────────

  /// One upsert, true on success. Isolated so the live save path and the
  /// background flush share exactly the same write — no chance of the
  /// two drifting apart.
  Future<bool> _upsert(String userId, BodyMetric entry) async {
    try {
      await _client.from(_table).upsert(
        {'user_id': userId, ...entry.toJson()},
        onConflict: 'user_id,recorded_on',
      ).timeout(_netTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Replays writes that never reached Supabase. Anything that succeeds
  /// leaves the queue; anything that still fails stays for next time. A
  /// queued day whose local entry has since been deleted is dropped
  /// rather than resurrected.
  Future<void> _flushPending() async {
    final pending = _pending();
    if (pending.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    final entries = _localEntries();
    final remaining = <String>{};
    for (final key in pending) {
      final entry = entries[key];
      if (entry == null) continue;
      if (!await _upsert(user.id, entry)) remaining.add(key);
    }
    if (remaining.length != pending.length) {
      await _savePending(remaining);
    }
  }

  // ─── local storage ───────────────────────────────────────────────

  Map<String, BodyMetric> _localEntries() {
    final raw = _prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final out = <String, BodyMetric>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final entry = BodyMetric.fromJson(item);
          out[entry.recordedOnIso] = entry;
        } catch (e) {
          AppLogger.warning(
            'BodyMetricsRepository · dropping malformed entry: $e',
            category: 'progress',
          );
        }
      }
      return out;
    } catch (e, st) {
      AppLogger.error(
        'BodyMetricsRepository · read failed, treating as empty',
        e,
        stackTrace: st,
        category: 'progress',
      );
      return {};
    }
  }

  Future<void> _writeAll(Map<String, BodyMetric> entries) async {
    final payload = jsonEncode(
      _sorted(entries.values).map((e) => e.toJson()).toList(growable: false),
    );
    await _prefs.setString(_entriesKey, payload);
  }

  Set<String> _pending() =>
      (_prefs.getStringList(_pendingKey) ?? const <String>[]).toSet();

  Future<void> _savePending(Set<String> keys) async {
    if (keys.isEmpty) {
      await _prefs.remove(_pendingKey);
      return;
    }
    await _prefs.setStringList(_pendingKey, keys.toList());
  }

  Future<void> _queue(String key) async => _savePending(_pending()..add(key));

  Future<void> _unqueue(String key) async =>
      _savePending(_pending()..remove(key));

  static List<BodyMetric> _sorted(Iterable<BodyMetric> entries) {
    final list = entries.toList()
      ..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));
    return list;
  }

  /// Whether two keyed sets hold the same measurements. Used to decide
  /// if a merge actually changed anything before paying for a write —
  /// `loadAll` runs on every screen build, and rewriting an identical
  /// payload each time is a disk write per frame.
  static bool _sameValues(
    Map<String, BodyMetric> a,
    Map<String, BodyMetric> b,
  ) {
    for (final key in a.keys) {
      final left = a[key];
      final right = b[key];
      if (right == null) return false;
      for (final measure in BodyMeasure.values) {
        if (left!.valueOf(measure) != right.valueOf(measure)) return false;
      }
      if (left!.note != right.note) return false;
    }
    return true;
  }
}

final bodyMetricsRepositoryProvider = Provider<BodyMetricsRepository>((ref) {
  return BodyMetricsRepository(ref.watch(sharedPreferencesProvider));
});

/// Every logged entry, oldest first. Async because the load may hit the
/// network; consumers `.when` over it like every other source in the
/// progress surfaces.
final bodyMetricsProvider = FutureProvider<List<BodyMetric>>((ref) async {
  return ref.watch(bodyMetricsRepositoryProvider).loadAll();
});
