import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/disclosure_providers.dart';
import 'package:sixpack_ai/core/services/progressive_disclosure.dart';
import 'package:sixpack_ai/core/services/unlock_announcer.dart';

/// Roadmap Phase 4 (R1.3) · the upgrade path.
///
/// The roadmap's regression requirement for this phase is one sentence:
/// "users mid-journey at upgrade time are not re-locked out of anything
/// they already had." Introducing a schedule to someone on day 40 would
/// take away surfaces they use daily — the single failure this system
/// cannot have. These tests are that sentence, executable.
Future<AppPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container.read(appPreferencesProvider);
}

Map<String, Object> _installedDaysAgo(int days) => {
      'sixpack.installed_at':
          DateTime.now().subtract(Duration(days: days)).toIso8601String(),
    };

void main() {
  group('who gets grandfathered', () {
    test('a brand-new install does NOT — it is the cohort the schedule is for',
        () async {
      final prefs = await _prefs(_installedDaysAgo(0));
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      expect(prefs.disclosureGrandfathered, isFalse);
    });

    test('an install older than a day does', () async {
      final prefs = await _prefs(_installedDaysAgo(1));
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      expect(prefs.disclosureGrandfathered, isTrue);
    });

    test('a same-day user who already trained does', () async {
      // Installed today but with a session logged: real use, and the
      // day count alone would have missed them.
      final prefs = await _prefs(_installedDaysAgo(0));
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 1);
      expect(prefs.disclosureGrandfathered, isTrue);
    });

    test('a long-standing user does', () async {
      final prefs = await _prefs(_installedDaysAgo(40));
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 12);
      expect(prefs.disclosureGrandfathered, isTrue);
    });
  });

  group('the flag is a one-way door', () {
    test('it is never cleared once set', () async {
      final prefs = await _prefs({
        ..._installedDaysAgo(0),
        'sixpack.disclosure_grandfathered': true,
      });
      // A fresh-looking state must not un-grandfather someone: that
      // would re-lock a user who already had everything.
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      expect(prefs.disclosureGrandfathered, isTrue);
    });

    test('repeated calls are idempotent', () async {
      final prefs = await _prefs(_installedDaysAgo(5));
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      await applyDisclosureGrandfathering(prefs: prefs, completedSessions: 0);
      expect(prefs.disclosureGrandfathered, isTrue);
    });
  });

  group('what grandfathering buys', () {
    test('every capability is open on day 0', () {
      const s = DisclosureState(
        daysSinceInstall: 0,
        completedSessions: 0,
        manuallyUnlocked: {},
        grandfathered: true,
      );
      for (final capability in Capability.values) {
        expect(isUnlocked(capability, s), isTrue, reason: capability.key);
      }
    });

    test('and nothing is announced as new', () {
      // Telling a 40-day user that Gelişim "just unlocked" would be the
      // app noticing something they have been using for weeks.
      const s = DisclosureState(
        daysSinceInstall: 0,
        completedSessions: 0,
        manuallyUnlocked: {},
        grandfathered: true,
      );
      expect(newlyUnlocked(previous: s, current: s), isEmpty);
    });
  });

  group('unlock announcement copy', () {
    test('names the capability', () {
      final body = UnlockAnnouncer.announcementBody(Capability.nutrition);
      expect(body, contains(Capability.nutrition.title));
      expect(body, contains('yeni bir şey açıldı'));
    });

    test('uses the name when there is one', () {
      final body = UnlockAnnouncer.announcementBody(
        Capability.progress,
        firstName: 'Deniz',
      );
      expect(body, startsWith('Deniz,'));
    });

    test('stays grammatical with no name', () {
      final body = UnlockAnnouncer.announcementBody(Capability.progress);
      expect(body, startsWith('Bugün'));
      expect(body, isNot(contains(', bugün')));
    });

    test('mentions the streak only when there is one worth mentioning', () {
      expect(
        UnlockAnnouncer.announcementBody(Capability.badges, streakDays: 1),
        isNot(contains('serin')),
      );
      expect(
        UnlockAnnouncer.announcementBody(Capability.badges, streakDays: 4),
        contains('4 günlük serin'),
      );
    });

    test('a blank name is treated as no name, not as an empty prefix', () {
      final body = UnlockAnnouncer.announcementBody(
        Capability.badges,
        firstName: '   ',
      );
      expect(body, startsWith('Bugün'));
    });

    test('every capability produces usable copy', () {
      for (final capability in Capability.values) {
        final body = UnlockAnnouncer.announcementBody(
          capability,
          firstName: 'Efe',
          streakDays: 3,
        );
        expect(body.trim(), isNotEmpty, reason: capability.key);
        expect(body, contains(capability.blurb), reason: capability.key);
      }
    });
  });
}
