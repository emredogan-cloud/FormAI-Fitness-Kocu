import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';

/// Roadmap Phase 2 · walkthrough + discovery persistence.
Future<AppPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container.read(appPreferencesProvider);
}

void main() {
  group('tour + showcase flags', () {
    test('both default to false and flip once', () async {
      final prefs = await _prefs();
      expect(prefs.seenDashboardTour, isFalse);
      expect(prefs.seenFeatureShowcase, isFalse);

      await prefs.markSeenDashboardTour();
      await prefs.markSeenFeatureShowcase();

      expect(prefs.seenDashboardTour, isTrue);
      expect(prefs.seenFeatureShowcase, isTrue);
    });
  });

  group('visited tabs', () {
    test('starts empty; first visit returns true, repeat returns false',
        () async {
      final prefs = await _prefs();
      expect(prefs.visitedTabs, isEmpty);

      expect(await prefs.markTabVisited(1), isTrue);
      expect(await prefs.markTabVisited(1), isFalse);
      expect(prefs.visitedTabs, {1});
    });

    test('accumulates across tabs without duplication', () async {
      final prefs = await _prefs();
      await prefs.markTabVisited(0);
      await prefs.markTabVisited(2);
      await prefs.markTabVisited(0);
      expect(prefs.visitedTabs, {0, 2});
    });

    test('a corrupt entry is skipped rather than crashing', () async {
      final prefs = await _prefs({
        'sixpack.visited_tabs': <String>['1', 'not-a-number', '3'],
      });
      expect(prefs.visitedTabs, {1, 3});
    });
  });

  group('dismissed tips', () {
    test('accumulate without duplication', () async {
      final prefs = await _prefs();
      await prefs.markTipDismissed('coach_unused');
      await prefs.markTipDismissed('coach_unused');
      expect(prefs.dismissedTipIds, {'coach_unused'});
    });
  });

  group('hasChattedWithCoach', () {
    String encode(List<Map<String, Object?>> turns) => jsonEncode(turns);

    test('false with no transcript', () async {
      final prefs = await _prefs();
      expect(prefs.hasChattedWithCoach, isFalse);
    });

    test(
        'false for a transcript holding ONLY the coach greeting — the '
        'whole point of the coach_unused tip is to reach that user', () async {
      final prefs = await _prefs({
        'sixpack.coach_turns_v1': encode([
          {'c': true, 't': 'Merhaba! Ben Form.'},
        ]),
      });
      expect(prefs.hasChattedWithCoach, isFalse);
    });

    test('true once a user turn exists', () async {
      final prefs = await _prefs({
        'sixpack.coach_turns_v1': encode([
          {'c': true, 't': 'Merhaba!'},
          {'c': false, 't': 'Bugün ne yapmalıyım?'},
        ]),
      });
      expect(prefs.hasChattedWithCoach, isTrue);
    });

    test('false for a user turn with empty text', () async {
      final prefs = await _prefs({
        'sixpack.coach_turns_v1': encode([
          {'c': false, 't': ''},
        ]),
      });
      expect(prefs.hasChattedWithCoach, isFalse);
    });

    test('a corrupt payload degrades to false, never throws', () async {
      final prefs = await _prefs({
        'sixpack.coach_turns_v1': 'not json at all',
      });
      expect(prefs.hasChattedWithCoach, isFalse);
    });

    test('a non-list payload degrades to false', () async {
      final prefs = await _prefs({
        'sixpack.coach_turns_v1': '{"c":false}',
      });
      expect(prefs.hasChattedWithCoach, isFalse);
    });
  });
}
