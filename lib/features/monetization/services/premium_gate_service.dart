import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_haptics.dart';
import '../models/locked_feature_type.dart';
import '../providers/monetization_provider.dart';

/// Phase 134 · single entry point for every premium-gated callsite.
///
/// Before this service, premium checks were `if (!ref.read(isProProvider))
/// { context.push('/paywall'); }` scattered through the codebase. Adding
/// a cinematic conversion moment (Phase 135) would have meant grepping
/// for each site and rewriting it. This service centralises both:
///
///   • [isUnlocked] is the canonical "should this feature work?" check.
///   • [handleLockedTap] is the canonical "user tapped a locked thing,
///     decide what cinematic / paywall flow to fire" routine.
///
/// Phase 134 keeps [handleLockedTap] as a direct paywall route so the
/// behaviour is unchanged. Phase 135 will swap the body for a
/// `ConversionMomentService.show(...)` call that fires a contextual
/// cinematic scene first, then routes to paywall via the scene's CTA.
/// Callsites do not change — the contract is stable from C1 onward.
class PremiumGateService {
  PremiumGateService(this._ref);

  final Ref _ref;

  /// Mirror of [isProProvider]. Exposed here so callsites don't need
  /// two imports (gate + provider) to do a one-line check.
  bool get isPro => _ref.read(isProProvider);

  /// True if the feature is accessible to the current user. Currently
  /// reduces to [isPro] for every type — future tiers (e.g. trial
  /// flags, partial-grant entitlements) layer in here without
  /// disturbing callsites.
  bool isUnlocked(LockedFeatureType _) => isPro;

  /// Single tap-handler for every locked surface. Emits a typed
  /// `paywall_viewed` event with [type]'s analytics source, fires a
  /// soft secondary-tap haptic, then routes to `/paywall`.
  ///
  /// Phase 135 will intercept this method to fire a contextual
  /// cinematic AI scene before the paywall navigation. The contract
  /// (`type` + optional `source` override) stays stable so callsites
  /// don't churn between phases.
  Future<void> handleLockedTap(
    BuildContext context,
    LockedFeatureType type, {
    String? source,
  }) async {
    AppHaptics.secondaryTap();
    AnalyticsService.instance
        .paywallViewed(source: source ?? type.analyticsSource);
    if (!context.mounted) return;
    context.push(AppRoutes.paywall);
  }
}

/// Riverpod-exposed singleton. Kept as a `Provider` (not `AsyncNotifier`)
/// because the service holds no async state — it's a thin orchestrator
/// over [isProProvider], analytics, and routing.
final premiumGateProvider =
    Provider<PremiumGateService>(PremiumGateService.new);
