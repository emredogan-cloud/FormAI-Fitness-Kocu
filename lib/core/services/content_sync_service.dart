import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/domain/content_freshness.dart';
import '../utils/app_logger.dart';
import 'app_preferences.dart';

/// Roadmap Phase 14 (C5, C6, R5) · the catalogue of what is new.
///
/// # Why this caches rather than fetches
///
/// The roadmap's requirement is that this "must degrade gracefully to
/// bundled content when offline (protecting the 'train anywhere'
/// claim)". Content freshness is the one feature whose entire purpose is
/// to be *newer* than the app — so the naive shape is a live fetch, and
/// the naive shape means a plane makes the What's New screen an error.
///
/// So every read answers from the cache and the network only ever
/// refreshes it. There is no loading state that can fail: the first run
/// with no connectivity has an empty catalogue, which renders as nothing
/// at all, which is the correct appearance of an app with no new
/// content.
///
/// # Why the cache is JSON and not parsed objects
///
/// The rows are stored exactly as PostgREST returned them and parsed on
/// every read. That costs a decode per screen open and buys the property
/// that **a client which learns a new field reads it out of a cache
/// written by a client which did not.** An app updated after a
/// month offline shows the new content immediately rather than after its
/// first successful sync — and given this phase exists to make the app
/// feel alive, the version that needs the network first is the wrong
/// one.
///
/// # What it deliberately does not do
///
/// No periodic timer, no background isolate, no push. [refresh] is
/// called when the app resumes and when a surface that shows content is
/// opened. A content drop that lands while somebody is mid-workout can
/// wait until they next open the app; the alternative is a background
/// job whose battery cost is paid by every user for the benefit of the
/// few who leave the app open for days.
class ContentSyncService {
  ContentSyncService(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _releasesKey = 'sixpack.content_releases_v1';
  static const String _dropsKey = 'sixpack.content_drops_v1';
  static const String _syncedAtKey = 'sixpack.content_synced_at_v1';

  /// Same 10 s ceiling as `WorkoutRepository` and
  /// `BodyMetricsRepository`. The SDK's own ~30 s is long enough that a
  /// wedged link reads as a hung screen.
  static const Duration _netTimeout = Duration(seconds: 10);

  /// How stale the cache may be before [refreshIfStale] does anything.
  ///
  /// Content lands on a weekly-to-monthly cadence, so an hour is already
  /// far finer-grained than the thing it is tracking. It exists to stop
  /// four surfaces opening in one session issuing four identical
  /// requests, not to bound staleness.
  static const Duration _staleAfter = Duration(hours: 1);

  /// Release notes the device knows about. Never throws, never empty
  /// because of a network failure — only because there are none.
  List<ContentRelease> releases() => _decode(_releasesKey)
      .map(ContentRelease.fromJson)
      .whereType<ContentRelease>()
      .toList(growable: false);

  /// Content drops the device knows about, newest first.
  List<ContentDrop> drops() {
    final parsed = _decode(_dropsKey)
        .map(ContentDrop.fromJson)
        .whereType<ContentDrop>()
        .toList();
    parsed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return List.unmodifiable(parsed);
  }

  DateTime? get lastSyncedAt {
    final raw = _prefs.getString(_syncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool get isStale {
    final last = lastSyncedAt;
    return last == null || DateTime.now().difference(last) > _staleAfter;
  }

  Future<void> refreshIfStale() => isStale ? refresh() : Future.value();

  /// Pulls both catalogues and replaces the cache.
  ///
  /// **A failure leaves the previous cache in place**, which is the
  /// whole design: a partial sync that emptied the catalogue would make
  /// a flaky connection look like an app with nothing new in it.
  Future<void> refresh() async {
    if (_client.auth.currentUser == null) return;
    var wrote = false;
    wrote = await _pull('content_releases', _releasesKey) || wrote;
    wrote = await _pull('content_drops', _dropsKey) || wrote;
    if (wrote) {
      await _prefs.setString(_syncedAtKey, DateTime.now().toIso8601String());
    }
  }

  Future<bool> _pull(String table, String key) async {
    try {
      final rows = await _client.from(table).select().timeout(_netTimeout);
      await _prefs.setString(key, jsonEncode(rows));
      return true;
    } on PostgrestException catch (e) {
      // `024` not applied yet is a state, not an error — the same answer
      // `CommunityRepository` gives for a missing relation. Anything
      // else is worth a Sentry issue.
      if (e.code == '42P01') {
        AppLogger.info('content: $table not present — nothing to sync',
            category: 'content');
      } else {
        AppLogger.error('content sync failed', e, category: 'content');
      }
      return false;
    } catch (e, st) {
      AppLogger.error('content sync failed', e,
          stackTrace: st, category: 'content');
      return false;
    }
  }

  List<Map<String, dynamic>> _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final row in decoded)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    } on FormatException catch (e) {
      // A cache written by a build that stored something else. Dropping
      // it is right; the next refresh rewrites it.
      AppLogger.warning('content cache unreadable, discarding: $e',
          category: 'content');
      return const [];
    }
  }
}

final contentSyncServiceProvider = Provider<ContentSyncService>(
  (ref) => ContentSyncService(ref.watch(sharedPreferencesProvider)),
);
