import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/providers/auth_provider.dart';

/// Entitlement id configured on the RevenueCat dashboard. Products mapped
/// to this id (monthly/quarterly/yearly) all unlock the same premium gate.
/// Case-sensitive — must match the RC dashboard exactly (space included).
const String kProEntitlementId = 'FormAI Pro';

/// Persisted flag used by the debug "Sandbox" button on the paywall to
/// force-unlock Premium without a real RevenueCat purchase. Needed while
/// Google Play Console verification is pending and native products aren't
/// available; [isProProvider] OR-s this with the live entitlement.
const String _kDevProOverrideKey = 'sixpack.monetization.dev_pro_override';

/// Outcome of a `purchase()` attempt. UI consumers use this to decide
/// whether to show a success SnackBar, silently return (user cancelled),
/// or surface an error toast.
/// Phase 138 · M-10. `pending` was added so the paywall can distinguish
/// the Play / App Store "deferred payment" state (parental approval
/// pending, family-share approval pending, slow card review) from a
/// hard `error`. A pending purchase resolves later — the user shouldn't
/// be told "Satın alma başarısız oldu" in the same breath as a real
/// network failure.
enum PurchaseOutcome { success, pending, cancelled, notEntitled, error }

enum RestoreOutcome { restored, nothingToRestore, error }

/// Snapshot of the user's current RevenueCat state plus the latest
/// offerings catalogue. Both can be null while we're waiting on the SDK
/// or when RevenueCat isn't configured (dev builds without API keys).
@immutable
class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.isDeveloperOverride = false,
    this.offerings,
  });

  /// True iff RevenueCat reports an active `FormAI Pro` entitlement.
  final bool isPro;

  /// Debug-only SharedPreferences flag flipped by the Sandbox button. Gates
  /// the same premium features as [isPro]; consumers should prefer
  /// [isProProvider], which OR-s the two.
  final bool isDeveloperOverride;

  final Offerings? offerings;

  SubscriptionState copyWith({
    bool? isPro,
    bool? isDeveloperOverride,
    Offerings? offerings,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      isDeveloperOverride: isDeveloperOverride ?? this.isDeveloperOverride,
      offerings: offerings ?? this.offerings,
    );
  }
}

/// Wraps [Purchases] with a typed state surface. Lives as an AsyncNotifier
/// so the paywall can watch initial loading, and so we can invalidate +
/// rebuild after linking a guest user to a real account.
class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() => _load();

  Future<SubscriptionState> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Debug-only: the sandbox override must never unlock Pro in a
    // release build — a stale flag left by a previously side-loaded
    // debug build would otherwise grant a permanent free entitlement.
    final devOverride =
        kDebugMode && (prefs.getBool(_kDevProOverrideKey) ?? false);
    try {
      final customer = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      return SubscriptionState(
        isPro: customer.entitlements.active.containsKey(kProEntitlementId),
        isDeveloperOverride: devOverride,
        offerings: offerings,
      );
    } catch (e, st) {
      // Happens in dev builds without API keys or when the device has no
      // Play Store / App Store session. Return a neutral state so the UI
      // can still render — the paywall shows the em-dash price slots and
      // the "Fiyatlar yüklenemedi" retry notice (M2).
      AppLogger.warning(
        'SubscriptionNotifier load failed — paywall falls back',
        category: 'monetization',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
      return SubscriptionState(isDeveloperOverride: devOverride);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    try {
      // purchases_flutter 10.x (M3/BL8): purchasePackage → purchase(
      // PurchaseParams); the customer info now rides in PurchaseResult.
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final info = result.customerInfo;
      final isPro = info.entitlements.active.containsKey(kProEntitlementId);
      // Guard: invalidation (sign-out) mid-purchase disposes this
      // notifier; the purchase outcome still returns to the caller.
      if (!ref.mounted) {
        return isPro ? PurchaseOutcome.success : PurchaseOutcome.notEntitled;
      }
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isPro: isPro));
      if (isPro) {
        AnalyticsService.instance.purchaseSucceeded(
          productId: package.storeProduct.identifier,
        );
      }
      return isPro ? PurchaseOutcome.success : PurchaseOutcome.notEntitled;
    } on PlatformException catch (e, st) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      // Phase 138 · M-10. `paymentPendingError` means Play / App Store
      // accepted the purchase but the charge hasn't resolved yet
      // (parental approval, family-share approval, slow card review).
      // The webhook will fire INITIAL_PURCHASE once it clears — the
      // user just needs to wait. Returning `pending` lets the paywall
      // show a soft "Satın alman onay bekliyor" toast instead of the
      // generic error.
      if (code == PurchasesErrorCode.paymentPendingError) {
        return PurchaseOutcome.pending;
      }
      AppLogger.error(
        'purchasePackage PlatformException: $code',
        e,
        stackTrace: st,
        category: 'monetization',
      );
      return PurchaseOutcome.error;
    } catch (e, st) {
      AppLogger.error(
        'purchasePackage failed',
        e,
        stackTrace: st,
        category: 'monetization',
      );
      return PurchaseOutcome.error;
    }
  }

  Future<RestoreOutcome> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active.containsKey(kProEntitlementId);
      // Guard: same disposed-notifier race as purchase().
      if (!ref.mounted) {
        return isPro
            ? RestoreOutcome.restored
            : RestoreOutcome.nothingToRestore;
      }
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isPro: isPro));
      return isPro ? RestoreOutcome.restored : RestoreOutcome.nothingToRestore;
    } catch (e, st) {
      AppLogger.error(
        'restorePurchases failed',
        e,
        stackTrace: st,
        category: 'monetization',
      );
      return RestoreOutcome.error;
    }
  }

  /// Debug-only escape hatch wired to the paywall's Sandbox button. Persists
  /// the override so a restart keeps Premium unlocked while the operator
  /// waits on Play Console verification.
  Future<void> unlockPremiumAsDeveloper() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevProOverrideKey, true);
    final current = state.value ?? const SubscriptionState();
    state = AsyncData(current.copyWith(isDeveloperOverride: true));
  }
}

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Single source of truth for premium gating across the app. Resolves to
/// `isProLocalOverride || isRevenueCatPro || isReviewer` so the debug
/// Sandbox button can unlock features without a real purchase, and a
/// Google Play / App Store reviewer account flagged with
/// `app_metadata.role == 'reviewer'` (see [isReviewerProvider])
/// experiences the full Pro app during store review.
final isProProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(subscriptionProvider).value;
  final isReviewer = ref.watch(isReviewerProvider);
  if (snapshot == null) return isReviewer;
  return snapshot.isDeveloperOverride || snapshot.isPro || isReviewer;
});

