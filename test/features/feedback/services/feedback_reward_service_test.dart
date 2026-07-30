import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/feedback/services/feedback_reward_service.dart';
import 'package:sixpack_ai/features/progress/providers/xp_provider.dart';

/// Roadmap Phase 1 (R2.3) · the feedback-participation reward.
///
/// The policy under test has a compliance dimension, not just a
/// behavioural one: the reward must attach to *submitting feedback* and
/// must never read a rating or review, because Google Play prohibits
/// incentivising reviews. The service's API surface is the guarantee —
/// `grantIfEligible()` takes no rating argument at all.
Future<ProviderContainer> _container([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('a first submission increments the count and grants XP', () async {
    final container = await _container();
    addTearDown(container.dispose);
    final prefs = container.read(appPreferencesProvider);

    expect(prefs.feedbackSubmittedCount, 0);
    expect(container.read(lifetimeXpProvider), 0);

    final reward =
        await container.read(feedbackRewardProvider).grantIfEligible();

    expect(reward, isNotNull);
    expect(reward!.xp, kFeedbackRewardXp);
    expect(prefs.feedbackSubmittedCount, 1);
    expect(container.read(lifetimeXpProvider), kFeedbackRewardXp);
  });

  test(
      'a second submission inside the cooldown still counts but is not '
      'rewarded — the reward is rate-limited, sending feedback never is',
      () async {
    final container = await _container();
    addTearDown(container.dispose);
    final prefs = container.read(appPreferencesProvider);
    final service = container.read(feedbackRewardProvider);

    await service.grantIfEligible();
    final second = await service.grantIfEligible();

    expect(second, isNull, reason: 'inside the 7-day cooldown');
    expect(
      prefs.feedbackSubmittedCount,
      2,
      reason: 'every contribution counts toward the badge, rewarded or not',
    );
    expect(
      container.read(lifetimeXpProvider),
      kFeedbackRewardXp,
      reason: 'XP was paid exactly once',
    );
  });

  test('a submission past the cooldown is rewarded again', () async {
    final stale = DateTime.now()
        .subtract(AppPreferences.kFeedbackRewardCooldown)
        .subtract(const Duration(days: 1));
    final container = await _container({
      'sixpack.feedback_last_reward_at': stale.toIso8601String(),
      'sixpack.feedback_submitted_count': 1,
    });
    addTearDown(container.dispose);

    final reward =
        await container.read(feedbackRewardProvider).grantIfEligible();

    expect(reward, isNotNull);
    expect(container.read(appPreferencesProvider).feedbackSubmittedCount, 2);
  });

  test('the reward XP is a sane fraction of the level curve', () {
    // Sized to read as a thank-you, not as a shortcut past the game.
    expect(kFeedbackRewardXp, greaterThan(0));
    expect(kFeedbackRewardXp, lessThanOrEqualTo(100));
  });
}
