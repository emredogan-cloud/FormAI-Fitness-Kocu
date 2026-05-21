# Auth Post-Routing Race Fix (V2)

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Refers to:** the previous V1 fix in `AUTH_FIX_REPORT.md` and `AUTH_PAYWALL_ROOT_CAUSE.md`.

---

## 1. Root Cause

V1 fixed the popup loop. The remaining bug was a different race in the same handshake:

```
/auth → user signs in as existing Pro → expected: /dashboard
                                       → actual:   /paywall
```

Trace:

1. **`_submit` calls `await _client.auth.signInWithPassword(...)`.**
2. Supabase updates its in-memory session and emits `AuthChangeEvent.signedIn` on `auth.onAuthStateChange`.
3. The stream emission propagates synchronously into `authRefreshListenable` (its `.listen(...)` calls `notifier.refresh()`), which fires `notifyListeners()` on the listenable bound to GoRouter's `refreshListenable`.
4. **GoRouter re-evaluates redirect for the current location `/auth`. The rule `if (path == AppRoutes.auth) return user.isAnonymous ? null : AppRoutes.paywall;` returns `/paywall`. Router navigates.**
5. `AuthScreen` unmounts. `_submit`'s `await` is still pending; its closure keeps running, but on a `WidgetRef` that's now bound to a disposed `ConsumerState`.
6. `_submit` continues: `await _persistWizardMetrics()`. This calls `ref.read(...)` on the disposed ref. Depending on Riverpod version, either throws silently into the `catch` or returns a stale value.
7. **`aliasRevenueCatWithCurrentUser` never gets called.** `subscriptionProvider` is not invalidated. RC SDK is still pointing at the anonymous app-user-ID. `Purchases.getCustomerInfo` would return the anonymous (empty) entitlement set.
8. PaywallScreen mounts (from step 4). It reads `isProProvider`. With `subscriptionProvider` still holding the pre-auth anonymous snapshot, `isPro == false`. Offer cards render.
9. The user taps the close button (X). `_close()` runs `aliasRevenueCatWithCurrentUser` for the first time. RC re-aliases. `getCustomerInfo` returns Pro entitlements. By the time the dashboard mounts, `subscriptionProvider` has lazily refreshed and `isProProvider` reports true — hence "after closing paywall, dashboard shows Pro already active."

This is exactly the user's reported symptom: auth works, RC works, subscription works, **routing timing is wrong** — because the side-effect that would refresh subscription (alias) only happens at paywall close, not at paywall mount.

---

## 2. Files Changed

| File | Change |
|---|---|
| `lib/features/auth/providers/auth_provider.dart` | `aliasRevenueCatWithCurrentUser` now `_ref.invalidate(subscriptionProvider)` after `Purchases.logIn`. Forces `getCustomerInfo` against the newly-aliased user on the next read. |
| `lib/features/monetization/presentation/paywall_screen.dart` | (a) `initState` schedules a post-frame `aliasRevenueCatWithCurrentUser` so RC + subscription are guaranteed fresh on mount, regardless of whether `_submit` got to run alias before AuthScreen unmounted. (b) `build` now `ref.listen<bool>(isProProvider, _onProDetected)` + a synchronous first-pass check, both behind a one-shot `_proRouteScheduled` latch, scheduling `context.go('/')` the moment Pro is detected. |

No other files touched. Working auth paths (modal-direct Google/Apple, anonymous-guest, popup latch, onboarding) are untouched.

---

## 3. Patch Summary

### a. alias now invalidates subscriptionProvider

```dart
// auth_provider.dart, aliasRevenueCatWithCurrentUser
await Purchases.logIn(user.id);
_ref.invalidate(subscriptionProvider);  // ← NEW
return true;
```

The next read of `subscriptionProvider` re-runs `_load`, which calls `Purchases.getCustomerInfo` against the just-aliased user, populating `isPro` from the active entitlement set.

### b. paywall hydrates subscription on mount

```dart
// paywall_screen.dart, initState
WidgetsBinding.instance.addPostFrameCallback((_) {
  _hydrateSubscriptionForCurrentUser();
});

Future<void> _hydrateSubscriptionForCurrentUser() async {
  if (!mounted) return;
  try {
    await ref
        .read(authControllerProvider)
        .aliasRevenueCatWithCurrentUser();
  } catch (e, st) {
    AppLogger.warning(...);
  }
}
```

`aliasRevenueCatWithCurrentUser` is idempotent — short-circuits when RC's `appUserID` already matches the Supabase user. For the post-`/auth`-landing case, RC was still on the anonymous ID, so the call actually runs `Purchases.logIn` + invalidates subscription. For Pro users navigating to paywall from anywhere else (dashboard, locked-feature tap), the call is a no-op.

### c. paywall self-redirects when Pro

```dart
// paywall_screen.dart, build
ref.listen<bool>(isProProvider, _onProDetected);
final currentIsPro = ref.read(isProProvider);
if (currentIsPro && !_proRouteScheduled) {
  _proRouteScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.go('/');
  });
}

void _onProDetected(bool? previous, bool next) {
  if (!next || _proRouteScheduled) return;
  _proRouteScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.go('/');
  });
}
```

The synchronous first-pass covers the case where `isProProvider` is already true on mount (reviewer user, or alias completed before paywall finished building). The `ref.listen` covers the typical case where alias hydration completes after build, flipping the provider.

The `_proRouteScheduled` latch dedupes against (1) repeated `ref.listen` fires within a frame and (2) the synchronous read racing the listen callback.

---

## 4. Why the Previous Logic Failed

`_routePostAuth` in AuthScreen had:

