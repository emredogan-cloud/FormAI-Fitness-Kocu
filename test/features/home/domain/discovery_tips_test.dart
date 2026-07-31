import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/domain/discovery_tips.dart';

/// Roadmap Phase 2 (C28) · the contextual-tip selection policy.
TipContext ctx({
  int completedDays = 0,
  int currentStreak = 0,
  Set<int> visitedTabs = const {0},
  bool hasUsedCoach = false,
  bool nutritionOnboarded = false,
  int daysSinceInstall = 0,
}) {
  return TipContext(
    completedDays: completedDays,
    currentStreak: currentStreak,
    visitedTabs: visitedTabs,
    hasUsedCoach: hasUsedCoach,
    nutritionOnboarded: nutritionOnboarded,
    daysSinceInstall: daysSinceInstall,
  );
}

void main() {
  group('selection', () {
    test('a brand-new user with no workouts gets no tip', () {
      expect(
        selectTip(context: ctx(), dismissedIds: const {}),
        isNull,
      );
    });

    test('a user who trained but never opened the coach gets the coach tip',
        () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
      );
      expect(tip?.id, 'coach_unused');
    });

    test('the coach tip stops once the user has actually chatted', () {
      final tip = selectTip(
        context: ctx(
          completedDays: 1,
          hasUsedCoach: true,
          visitedTabs: {0, 1, 2},
        ),
        dismissedIds: const {},
      );
      expect(tip?.id, isNot('coach_unused'));
    });

    test('declaration order is priority order', () {
      // This context satisfies coach_unused AND nutrition_unvisited AND
      // camera_framing; the earliest-declared wins.
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0}),
        dismissedIds: const {},
      );
      expect(tip?.id, 'coach_unused');
    });

    test('dismissing the top tip promotes the next match', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0}),
        dismissedIds: const {'coach_unused'},
      );
      expect(tip?.id, 'nutrition_unvisited');
    });

    test('a dismissed tip is never returned again — dismissal is permanent',
        () {
      final allIds = kDiscoveryTips.map((t) => t.id).toSet();
      final tip = selectTip(
        context: ctx(
          completedDays: 10,
          currentStreak: 5,
          visitedTabs: {0},
          daysSinceInstall: 30,
        ),
        dismissedIds: allIds,
      );
      expect(tip, isNull);
    });

    test('the progress tip needs a streak, not just completions', () {
      final noStreak = selectTip(
        context: ctx(completedDays: 5, visitedTabs: {0, 1}),
        dismissedIds: const {'coach_unused', 'nutrition_unvisited'},
      );
      expect(noStreak?.id, isNot('progress_unvisited'));

      final withStreak = selectTip(
        context: ctx(completedDays: 5, currentStreak: 2, visitedTabs: {0, 1}),
        dismissedIds: const {'coach_unused', 'nutrition_unvisited'},
      );
      expect(withStreak?.id, 'progress_unvisited');
    });

    test('the reminder tip waits for both engagement and elapsed days', () {
      final dismissed = {
        'coach_unused',
        'nutrition_unvisited',
        'progress_unvisited',
      };
      // 2 workouts but installed today — too early.
      expect(
        selectTip(
          context: ctx(
            completedDays: 2,
            visitedTabs: {0, 1, 2},
            hasUsedCoach: true,
            daysSinceInstall: 1,
          ),
          dismissedIds: dismissed,
        )?.id,
        isNot('reminder_setup'),
      );
      // 2 workouts and 3 days in — fires.
      expect(
        selectTip(
          context: ctx(
            completedDays: 2,
            visitedTabs: {0, 1, 2},
            hasUsedCoach: true,
            daysSinceInstall: 3,
          ),
          dismissedIds: dismissed,
        )?.id,
        'reminder_setup',
      );
    });

    test('the camera-framing tip is early-only and retires after 3 days', () {
      final dismissed = {
        'coach_unused',
        'nutrition_unvisited',
        'progress_unvisited',
        'reminder_setup',
      };
      expect(
        selectTip(
          context: ctx(
            completedDays: 2,
            visitedTabs: {0, 1, 2},
            hasUsedCoach: true,
          ),
          dismissedIds: dismissed,
        )?.id,
        'camera_framing',
      );
      expect(
        selectTip(
          context: ctx(
            completedDays: 9,
            visitedTabs: {0, 1, 2},
            hasUsedCoach: true,
            nutritionOnboarded: true,
          ),
          dismissedIds: dismissed,
        )?.id,
        isNot('camera_framing'),
        reason: 'a user 9 sessions in does not need framing basics',
      );
    });

    test('an explicit catalog overrides the shipped one', () {
      final custom = [
        DiscoveryTip(id: 'x', body: 'b', matches: (_) => true),
      ];
      final tip = selectTip(
        context: ctx(),
        dismissedIds: const {},
        catalog: custom,
      );
      expect(tip?.id, 'x');
    });
  });

  group('shipped catalogue integrity', () {
    test('tip ids are unique — they are the dismissal-ledger keys', () {
      final ids = kDiscoveryTips.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every tip has substantive body copy', () {
      for (final tip in kDiscoveryTips) {
        expect(tip.body.length, greaterThan(30), reason: tip.id);
      }
    });

    test('a CTA label and a route are all-or-nothing', () {
      for (final tip in kDiscoveryTips) {
        expect(
          tip.ctaLabel == null,
          tip.route == null,
          reason: '${tip.id}: a label without a route (or vice versa) '
              'renders a dead button',
        );
      }
    });

    test('every route is an absolute in-app path', () {
      for (final tip in kDiscoveryTips) {
        final route = tip.route;
        if (route == null) continue;
        expect(route.startsWith('/'), isTrue, reason: tip.id);
      }
    });
  });
}
