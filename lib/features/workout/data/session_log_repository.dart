import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../models/session_log_model.dart';

/// Progress redesign Phase 2.A · local persistence for [SessionLog].
///
/// Mirrors the offline-first pattern `WorkoutRepository` already uses
/// for `_completedDays` — JSON-encoded list under a versioned
/// SharedPreferences key. Reads tolerate per-entry parse failures by
/// dropping the bad entry and logging, so a single corrupted log can't
/// take down the whole stats surface.
class SessionLogRepository {
  SessionLogRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Versioned to allow a future schema migration without a destructive
  /// in-place rewrite. Bumping to `_v2` simply means v1 logs become
  /// invisible to the new readers; no in-place migration code is
  /// required because logs are advisory (the `isCompleted` flag is the
  /// authoritative completion signal).
  static const String _logsKey = 'sixpack.session_logs_v1';

  /// Loads every persisted log, sorted by ascending dayNumber. Returns
  /// an empty list when the key is absent (fresh install) or when the
  /// stored value is unparseable (defensive — equivalent to "no logs").
  Future<List<SessionLog>> loadAll() async {
    final raw = _prefs.getString(_logsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final logs = <SessionLog>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          logs.add(SessionLog.fromJson(entry));
        } catch (e) {
          AppLogger.warning(
            'SessionLogRepository · dropping malformed log entry: $e',
            category: 'progress',
          );
        }
      }
      logs.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      return logs;
    } catch (e, st) {
      AppLogger.error(
        'SessionLogRepository · loadAll failed, returning empty',
        e,
        stackTrace: st,
        category: 'progress',
      );
      return const [];
    }
  }

  /// Persists a new log entry, replacing any prior log for the same
  /// `dayNumber`. The "replace" semantics matter for users who repeat
  /// a day's workout (e.g. via the "Tekrar başla" affordance — not
  /// implemented in Phase 2 but the schema accommodates it cleanly).
  Future<void> saveLog(SessionLog log) async {
    final existing = await loadAll();
    final filtered =
        existing.where((l) => l.dayNumber != log.dayNumber).toList();
    filtered.add(log);
    filtered.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    await _writeAll(filtered);
  }

  /// Wipes all stored logs. Called by `WorkoutRepository.resetProgress`
  /// so a "start over" flow doesn't leave orphaned logs pointing at a
  /// completion ledger that's been zeroed.
  Future<void> clearAll() async {
    await _prefs.remove(_logsKey);
  }

  Future<void> _writeAll(List<SessionLog> logs) async {
    final payload =
        jsonEncode(logs.map((l) => l.toJson()).toList(growable: false));
    await _prefs.setString(_logsKey, payload);
  }
}

/// Single repository instance scoped to the live SharedPreferences. The
/// shared instance ensures the workout-completion path's writes are
/// observable by the gelisim_tab read providers without a manual
/// invalidate.
final sessionLogRepositoryProvider = Provider<SessionLogRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SessionLogRepository(prefs);
});

/// Read-side projection: every log keyed by dayNumber for O(1) lookup
/// from the calendar drilldown and the volume-metrics derivation. Held
/// as a `FutureProvider` because the underlying load is async; the
/// gelisim_tab consumers `.when` over it like every other async source
/// in the file.
final sessionLogsProvider = FutureProvider<Map<int, SessionLog>>((ref) async {
  final repo = ref.watch(sessionLogRepositoryProvider);
  final logs = await repo.loadAll();
  return {for (final log in logs) log.dayNumber: log};
});
