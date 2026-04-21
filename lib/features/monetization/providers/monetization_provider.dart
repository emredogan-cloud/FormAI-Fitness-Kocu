import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
enum PurchaseOutcome { success, cancelled, notEntitled, error }

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
    final devOverride = prefs.getBool(_kDevProOverrideKey) ?? false;
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
      // can still render — the paywall will fall back to hardcoded prices.
      debugPrint('SubscriptionNotifier load failed: $e\n$st');
      return SubscriptionState(isDeveloperOverride: devOverride);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      final isPro = info.entitlements.active.containsKey(kProEntitlementId);
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isPro: isPro));
      return isPro ? PurchaseOutcome.success : PurchaseOutcome.notEntitled;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      debugPrint('purchasePackage PlatformException: $code $e');
      return PurchaseOutcome.error;
    } catch (e, st) {
      debugPrint('purchasePackage failed: $e\n$st');
      return PurchaseOutcome.error;
    }
  }

  Future<RestoreOutcome> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active.containsKey(kProEntitlementId);
      final current = state.value ?? const SubscriptionState();
      state = AsyncData(current.copyWith(isPro: isPro));
      return isPro ? RestoreOutcome.restored : RestoreOutcome.nothingToRestore;
    } catch (e, st) {
      debugPrint('restorePurchases failed: $e\n$st');
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
/// `isProLocalOverride || isRevenueCatPro` so the debug Sandbox button can
/// unlock features without a real purchase.
final isProProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(subscriptionProvider).value;
  if (snapshot == null) return false;
  return snapshot.isDeveloperOverride || snapshot.isPro;
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

/// Idempotent configuration — main.dart calls this once per app launch.
/// Any failure is logged and swallowed so a bad key doesn't block the
/// rest of the boot sequence; the paywall provider also tolerates an
/// unconfigured SDK.
Future<void> configureRevenueCat() async {
  final key = revenueCatApiKey();
  if (key == null) {
    debugPrint(
      'RevenueCat: no API key in .env for this platform — '
      'paywall will run in fallback mode (offerings will be empty).',
    );
    return;
  }
  try {
    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );
    await Purchases.configure(PurchasesConfiguration(key));
  } catch (e, st) {
    debugPrint('Purchases.configure failed: $e\n$st');
  }
}
