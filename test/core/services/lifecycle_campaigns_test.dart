import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/lifecycle_campaigns.dart';

/// Roadmap Phase 14 (C50) · the campaigns, and the cap that is the point.
void main() {
  final now = DateTime(2026, 8, 4, 18);
  DateTime ago(Duration d) => now.subtract(d);
  DateTime daysAgo(int d) => ago(Duration(days: d));

  group('what is due', () {
    LifecycleCampaign? due({
      DateTime? lastWorkout,
      int streak = 0,
      bool milestone = false,
      bool content = false,
    }) =>
        dueCampaign(
          now: now,
          lastWorkoutAt: lastWorkout,
          streakDays: streak,
          hasUnseenMilestone: milestone,
          hasUnseenContent: content,
        );

    test('a user who never trained gets no win-back', () {
      // Onboarding owns them. Winning back somebody never won is the
      // wrong message entirely.
      expect(due(lastWorkout: null), isNull);
      expect(due(lastWorkout: null, content: true), isNull);
    });

    test('the win-back windows fire at 7, 14 and 30 days', () {
      expect(due(lastWorkout: daysAgo(6)), isNull);
      expect(due(lastWorkout: daysAgo(7)), LifecycleCampaign.winBack7);
      expect(due(lastWorkout: daysAgo(13)), LifecycleCampaign.winBack7);
      expect(due(lastWorkout: daysAgo(14)), LifecycleCampaign.winBack14);
      expect(due(lastWorkout: daysAgo(29)), LifecycleCampaign.winBack14);
      expect(due(lastWorkout: daysAgo(30)), LifecycleCampaign.winBack30);
    });

    test('the longest-lapsed user gets the WIDEST window, not the first', () {
      // Reading the thresholds in ascending order is a bug that only
      // shows up for the users who have been gone longest — which is to
      // say, the ones the campaign exists for.
      expect(due(lastWorkout: daysAgo(200)), LifecycleCampaign.winBack30);
    });

    test('nothing fires past 30 days beyond the last win-back', () {
      // There is deliberately no fourth. A user 30 days gone who does
      // not return is not reachable by another notification.
      final campaigns = {
        for (var d = 30; d < 400; d += 17) due(lastWorkout: daysAgo(d)),
      };
      expect(campaigns, {LifecycleCampaign.winBack30});
    });

    test('a milestone outranks everything', () {
      expect(
        due(lastWorkout: daysAgo(30), streak: 9, milestone: true),
        LifecycleCampaign.milestone,
      );
    });

    test('streak risk needs a streak and a 40-hour gap', () {
      expect(
          due(lastWorkout: ago(const Duration(hours: 39)), streak: 5), isNull);
      expect(due(lastWorkout: ago(const Duration(hours: 41)), streak: 5),
          LifecycleCampaign.streakRisk);
      // No streak, nothing to warn about.
      expect(due(lastWorkout: ago(const Duration(hours: 41))), isNull);
    });

    test('streak risk stops once a win-back takes over', () {
      // Otherwise a user seven days gone is told about a streak they
      // lost six days ago.
      expect(
          due(lastWorkout: daysAgo(7), streak: 5), LifecycleCampaign.winBack7);
    });

    test('content is the lowest priority and only for active users', () {
      expect(due(lastWorkout: daysAgo(1), content: true),
          LifecycleCampaign.contentDrop);
      // A lapsed user gets the win-back instead — the point is to get
      // them back, not to browse.
      expect(due(lastWorkout: daysAgo(9), content: true),
          LifecycleCampaign.winBack7);
    });

    test('a future last-workout timestamp yields nothing, not a negative', () {
      // Clock skew and timezone edits both produce this.
      expect(due(lastWorkout: now.add(const Duration(days: 2))), isNull);
    });
  });

  group('the global cap', () {
    test('two in a week is the ceiling', () {
      final history = [
        CampaignSend(LifecycleCampaign.milestone, daysAgo(6)),
        CampaignSend(LifecycleCampaign.contentDrop, daysAgo(3)),
      ];
      expect(
        canSend(
            campaign: LifecycleCampaign.winBack7, history: history, now: now),
        isFalse,
      );
    });

    test('the week is a ROLLING one', () {
      final history = [
        CampaignSend(LifecycleCampaign.milestone, daysAgo(8)),
        CampaignSend(LifecycleCampaign.contentDrop, daysAgo(3)),
      ];
      expect(
        canSend(
            campaign: LifecycleCampaign.winBack7, history: history, now: now),
        isTrue,
        reason: 'the 8-day-old send has aged out',
      );
    });

    test('two allowed sends cannot both land on the same afternoon', () {
      // A weekly count alone passes this and it is the exact experience
      // the cap exists to prevent.
      final history = [
        CampaignSend(
            LifecycleCampaign.milestone, ago(const Duration(hours: 3))),
      ];
      expect(
        canSend(
            campaign: LifecycleCampaign.winBack7, history: history, now: now),
        isFalse,
      );
      expect(
        canSend(
          campaign: LifecycleCampaign.winBack7,
          history: [
            CampaignSend(
                LifecycleCampaign.milestone, ago(const Duration(hours: 49))),
          ],
          now: now,
        ),
        isTrue,
      );
    });

    test('each campaign also has its own cooldown', () {
      final history = [
        CampaignSend(LifecycleCampaign.streakRisk, daysAgo(4)),
      ];
      expect(
        canSend(
            campaign: LifecycleCampaign.streakRisk, history: history, now: now),
        isFalse,
        reason: 'streak risk repeats no sooner than weekly',
      );
      expect(
        canSend(
            campaign: LifecycleCampaign.milestone, history: history, now: now),
        isTrue,
        reason: 'a different campaign is only bound by the global rules',
      );
    });

    test('an empty history allows anything', () {
      for (final c in LifecycleCampaign.values) {
        expect(canSend(campaign: c, history: const [], now: now), isTrue);
      }
    });

    test('a send stamped in the future is ignored, not counted', () {
      final history = [
        CampaignSend(
            LifecycleCampaign.milestone, now.add(const Duration(days: 1))),
      ];
      expect(
        canSend(
            campaign: LifecycleCampaign.winBack7, history: history, now: now),
        isTrue,
      );
    });
  });

  group('nextCampaign is the only door', () {
    test('due and allowed sends', () {
      expect(
        nextCampaign(
          now: now,
          lastWorkoutAt: daysAgo(15),
          streakDays: 0,
          history: const [],
        ),
        LifecycleCampaign.winBack14,
      );
    });

    test('due but capped sends nothing, and does not fall through', () {
      // The tempting bug: if the cap blocks the due campaign, try the
      // next one down. That turns a cap into a menu.
      final result = nextCampaign(
        now: now,
        lastWorkoutAt: daysAgo(15),
        streakDays: 0,
        hasUnseenContent: true,
        history: [
          CampaignSend(
              LifecycleCampaign.milestone, ago(const Duration(hours: 2))),
        ],
      );
      expect(result, isNull);
    });

    test('nothing due sends nothing', () {
      expect(
        nextCampaign(
          now: now,
          lastWorkoutAt: daysAgo(1),
          streakDays: 3,
          history: const [],
        ),
        isNull,
      );
    });
  });

  test('every campaign token is unique and stable', () {
    // They are analytics dimensions. A duplicate silently merges two
    // campaigns' numbers.
    final tokens = LifecycleCampaign.values.map((c) => c.token).toSet();
    expect(tokens, hasLength(LifecycleCampaign.values.length));
    expect(tokens, contains('win_back_30'));
  });
}
