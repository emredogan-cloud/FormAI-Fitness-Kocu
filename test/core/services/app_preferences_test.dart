// Phase 1/2 (P-Risk) · unit tests for AppPreferences — a core service the
// audit flagged as untested (F29). Uses an in-memory SharedPreferences mock,
// so these are deterministic and need no device.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';

Future<(SharedPreferences, AppPreferences)> _mk([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final p = await SharedPreferences.getInstance();
  return (p, AppPreferences(p));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onboarding flags', () {
    test('isFirstTime defaults true; completeOnboarding flips it + stores goal',
        () async {
      final (_, prefs) = await _mk();
      expect(prefs.isFirstTime, isTrue);
      await prefs.completeOnboarding(goal: 'lean', hasEquipment: true);
      expect(prefs.isFirstTime, isFalse);
      expect(prefs.goal, 'lean');
      expect(prefs.hasEquipment, isTrue);
    });

    test('hasEquipment is null on legacy installs (key absent)', () async {
      final (_, prefs) = await _mk();
      expect(prefs.hasEquipment, isNull);
    });
  });

  group('consent (KVKK — explicit opt-in)', () {
    test('defaults are all false', () async {
      final (_, prefs) = await _mk();
      expect(prefs.consentDecisionMade, isFalse);
      expect(prefs.analyticsConsentGranted, isFalse);
      expect(prefs.crashReportingConsentGranted, isFalse);
    });

    test('setConsent persists both channels + the decided flag', () async {
      final (_, prefs) = await _mk();
      await prefs.setConsent(analytics: true, crash: false);
      expect(prefs.consentDecisionMade, isTrue);
      expect(prefs.analyticsConsentGranted, isTrue);
      expect(prefs.crashReportingConsentGranted, isFalse);
    });
  });

  group('age gate', () {
    test('ageVerified false by default; setAgeVerified stamps both', () async {
      final (_, prefs) = await _mk();
      expect(prefs.ageVerified, isFalse);
      expect(prefs.birthYear, isNull);
      await prefs.setAgeVerified(birthYear: 1995);
      expect(prefs.ageVerified, isTrue);
      expect(prefs.birthYear, 1995);
    });
  });

  group('freeze tokens', () {
    test('seeds 1 token on a fresh install', () async {
      final (_, prefs) = await _mk();
      expect(prefs.freezeTokensAvailable, 1);
      expect(prefs.freezeTokensMax, 2);
    });

    test('refill tops up to max then is a no-op within the same week',
        () async {
      final (_, prefs) = await _mk();
      expect(await prefs.refillFreezeTokensIfDue(), isTrue);
      expect(prefs.freezeTokensAvailable, 2);
      expect(await prefs.refillFreezeTokensIfDue(), isFalse);
    });
  });

  group('max streak high-water mark', () {
    test('bump is monotonic — a lower candidate is ignored', () async {
      final (_, prefs) = await _mk();
      expect(prefs.maxStreak, 0);
      await prefs.bumpMaxStreakIfHigher(5);
      expect(prefs.maxStreak, 5);
      await prefs.bumpMaxStreakIfHigher(3);
      expect(prefs.maxStreak, 5);
      await prefs.bumpMaxStreakIfHigher(10);
      expect(prefs.maxStreak, 10);
    });
  });

  group('recent coach-line window', () {
    test('caps at 7 entries, evicting the oldest', () async {
      final (_, prefs) = await _mk();
      for (var i = 1; i <= 8; i++) {
        await prefs.pushRecentCoachHash(i);
      }
      final hashes = prefs.recentCoachLineHashes;
      expect(hashes.length, 7);
      expect(hashes.contains(1), isFalse); // oldest evicted
      expect(hashes.contains(8), isTrue);
    });
  });

  group('XP ledgers (idempotent)', () {
    test('markSessionDayAwarded de-dupes; addLifetimeXp ignores <= 0',
        () async {
      final (_, prefs) = await _mk();
      await prefs.markSessionDayAwarded(3);
      await prefs.markSessionDayAwarded(3);
      await prefs.markSessionDayAwarded(5);
      expect(prefs.awardedSessionDays, {3, 5});

      expect(prefs.lifetimeXp, 0);
      await prefs.addLifetimeXp(50);
      await prefs.addLifetimeXp(-10);
      await prefs.addLifetimeXp(0);
      expect(prefs.lifetimeXp, 50);
    });
  });

  group('user metrics → plan cache invalidation', () {
    test('changing goal drops the cached 30-day plan', () async {
      final (raw, prefs) = await _mk({
        'sixpack.goal': 'old_goal',
        'sixpack.user_custom_plan_v3': 'cached-plan-blob',
      });
      await prefs.saveUserMetrics({'targetPhysique': 'new_goal'});
      expect(prefs.goal, 'new_goal');
      expect(raw.containsKey('sixpack.user_custom_plan_v3'), isFalse);
    });

    test('same goal keeps the cached plan', () async {
      final (raw, prefs) = await _mk({
        'sixpack.goal': 'same_goal',
        'sixpack.user_custom_plan_v3': 'cached-plan-blob',
      });
      await prefs.saveUserMetrics({'targetPhysique': 'same_goal'});
      expect(raw.containsKey('sixpack.user_custom_plan_v3'), isTrue);
    });
  });

  group('wizard checkpoint', () {
    test('save → load round-trips; clear removes it', () async {
      final (_, prefs) = await _mk();
      expect(prefs.loadWizardCheckpoint(), isNull);
      await prefs.saveWizardCheckpoint(stateJson: '{"step":"a"}', stepIndex: 4);
      final cp = prefs.loadWizardCheckpoint();
      expect(cp, isNotNull);
      expect(cp!.stateJson, '{"step":"a"}');
      expect(cp.stepIndex, 4);
      await prefs.clearWizardCheckpoint();
      expect(prefs.loadWizardCheckpoint(), isNull);
    });
  });
}
