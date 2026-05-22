# Auth/Paywall Validation Report

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Refers to:** `AUTH_FIX_REPORT.md` for the changes under test.

---

## Static Validation

- `flutter analyze lib/` → **No issues found! (ran in 3.4s)**
- `grep -rn "_goToPaywall" lib/` → zero matches (old method fully replaced).
- `grep -rn "authGateClearedProvider" lib/` → 7 expected references across `auth_provider.dart` (definition + Google + Apple + reset), `auth_screen.dart` (3 email-auth paths), `paywall_screen.dart` (read site).

---

## Manual Flow Validation Matrix

The matrix below was walked through statically against the new code paths. Each row names the user actions, the expected provider/state transitions, and the resulting paywall behaviour.

### 1. Popup → Google (modal-direct)
**Actions:** Anonymous user opens paywall → gate modal appears → taps Google → completes Google sign-in.

**Trace:**
1. `_onGooglePressed` → `AuthController.signInWithGoogle`
2. Supabase `signInWithIdToken` succeeds. `currentUser` becomes the Google user (`isAnonymous == false`).
3. `aliasRevenueCatWithCurrentUser` → `Purchases.logIn(user.id)`.
4. **`authGateClearedProvider.state = true`.**
5. Modal returns `SocialAuthOutcome.success`; modal pops via `Navigator.of(context, rootNavigator: true).pop()`.

**Paywall behaviour:** Same PaywallScreen instance still mounted; `_authGateShown` was already true from the original fire. Auth state stream re-emits; `_onAuthStateChanged` short-circuits at the local latch. **No second popup.** ✅

### 2. Popup → Email login page → Google (cross-screen Google)
**Actions:** Anonymous user on paywall → gate modal → taps "E-posta ile Giriş Sayfasına Git" → navigates to `/auth` → taps Google on `/auth` → completes Google sign-in.

**Trace:**
1. Modal: `Navigator.pop()` + `context.go(/auth)` — paywall destroyed.
2. AuthScreen `_signInWithGoogle` → `AuthController.signInWithGoogle`.
3. Google sign-in succeeds. **`authGateClearedProvider.state = true`** (set inside `AuthController.signInWithGoogle`).
4. `_runSocial` calls `_routePostAuth`.
5. `subscriptionProvider.refresh()` runs against the now-aliased RC SDK; resolves to the user's real entitlement set.
6. `isProProvider` read:
   - If Pro → `context.go(/)` — dashboard, no paywall ever rendered. ✅
   - If Free → `context.go(/paywall)` — fresh PaywallScreen mounts.

**Fresh paywall mount path (free user):**
- `_onAuthStateChanged` synchronous first-pass: reads live `Supabase.auth.currentUser` (Google user, `isAnonymous == false`). Even if it were anonymous, `authGateClearedProvider == true` short-circuits the gate. **No popup.** ✅

### 3. Popup → Email login page → Email signup (anon-upgrade)
**Actions:** Anonymous onboarding user → paywall → gate modal → "/auth" → switches to "KAYIT OL" mode → enters email+password → submits.

**Trace:**
1. `_submit` enters the signUp branch with an anonymous current user.
2. `auth.updateUser(UserAttributes(email, password))` — Supabase upgrades the anonymous user identity in-place. `currentUser.isAnonymous` stays true (until verification) but `currentUser.email` or `currentUser.newEmail` is now set.
3. `aliasRevenueCatWithCurrentUser` — RC aliased to the (now-stable) Supabase UUID.
4. **`authGateClearedProvider.state = true`.**
5. Toast: "E-posta adresine doğrulama bağlantısı gönderildi. Hesabın yükseltildi, ilerlemen korundu."
6. `_routePostAuth` → fresh `subscriptionProvider.refresh()` → `isProProvider` (false for a new email) → `context.go(/paywall)`.

**Fresh paywall mount path:**
- Synchronous first-pass: `Supabase.auth.currentUser` returns the updated user (whose `email` or `newEmail` is set). `authGateClearedProvider == true` short-circuits at step (2) of the gate predicate. **No popup.** ✅

### 4. Popup → Email login page → Existing Free account (sign-in)
**Actions:** Anonymous user → paywall → gate modal → "/auth" → enters existing free credentials → "GİRİŞ YAP".

**Trace:**
1. `_submit` enters signIn branch.
2. `auth.signInWithPassword` succeeds. `currentUser` is the free account (`isAnonymous == false`).
3. `aliasRevenueCatWithCurrentUser` — RC.logIn aliases to the free user's UUID.
4. **`authGateClearedProvider.state = true`.**
5. `_routePostAuth` → refresh → `isProProvider == false` → `context.go(/paywall)`.

**Fresh paywall mount path:** Same as case 3. **No popup.** ✅

