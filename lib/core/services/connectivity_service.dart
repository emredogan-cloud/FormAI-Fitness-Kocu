import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 89 · thin wrapper over `connectivity_plus` that exposes the
/// app's notion of "is the device online" as a Riverpod stream + a
/// one-shot helper.
///
/// Why a wrapper instead of using `Connectivity().onConnectivityChanged`
/// directly: callers want a `bool` (online/offline), not a list of
/// `ConnectivityResult` enum values, and the API of the plugin changed
/// shape between v5 (single result) and v6 (list of results — covers
/// dual-SIM / multi-interface devices). Centralising the
/// "any active interface = online" rule here means consumers don't
/// need to know which version is pinned.
///
/// We treat the device as **online** when at least one of the returned
/// results is anything other than `ConnectivityResult.none`. WiFi,
/// mobile, ethernet, VPN, bluetooth-tether — all count. False
/// positives (interface up but no actual internet) are tolerated:
/// the downstream Supabase call will still error, and the UI's
/// existing error/empty paths cover that. The plugin's whole point
/// is to skip the **certain offline** case so we don't wait 30 s
/// for a TCP timeout.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  /// True when the platform reports any non-`none` interface. Used by
  /// the Google/Apple sign-in buttons and the workout-camera entry to
  /// short-circuit before kicking off a network handshake.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnlineFromResults(results);
  }

  Stream<bool> watch() {
    return _connectivity.onConnectivityChanged.map(_isOnlineFromResults);
  }

  static bool _isOnlineFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Singleton so the underlying platform-channel subscription is shared
/// across the widget tree. `connectivity_plus` itself is cheap (no
/// active polling — the platform pushes updates), but creating multiple
/// `Connectivity` instances would still spawn redundant
/// subscribers under the hood.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});

/// Reactive view of the device's online state. UI consumers `watch`
/// this to swap their content for an offline tile when the value
/// flips to false.
///
/// Initial value: assumes online until the first platform event. The
/// alternative (assume offline → flicker through an offline tile on
/// every cold start) trades one false-positive offline tile for one
/// false-negative; in practice the platform event arrives within
/// ~50 ms so an "assume online" default is the better UX on the
/// dominant case.
final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.watch();
});
