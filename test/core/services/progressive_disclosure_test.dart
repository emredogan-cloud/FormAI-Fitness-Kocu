import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/progressive_disclosure.dart';

/// Roadmap Phase 4 (R1.3) · the unlock schedule.
///
/// Two properties matter more than any individual threshold:
///
///   * **Nobody is ever re-locked.** Not by the kill switch, not by
///     grandfathering, not by a manual unlock, and not by the passage of
///     time. Taking a surface away from someone who had it is the one
///     failure this system cannot be allowed to have.
///   * **Effort beats waiting.** A user who trains hard reaches
///     everything sooner than the calendar would allow, because making
///     them wait would punish exactly the behaviour the app wants.
DisclosureState state({
  int days = 0,
  int sessions = 0,
  Set<String> manual = const {},
  bool enabled = true,
  bool grandfathered = false,
}) =>
    DisclosureState(
      daysSinceInstall: days,
      completedSessions: sessions,
      manuallyUnlocked: manual,
      enabled: enabled,
      grandfathered: grandfathered,
    );

void main() {
  group('the catalogue', () {
    test('keys are unique and snake_case — they are persisted ledger keys', () {
      final keys = Capability.values.map((c) => c.key).toSet();
      expect(keys.length, Capability.values.length);
      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final c in Capability.values) {
        expect(pattern.hasMatch(c.key), isTrue, reason: c.key);
      }
    });

    test('fromKey round-trips and rejects unknowns', () {
      for (final c in Capability.values) {
        expect(Capability.fromKey(c.key), c);
      }
      expect(Capability.fromKey('nope'), isNull);
    });

    test('every capability has user-facing copy', () {
      for (final c in Capability.values) {
        expect(c.title.trim(), isNotEmpty, reason: c.key);
        expect(c.blurb.trim(), isNotEmpty, reason: c.key);
      }
    });

    test('every capability is reachable — a route or a tab, never neither', () {
      // A capability the hub can list but not open would be a promise
      // the UI cannot keep.
      for (final c in Capability.values) {
        expect(
          c.route != null || c.tabIndex != null,
          isTrue,
          reason: '${c.key} has no way to open it',
        );
      }
    });

    test('declaration order matches schedule order', () {
      // The hub and the "what arrives next" copy both rely on this.
      var lastDay = -1;
      for (final c in Capability.values) {
        expect(c.unlockDay, greaterThanOrEqualTo(lastDay), reason: c.key);
        lastDay = c.unlockDay;
      }
    });

    test('nothing unlocks on day 0 — day 0 is the workout and the coach', () {
      for (final c in Capability.values) {
        expect(c.unlockDay, greaterThan(0), reason: c.key);
      }
    });
  });

  group('the day schedule', () {
    test('a brand-new install has everything still to come', () {
      final s = state();
      expect(unlockedCapabilities(s), isEmpty);
      expect(lockedCapabilities(s).length, Capability.values.length);
    });

    test('each capability opens on its own day', () {
      for (final c in Capability.values) {
        expect(isUnlocked(c, state(days: c.unlockDay - 1)), isFalse,
            reason: '${c.key} opened early');
        expect(isUnlocked(c, state(days: c.unlockDay)), isTrue,
            reason: '${c.key} did not open on schedule');
      }
    });

    test('a long-dormant user has everything', () {
      final s = state(days: 365);
      expect(unlockedCapabilities(s).length, Capability.values.length);
      expect(lockedCapabilities(s), isEmpty);
    });
  });

  group('effort unlocks faster than time', () {
    test('sessions alone can open a capability on day 0', () {
      // Three workouts on install day: the badge surface is earned.
      expect(
          isUnlocked(Capability.badges, state(days: 0, sessions: 3)), isTrue);
    });

    test('the two paths are independent — either is sufficient', () {
      for (final c in Capability.values) {
        expect(isUnlocked(c, state(sessions: c.unlockSessions)), isTrue,
            reason: '${c.key} ignored the session path');
        expect(isUnlocked(c, state(days: c.unlockDay)), isTrue,
            reason: '${c.key} ignored the day path');
      }
    });

    test('a heavy first day outruns the calendar', () {
      final s = state(days: 0, sessions: 10);
      expect(unlockedCapabilities(s).length, Capability.values.length);
    });
  });

  group('nobody is ever re-locked', () {
    test('the kill switch unlocks everything', () {
      final s = state(days: 0, sessions: 0, enabled: false);
      expect(unlockedCapabilities(s).length, Capability.values.length);
      expect(lockedCapabilities(s), isEmpty);
    });

    test('a grandfathered user has everything on day 0', () {
      // The upgrade case: someone mid-journey when disclosure shipped.
      final s = state(days: 0, sessions: 0, grandfathered: true);
      expect(unlockedCapabilities(s).length, Capability.values.length);
    });

    test('a manual unlock is permanent and specific', () {
      final s = state(manual: {Capability.referral.key});
      expect(isUnlocked(Capability.referral, s), isTrue);
      // ...and doesn't leak into its neighbours.
      expect(isUnlocked(Capability.calendar, s), isFalse);
    });

    test('an unknown key in the manual ledger is harmless', () {
      final s = state(manual: {'a_capability_that_was_removed'});
      expect(unlockedCapabilities(s), isEmpty);
    });

    test('unlocked capabilities only ever grow as days pass', () {
      var previous = 0;
      for (var day = 0; day <= 30; day++) {
        final count = unlockedCapabilities(state(days: day)).length;
        expect(count, greaterThanOrEqualTo(previous), reason: 'day $day');
        previous = count;
      }
    });
  });

  group('newlyUnlocked', () {
    test('reports only the difference between two states', () {
      final before = state(days: 2);
      final after = state(days: 3);
      final fresh = newlyUnlocked(previous: before, current: after);
      expect(fresh.map((c) => c.key), contains(Capability.progress.key));
      expect(fresh.map((c) => c.key), isNot(contains(Capability.nutrition.key)),
          reason: 'nutrition was already open at day 2');
    });

    test('is empty when nothing changed', () {
      final s = state(days: 5);
      expect(newlyUnlocked(previous: s, current: s), isEmpty);
    });

    test('a week away can surface several at once', () {
      final fresh = newlyUnlocked(
        previous: state(days: 0),
        current: state(days: 7),
      );
      expect(fresh.length, greaterThan(1));
    });
  });

  group('unlockHint', () {
    test('is null for anything already open', () {
      for (final c in Capability.values) {
        expect(unlockHint(c, state(days: 365)), isNull, reason: c.key);
      }
    });

    test('names the shorter road — training, when training is closer', () {
      // Day 0, 2 sessions done: badges need 1 more session or 5 days.
      final hint = unlockHint(Capability.badges, state(days: 0, sessions: 2));
      expect(hint, '1 antrenman sonra açılıyor');
    });

    test('falls back to days when the calendar is closer', () {
      // Day 6, no sessions: calendar is 1 day away, 5 sessions away.
      final hint = unlockHint(Capability.calendar, state(days: 6));
      expect(hint, 'Yarın açılıyor');
    });

    test('every locked capability produces non-empty copy', () {
      for (var day = 0; day <= 14; day++) {
        for (final c in lockedCapabilities(state(days: day))) {
          final hint = unlockHint(c, state(days: day));
          expect(hint, isNotNull, reason: '${c.key} on day $day');
          expect(hint!.trim(), isNotEmpty, reason: '${c.key} on day $day');
        }
      }
    });
  });
}
