import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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
import '../../../l10n/app_localizations.dart';

/// Streams Supabase auth state changes (login, logout, refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Phase 140 · single source of truth for "the paywall's auth gate
/// has already been cleared in this session".
///
/// **Why this exists** — the paywall's [_authGateShown] latch was
/// local to a single PaywallScreen instance. The email-login path
/// (`/auth` → `signInWithPassword`/`updateUser` → `pushReplacement`
/// back to `/paywall`) destroyed the old PaywallScreen and created a
/// fresh one, so the latch reset to `false` and the gate re-fired —
/// even though the user had just authenticated. Compounded by a
/// Riverpod cache race: between Supabase's `updateUser` returning
/// and its auth-state stream emitting, [currentUserProvider]'s
/// cached value could still be the pre-auth anonymous user, so the
/// `hasLinkedEmail` heuristic failed even when the user object was
/// actually correct in the in-memory Supabase session.
///
/// This provider survives `pushReplacement` (Riverpod scope is the
/// whole app, not the widget tree). It's flipped to `true` from
/// every auth-success path:
///
///   • `AuthController.signInWithGoogle` (modal + standalone)
///   • `AuthController.signInWithApple` (modal + standalone)
///   • `AuthScreen._submit` (signIn, anon-upgrade-via-updateUser,
///     and signUp-with-session branches)
///
/// And reset to `false` from `_invalidateUserScopedProviders`
/// (sign-out + delete-account) so the next anonymous session sees
/// the gate again.
///
/// Read by `PaywallScreen._onAuthStateChanged` as the first
/// short-circuit: if the flag is true, skip the gate unconditionally,
/// regardless of what `isAnonymous` / `email` / `newEmail` say.
class AuthGateClearedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Phase 2 (P-Risk) F19 · explicit intent methods replace the previous
  /// public `set state` override, which leaked Riverpod's protected state
  /// setter onto the outward-facing API. Behaviour is identical.

  /// Mark the paywall auth-gate as cleared (post sign-in / sign-up) so the
  /// next emission short-circuits past the gate.
  void markCleared() => state = true;

  /// Re-arm the gate (sign-out / delete-account) so the next anonymous
  /// session sees the gate again.
  void reset() => state = false;
}

final authGateClearedProvider = NotifierProvider<AuthGateClearedNotifier, bool>(
  AuthGateClearedNotifier.new,
);

/// Currently signed-in user, or `null` if no session. Rebuilds whenever the
/// auth state stream emits.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// Uncached synchronous live-read of the in-memory Supabase auth user.
/// Mirrors `Supabase.instance.client.auth.currentUser` so callers that
/// need the up-to-the-moment session (rather than the cached value from
/// [currentUserProvider]) can still go through Riverpod. The indirection
/// also lets widget tests override the read without booting Supabase.
final supabaseAuthReader = Provider<User? Function()>((ref) {
  return () => Supabase.instance.client.auth.currentUser;
});

/// Phase 50B · `true` when the current user carries the
/// `app_metadata.role = 'admin'` claim minted from Supabase Studio.
/// Routes / widgets behind the admin tools watch this provider so a
/// regular user navigating to `/admin` is bounced back to the dashboard
/// instead of seeing a half-rendered shell.
///
/// `app_metadata` (not `user_metadata`) is intentional: the former can
/// only be edited from a trusted server context, so a malicious client
/// cannot self-promote by writing into the JWT — it would just fail the
/// RLS policy anyway, but failing the route guard early avoids a
/// confusing "you have access here but every write 401s" experience.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final role = user.appMetadata['role'];
  return role is String && role == 'admin';
});

