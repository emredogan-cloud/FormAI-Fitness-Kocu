import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../utils/app_logger.dart';

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
      AppLogger.info('PostHog initialised', category: 'analytics');
    } catch (e, st) {
      AppLogger.error(
        'PostHog init failed',
        e,
        stackTrace: st,
        category: 'analytics',
      );
    }
  }

  Future<void> _capture(String event, [Map<String, Object>? props]) async {
    if (!_enabled) return;
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

  /// Phase 56 Lite · churn-survey response. Fired before the user is
  /// handed off to the App Store / Play Store cancellation flow so we
  /// always capture intent even if the user backs out at the last
  /// step. [reason] is the stable English token (`too_expensive`,
  /// `reached_goal`, `not_using`, `other`) — never the localised UI
  /// label, which would shift if we ever localise.
  Future<void> logChurnReason({required String reason}) {
    return _capture('churn_reason_logged', {'reason': reason});
  }

  // ==========================================================================
  // iOS App Tracking Transparency — Apple requires this prompt before any
  // cross-app tracking identifier (IDFA) can be read. PostHog uses IDFA
  // when available for install attribution; if the user denies, we still
  // capture events against a hashed UUID. Non-iOS is a no-op.
  // ==========================================================================

  Future<void> requestAttIfNeeded() async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Give the OS a beat to settle so the prompt isn't eaten by the
        // onboarding-finish navigation animation.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final resolved =
            await AppTrackingTransparency.requestTrackingAuthorization();
        AppLogger.info(
          'ATT resolved: $resolved',
          category: 'analytics',
          data: {'status': resolved.name},
        );
      }
    } catch (e, st) {
      AppLogger.warning(
        'ATT prompt failed: $e',
        category: 'analytics',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }
}
