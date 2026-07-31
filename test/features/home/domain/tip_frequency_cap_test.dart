import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/domain/discovery_tips.dart';

/// Roadmap Phase 4 (C28) · the tips engine's frequency cap and the new
/// context-aware rules.
///
/// Dismissal already stops a single tip repeating. The cap is the other
/// half of "never nagging": without it, dismissing one tip immediately
/// produces the next and the dashboard becomes a queue of advice. A tip
/// should read as an observation, not a campaign.
TipContext ctx({
  int completedDays = 0,
  int currentStreak = 0,
  Set<int> visitedTabs = const {0},
  bool hasUsedCoach = false,
  bool nutritionOnboarded = false,
  int daysSinceInstall = 0,
  bool pausedMidWorkout = false,
  bool manualModeUser = false,
}) =>
    TipContext(
      completedDays: completedDays,
      currentStreak: currentStreak,
      visitedTabs: visitedTabs,
      hasUsedCoach: hasUsedCoach,
      nutritionOnboarded: nutritionOnboarded,
      daysSinceInstall: daysSinceInstall,
      pausedMidWorkout: pausedMidWorkout,
      manualModeUser: manualModeUser,
    );

final _now = DateTime(2026, 7, 31, 12);

void main() {
  group('frequency cap', () {
    test('with no history, a matching tip surfaces immediately', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
        lastShownAt: null,
        now: _now,
      );
      expect(tip?.id, 'coach_unused');
    });

    test('a NEW tip is suppressed inside the cap window', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
        lastShownAt: _now.subtract(const Duration(hours: 2)),
        now: _now,
      );
      expect(tip, isNull);
    });

    test('and surfaces once the window has passed', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
        lastShownAt: _now.subtract(kTipFrequencyCap + const Duration(hours: 1)),
        now: _now,
      );
      expect(tip?.id, 'coach_unused');
    });

    test('exactly at the boundary the tip is allowed', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
        lastShownAt: _now.subtract(kTipFrequencyCap),
        now: _now,
      );
      expect(tip?.id, 'coach_unused');
    });

    test('the tip already on screen is exempt — it must not flicker away', () {
      // Every rebuild re-runs selection. Without this exemption the
      // visible tip would vanish on the next frame after being shown.
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
        lastShownAt: _now.subtract(const Duration(minutes: 1)),
        now: _now,
        currentTipId: 'coach_unused',
      );
      expect(tip?.id, 'coach_unused');
    });

    test('the cap does not resurrect a dismissed tip', () {
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {'coach_unused'},
        lastShownAt: null,
        now: _now,
        currentTipId: 'coach_unused',
      );
      expect(tip?.id, isNot('coach_unused'));
    });

    test('omitting the clock disables the cap entirely', () {
      // Backwards-compatible for callers that do not track it.
      final tip = selectTip(
        context: ctx(completedDays: 1, visitedTabs: {0, 1, 2}),
        dismissedIds: const {},
      );
      expect(tip?.id, 'coach_unused');
    });
  });

  group('the paused-session tip', () {
    test('outranks every discovery tip', () {
      // Someone who walked away mid-session is the likeliest to churn,
      // and the likeliest to read a feature suggestion as the app
      // missing the point.
      final tip = selectTip(
        context: ctx(
          completedDays: 1,
          visitedTabs: {0},
          pausedMidWorkout: true,
        ),
        dismissedIds: const {},
      );
      expect(tip?.id, 'paused_reassurance');
    });

    test('does not fire for a user who simply has not trained', () {
      final tip = selectTip(
        context: ctx(completedDays: 0),
        dismissedIds: const {},
      );
      expect(tip?.id, isNot('paused_reassurance'));
    });

    test('is reassurance, with no call to action', () {
      final tip =
          kDiscoveryTips.firstWhere((t) => t.id == 'paused_reassurance');
      expect(tip.ctaLabel, isNull);
      expect(tip.route, isNull);
    });
  });

  group('camera-free users', () {
    test('never get camera-framing advice', () {
      // Advice about a feature they deliberately turned off.
      final tip = selectTip(
        context: ctx(
          completedDays: 2,
          visitedTabs: {0, 1, 2},
          hasUsedCoach: true,
          nutritionOnboarded: true,
          manualModeUser: true,
        ),
        dismissedIds: const {'reminder_setup'},
      );
      expect(tip?.id, isNot('camera_framing'));
    });

    test('camera users still do', () {
      final tip = selectTip(
        context: ctx(
          completedDays: 2,
          visitedTabs: {0, 1, 2},
          hasUsedCoach: true,
          nutritionOnboarded: true,
        ),
        dismissedIds: const {'reminder_setup'},
      );
      expect(tip?.id, 'camera_framing');
    });
  });

  group('the nutrition-wizard tip', () {
    test('fires for someone who looked but did not finish', () {
      final tip = selectTip(
        context: ctx(
          completedDays: 4,
          visitedTabs: {0, 1, 2},
          hasUsedCoach: true,
        ),
        dismissedIds: const {'reminder_setup'},
      );
      expect(tip?.id, 'nutrition_wizard_incomplete');
    });

    test('stops once the wizard is done', () {
      final tip = selectTip(
        context: ctx(
          completedDays: 4,
          visitedTabs: {0, 1, 2},
          hasUsedCoach: true,
          nutritionOnboarded: true,
        ),
        dismissedIds: const {'reminder_setup'},
      );
      expect(tip?.id, isNot('nutrition_wizard_incomplete'));
    });
  });

  group('catalogue integrity', () {
    test('tip ids are unique — they are the dismissal ledger keys', () {
      final ids = kDiscoveryTips.map((t) => t.id).toSet();
      expect(ids.length, kDiscoveryTips.length);
    });

    test('every tip has non-empty copy', () {
      for (final tip in kDiscoveryTips) {
        expect(tip.body.trim(), isNotEmpty, reason: tip.id);
      }
    });

    test('a tip with a CTA label also has a route, and vice versa', () {
      // A button that goes nowhere, or a destination with no way to
      // reach it, are both broken promises.
      for (final tip in kDiscoveryTips) {
        expect((tip.ctaLabel == null) == (tip.route == null), isTrue,
            reason: tip.id);
      }
    });
  });
}