/// Reads the platform-appropriate RevenueCat API key from the .env file.
/// Missing keys return null so the caller can skip configuration instead
/// of crashing (dev builds frequently run without the prod keys).
String? revenueCatApiKey() {
  final key = Platform.isIOS
      ? dotenv.env['REVENUECAT_IOS_KEY']
      : Platform.isAndroid
          ? dotenv.env['REVENUECAT_ANDROID_KEY']
          : null;
  if (key == null || key.isEmpty) return null;
  return key;
}

/// Phase 48 · single-shot guard. The SDK was previously configured
/// from `_BootGate._init` on cold start, blocking the splash for the
/// duration of the platform channel handshake (~250-600 ms on
/// mid-range Androids). Now `configureRevenueCat` runs lazily — first
/// from `OnboardingScreen._finish()` after the wizard payload is
/// saved, and from `AuthController.signInWith{Google,Apple}` after a
/// successful sign-in — and this flag protects against both a double
/// configure (RevenueCat throws on the second call) and a redundant
/// no-key log spam.
bool _revenueCatConfigured = false;

/// Idempotent configuration. Safe to call from multiple deferred entry
/// points (post-onboarding, post-sign-in, lazy paywall view); the
/// `_revenueCatConfigured` guard ensures the underlying SDK call only
/// fires once. Any failure is logged and swallowed so a bad key
/// doesn't block the surrounding flow; the paywall provider also
/// tolerates an unconfigured SDK.
Future<void> configureRevenueCat() async {
  if (_revenueCatConfigured) return;
  _revenueCatConfigured = true;
  final key = revenueCatApiKey();
  if (key == null) {
    AppLogger.info(
      'RevenueCat: no API key in .env for this platform — '
      'paywall will run in fallback mode (offerings will be empty).',
      category: 'monetization',
    );
    return;
  }
  try {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );
    await Purchases.configure(PurchasesConfiguration(key));
  } catch (e, st) {
    // Reset the flag so a transient init failure can be retried by the
    // next entry point (e.g. user signs in after the post-onboarding
    // call failed).
    _revenueCatConfigured = false;
    AppLogger.error(
      'Purchases.configure failed',
      e,
      stackTrace: st,
      category: 'monetization',
    );
  }
}
