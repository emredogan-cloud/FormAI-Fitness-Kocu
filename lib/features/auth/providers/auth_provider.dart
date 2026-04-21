import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
class AuthController {
  const AuthController();

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
        debugPrint('signInWithGoogle: idToken was null');
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
      } catch (e) {
        debugPrint('signInWithGoogle: authorizationForScopes failed: $e');
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return SocialAuthOutcome.success;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return SocialAuthOutcome.cancelled;
      }
      debugPrint('signInWithGoogle GoogleSignInException: ${e.code} $e');
      return SocialAuthOutcome.error;
    } catch (e, st) {
      debugPrint('signInWithGoogle failed: $e\n$st');
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
        debugPrint('signInWithApple: identityToken was null');
        return SocialAuthOutcome.error;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return SocialAuthOutcome.success;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialAuthOutcome.cancelled;
      }
      debugPrint('signInWithApple AuthorizationException: ${e.code} $e');
      return SocialAuthOutcome.error;
    } catch (e, st) {
      debugPrint('signInWithApple failed: $e\n$st');
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
      debugPrint('deleteAccount RPC failed: $e\n$st');
      return DeleteAccountOutcome.error;
    }
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('deleteAccount signOut (non-fatal): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('deleteAccount prefs.clear (non-fatal): $e');
    }
    return DeleteAccountOutcome.success;
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
  return const AuthController();
});
