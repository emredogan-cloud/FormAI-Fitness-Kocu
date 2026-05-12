import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_haptics.dart';
import '../models/locked_feature_type.dart';
import '../providers/monetization_provider.dart';
import 'conversion_moment_service.dart';

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
/// Phase 135 · [handleLockedTap] now delegates to
/// [ConversionMomentService.show] so every locked surface fires its
/// own contextual cinematic scene before the paywall. Pro users still
/// short-circuit to [AppRoutes.paywall] for the rare case where Pro
/// state is stale and the gate is consulted directly.
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

  /// Single tap-handler for every locked surface. Fires a soft
  /// secondary-tap haptic, emits a typed `paywall_viewed` event with
  /// [type]'s analytics source for funnel-stitching with the eventual
  /// purchase, then hands off to [ConversionMomentService.show] to
  /// present the cinematic scene. The scene's PremiumCtaButton owns
  /// the paywall navigation.
  Future<void> handleLockedTap(
    BuildContext context,
    LockedFeatureType type, {
    String? source,
  }) async {
    AppHaptics.secondaryTap();
    AnalyticsService.instance
        .paywallViewed(source: source ?? type.analyticsSource);
    if (!context.mounted) return;
    await _ref.read(conversionMomentProvider).show(context, type);
  }
}

/// Riverpod-exposed singleton. Kept as a `Provider` (not `AsyncNotifier`)
/// because the service holds no async state — it's a thin orchestrator
/// over [isProProvider], analytics, and routing.
final premiumGateProvider =
    Provider<PremiumGateService>(PremiumGateService.new);
