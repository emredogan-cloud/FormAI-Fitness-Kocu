import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Phase 51 · single resolver for "where does this media file live".
///
/// Was a one-liner in `workout_repository.dart::_composeVideoUrl` that
/// only knew about the Supabase Storage public endpoint, plus an
/// implicit "store the URL verbatim" rule baked into Recipe.fromJson.
/// Now centralised so:
///
///   • Exercise videos, exercise thumbnails, and recipe images all run
///     through the same routing — flip on a CDN once, every surface
///     benefits.
///   • The migration is reversible without redeploying: clearing
///     `CDN_BASE_URL` in the .env file collapses the rewrite back to
///     the raw Supabase Storage URL on the next launch.
///
/// Resolution rules (in order):
///   1. `null` / empty input → `null`. Callers treat that as "no media,
///      render fallback".
///   2. Bare filename (no scheme, e.g. `'Crunch.mp4'`) → composed under
///      `bucket`. Prefers `<CDN_BASE_URL>/<bucket>/<filename>` when a
///      CDN is configured; falls back to
///      `<SUPABASE_URL>/storage/v1/object/public/<bucket>/<filename>`.
///   3. Full http(s) URL pointing at the configured Supabase Storage
///      public endpoint → rewritten so the host portion is the CDN,
///      preserving the bucket + path tail. Lets admin-uploaded media
///      (which `getPublicUrl()` returns as a full Supabase URL) flip
///      onto the CDN without touching the database.
///   4. Full http(s) URL pointing anywhere else (Unsplash, third-party
///      CDNs already in use) → passed through unchanged. Rewriting
///      arbitrary external URLs would break them.
class MediaUrl {
  const MediaUrl._();

  /// Resolves a stored media reference into a fully-qualified URL.
  /// Returns `null` for empty input, an empty Supabase fallback when
  /// no env vars are configured (the caller decides how to surface
  /// that), or a fully-qualified URL otherwise.
  static String? resolve(String? raw, {required String bucket}) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final cdn = _normalisedCdnBase();
    final supabase = _normalisedSupabaseBase();

    final isAbsolute =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');

    if (isAbsolute) {
      // Full URL path — try to rewrite Supabase Storage URLs onto the
      // CDN; otherwise pass through. We deliberately match BOTH the
      // public storage prefix and a CDN that already happens to be
      // configured (the second case is a re-entrancy guard so chaining
      // .resolve() on an already-CDN URL doesn't double-prefix).
      if (cdn != null && trimmed.startsWith('$cdn/')) return trimmed;
      if (cdn != null && supabase != null) {
        final storagePrefix = '$supabase/storage/v1/object/public/';
        if (trimmed.startsWith(storagePrefix)) {
          return '$cdn/${trimmed.substring(storagePrefix.length)}';
        }
      }
      return trimmed;
    }

    // Bare filename — compose under the bucket.
    if (cdn != null) return '$cdn/$bucket/$trimmed';
    if (supabase != null) {
      return '$supabase/storage/v1/object/public/$bucket/$trimmed';
    }
    // Neither base configured — most likely a unit test that never
    // initialised dotenv. Return null so callers fall back to their
    // empty-state UI rather than rendering a broken `'/Crunch.mp4'`.
    return null;
  }

  /// Returns the configured CDN base URL with any trailing slash
  /// stripped, or `null` when the env var is missing / empty.
  static String? _normalisedCdnBase() => _normalised('CDN_BASE_URL');

  /// Same trim treatment for the Supabase URL — the dotenv values can
  /// arrive with or without a trailing slash depending on how the PM
  /// pasted them, and double-slashes show up as `404` against the
  /// public endpoint.
  static String? _normalisedSupabaseBase() => _normalised('SUPABASE_URL');

  static String? _normalised(String key) {
    // `dotenv.env` throws `NotInitializedError` when `dotenv.load()`
    // hasn't run yet — the case in any unit test that constructs a
    // model without initialising dotenv. Treat that as "no value
    // configured" so models stay easy to test in isolation.
    String raw;
    try {
      raw = (dotenv.env[key] ?? '').trim();
    } on Object {
      return null;
    }
    if (raw.isEmpty) return null;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