/// Phase 139 · Google Play / App Store reviewer override. Mirror of
/// [isAdminProvider] — reads `app_metadata.role == 'reviewer'` minted
/// from a trusted server context (Supabase Studio or an admin RPC)
/// onto the reviewer test account (`emre30283@gmail.com`).
///
/// Like the admin claim, `app_metadata` is service-role writable only,
/// so a regular user cannot self-promote into reviewer-Pro by tampering
/// with their client — the JWT signature would fail Supabase's
/// verification step before this provider ever sees the claim.
///
/// Wired into [isProProvider] so the reviewer experiences the full Pro
/// app without a real RevenueCat purchase. Revocation is a single
/// `UPDATE auth.users SET raw_app_meta_data = raw_app_meta_data - 'role'`
/// — see `docs/OPERATOR_REVIEWER_ACCESS.md` for the runbook.
final isReviewerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final role = user.appMetadata['role'];
  return role is String && role == 'reviewer';
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

/// Phase 88 · richer return shape for the social sign-in methods.
///
/// The plain enum hid the underlying failure reason from the UI — most
/// notably an `AuthException` from Supabase rejecting the id token
/// (typical cause: `GOOGLE_WEB_CLIENT_ID` doesn't match the audience
/// claim Supabase's Google provider expects). Surfacing the message
/// at the toast layer turns "Google ile giriş başarısız oldu" into
/// something that reveals the actual root cause without a Sentry
/// round-trip.
///
/// `errorMessage` is non-null only when `outcome == error`; it stays
/// null on success and cancellation. Callers can use the bare outcome
/// for branching and only consult the message when actually showing a
/// toast.
typedef SocialAuthResult = ({SocialAuthOutcome outcome, String? errorMessage});

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

  Future<SocialAuthResult> signInWithGoogle(AppLocalizations l10n) async {
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
        return (
          outcome: SocialAuthOutcome.error,
          errorMessage: l10n.authErrorGoogleNoIdToken,
        );
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
      // resurfaces post-sign-in. Phase 94 promoted this from
      // `unawaited(configureRevenueCat())` to a serialised
      // `await` + `Purchases.logIn(...)` so the SDK's anonymous
      // app-user-ID is aliased to the freshly-minted Supabase UUID
      // BEFORE the user reaches the paywall purchase action.
      // Without the alias, an anonymous purchase made later would be
      // associated with the throwaway RC anonymous ID and would
      // disappear on the next sign-in — the bug Phase 94 was
      // commissioned to fix. configureRevenueCat is idempotent and
      // costs ~250-600 ms once per cold start; the user is already
      // in a "signing in" progress state, so the latency is invisible.
      await aliasRevenueCatWithCurrentUser();
      // Phase 140 · single-source latch — auth complete, paywall
      // gate stays down for the rest of this session.
      _ref.read(authGateClearedProvider.notifier).markCleared();
      return (outcome: SocialAuthOutcome.success, errorMessage: null);
    } on AuthException catch (e, st) {
      // Phase 88 · Supabase rejected the id token. Most common cause:
      // GOOGLE_WEB_CLIENT_ID in .env doesn't match what the Supabase
      // Google provider was configured with, so the audience claim
      // fails verification. Surface the underlying message so the
      // toast points at the real cause instead of a generic "try again".
      AppLogger.error(
        'signInWithGoogle Supabase AuthException: ${e.message}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return (outcome: SocialAuthOutcome.error, errorMessage: e.message);
    } on GoogleSignInException catch (e, st) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return (outcome: SocialAuthOutcome.cancelled, errorMessage: null);
      }
      AppLogger.error(
        'signInWithGoogle GoogleSignInException: ${e.code}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return (
        outcome: SocialAuthOutcome.error,
        errorMessage:
            'Google: ${e.code.name}', // i18n-ignore — provider error code
      );
    } catch (e, st) {
      AppLogger.error(
        'signInWithGoogle failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      // null → the calling surface shows its localized fallback copy.
      // Returning e.toString() here used to toast raw ClientException /
      // SocketException dumps at users on flaky networks.
      return (outcome: SocialAuthOutcome.error, errorMessage: null);
    }
  }

  Future<SocialAuthResult> signInWithApple(AppLocalizations l10n) async {
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
        return (
          outcome: SocialAuthOutcome.error,
          errorMessage: l10n.authErrorAppleNoIdentityToken,
        );
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Phase 94 · same RC-aliasing pattern as the Google path.
      await aliasRevenueCatWithCurrentUser();
      // Phase 140 · single-source latch (see authGateClearedProvider).
      _ref.read(authGateClearedProvider.notifier).markCleared();
      return (outcome: SocialAuthOutcome.success, errorMessage: null);
    } on AuthException catch (e, st) {
      AppLogger.error(
        'signInWithApple Supabase AuthException: ${e.message}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return (outcome: SocialAuthOutcome.error, errorMessage: e.message);
    } on SignInWithAppleAuthorizationException catch (e, st) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return (outcome: SocialAuthOutcome.cancelled, errorMessage: null);
      }
      AppLogger.error(
        'signInWithApple AuthorizationException: ${e.code}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return (
        outcome: SocialAuthOutcome.error,
        errorMessage:
            'Apple: ${e.code.name}', // i18n-ignore — provider error code
      );
    } catch (e, st) {
      AppLogger.error(
        'signInWithApple failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      // null → localized fallback at the call site (see Google above).
      return (outcome: SocialAuthOutcome.error, errorMessage: null);
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
    // Drop the RevenueCat identity so the deleted account's Pro
    // entitlement can't bleed into the next user of this device
    // (Purchases.logIn is called on every sign-in; without a logOut
    // the SDK keeps serving the old app-user-ID's customer info).
    await _logOutRevenueCat();
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
  ///
  /// Shared-device hygiene: also logs the RevenueCat identity out (so
  /// the previous user's Pro entitlement can't leak to the next
  /// session) and wipes user-scoped SharedPreferences (height/weight/
  /// age/goal/plan/XP re-hydrated for a stranger otherwise). Device-
  /// level keys — consent decisions, the 18+ age gate, theme — survive.
  Future<void> signOut() async {
    await _logOutRevenueCat();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearUserScopedPrefs(prefs);
    } catch (e) {
      AppLogger.warning(
        'signOut prefs wipe (non-fatal)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    _invalidateUserScopedProviders();
  }

  /// Prefs that describe the DEVICE, not the account — they survive a
  /// sign-out. Everything else (metrics, plan cache, wizard state, XP,
  /// session logs, streaks, seen-flags…) is user data and is wiped so
  /// the next account on this device starts clean.
  static const Set<String> _deviceLevelPrefKeys = {
    'sixpack.consent.decided',
    'sixpack.consent.analytics',
    'sixpack.consent.crash',
    'sixpack.age_verified',
    'sixpack.birth_year',
    'sixpack.theme_mode',
    'auth.was_anonymous',
  };

  Future<void> _clearUserScopedPrefs(SharedPreferences prefs) async {
    final preserved = <String, Object>{};
    for (final key in _deviceLevelPrefKeys) {
      final value = prefs.get(key);
      if (value != null) preserved[key] = value;
    }
    await prefs.clear();
    for (final entry in preserved.entries) {
      final value = entry.value;
      switch (value) {
        case final bool v:
          await prefs.setBool(entry.key, v);
        case final int v:
          await prefs.setInt(entry.key, v);
        case final double v:
          await prefs.setDouble(entry.key, v);
        case final String v:
          await prefs.setString(entry.key, v);
        case final List<Object?> v:
          await prefs.setStringList(entry.key, v.whereType<String>().toList());
      }
    }
  }

  /// Best-effort RevenueCat identity drop. `logOut` throws when the
  /// current RC user is already anonymous (nothing to log out) or when
  /// the SDK isn't configured (dev builds without keys) — both are
  /// fine to swallow with a breadcrumb.
  Future<void> _logOutRevenueCat() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      AppLogger.warning(
        'RevenueCat logOut skipped',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
  }

  /// Sends a Supabase password-reset email. Returns `null` on success
  /// or a localized, non-technical error message for the toast — never
  /// the raw English Supabase string. An email/password user who
  /// forgets their password was previously locked out permanently
  /// (nothing in the app called `resetPasswordForEmail`).
  Future<String?> resetPassword(AppLocalizations l10n, String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e, st) {
      AppLogger.error(
        'resetPassword AuthException: ${e.message}',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return l10n.authResetEmailFailedCheckAddress;
    } catch (e, st) {
      AppLogger.error(
        'resetPassword failed',
        e,
        stackTrace: st,
        category: 'auth',
      );
      return l10n.authResetEmailFailedGeneric;
    }
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
    // Phase 140 · re-arm the paywall auth gate so a fresh anonymous
    // session (e.g. sign-out then continue-as-guest) sees the gate
    // again before any purchase action.
    _ref.read(authGateClearedProvider.notifier).reset();
  }

  /// Phase 94 · alias the RevenueCat anonymous app-user-ID to the
  /// Supabase user that we just signed in. Wraps configureRevenueCat
  /// (idempotent) so this is safe to call from any sign-in surface
  /// — the modal AuthGate, the standalone /auth screen, or a future
  /// account-link flow — without each call site needing to know the
  /// SDK lifecycle.
  ///
  /// Returns `true` when the alias was completed (or already aligned —
  /// `Purchases.appUserID` already matches the Supabase UUID, so the
  /// `logIn` call is skipped); returns `false` when there was nothing
  /// to align (no current user / anonymous user) or when the call
  /// failed. Public so the paywall close handler can re-await this
  /// before navigating to the dashboard, closing the gap that opened
  /// when an email-auth login left RC unaliased.
  ///
  /// Failures are logged + swallowed: a missed alias is recoverable
  /// (the next purchase still succeeds against the RC anonymous ID,
  /// it just wouldn't be linkable to the Supabase user without a
  /// follow-up logIn). Throwing here would leak into the social-auth
  /// outcome and tell the user "Google sign-in failed" when in fact
  /// only the RC alias did.
  Future<bool> aliasRevenueCatWithCurrentUser() async {
    try {
      await configureRevenueCat();
      final user = Supabase.instance.client.auth.currentUser;
      // Skip if the auth-state stream hasn't published yet (rare —
      // signInWithIdToken resolves with the new user attached).
      if (user == null) return false;
      // Phase 139 · refined anonymous-skip rule. The original guard
      // bailed on any `isAnonymous` user because aliasing a pure-
      // `signInAnonymously` UUID would lock the RC id to a throwaway
      // identity that could later be replaced when the user signs in
      // with Google/Apple (which creates a different Supabase row).
      // BUT: an anonymous user who has linked an email via
      // `auth.updateUser` is mid-conversion — the Supabase UUID is
      // stable across email verification, and the email-signup flow
      // on the paywall fires this alias EXPECTING it to land RC
      // before the user can purchase. Check both `email` and
      // `newEmail` so the rule works regardless of whether the
      // Supabase project requires email confirmation.
      final hasLinkedEmail =
          (user.email ?? '').isNotEmpty || (user.newEmail ?? '').isNotEmpty;
      if (user.isAnonymous && !hasLinkedEmail) return false;
      // Short-circuit if the SDK is already pointing at this user —
      // saves the platform-channel round-trip on repeat invocations
      // (paywall close handler may re-call after the social path has
      // already aliased).
      try {
        final currentRcId = await Purchases.appUserID;
        if (currentRcId == user.id) return true;
      } catch (_) {
        // appUserID throws when the SDK isn't configured; fall through
        // to the logIn attempt, which itself will surface the same
        // condition through the outer catch.
      }
      await Purchases.logIn(user.id);
      // Phase 141 · invalidate the subscription cache so the next
      // read of `subscriptionProvider` re-fetches `Purchases.getCustomerInfo`
      // against the now-aliased user, not against the pre-`logIn`
      // anonymous customerInfo. Without this, the paywall's
      // self-redirect (which keys off `isProProvider`) sees the old
      // anonymous entitlement set and never flips to true for an
      // existing-Pro user signing in from `/auth`.
      _ref.invalidate(subscriptionProvider);
      return true;
    } catch (e, st) {
      AppLogger.warning(
        'RevenueCat alias failed; purchase will fall back to anon RC id',
        category: 'monetization',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
      return false;
    }
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
