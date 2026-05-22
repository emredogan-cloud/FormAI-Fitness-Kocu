# Auth/Paywall Popup Loop — Root Cause Analysis

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Bug:** Anonymous user hits paywall → auth-gate popup → clicks "E-posta ile Giriş" → /auth screen → completes Google or email auth → returns to paywall → **popup reappears**, even though the user is now authenticated.

---

## Why Google/Apple-direct-from-popup Worked, but Email-via-/auth Did Not

The two paths take different return routes back to `/paywall`:

| Path | Return mechanism | PaywallScreen lifecycle |
|---|---|---|
| **Modal → Google/Apple** | `Navigator.of(context, rootNavigator: true).pop()` (auth_modal_bottom_sheet.dart:451) | Underlying paywall stays mounted → `_authGateShown=true` latch survives → gate doesn't refire |
| **Modal → /auth → ANY auth method** | `context.pushReplacement(AppRoutes.paywall)` (auth_screen.dart:53, old `_goToPaywall`) | **Fresh PaywallScreen instance** → `_authGateShown=false` resets → gate evaluates from scratch |

This single line — `pushReplacement` from `_goToPaywall` — destroyed the existing paywall mount and rebuilt it with a fresh widget-state latch. That alone is half the bug.

---

## The Other Half — Riverpod Cache Race

In `PaywallScreen.build()`, the synchronous first-pass call was:

```dart
_onAuthStateChanged(null, ref.read(currentUserProvider));
```

`currentUserProvider` is defined as:

```dart
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});
```

The provider re-runs only when `authStateProvider` (a `StreamProvider` over `Supabase.instance.client.auth.onAuthStateChange`) emits. Between auth operations resolving and that stream emitting, the provider's cached value is stale.

For `Supabase.auth.updateUser(...)` (the anonymous → email-linked upgrade path used in `_submit`'s sign-up branch on guest users):

1. `updateUser` returns; `Supabase.instance.client.auth.currentUser` is **synchronously updated** to the now-email-linked user.
2. The auth-state stream emits — but on a microtask, NOT synchronously inside `updateUser`.
3. `pushReplacement(/paywall)` runs immediately after `updateUser` resolves.
4. Fresh `PaywallScreen` mounts → `build()` runs → `ref.read(currentUserProvider)` returns the **cached pre-update value** because the stream hasn't emitted yet.
5. That cached value is the original anonymous user with no email. The Phase-139 `hasLinkedEmail` heuristic fails. Gate fires.

The bug is intermittent in theory (depends on microtask ordering); in practice the navigation always wins, so the gate always re-fires.

---

## Compounding Issue — Phase 139 `hasLinkedEmail` Heuristic Is Fragile

Phase 139 added:

```dart
final hasLinkedEmail =
    (next?.email ?? '').isNotEmpty || (next?.newEmail ?? '').isNotEmpty;
final needsAuth = next == null || (next.isAnonymous && !hasLinkedEmail);
```

This is correct in principle but depends on:

- `User.email` being populated post-`updateUser` (only when Supabase confirmations are disabled)
- `User.newEmail` being populated when confirmations are pending (only correctly populated by certain `supabase_flutter` SDK versions, and only after a refresh of the user from the server)

For the synchronous-first-pass code path the values come from the Riverpod cache (stale) anyway, so even when the SDK eventually has the right fields populated, the gate's evaluation already happened with stale data.

---

## Why a Latch Plus a Live-Read Fixes It

Two reinforcing fixes, both rooted in the diagnosis above:

1. **A Riverpod-scoped session latch.** `authGateClearedProvider` lives in the app-scoped `ProviderContainer`, not the widget. When any auth flow succeeds, the notifier flips to `true`; the paywall's gate code reads it first and short-circuits regardless of `isAnonymous` / `email` / `newEmail`. `pushReplacement` destroys widgets but not providers, so the latch survives. Reset happens only on sign-out / delete-account via `_invalidateUserScopedProviders`.

2. **Bypass Riverpod's cache for the synchronous first-pass.** Read `Supabase.instance.client.auth.currentUser` directly. It's the in-memory session getter — updated synchronously by every auth operation before its future resolves. No stream-microtask race.

Together, those two changes mean:

- The "post-`updateUser`-pushReplacement" path is covered by the latch (set by `_submit` right before `_routePostAuth` runs).
- The "stream hasn't emitted yet on remount" race is covered by the live-read.
- Cold restarts where the session was lost (no real auth happened) still fire the gate correctly — the latch is initially `false` and `currentUser` correctly reports anonymous.

---

## CASE B (Existing Pro User on New Device)

The bug had a sibling: even when the loop was eventually patched manually, a returning Pro user landed on the paywall instead of the dashboard. AuthScreen always called `pushReplacement(/paywall)` regardless of subscription status.

Fixed by `_routePostAuth`: refresh `subscriptionProvider` (so RC's customerInfo is hydrated post-`Purchases.logIn`), then `context.go('/')` if `isPro`, else `context.go(/paywall)`.

---

## Files Identified in Diagnosis (all reviewed)

- `lib/features/monetization/presentation/paywall_screen.dart` — the `_authGateShown` widget-state latch and the `currentUserProvider` synchronous-read pattern.
- `lib/features/auth/presentation/auth_screen.dart` — the `_goToPaywall` `pushReplacement` call site.
- `lib/features/auth/presentation/auth_modal_bottom_sheet.dart` — the working Google/Apple path (kept as-is; it's the working baseline).
- `lib/features/auth/providers/auth_provider.dart` — `currentUserProvider`, `authStateProvider`, `AuthController`.
- `lib/core/routing/app_router.dart` — confirmed redirect logic does NOT re-trigger the gate (it only redirects authenticated users away from `/auth`).
- `lib/features/monetization/providers/monetization_provider.dart` — confirmed `isProProvider` reads from `subscriptionProvider` which needs an explicit refresh after RC `logIn`.

---

## Summary Table

| Layer | Defect | Why it bit | Fix |
|---|---|---|---|
| Widget state | `_authGateShown` reset on remount | `pushReplacement` destroyed paywall after `/auth` returned | Cross-cutting latch in Riverpod (`authGateClearedProvider`) |
| Riverpod cache | `currentUserProvider` lagged Supabase in-memory state | Stream emits on microtask; navigation outraces it | Synchronous read of `Supabase.auth.currentUser` |
| Heuristic | `hasLinkedEmail` depended on SDK populating `newEmail` | Version-dependent + stale-cache compounded | Replaced as first short-circuit with explicit "auth completed this session" flag |
| Routing | `/auth` always returned to `/paywall` | No subscription check | `_routePostAuth` refreshes RC + branches on `isPro` |