### 5. Popup → Email login page → Existing Pro account (sign-in)
**Actions:** Anonymous user → paywall → gate modal → "/auth" → enters existing Pro credentials → "GİRİŞ YAP".

**Trace:**
1. `_submit` enters signIn branch.
2. `auth.signInWithPassword` succeeds. `currentUser` is the Pro account.
3. `aliasRevenueCatWithCurrentUser` — RC.logIn aliases to the Pro user's UUID. RC's customerInfo cache now reflects the active entitlement (after refresh).
4. **`authGateClearedProvider.state = true`.**
5. `_routePostAuth` → `subscriptionProvider.refresh()` awaits the network round-trip → `subscriptionState.isPro == true` → `isProProvider == true` → `context.go(/)`.

**User experience:** Lands on dashboard with Pro features unlocked. Paywall never re-rendered. ✅

### 6. Cold restart
**Actions:** App closed and reopened.

**Trace:**
- Supabase persists session to disk; on restart `currentUser` is restored (or null if expired).
- `authGateClearedProvider` resets to its initial value (`false`) because it's an in-memory Riverpod state.

**Result depending on persisted state:**
- Pro user (session restored, `isAnonymous == false`): no gate would fire; `isProProvider` resolves to true after `subscriptionProvider` boots. Dashboard. ✅
- Free user (session restored, `isAnonymous == false`): gate predicate sees a non-anonymous user → no gate. Paywall renders normally. ✅
- Anonymous user (no real auth ever): `authGateClearedProvider == false`, `isAnonymous == true`, no linked email → gate fires correctly. ✅

### 7. Cross-device session restore
Identical to case 5 except the device is fresh. The Supabase session is established by signInWithPassword on the new device; RC is aliased; subscription refresh hits the network for entitlement. Pro routes to dashboard, Free routes to paywall (no gate). ✅

---

## Sign-Out Re-Arm Test (Defence-in-Depth)

**Actions:** Authenticated user goes to account-settings → signs out.

**Trace:**
1. `AuthController.signOut` calls `Supabase.instance.client.auth.signOut`.
2. Calls `_invalidateUserScopedProviders` which:
   - Invalidates user-scoped Riverpod providers (workout, subscription, wizard, recipes, etc.)
   - **Resets `authGateClearedProvider.state = false`.**
3. Router redirects to `/auth` because session is null.

**Subsequent paywall reach (after re-auth as anonymous via "Misafir Olarak Devam Et"):**
- `_continueAsGuest` does NOT flip the flag (anonymous users still need the gate before purchase).
- Paywall mounts; `authGateClearedProvider == false`; `currentUser.isAnonymous == true`; gate fires correctly. ✅

---

## What's NOT Tested by This Walkthrough

- Real Google / Apple OAuth round-trips (requires device, store accounts).
- Real Supabase server-side `updateUser` flow with confirmations enabled vs disabled (project config).
- Real RevenueCat entitlement fetch latency on a slow network.
- Web platform (`/auth` flow differs on Flutter web — not in scope for this fix).

These require manual testing on a device or staging. The code paths above have been statically traced against the post-fix codebase and `flutter analyze` is clean.

---

## Manual Test Plan for Device QA

When the build hits a device, run this checklist:

1. [ ] Fresh install → onboarding → reach paywall → "E-posta ile Giriş" → "GİRİŞ YAP" with an unknown email → assert error toast, stay on /auth (no loop).
2. [ ] Fresh install → onboarding → reach paywall → "E-posta ile Giriş" → "KAYIT OL" with a new email → assert confirmation toast + lands on paywall WITHOUT gate popup.
3. [ ] Fresh install → onboarding → reach paywall → "E-posta ile Giriş" → Google → assert lands on paywall WITHOUT gate popup, or on dashboard if the Google account is already Pro.
4. [ ] Fresh install → onboarding → reach paywall → modal → tap Google directly → assert no second popup after sign-in.
5. [ ] Existing-Pro account → sign in via email → assert lands on dashboard, NOT paywall.
6. [ ] Cold-restart while authenticated → assert no gate popup anywhere.
7. [ ] Sign out from settings → continue as guest → reach paywall → assert gate popup fires (re-armed).
8. [ ] After case 7, close the popup via successful Google → assert no second popup.

---

## Confidence Level

- **Static analysis**: clean.
- **Code-path tracing**: all 7 user-listed cases trace correctly through the new code.
- **Architecture**: single source of truth achieved; the latch is the only thing that can suppress the gate, and it's only flipped where auth genuinely succeeded.

Remaining risk: SDK-specific behaviors of `Supabase.auth.updateUser` and `Purchases.logIn` under network failure modes. The fix is defensive against the cache/timing races we identified, but a hard network failure during `_routePostAuth.refresh()` falls back to "free routing" (paywall). Acceptable — user can retry from the paywall via Restore.
