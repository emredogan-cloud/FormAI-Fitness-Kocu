import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Entitlement id configured on the RevenueCat dashboard. Products mapped
/// to this id (monthly/quarterly/yearly) all unlock the same premium gate.
const String kProEntitlementId = 'entitlement_pro';

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
  const SubscriptionState({this.isPro = false, this.offerings});

  final bool isPro;
  final Offerings? offerings;

  SubscriptionState copyWith({bool? isPro, Offerings? offerings}) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
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
    try {
      final customer = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      return SubscriptionState(
        isPro: customer.entitlements.active.containsKey(kProEntitlementId),
        offerings: offerings,
      );
    } catch (e, st) {
      // Happens in dev builds without API keys or when the device has no
      // Play Store / App Store session. Return a neutral state so the UI
      // can still render — the paywall will fall back to hardcoded prices.
      debugPrint('SubscriptionNotifier load failed: $e\n$st');
      return const SubscriptionState();
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
}

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

/// Convenience boolean — paywall wrappers can watch this directly without
/// unpacking the AsyncValue.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).value?.isPro ?? false;
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
