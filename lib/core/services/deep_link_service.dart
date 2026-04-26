import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';
import '../utils/app_logger.dart';

/// Phase 54 · listens to incoming `formai://...` and `https://formai.app/...`
/// URLs and routes them through the app's `GoRouter`.
///
/// Two surfaces:
///   • cold-start: `getInitialAppLink()` resolves the URL the user
///     tapped to launch the app. We replay it as soon as the router
///     finishes its first redirect pass (auth gate, onboarding gate)
///     so the destination respects the same redirects every other
///     navigation does.
///   • warm: `uriLinkStream` fires when the running app receives a
///     URL via `singleTop` resume (Android) / `application(_:open:)`
///     (iOS). We re-route immediately.
///
/// The service is owned by Riverpod so the underlying StreamSubscription
/// is disposed alongside the provider; no manual lifecycle hook needed
/// from the widget tree.
class DeepLinkService {
  DeepLinkService(this._router, {AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  final GoRouter _router;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _route(initial, source: 'cold');
      }
    } catch (e, st) {
      AppLogger.warning(
        'getInitialLink failed: $e',
        category: 'deeplink',
        data: {'stack': st.toString()},
      );
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _route(uri, source: 'warm'),
      onError: (Object e, StackTrace st) {
        AppLogger.warning(
          'uriLinkStream error: $e',
          category: 'deeplink',
          data: {'stack': st.toString()},
        );
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Translates an incoming URI to a `GoRouter.go(...)` target. Only
  /// known shapes are accepted; unknown paths fall through to the
  /// dashboard so a malformed link doesn't strand the user on a
  /// blank screen.
  void _route(Uri uri, {required String source}) {
    AppLogger.info(
      'Deep link received',
      category: 'deeplink',
      data: {'uri': uri.toString(), 'source': source},
    );
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      _router.go(AppRoutes.dashboard);
      return;
    }
    // formai://r/<code>  → /referral?code=<code>
    // https://formai.app/r/<code>  → /referral?code=<code>
    if (segments.first == 'r' && segments.length >= 2) {
      final code = segments[1].toUpperCase();
      _router.go('${AppRoutes.referralLanding}?code=$code');
      return;
    }
    // Phase 55 · formai://workout/today → live workout camera screen.
    // Triggered from the home-screen widget tap and the Live Activity
    // tap. The router's auth + first-time gates still apply, so a
    // signed-out user clicking the widget lands on /auth and gets
    // bounced through onboarding before the camera surface opens.
    if (segments.first == 'workout' &&
        segments.length >= 2 &&
        segments[1] == 'today') {
      _router.go(AppRoutes.workout);
      return;
    }
    _router.go(AppRoutes.dashboard);
  }
}

/// Provider lifetime owns the DeepLinkService — invalidating the router
/// (which we never do today, but keep the hook for tests) tears the
/// listener down too.
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final router = ref.watch(appRouterProvider);
  final service = DeepLinkService(router);
  ref.onDispose(service.stop);
  return service;
});
