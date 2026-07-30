import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';

/// Roadmap Phase 1 · the persistence layer added for the rating,
/// feedback-reward and survey subsystems.
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
  group('installedAt', () {
    test('self-seeds on first read and is stable afterwards', () async {
      final prefs = await _prefs();
      final first = prefs.installedAt;
      // Let the fire-and-forget write land.
      await Future<void>.delayed(Duration.zero);
      final second = prefs.installedAt;
      expect(second, first);
    });

    test('an existing stamp is honoured, not overwritten', () async {
      final stamped = DateTime(2026, 1, 1);
      final prefs = await _prefs({
        'sixpack.installed_at': stamped.toIso8601String(),
      });
      expect(prefs.installedAt, stamped);
    });

    test('daysSinceInstall reflects the stamp and is never negative', () async {
      final prefs = await _prefs({
        'sixpack.installed_at':
            DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
      });
      expect(prefs.daysSinceInstall, 20);

      final future = await _prefs({
        'sixpack.installed_at':
            DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      });
      expect(future.daysSinceInstall, 0);
    });

    test('a corrupt stamp degrades to now rather than throwing', () async {
      final prefs = await _prefs({'sixpack.installed_at': 'not-a-date'});
      expect(prefs.daysSinceInstall, 0);
    });
  });

  group('rating trigger ledger', () {
    test('starts empty and accumulates tokens', () async {
      final prefs = await _prefs();
      expect(prefs.firedRatingTriggers, isEmpty);
      await prefs.markRatingTriggerFired('first_workout');
      await prefs.markRatingTriggerFired('third_workout');
      expect(
        prefs.firedRatingTriggers,
        containsAll(['first_workout', 'third_workout']),
      );
    });

    test('marking the same token twice does not duplicate it', () async {
      final prefs = await _prefs();
      await prefs.markRatingTriggerFired('first_workout');
      await prefs.markRatingTriggerFired('first_workout');
      expect(prefs.firedRatingTriggers, hasLength(1));
    });

    test('recordRatingPromptShown bumps the count and stamps the clock',
        () async {
      final prefs = await _prefs();
      expect(prefs.ratingPromptCount, 0);
      expect(prefs.lastRatingPromptAt, isNull);

      final at = DateTime(2026, 7, 30, 12);
      await prefs.recordRatingPromptShown(at);

      expect(prefs.ratingPromptCount, 1);
      expect(prefs.lastRatingPromptAt, at);
    });

    test('the policy constants are the documented values', () {
      expect(AppPreferences.kMaxLifetimeRatingPrompts, 3);
      expect(AppPreferences.kRatingPromptCooldown, const Duration(days: 90));
      expect(
        AppPreferences.kRatingPromptCooldown.inDays,
        greaterThan(30),
        reason: 'must exceed Play\'s own review quota window so we never '
            'burn a quota slot on a user who just declined',
      );
    });
  });

  group('feedback participation', () {
    test('count increments and the reward clock stamps', () async {
      final prefs = await _prefs();
      expect(prefs.feedbackSubmittedCount, 0);
      expect(prefs.lastFeedbackRewardAt, isNull);

      await prefs.incrementFeedbackSubmittedCount();
      final at = DateTime(2026, 7, 30);
      await prefs.recordFeedbackRewardGranted(at);

      expect(prefs.feedbackSubmittedCount, 1);
      expect(prefs.lastFeedbackRewardAt, at);
    });
  });

  group('surveys', () {
    test('answered ids accumulate without duplication', () async {
      final prefs = await _prefs();
      await prefs.markSurveyAnswered('nps_v1');
      await prefs.markSurveyAnswered('nps_v1');
      expect(prefs.answeredSurveyIds, hasLength(1));
    });

    test('shown clock round-trips', () async {
      final prefs = await _prefs();
      final at = DateTime(2026, 7, 30, 9, 30);
      await prefs.recordSurveyShown(at);
      expect(prefs.lastSurveyShownAt, at);
    });
  });

  group('legacy migration surface', () {
    test(
        'the Phase 136 Pro rating flag is still readable so an existing '
        'user is not asked twice', () async {
      final prefs = await _prefs({
        'sixpack.seen_pro_3rd_workout_rating': true,
      });
      expect(prefs.seenPro3rdWorkoutRating, isTrue);
    });

    test('a fresh install reports the legacy flag as false', () async {
      final prefs = await _prefs();
      expect(prefs.seenPro3rdWorkoutRating, isFalse);
    });
  });
}
