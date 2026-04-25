import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../nutrition/providers/daily_menu_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../onboarding/providers/wizard_provider.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../workout/providers/workout_provider.dart';

/// Streams Supabase auth state changes (login, logout, refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Currently signed-in user, or `null` if no session. Rebuilds whenever the
/// auth state stream emits.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// `Listenable` that notifies on every auth state change. Wired into
/// `GoRouter.refreshListenable` so navigation re-evaluates on login/logout
/// without tearing down the router.
final authRefreshListenableProvider = Provider<Listenable>((ref) {
  final notifier = _AuthRefreshListenable();
  final sub = Supabase.instance.client.auth.onAuthStateChange
      .listen((_) => notifier.refresh());
  ref.onDispose(() {
    sub.cancel();
    notifier.dispose();
  });
  return notifier;
});

class _AuthRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Outcome of a social sign-in attempt. UI consumers use this to decide
/// whether to navigate forward on success, stay silent on cancellation, or
/// surface an error toast.
enum SocialAuthOutcome { success, cancelled, error }

/// Outcome of a [AuthController.deleteAccount] attempt. The UI uses this
/// to decide whether to show a success SnackBar or a retry toast.
enum DeleteAccountOutcome { success, error }

/// Wraps the native Google + Apple flows and hands the resulting id tokens
/// to Supabase. Kept as a plain class (not a Notifier) because the global
/// auth state is already watched via [authStateProvider]; the screen just
/// needs a one-shot `Future` it can await.
///
/// Holds a [Ref] so sign-out / delete-account can invalidate the
/// user-scoped providers whose caches would otherwise survive an identity
/// change — see [_invalidateUserScopedProviders] for the list and the
/// ghost-data incident that motivated it.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<SocialAuthOutcome> signInWithGoogle() async {
    try {
      final signIn = GoogleSignIn.instance;
      // `initialize` is idempotent on the plugin side but the public API
      // documents "exactly once" — calling it per sign-in is safe because
      // we await it before any other method.
      await signIn.initialize(
        // Web client ID from Google Cloud Console, linked to the Supabase
        // Google provider. Required on Android so the returned id token's
        // `aud` claim matches what Supabase validates against.
        serverClientId: _envOrNull('GOOGLE_WEB_CLIENT_ID'),
        // iOS client ID (from GoogleService-Info.plist). Optional when the
        // plist is bundled, but passing it explicitly avoids surprises.
        clientId: Platform.isIOS ? _envOrNull('GOOGLE_IOS_CLIENT_ID') : null,
      );
      final account = await signIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        AppLogger.warning(
          'signInWithGoogle: idToken was null',
          category: 'auth',
        );
        return SocialAuthOutcome.error;
      }
      // Access token is best-effort — Supabase only strictly requires the
      // id token, but passing the access token lets Supabase revoke the
      // session cleanly on sign-out.
      String? accessToken;
      try {
        final authz = await account.authorizationClient
            .authorizationForScopes(const ['email', 'profile']);
        accessToken = authz?.accessToken;
      } catch (e, st) {
        AppLogger.warning(
          'signInWithGoogle: authorizationForScopes failed',
          category: 'auth',
          data: {'error': e.toString(), 'stack': st.toString()},
        );
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      // Phase 48 · ensure the RevenueCat SDK is up before the paywall
      // resurfaces post-sign-in. Idempotent — no-op if onboarding
      // already triggered the configure.
      unawaited(configureRevenueCat());
      return SocialAuthOutcome.success;
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return SocialAuthOutcome.cancelled;
      }
      AppLogger.error(
        'signInWithGoogle GoogleSignInException: ${e.code}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return SocialAuthOutcome.error;
    } catch (e, st) {
      AppLogger.error(
        'signInWithGoogle failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return SocialAuthOutcome.error;
    }
  }

  Future<SocialAuthOutcome> signInWithApple() async {
    try {
      // Nonce pattern from Supabase docs: send the SHA-256 hash to Apple
      // (embedded in the returned id token) and the raw value to Supabase
      // so it can verify the binding.
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        AppLogger.warning(
          'signInWithApple: identityToken was null',
          category: 'auth',
        );
        return SocialAuthOutcome.error;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Phase 48 · same lazy-init story as Google sign-in.
      unawaited(configureRevenueCat());
      return SocialAuthOutcome.success;
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialAuthOutcome.cancelled;
      }
      AppLogger.error(
        'signInWithApple AuthorizationException: ${e.code}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return SocialAuthOutcome.error;
    } catch (e, st) {
      AppLogger.error(
        'signInWithApple failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return SocialAuthOutcome.error;
    }
  }

  /// Irreversible account deletion. Supabase's client SDK deliberately
  /// can't delete users (it would need service-role keys we refuse to ship);
  /// instead we call a `delete_user` Postgres RPC that runs under
  /// `SECURITY DEFINER` on the server side. See the operator note in the
  /// Phase 13 report for the SQL.
  ///
  /// The flow intentionally wipes local state even if the signOut call
  /// throws — the row is already gone server-side, so the session token
  /// is an invalid ghost anyway and we don't want stale metrics leaking
  /// into the next account.
  Future<DeleteAccountOutcome> deleteAccount() async {
    try {
      await Supabase.instance.client.rpc('delete_user');
    } catch (e, st) {
      AppLogger.error(
        'deleteAccount RPC failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return DeleteAccountOutcome.error;
    }
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      AppLogger.warning(
        'deleteAccount signOut (non-fatal)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      AppLogger.warning(
        'deleteAccount prefs.clear (non-fatal)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    _invalidateUserScopedProviders();
    return DeleteAccountOutcome.success;
  }

  /// Signs the current user out of Supabase and clears the user-scoped
  /// provider caches so the next login sees a fresh slate. Callers can
  /// treat the returned future as "done when the UI is safe to
  /// redirect" — the router's authRefreshListenable will then route
  /// them to /auth automatically.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e, st) {
      AppLogger.error(
        'signOut failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
    }
    _invalidateUserScopedProviders();
  }

  /// Invalidates every provider whose cached value belongs to the
  /// signed-in user. Riverpod rebuilds them lazily on next read, so the
  /// next login / guest session lands on a clean state instead of
  /// inheriting the previous account's 30-day plan, pro entitlement,
  /// preference wrapper, or onboarding wizard state.
  ///
  /// Phase 48 · also drops the paginated recipe list, the user's daily
  /// menu, and the celebrated-badges set so a fresh login starts with
  /// an empty cache rather than the previous user's recommendations.
  void _invalidateUserScopedProviders() {
    _ref.invalidate(workoutSessionProvider);
    _ref.invalidate(subscriptionProvider);
    _ref.invalidate(appPreferencesProvider);
    _ref.invalidate(wizardProvider);
    _ref.invalidate(recipesProvider);
    _ref.invalidate(dailyMenuProvider);
    _ref.invalidate(celebratedBadgesProvider);
  }

  String? _envOrNull(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});
