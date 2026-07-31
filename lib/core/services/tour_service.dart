import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/spotlight_tour.dart';
import 'analytics_service.dart';
import 'app_preferences.dart';
import 'tour_targets.dart';

/// Roadmap Phase 2 (R1.1 · P3) · tour definitions + gating + replay.
///
/// The Testers Community observed that FormAI has *"no dynamic
/// walkthrough or tutorial"*, and they were right in a way the codebase
/// makes precise: the 19-step onboarding collects data and builds
/// commitment, and the one existing orientation surface
/// ([FirstTimeAiScenes.dashboardWelcome]) *names* the tabs in a sentence
/// that auto-closes after 8 seconds. It tells; it doesn't show.
///
/// This service adds the showing. The cinematic welcome scene is kept —
/// it carries the emotional beat, which the tour deliberately does not
/// try to replicate — and the tour runs immediately after it as the
/// functional layer.
///
/// Two entry points:
///   * [maybeStartDashboardTour] — one-shot, gated on
///     `seenDashboardTour`, called after the welcome scene resolves.
///   * [replayDashboardTour] — from the Settings row, always available.
///     A tour the user can never see again is a tour they lose the one
///     time they weren't paying attention.
class TourService {
  TourService(this._ref);

  final Ref _ref;

  /// Fires the dashboard tour the first time, then never again on its
  /// own. Safe to call on every dashboard build — the flag short-circuits.
  ///
  /// Returns `true` if the tour was actually presented.
  Future<bool> maybeStartDashboardTour(BuildContext context) async {
    final prefs = _ref.read(appPreferencesProvider);
    if (prefs.seenDashboardTour) return false;
    // Mark before presenting — matches the idempotency contract used by
    // [FirstTimeAiScenes] and [RatingMomentService]. A tour interrupted
    // by backgrounding is treated as shown; the Settings replay row is
    // the recovery path, which is part of why that row exists.
    await prefs.markSeenDashboardTour();
    if (!context.mounted) return false;
    return _present(context, source: 'first_run');
  }

  /// User-initiated replay. No gate, no cooldown, no one-shot flag.
  Future<bool> replayDashboardTour(BuildContext context) {
    return _present(context, source: 'settings');
  }

  Future<bool> _present(BuildContext context, {required String source}) async {
    final targets = _ref.read(tourTargetsProvider);
    AnalyticsService.instance
        .tourStarted(tour: _kDashboardTour, source: source);

    final completed = await showSpotlightTour(
      context,
      steps: _dashboardSteps(targets, AppLocalizations.of(context)),
      onStepShown: (index) => AnalyticsService.instance.tourStepViewed(
        tour: _kDashboardTour,
        stepIndex: index,
      ),
    );

    if (completed) {
      AnalyticsService.instance.tourCompleted(tour: _kDashboardTour);
    } else {
      AnalyticsService.instance.tourSkipped(tour: _kDashboardTour);
    }
    return completed;
  }

  /// The five steps. Ordered as a narrative — what you do today, who
  /// helps you, then the three places to look — rather than as a
  /// left-to-right sweep of the nav bar.
  ///
  /// Copy follows the Form coach voice established in
  /// `first_time_ai_scenes.dart`: second person, calm, one idea per step,
  /// no exclamation marks, no hype.
  List<SpotlightStep> _dashboardSteps(TourTargets t, AppLocalizations l10n) {
    return [
      SpotlightStep(
        title: l10n.tourPlanTitle,
        body: l10n.tourPlanBody,
        rect: () => t.clampAboveNav(TourTargets.rectOf(t.planCard)),
        radius: 20,
      ),
      SpotlightStep(
        title: l10n.tourCoachTitle,
        body: l10n.tourCoachBody,
        rect: () => t.clampAboveNav(TourTargets.rectOf(t.coachCard)),
        radius: 18,
      ),
      SpotlightStep(
        title: l10n.tourNutritionTitle,
        body: l10n.tourNutritionBody,
        rect: () => t.navItemRect(1),
        radius: 14,
        padding: 6,
      ),
      SpotlightStep(
        title: l10n.tourProgressTitle,
        body: l10n.tourProgressBody,
        rect: () => t.navItemRect(2),
        radius: 14,
        padding: 6,
      ),
      SpotlightStep(
        title: l10n.tourProfileTitle,
        body: l10n.tourProfileBody,
        rect: () => t.navItemRect(3),
        radius: 14,
        padding: 6,
      ),
    ];
  }
}

const String _kDashboardTour = 'dashboard';

final tourServiceProvider = Provider<TourService>(TourService.new);
