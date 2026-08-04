import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';
import 'analytics_service.dart';
import 'app_preferences.dart';
import 'content_sync_service.dart';
import 'lifecycle_campaigns.dart';
import 'notification_service.dart';

/// Roadmap Phase 14 (C50) · the one place a campaign gets scheduled.
///
/// # Why this is a single function and not a listener per campaign
///
/// Six campaigns with six triggers would be six places that each know
/// their own rule and none that knows the total, which is precisely how
/// a user ends up with three notifications on the day they lapse.
/// [LifecycleCampaigns.nextCampaign] answers "what, if anything" against
/// the whole history, and this runs it exactly once per evaluation.
///
/// # Why it runs on resume rather than on a timer
///
/// The app cannot execute Dart at an arbitrary future moment without a
/// background isolate, and `smart_reminder_scheduler.dart` already
/// carries the argument for not shipping one: pre-bake the right thing
/// whenever state changes, and accept that a user who never opens the
/// app again gets whatever was last scheduled. For campaigns that is
/// the correct trade — a win-back for somebody who never returns is a
/// notification nobody reads either way.
///
/// # What "sent" means here
///
/// `campaignSent` fires when a notification is SCHEDULED. The app cannot
/// observe the OS actually showing it, and an event named `delivered`
/// would be a claim this code is not in a position to make. The ledger
/// records the same moment, so the cap counts scheduling rather than
/// delivery — which is the conservative direction: a notification that
/// was scheduled and suppressed by the OS still costs the user's
/// allowance, and under-sending is the failure this feature can afford.
class LifecycleCampaignScheduler {
  const LifecycleCampaignScheduler(this._prefs, this._content);

  final AppPreferences _prefs;
  final ContentSyncService _content;

  /// Evaluates and schedules at most one campaign.
  ///
  /// Returns what was scheduled, or null. Never throws: a campaign is
  /// the least important thing the app does and must not be able to
  /// break a resume.
  Future<LifecycleCampaign?> evaluate({DateTime? now}) async {
    try {
      final moment = now ?? DateTime.now();
      final due = nextCampaign(
        now: moment,
        lastWorkoutAt: _prefs.lastWorkoutAt,
        streakDays: _prefs.maxStreak,
        history: _prefs.campaignLedger,
        hasUnseenMilestone: false,
        hasUnseenContent: _hasUnseenContent(moment),
      );
      if (due == null) return null;

      await NotificationService.instance.scheduleCampaign(due);
      await _prefs.recordCampaignSent(due, moment);
      unawaited(AnalyticsService.instance.campaignSent(campaign: due.token));
      AppLogger.info('campaign scheduled: ${due.token}',
          category: 'notifications');
      return due;
    } catch (e, st) {
      AppLogger.error('campaign evaluation failed', e,
          stackTrace: st, category: 'notifications');
      return null;
    }
  }

  /// Whether a live content drop exists that this device has not shown
  /// a badge for.
  ///
  /// Reads the same cache and the same seen-set the discovery section
  /// uses, so a user who has already looked is not notified about what
  /// they just read. Targeting is deliberately NOT applied: a
  /// notification is a coarser instrument than a card, and the audience
  /// filter needs a `BuildContext` for the locale that this has no
  /// business holding.
  bool _hasUnseenContent(DateTime now) {
    final seen = _prefs.seenContentDrops;
    return _content.drops().any((d) => d.isLive(now) && !seen.contains(d.slug));
  }

  /// The user opened the app from a campaign notification.
  ///
  /// Records the campaign so [markConverted] can fire later, when the
  /// thing the campaign asked for actually happens. An open is
  /// attention; a conversion is a workout, and conflating them would
  /// make the campaign look like it worked every time somebody tapped
  /// it out of curiosity.
  Future<void> markOpened(String token) async {
    unawaited(AnalyticsService.instance.campaignOpened(campaign: token));
    await _prefs.setPendingCampaignConversion(token);
  }

  /// A session finished. If it followed a campaign open, that campaign
  /// converted.
  ///
  /// One conversion per open, because the pending token is cleared —
  /// otherwise a single win-back would claim credit for every workout
  /// the user ever did afterwards.
  Future<void> markConverted() async {
    final pending = _prefs.pendingCampaignConversion;
    if (pending == null) return;
    await _prefs.setPendingCampaignConversion(null);
    unawaited(AnalyticsService.instance.campaignConverted(campaign: pending));
  }
}

final lifecycleCampaignSchedulerProvider = Provider<LifecycleCampaignScheduler>(
  (ref) => LifecycleCampaignScheduler(
    ref.watch(appPreferencesProvider),
    ref.watch(contentSyncServiceProvider),
  ),
);
