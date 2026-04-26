import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../services/referral_service.dart';

/// Phase 54 · DI for `ReferralService`.
///
/// Held as a `Provider` (not `NotifierProvider`) because the service is
/// stateless beyond the SharedPreferences handle it owns; the actual
/// "current code" surface is the [referralCodeProvider] below.
final referralServiceProvider = Provider<ReferralService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReferralService(prefs);
});

/// The user's current referral code, materialised lazily.
///
/// Returned as `AsyncValue<String>` so callers can render a shimmer
/// while the first generation rountrip lands. After that the value is
/// cached locally and subsequent reads resolve synchronously through
/// the cached SharedPreferences entry.
final referralCodeProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(referralServiceProvider);
  final code = await service.getOrCreateCode();
  // Phase 54 · funnel breadcrumb. Fired exactly once per session for
  // each materialisation of the code so we can compute "% of installs
  // that ever surface a referral code" without polluting the share
  // funnel.
  AnalyticsService.instance.referralCodeSurfaced(code: code);
  return code;
});
