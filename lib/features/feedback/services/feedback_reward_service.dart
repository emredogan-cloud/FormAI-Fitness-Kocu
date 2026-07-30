import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../progress/providers/xp_provider.dart';

/// XP credited for a substantive piece of feedback. Sized to feel like
/// a real thank-you without distorting the level curve — roughly a
/// third of a completed workout.
const int kFeedbackRewardXp = 50;

/// Roadmap Phase 1 (R2.3) · the feedback-participation reward.
///
/// The Testers Community suggested rewarding users for leaving reviews.
/// Google Play's Developer Program Policy prohibits incentivising
/// ratings or reviews, so the reward is attached to the action we
/// actually want and are free to encourage: **submitting feedback**.
/// Nothing here reads, or is conditioned on, a star rating or review
/// text. The engagement benefit is fully preserved; the listing risk is
/// not taken.
///
/// Rate-limited by [AppPreferences.kFeedbackRewardCooldown] so the
/// reward can't be farmed with repeated low-effort submissions. The
/// limit applies to the *reward*, never to sending feedback — a user
/// may always submit, they just won't be paid twice in a week.
class FeedbackRewardService {
  FeedbackRewardService(this._ref);

  final Ref _ref;

  /// Records the submission and grants XP when the cooldown allows.
  /// Returns the reward that was granted, or `null` when the
  /// submission counted but no reward was due.
  ///
  /// Always increments the lifetime feedback count — that count backs
  /// the `voice_heard` badge and should reflect every contribution,
  /// rewarded or not.
  Future<FeedbackReward?> grantIfEligible() async {
    final prefs = _ref.read(appPreferencesProvider);
    await prefs.incrementFeedbackSubmittedCount();

    final now = DateTime.now();
    final last = prefs.lastFeedbackRewardAt;
    if (last != null &&
        now.difference(last) < AppPreferences.kFeedbackRewardCooldown) {
      return null;
    }

    await prefs.recordFeedbackRewardGranted(now);
    _ref.read(lifetimeXpProvider.notifier).add(kFeedbackRewardXp);
    AnalyticsService.instance.feedbackRewardGranted(xp: kFeedbackRewardXp);
    return const FeedbackReward(xp: kFeedbackRewardXp);
  }
}

class FeedbackReward {
  const FeedbackReward({required this.xp});
  final int xp;
}

final feedbackRewardProvider =
    Provider<FeedbackRewardService>(FeedbackRewardService.new);
