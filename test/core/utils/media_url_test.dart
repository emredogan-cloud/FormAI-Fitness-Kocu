import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/media_url.dart';

/// Coverage for the media-URL resolver. dotenv is driven directly via
/// its (mutable) env map so each test pins an exact CDN / Supabase
/// configuration without touching the filesystem.
const _cdn = 'https://cdn.example.com';
const _supabase = 'https://proj.supabase.co';
const _storagePrefix = '$_supabase/storage/v1/object/public';

void _useEnv(Map<String, String> values) {
  dotenv.clean();
  dotenv.env.addAll(values);
}

void main() {
  setUpAll(() {
    // Mark dotenv initialised so MediaUrl reads from the env map instead
    // of hitting NotInitializedError; per-test state is set via _useEnv.
    dotenv.loadFromString(envString: 'INIT=1', isOptional: true);
  });

  group('empty / null input', () {
    setUp(() => _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase}));

    test('null → null', () {
      expect(MediaUrl.resolve(null, bucket: 'exercises'), isNull);
    });

    test('empty string → null', () {
      expect(MediaUrl.resolve('', bucket: 'exercises'), isNull);
    });

    test('whitespace-only → null', () {
      expect(MediaUrl.resolve('   ', bucket: 'exercises'), isNull);
    });
  });

  group('bundled local-asset passthrough (env irrelevant)', () {
    setUp(() => _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase}));

    test('photos/ path is returned unchanged', () {
      expect(
        MediaUrl.resolve('photos/meals/foo.webp', bucket: 'recipes'),
        'photos/meals/foo.webp',
      );
    });

    test('assets/ path is returned unchanged', () {
      expect(
        MediaUrl.resolve('assets/img/x.png', bucket: 'recipes'),
        'assets/img/x.png',
      );
    });

    test('surrounding whitespace is trimmed before the asset check', () {
      expect(
        MediaUrl.resolve('  photos/a.webp  ', bucket: 'recipes'),
        'photos/a.webp',
      );
    });
  });

  group('bare filename composition', () {
    test('prefers CDN when configured', () {
      _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase});
      expect(
        MediaUrl.resolve('Squat.mp4', bucket: 'exercises'),
        '$_cdn/exercises/Squat.mp4',
      );
    });

    test('falls back to Supabase public storage when no CDN', () {
      _useEnv({'SUPABASE_URL': _supabase});
      expect(
        MediaUrl.resolve('Squat.mp4', bucket: 'exercises'),
        '$_storagePrefix/exercises/Squat.mp4',
      );
    });

    test('returns null when neither base is configured', () {
      _useEnv({});
      expect(MediaUrl.resolve('Squat.mp4', bucket: 'exercises'), isNull);
    });

    test('strips a trailing slash on the CDN base (no double slash)', () {
      _useEnv({'CDN_BASE_URL': '$_cdn/', 'SUPABASE_URL': _supabase});
      expect(
        MediaUrl.resolve('Squat.mp4', bucket: 'exercises'),
        '$_cdn/exercises/Squat.mp4',
      );
    });

    test('a quote-wrapped empty CDN ("") collapses to no-CDN', () {
      // Exercises MediaUrl's own quote-stripping: the raw env value is the
      // literal 2-char string `""`, set directly to bypass the parser.
      _useEnv({'SUPABASE_URL': _supabase});
      dotenv.env['CDN_BASE_URL'] = '""';
      expect(
        MediaUrl.resolve('Squat.mp4', bucket: 'exercises'),
        '$_storagePrefix/exercises/Squat.mp4',
      );
    });
  });

  group('absolute URL handling', () {
    test('Supabase storage URL is rewritten onto the CDN', () {
      _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase});
      expect(
        MediaUrl.resolve(
          '$_storagePrefix/exercises/Squat.mp4',
          bucket: 'exercises',
        ),
        '$_cdn/exercises/Squat.mp4',
      );
    });

    test('an already-CDN URL passes through (re-entrancy guard)', () {
      _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase});
      const already = '$_cdn/exercises/Squat.mp4';
      expect(MediaUrl.resolve(already, bucket: 'exercises'), already);
    });

    test('an external URL passes through unchanged', () {
      _useEnv({'CDN_BASE_URL': _cdn, 'SUPABASE_URL': _supabase});
      const external = 'https://images.unsplash.com/photo-1.jpg';
      expect(MediaUrl.resolve(external, bucket: 'recipes'), external);
    });

    test('Supabase storage URL passes through unchanged when no CDN', () {
      _useEnv({'SUPABASE_URL': _supabase});
      const url = '$_storagePrefix/exercises/Squat.mp4';
      expect(MediaUrl.resolve(url, bucket: 'exercises'), url);
    });
  });
}
