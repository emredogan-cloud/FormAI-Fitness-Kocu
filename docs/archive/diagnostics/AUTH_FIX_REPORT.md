# Auth/Paywall Fix Report

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Refers to:** `AUTH_PAYWALL_ROOT_CAUSE.md` for the underlying diagnosis.

---

## Architecture Change — Single Source of Truth

Introduced `authGateClearedProvider` as the app-scoped, post-auth latch. The paywall consults it before any other gate evaluation. All other gate logic (email/newEmail/isAnonymous heuristics) remains as defence-in-depth.

```dart
class AuthGateClearedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  @override
  set state(bool value) => super.state = value;
}

final authGateClearedProvider =
    NotifierProvider<AuthGateClearedNotifier, bool>(
  AuthGateClearedNotifier.new,
);
```

Reset to `false` only in `AuthController._invalidateUserScopedProviders()` (sign-out + delete-account).

Set to `true` at every successful auth completion:

| Site | When |
|---|---|
| `AuthController.signInWithGoogle` | After Supabase id-token exchange + RC alias |
| `AuthController.signInWithApple` | After Apple id-token exchange + RC alias |
| `AuthScreen._submit` — signIn branch | After `signInWithPassword` + RC alias |
| `AuthScreen._submit` — anon-upgrade | After `updateUser` + RC alias |
| `AuthScreen._submit` — signUp-with-session | After `signUp` (when session non-null) + RC alias |

---

## Paywall Gate — Updated Predicate

`PaywallScreen._onAuthStateChanged` now reads:

```dart
void _onAuthStateChanged(User? previous, User? next) {
  if (_authGateShown) return;
  if (ref.read(authGateClearedProvider)) {
    _authGateShown = true;
    return;
  }
  final hasLinkedEmail =
      (next?.email ?? '').isNotEmpty || (next?.newEmail ?? '').isNotEmpty;
  final needsAuth = next == null || (next.isAnonymous && !hasLinkedEmail);
  if (!needsAuth) return;
  _authGateShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    showAuthGate(context);
  });
}
```

Order of guards:

1. Local widget latch (`_authGateShown`) — dedupes within a single mount.
2. **Session latch (`authGateClearedProvider`) — survives `pushReplacement`.**
3. `hasLinkedEmail` heuristic — covers the cold-restart anonymous-with-pending-email case.

If any of the three say "no gate", we skip.

---

## Riverpod Cache Race Fix

Replaced the synchronous first-pass read:

```dart
// before
_onAuthStateChanged(null, ref.read(currentUserProvider));

// after
_onAuthStateChanged(null, Supabase.instance.client.auth.currentUser);
```

`currentUser` reads from Supabase's in-memory session row, updated synchronously by every auth operation before its future resolves. No stream microtask. No Riverpod cache.

The `ref.listen` on `currentUserProvider` is kept for subsequent transitions; the listen+read combo together cover both fresh mounts and in-session changes.

---

## Post-Auth Routing — CASE B Fix

Old:

```dart
void _goToPaywall() {
  if (!mounted) return;
  context.pushReplacement(AppRoutes.paywall);
}
```

New:

```dart
Future<void> _routePostAuth() async {
  if (!mounted) return;
  try {
    await ref.read(subscriptionProvider.notifier).refresh();
  } catch (_) {
    // Falls back to free routing — the paywall will re-attempt
    // refresh on mount and the user can still see / use Restore.
  }
  if (!mounted) return;
  final isPro = ref.read(isProProvider);
  if (isPro) {
    context.go(AppRoutes.dashboard);
  } else {
    context.go(AppRoutes.paywall);
  }
}
```

`subscriptionProvider.refresh()` is awaited so RevenueCat's customerInfo is fresh after `Purchases.logIn` aliased the SDK to the Supabase user. `isProProvider` derives from `subscriptionProvider`, so the routing decision is made on hot data.

Guests (`_continueAsGuest`) deliberately bypass `_routePostAuth` — they have NOT authenticated; they need to see the gate when they next reach `/paywall`. Direct `pushReplacement(/paywall)` instead.

---

## Files Touched

| File | Change |
|---|---|
| `lib/features/auth/providers/auth_provider.dart` | Added `authGateClearedProvider` + notifier class; flipped flag in Google + Apple success paths; reset in `_invalidateUserScopedProviders` |
| `lib/features/auth/presentation/auth_screen.dart` | Added `monetization_provider` import; replaced `_goToPaywall` with `_routePostAuth`; flipped `authGateClearedProvider` in the three email-auth success paths; updated `_runSocial` + `_continueAsGuest` |
| `lib/features/monetization/presentation/paywall_screen.dart` | `_onAuthStateChanged` consults `authGateClearedProvider` first; synchronous-first-pass reads `Supabase.auth.currentUser` directly |

No new test files (manual validation in `AUTH_VALIDATION_REPORT.md`).

---

## Architectural Properties Achieved

- **Single source of truth.** Whether the gate should fire is governed by one provider. No widget-local state can disagree with the provider.
- **Authenticated user never re-gated.** Once the flag flips, no remount, no rebuild, no router redirect can revive the gate within the session.
- **No race-prone modal conditions.** The synchronous first-pass reads in-memory Supabase state, not a downstream Riverpod cache.
- **Pro user routed to dashboard.** Returning Pro users never see the paywall (or its gate) again on the same auth.
- **Free user routed to paywall without gate.** Returning free users land directly on the offer cards; they can buy or close without an interstitial.
- **Sign-out cleanly re-arms.** `_invalidateUserScopedProviders` resets the latch alongside the rest of the user-scoped caches, so the next anonymous session sees the gate again.

---

## Validation Summary

- `flutter analyze lib/` → **No issues found! (ran in 3.4s)**
- Manual flow checks documented in `AUTH_VALIDATION_REPORT.md`.
