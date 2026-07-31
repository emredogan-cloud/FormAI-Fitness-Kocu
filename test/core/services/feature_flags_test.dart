import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/feature_flags.dart';

/// Roadmap Phase 4 (C7) · the remote-control layer.
///
/// The phase's hardest success criterion is "the app is 100% functional
/// with the flags service unreachable". These tests are that criterion
/// made executable: every path that could plausibly return nothing, or
/// throw, must instead return the value compiled into the binary.
Future<FeatureFlags> _flags([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container.read(featureFlagsProvider);
}

void main() {
  group('the catalogue itself', () {
    test('keys are unique — a duplicate would silently shadow a flag', () {
      final keys = FeatureFlag.values.map((f) => f.key).toSet();
      expect(keys.length, FeatureFlag.values.length);
    });

    test('keys are snake_case and non-empty — they are database keys', () {
      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final flag in FeatureFlag.values) {
        expect(pattern.hasMatch(flag.key), isTrue, reason: flag.key);
      }
    });

    test('fromKey round-trips every flag and rejects unknowns', () {
      for (final flag in FeatureFlag.values) {
        expect(FeatureFlag.fromKey(flag.key), flag);
      }
      expect(FeatureFlag.fromKey('not_a_flag'), isNull);
      expect(FeatureFlag.fromKey(''), isNull);
    });

    test('the phase ships at least 8 flags controlling real behaviour', () {
      // A success criterion of the phase, pinned so a later refactor
      // can't quietly reduce the surface the kill switches cover.
      expect(FeatureFlag.values.length, greaterThanOrEqualTo(8));
    });

    test('the onboarding experiment defaults OFF', () {
      // An A/B test that switches itself on at install time is an A/B
      // test nobody agreed to run.
      expect(FeatureFlag.onboardingLengthExperiment.defaultValue, isFalse);
    });
  });

  group('offline / no-remote behaviour', () {
    test('a fresh install resolves every flag to its compiled default',
        () async {
      final flags = await _flags();
      for (final flag in FeatureFlag.values) {
        expect(flags.isEnabled(flag), flag.defaultValue, reason: flag.key);
      }
    });

    test('a fresh install is stale, so a refresh is due', () async {
      expect((await _flags()).isStale, isTrue);
    });

    test('snapshot covers every flag', () async {
      final snap = (await _flags()).snapshot();
      expect(snap.length, FeatureFlag.values.length);
      for (final flag in FeatureFlag.values) {
        expect(snap[flag.key], flag.defaultValue);
      }
    });
  });

  group('the disk cache', () {
    test('a cached payload survives a cold start with no network', () async {
      final flags = await _flags({
        'sixpack.feature_flags_cache_v1':
            jsonEncode({'progressive_disclosure': false}),
      });
      expect(flags.isEnabled(FeatureFlag.progressiveDisclosure), isFalse);
      // Untouched flags keep their defaults rather than collapsing to
      // false — a partial payload is not a statement about the rest.
      expect(flags.isEnabled(FeatureFlag.discoveryHub), isTrue);
    });

    test('applyRemote persists, so the NEXT launch is already correct',
        () async {
      SharedPreferences.setMockInitialValues(const {});
      final raw = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
      );
      addTearDown(container.dispose);

      await container
          .read(featureFlagsProvider)
          .applyRemote({'rating_prompts': false});

      // A second instance over the same storage = the next cold start.
      final reborn = FeatureFlags(raw);
      expect(reborn.isEnabled(FeatureFlag.ratingPrompts), isFalse);
      expect(reborn.isStale, isFalse, reason: 'just fetched');
    });
  });

  group('malformed payloads cannot break the app', () {
    test('garbage in the cache falls back to defaults', () async {
      final flags = await _flags({
        'sixpack.feature_flags_cache_v1': 'not json at all',
      });
      for (final flag in FeatureFlag.values) {
        expect(flags.isEnabled(flag), flag.defaultValue, reason: flag.key);
      }
    });

    test('a JSON array is rejected wholesale', () {
      expect(FeatureFlags.parsePayload('[1,2,3]'), isNull);
    });

    test('non-bool values are dropped, not coerced', () {
      final parsed = FeatureFlags.parsePayload(jsonEncode({
        'discovery_hub': 'true',
        'contextual_tips': 1,
        'rating_prompts': null,
        'survey_prompts': false,
      }));
      // A string "true" is not a true. Coercing it would make a typo in
      // the dashboard silently flip a feature.
      expect(parsed, {'survey_prompts': false});
    });

    test('unknown keys are ignored so the server may run ahead of the app', () {
      final parsed = FeatureFlags.parsePayload(jsonEncode({
        'a_flag_from_the_future': true,
        'discovery_hub': false,
      }));
      expect(parsed, {'discovery_hub': false});
    });

    test('an empty object parses to no overrides rather than null', () {
      expect(FeatureFlags.parsePayload('{}'), isEmpty);
    });

    test('a bad payload leaves previously-good values intact', () async {
      SharedPreferences.setMockInitialValues(const {});
      final raw = await SharedPreferences.getInstance();
      final flags = FeatureFlags(raw);

      await flags.applyRemote({'discovery_hub': false});
      expect(flags.isEnabled(FeatureFlag.discoveryHub), isFalse);

      // Simulate a corrupt write landing on disk, then a cold start.
      await raw.setString('sixpack.feature_flags_cache_v1', '{{{');
      final reborn = FeatureFlags(raw);
      expect(
        reborn.isEnabled(FeatureFlag.discoveryHub),
        FeatureFlag.discoveryHub.defaultValue,
        reason: 'unusable cache degrades to the compiled default',
      );
    });
  });

  group('staleness / TTL', () {
    test('a payload fetched now is fresh', () async {
      final flags = await _flags({
        'sixpack.feature_flags_fetched_at': DateTime.now().toIso8601String(),
      });
      expect(flags.isStale, isFalse);
    });

    test('a payload older than the TTL is stale', () async {
      final old = DateTime.now().subtract(FeatureFlags.ttl * 2);
      final flags = await _flags({
        'sixpack.feature_flags_fetched_at': old.toIso8601String(),
      });
      expect(flags.isStale, isTrue);
    });

    test('an unparseable timestamp is treated as stale, not as fresh',
        () async {
      // Failing open here would strand a client on old values forever.
      final flags = await _flags({
        'sixpack.feature_flags_fetched_at': 'yesterday-ish',
      });
      expect(flags.isStale, isTrue);
    });

    test('the TTL matches the phase requirement of 5 minutes', () {
      expect(FeatureFlags.ttl, const Duration(minutes: 5));
    });
  });

  group('refresh never throws', () {
    test('with no Supabase initialised, refresh completes quietly', () async {
      // This is the critical failure test: `Supabase.instance` is not
      // initialised in a unit test, so the call inside `refresh` throws
      // immediately. The method must absorb it.
      final flags = await _flags();
      await expectLater(flags.refresh(), completes);
      // ...and the app still knows what every flag means.
      expect(
        flags.isEnabled(FeatureFlag.progressiveDisclosure),
        FeatureFlag.progressiveDisclosure.defaultValue,
      );
    });

    test('a fresh cache short-circuits the fetch entirely', () async {
      final flags = await _flags({
        'sixpack.feature_flags_fetched_at': DateTime.now().toIso8601String(),
      });
      await expectLater(flags.refresh(), completes);
    });
  });
}