```dart
if (!mounted) return;
try { await ref.read(subscriptionProvider.notifier).refresh(); } catch (_) {}
if (!mounted) return;   // ← KILLS HERE
final isPro = ref.read(isProProvider);
if (isPro) context.go(AppRoutes.dashboard);
else context.go(AppRoutes.paywall);
```

When AuthScreen unmounted due to the router's auto-redirect on auth state change, the second `if (!mounted) return` short-circuited before `isPro` could be evaluated and acted on. The paywall was left mounted with a stale anonymous subscription snapshot and no way for the user to be moved to the dashboard except by manually closing.

The V2 fix doesn't try to keep AuthScreen alive or fight the router redirect. Instead it moves the responsibility — "ensure subscription is fresh and Pro users land on dashboard" — into the **paywall itself**, which is the screen that's actually rendered after the redirect. Paywall's lifecycle is independent of AuthScreen's, so the post-frame `addPostFrameCallback` reliably runs the alias hydration, and the `ref.listen` reliably fires when subscription flips.

---

## 5. Validation

- `flutter analyze lib/` → **No issues found! (ran in 3.2s)**

### Code-path trace — existing Pro from /auth (the bug case)

1. User on `/auth`, GİRİŞ YAP with Pro credentials.
2. `signInWithPassword` succeeds. Auth stream emits.
3. Router refresh → redirect `/auth` → `/paywall`. AuthScreen unmounts.
4. PaywallScreen mounts.
5. `initState` schedules post-frame `_hydrateSubscriptionForCurrentUser`.
6. `build` runs: `_authGateShown` short-circuit via `authGateClearedProvider` (already true from `_submit`'s pre-unmount path), gate doesn't fire. `ref.listen<bool>(isProProvider, _onProDetected)` registered. `currentIsPro` snapshot is false (subscription still anonymous).
7. **Post-frame callback fires:** `_hydrateSubscriptionForCurrentUser` → `aliasRevenueCatWithCurrentUser`. Since RC's `appUserID` was still the anonymous ID, the alias's short-circuit doesn't trip. `Purchases.logIn(user.id)` runs. `_ref.invalidate(subscriptionProvider)` fires.
8. `subscriptionProvider` re-runs `_load`: `Purchases.getCustomerInfo` against the Pro user, returns active `FormAI Pro` entitlement. State → `AsyncData(isPro: true)`.
9. `isProProvider` re-evaluates → true.
10. `ref.listen<bool>(isProProvider, ...)` fires (`false → true`). `_onProDetected` schedules post-frame `context.go('/')`.
11. Dashboard mounts. Pro features unlocked. ✅

User-visible: paywall is rendered briefly (one or two frames + RC round-trip — typically 500-900ms) then transitions to dashboard.

### Other paths (no regression expected)

| Path | Outcome |
|---|---|
| Modal-direct Google/Apple → still-mounted paywall | Latch (V1) suppresses gate; isPro check runs; if user happens to be Pro, redirects to dashboard. Same behavior as before for free users. |
| `/auth` → existing Free | Router redirects `/auth` → `/paywall`. Paywall mounts. Alias runs (already aliased for free users post-`signInWithPassword`? Actually `_submit`'s alias may have died, so paywall's hydration alias takes over). `getCustomerInfo` returns empty entitlement set. `isProProvider == false`. Paywall stays, no gate. User can purchase or close. |
| `/auth` → email signup new user | Same as Free path — paywall mounts, alias hydrates against the anon-upgraded user, no Pro entitlements, paywall stays. |
| Anonymous guest reaches /paywall directly | `currentUser.isAnonymous == true`, `authGateClearedProvider == false`. Gate fires as before. Paywall's alias hydration short-circuits (anonymous + no linked email → bails inside alias helper). No regression. |
| Reviewer Pro user reaches /paywall | `isReviewerProvider` returns true → `isProProvider` returns true via the `OR isReviewer` branch — even with `subscriptionProvider` empty. Synchronous first-pass schedules dashboard navigation immediately on mount. Briefer flash than the network-bound Pro case. |
| Dashboard → "Premium" CTA → paywall (free user) | Free user, isPro=false, no self-redirect. Normal paywall behavior. |
| Paywall close (X) tapped manually | `_close` still runs alias (now also invalidates subscription as a side effect), then `context.go('/')`. Idempotent with V2. |

---

## 6. Confidence Level

**High** for the specific bug reported.

The fix doesn't depend on timing of microtask ordering, Supabase SDK behavior around stream emission, or whether `_submit` survives AuthScreen's unmount. The paywall takes responsibility for: (a) ensuring its own subscription state matches the live Supabase user, and (b) self-redirecting if that state turns out to be Pro. Both are operations on providers/refs owned by the paywall's own widget tree, not on an upstream-screen's potentially-disposed ref.

**Residual risk**:
- `Purchases.logIn` failures (network down, RC misconfigured) leave the paywall on the offer cards. That's already the fallback in the V1 catch path; no regression. The user can retry by closing and reopening.
- The brief flash of paywall (~500-900ms) before redirect. Acceptable; could be polished later with a loading overlay if needed.

---

## 7. Files Changed (final list)

- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/monetization/presentation/paywall_screen.dart`

---

## 8. Validation Re-run for the User's Specific Test

> Retest: popup → email login → existing PRO → dashboard direct

With V2:
1. **popup**: gate fires (anonymous user reaches paywall as usual)
2. **email login**: user clicks "E-posta ile Giriş Sayfasına Git" → navigates to `/auth`
3. **existing PRO sign-in**: user enters credentials, taps GİRİŞ YAP
4. **expected route to /dashboard**: covered by paywall's `_hydrateSubscriptionForCurrentUser` + `_onProDetected`. Even if `_submit`'s post-auth flow dies in the AuthScreen-unmount race, the paywall picks up where it left off, runs alias, invalidates subscription, sees `isPro=true`, and navigates to `/`.

No manual close required.
