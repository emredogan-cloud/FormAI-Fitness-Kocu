import 'package:posthog_flutter/posthog_flutter.dart';

import '../utils/app_logger.dart';
import 'consent_state.dart';

/// Phase 42: centralised event dictionary for SixPack AI.
///
/// Why a fasad instead of calling PostHog directly at call sites:
///
///   1. Typed methods per event — compile-time safety, autocomplete,
///      zero chance of a typo like `"onbaording_step_completd"` shipping
///      to prod.
///   2. One place to rename / scrub property names when the privacy
///      policy evolves.
///   3. Gracefully no-ops in dev builds when PostHog keys are missing,
///      so CI + simulator runs don't emit phantom events.
///
/// Initialised once from `_BootGate._init` (see `main.dart`); use the
/// singleton `AnalyticsService.instance` everywhere downstream.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _enabled = false;

  /// Reads POSTHOG_API_KEY / POSTHOG_HOST from `.env`. If the key is
  /// missing we stay disabled — every `_capture` call becomes a cheap
  /// no-op. Non-fatal init errors are logged but never thrown.
  Future<void> init({required String apiKey, required String host}) async {
    if (apiKey.isEmpty) {
      AppLogger.warning(
        'PostHog API key missing — analytics disabled',
        category: 'analytics',
      );
      return;
    }
    try {
      final config = PostHogConfig(apiKey)..host = host;
      await Posthog().setup(config);
      _enabled = true;
      // Phase 138 · H-2. If the consent screen has already run and
      // the user declined analytics, the SDK is configured but
      // immediately disabled. `setEnabled` is also exposed so the
      // consent screen can flip the switch at decision time without
      // requiring an app restart.
      if (!ConsentState.analyticsGranted) {
        await Posthog().disable();
      }
      AppLogger.info(
        'PostHog initialised (consent=${ConsentState.analyticsGranted})',
        category: 'analytics',
      );
    } catch (e, st) {
      AppLogger.error(
        'PostHog init failed',
        e,
        stackTrace: st,
        category: 'analytics',
      );
    }
  }

  /// Phase 138 · H-2. Called from the consent screen after the user
  /// makes a decision. Toggles the runtime gate so subsequent
  /// `_capture` calls are dropped (or resume) without an app
  /// restart. `enable=true` also flushes any queued events that
  /// PostHog buffered while disabled.
  Future<void> setEnabled(bool enabled) async {
    if (!_enabled) return;
    try {
      if (enabled) {
        await Posthog().enable();
      } else {
        await Posthog().disable();
      }
    } catch (e, st) {
      AppLogger.warning(
        'PostHog setEnabled($enabled) failed',
        category: 'analytics',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  Future<void> _capture(String event, [Map<String, Object>? props]) async {
    if (!_enabled) return;
    // Phase 138 · H-2. Defence in depth — PostHog's own opt-out
    // gate is the primary lever, but a misfiring `disable()` call
    // shouldn't leak events. Short-circuit at the facade too.
    if (!ConsentState.analyticsGranted) return;
    try {
      await Posthog().capture(eventName: event, properties: props);
    } catch (e, st) {
      AppLogger.error(
        'Analytics capture failed: $event',
        e,
        stackTrace: st,
        category: 'analytics',
      );
    }
  }

  // ==========================================================================
  // Event dictionary — keep alphabetically grouped by surface.
  // ==========================================================================

  /// Fires on every `PageView.onPageChanged` in the onboarding wizard.
  /// [stepIndex] is 0-based; [stepName] is the class name of the step
  /// widget (e.g. `_TargetPhysiqueStep`) so the funnel dashboard reads
  /// the same labels the code uses.
  Future<void> onboardingStepCompleted({
    required int stepIndex,
    required String stepName,
  }) {
    return _capture('onboarding_step_completed', {
      'step_index': stepIndex,
      'step_name': stepName,
    });
  }

  /// Phase 46 — fires on every page flip inside the deferred nutrition
  /// sheet (the four diet / allergies / meal-frequency / prep-time
  /// questions that were split out of the main 13-step wizard). Uses
  /// a distinct event name so funnel dashboards can measure drop-off
  /// on the deferred flow separately from primary onboarding.
  Future<void> nutritionOnboardingStepCompleted({
    required int stepIndex,
    required String stepName,
  }) {
    return _capture('nutrition_onboarding_step_completed', {
      'step_index': stepIndex,
      'step_name': stepName,
    });
  }

  /// Phase 46 — fires once when the user finishes the deferred
  /// nutrition sheet. Pairs with [nutritionOnboardingStepCompleted]
  /// to give a conversion rate from "sheet opened" to "sheet
  /// completed".
  Future<void> nutritionOnboardingCompleted() {
    return _capture('nutrition_onboarding_completed');
  }

  /// Fires when `WorkoutSessionNotifier.startDay` successfully enters a
  /// new day. `planId` is set when the session comes from an ad-hoc
  /// plan (push-limits strip / regional plan); `dayNumber` is the
  /// 30-day program day (0 when ad-hoc).
  Future<void> workoutStarted({
    String? planId,
    String? exerciseName,
    required int dayNumber,
  }) {
    return _capture('workout_started', {
      'day_number': dayNumber,
      if (planId != null) 'plan_id': planId,
      if (exerciseName != null) 'exercise_name': exerciseName,
    });
  }

  /// Fires after the last set of the last exercise — i.e. the moment
  /// `isSessionComplete` flips to true.
  Future<void> workoutCompleted({required int dayNumber}) {
    return _capture('workout_completed', {'day_number': dayNumber});
  }

  /// Fires in `PaywallScreen.initState` so the viewed-→-purchased ratio
  /// is derivable per [source] (home dashboard, locked-day tap, profile
  /// Premium tile, settings subscription manager).
  Future<void> paywallViewed({String? source}) {
    return _capture('paywall_viewed', {
      if (source != null) 'source': source,
    });
  }

  /// Fires from `SubscriptionNotifier.purchase` on `PurchaseOutcome.success`.
  Future<void> purchaseSucceeded({required String productId}) {
    return _capture('purchase_succeeded', {'product_id': productId});
  }

  /// Phase 135 · paired with the cinematic conversion-moment scenes.
  /// Fires when a contextual conversion scene is presented (locked-tap
  /// or one-shot first-workout invitation). [source] mirrors the
  /// `paywall_viewed.source` taxonomy so funnels stitch together.
  Future<void> conversionMomentShown({required String source}) {
    return _capture('conversion_moment_shown', {'source': source});
  }

  /// Phase 135 · fires when the user taps the PremiumCtaButton inside a
  /// conversion moment. Paired with [conversionMomentShown] so the
  /// tap-through ratio is derivable per scene.
  Future<void> conversionMomentCtaTapped({required String source}) {
    return _capture('conversion_moment_cta_tapped', {'source': source});
  }

  /// Phase 135 · fires when the user dismisses a conversion scene
  /// without tapping the CTA (back gesture / "Daha sonra" affordance).
  /// Captures the silent-bounce rate.
  Future<void> conversionMomentDismissed({required String source}) {
    return _capture('conversion_moment_dismissed', {'source': source});
  }

  /// Phase 136, extended in roadmap Phase 1 · fires when the cinematic
  /// rating scene is presented. Paired with [ratingSentimentCaptured],
  /// [ratingPromptLaunched] and [ratingPromptDismissed] so the
  /// rate / skip ratio is derivable **per trigger** — which is the
  /// signal needed to tune which moments actually earn reviews.
  Future<void> ratingPromptShown({required String trigger}) {
    return _capture('rating_prompt_shown', {'trigger': trigger});
  }

  /// Roadmap Phase 1 (C9) · the star value the user selected, and where
  /// it routed them. This is the app's only view into sentiment — the
  /// platform review dialog's outcome is opaque by policy — so it is
  /// the metric that tells us whether the routing split is working.
  Future<void> ratingSentimentCaptured({
    required int stars,
    required String trigger,
    required bool routedToStore,
  }) {
    return _capture('rating_sentiment_captured', {
      'stars': stars,
      'trigger': trigger,
      'routed_to_store': routedToStore,
    });
  }

  /// Phase 136 · the platform review dialog was requested. The OS
  /// handles the actual rating flow from here — the response is
  /// intentionally opaque to us (Apple/Google policy), so this is the
  /// most-downstream signal the app gets.
  Future<void> ratingPromptLaunched() {
    return _capture('rating_prompt_launched', const {});
  }

  /// Phase 136 · the user dismissed the rating scene with "Daha sonra"
  /// instead of picking a star. Captures the skip pattern per trigger
  /// so we can retire triggers that consistently get declined.
  Future<void> ratingPromptDismissed({required String trigger}) {
    return _capture('rating_prompt_dismissed', {'trigger': trigger});
  }

  /// Roadmap Phase 1 (R2.1) · the user opened the store listing
  /// themselves. [source] is the entry point (`settings`), so
  /// self-initiated ratings stay separable from prompted ones.
  Future<void> rateTapped({required String source}) {
    return _capture('rate_tapped', {'source': source});
  }

  /// Fires from `DailyMenuNotifier.addRecipeToPlan`.
  Future<void> recipeAddedToPlan({
    required String recipeId,
    required String mealType,
  }) {
    return _capture('recipe_added_to_plan', {
      'recipe_id': recipeId,
      'meal_type': mealType,
    });
  }

  /// Phase 54 · viral-loop instrumentation. Fired the moment the user
  /// taps a share-affordance — captures *intent to share*, regardless
  /// of whether the OS share-sheet ultimately resolves successfully.
  /// [surface] is the originating CTA: `progress`, `badge`, `referral`.
  Future<void> shareInitiated({required String surface}) {
    return _capture('share_initiated', {'surface': surface});
  }

  /// Phase 54 · paired with [shareInitiated]. Fired only when the OS
  /// share-sheet returns `ShareResultStatus.success` — the user picked
  /// a destination app and the share intent was actually dispatched.
  /// Compare initiated vs. completed counts to spot share-sheet
  /// abandonment (a privacy / friction signal).
  Future<void> shareCompleted({required String surface}) {
    return _capture('share_completed', {'surface': surface});
  }

  /// Phase 54 · referral funnel. Fired exactly once per user, at the
  /// moment a fresh install lands inside the Profile tab and the
  /// referral provider materialises a code. Lets us compute "% of
  /// installs that ever surface a referral code" without polluting
  /// the share funnel.
  Future<void> referralCodeSurfaced({required String code}) {
    return _capture('referral_code_surfaced', {'code': code});
  }

  /// Phase 54 · fired when `ReferralService.redeem` succeeds against
  /// the Supabase RPC. `referrer_code` is the code that was redeemed
  /// (server-side validated — self-referral / unknown codes don't
  /// reach this point).
  Future<void> referralRedeemed({required String referrerCode}) {
    return _capture('referral_redeemed', {'referrer_code': referrerCode});
  }

  /// Phase 56 Lite · fired when the user exports a shopping list from
  /// the Favorilerim screen. `recipe_count` segments the funnel so we
  /// can spot whether the export is a one-off "look at my list" vs a
  /// regular weekly habit.
  Future<void> shoppingListExported({required int recipeCount}) {
    return _capture('shopping_list_exported', {
      'recipe_count': recipeCount,
    });
  }

  /// Phase 56 Lite · in-app feedback funnel. Fired on submit
  /// regardless of which transport (Supabase RPC or mailto fallback)
  /// ultimately delivered the message — `transport` segments the two.
  Future<void> feedbackSubmitted({
    required String subject,
    required String transport,
  }) {
    return _capture('feedback_submitted', {
      'subject': subject,
      'transport': transport,
    });
  }

  /// Roadmap Phase 1 (R2.3) · the participation reward was granted.
  /// Note what this event is NOT: it never carries a rating or review,
  /// because the reward is attached to submitting feedback, never to
  /// leaving a review (Play Developer Program Policy).
  Future<void> feedbackRewardGranted({required int xp}) {
    return _capture('feedback_reward_granted', {'xp': xp});
  }

  /// Roadmap Phase 1 (C30) · the help centre was opened. Read against
  /// [feedbackSubmitted] to measure ticket deflection.
  Future<void> helpCenterOpened() {
    return _capture('help_center_opened', const {});
  }

  // ─── Roadmap Phase 1 (C8) · micro-surveys ─────────────────────────

  /// A survey was presented. [surveyId] is the stable catalogue id.
  Future<void> surveyShown({required String surveyId}) {
    return _capture('survey_shown', {'survey_id': surveyId});
  }

  /// A survey was answered. Exactly one of [score] / [optionToken] is
  /// set depending on the survey kind; [npsBucket] is pre-computed here
  /// rather than in the dashboard so the promoter/passive/detractor
  /// definition can never drift between the app and the analytics view.
  Future<void> surveyAnswered({
    required String surveyId,
    int? score,
    String? optionToken,
    String? npsBucket,
  }) {
    return _capture('survey_answered', {
      'survey_id': surveyId,
      if (score != null) 'score': score,
      if (optionToken != null) 'option_token': optionToken,
      if (npsBucket != null) 'nps_bucket': npsBucket,
    });
  }

  /// A survey was closed without an answer. Tracked because a high
  /// dismissal rate is itself a finding — it means we are asking at the
  /// wrong moment.
  Future<void> surveyDismissed({required String surveyId}) {
    return _capture('survey_dismissed', {'survey_id': surveyId});
  }

  // ─── Roadmap Phase 2 (R1.1 · C27 · C28) · walkthrough ─────────────

  /// A spotlight tour began. [source] separates the one-shot first-run
  /// presentation from a user-initiated replay, which matters: replay
  /// volume is a signal that the first run wasn't absorbed.
  Future<void> tourStarted({required String tour, required String source}) {
    return _capture('tour_started', {'tour': tour, 'source': source});
  }

  /// Fires per step. The drop-off curve across steps is the metric that
  /// says whether the tour is the right length.
  Future<void> tourStepViewed({
    required String tour,
    required int stepIndex,
  }) {
    return _capture('tour_step_viewed', {
      'tour': tour,
      'step_index': stepIndex,
    });
  }

  Future<void> tourCompleted({required String tour}) {
    return _capture('tour_completed', {'tour': tour});
  }

  /// Paired with [tourCompleted] to give the completion / skip ratio.
  Future<void> tourSkipped({required String tour}) {
    return _capture('tour_skipped', {'tour': tour});
  }

  /// The post-paywall capability carousel was opened.
  Future<void> showcaseViewed() {
    return _capture('showcase_viewed', const {});
  }

  /// The carousel was read to the end (vs. dismissed part-way).
  Future<void> showcaseCompleted({required int cardsViewed}) {
    return _capture('showcase_completed', {'cards_viewed': cardsViewed});
  }

  /// First-ever visit to a tab. Read as a cohort funnel, this is the
  /// direct measure of the feature-visibility problem the Testers
  /// Community reported: what share of users ever discover Beslenme,
  /// Gelişim and Profil at all.
  Future<void> tabFirstVisit({required int tabIndex}) {
    return _capture('tab_first_visit', {'tab_index': tabIndex});
  }

  /// A contextual "Biliyor muydun?" tip was surfaced.
  Future<void> tipShown({required String tipId}) {
    return _capture('tip_shown', {'tip_id': tipId});
  }

  /// The user dismissed a tip. Dismissal is permanent per tip.
  Future<void> tipDismissed({required String tipId}) {
    return _capture('tip_dismissed', {'tip_id': tipId});
  }

  /// The user acted on a tip's CTA — the signal that tips are earning
  /// their screen space rather than just occupying it.
  Future<void> tipActioned({required String tipId}) {
    return _capture('tip_actioned', {'tip_id': tipId});
  }

  /// Phase 56 Lite · churn-survey response. Fired before the user is
  /// handed off to the App Store / Play Store cancellation flow so we
  /// always capture intent even if the user backs out at the last
  /// step. [reason] is the stable English token (`too_expensive`,
  /// `reached_goal`, `not_using`, `other`) — never the localised UI
  /// label, which would shift if we ever localise.
  Future<void> logChurnReason({required String reason}) {
    return _capture('churn_reason_logged', {'reason': reason});
  }

  // NOTE · App Tracking Transparency was deliberately REMOVED. The app's
  // PrivacyInfo.xcprivacy declares `NSPrivacyTracking = false` and the
  // published privacy policy states no cross-app tracking occurs — so
  // requesting the ATT prompt (and linking the ATT API) contradicted
  // both and risked automatic App Store rejection. First-party PostHog
  // analytics work without IDFA. If install attribution via IDFA is
  // ever wanted, flip the privacy manifest + policy FIRST, then
  // reintroduce the prompt.
}
