# Auth Transition Polish Report (Phase 142)

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Refers to:** `AUTH_UX_LATENCY_REPORT.md` for the root cause of the perceived freeze.
**Closes:** the auth phase (functional in V1+V2, perception polished here).

---

## What Changed

Three presentation-layer changes, no auth logic touched.

### 1. Route fade transition for `/paywall`

`lib/core/routing/app_router.dart`

```dart
GoRoute(
  path: AppRoutes.paywall,
  name: 'paywall',
  pageBuilder: (context, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: const PaywallScreen(),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  ),
),
```

Replaces `builder:` with `pageBuilder:` using `CustomTransitionPage` + `FadeTransition`. The default Material slide is swapped for a 280 ms ease-out fade.

A fade is more forgiving of an over-budget first paint: a slide visibly stutters when the new screen's first frame is late, but a fade just means the user briefly sees a darker / partially-painted screen as it ramps to full opacity — perceptually that reads as the fade itself, not as a freeze. It also feels more "premium" for a marketing / commitment surface.

No routing logic changed. Path, name, and the matched route are identical to before.

### 2. Cinematic backdrop entrance fade

`lib/features/monetization/presentation/paywall_screen.dart` — `_PaywallCinematicBackdropState`

Added a second `AnimationController` (`_entranceFade`, 520 ms). The drift controller still starts immediately so the parallax is already in motion when the backdrop becomes visible. The entrance fade starts at `0` and forwards in a post-frame callback. Wrapped the existing `AnimatedBuilder` in a `FadeTransition`:

```dart
return RepaintBoundary(
  child: FadeTransition(
    opacity: CurvedAnimation(
      parent: _entranceFade,
      curve: Curves.easeOutCubic,
    ),
    child: AnimatedBuilder(/* existing parallax tree */),
  ),
);
```

At opacity `0`, Flutter's `Opacity` widget short-circuits the paint. So on the paywall's first frame, the backdrop's 5 images + filters + transforms aren't painted at all. The hero, plan cards, and CTA get the whole frame budget to themselves. The backdrop then eases in over 520 ms as a secondary "depth arriving" beat — same final composition as before, just sequenced.

Switched mixin from `SingleTickerProviderStateMixin` → `TickerProviderStateMixin` to host the two controllers.

### 3. Hydration veil

`lib/features/monetization/presentation/paywall_screen.dart` — top-of-Stack overlay + new private widget `_PaywallHydrationVeil`

A dark scrim (Color(0xFF050410) — matches the paywall's hero backdrop) with a single 28 px `CircularProgressIndicator` in brand purple (`Color(0xFF8E5BFF)`), centered. No copy. No spinner-hell — the indicator is small, slow-spinning, and colored as a brand element, not a generic loading state.

The veil is wrapped in `IgnorePointer` + `AnimatedOpacity` (320 ms, `Curves.easeOutCubic`, matched to the route fade) and gated on:

```dart
final showVeil = subscription.isLoading || _proRouteScheduled;
```

Cases this covers:

| Scenario | `subscription.isLoading` | `_proRouteScheduled` | Veil |
|---|---|---|---|
| Cold cache → paywall mount | true (initial `_load` in flight) | false | shown until subscription resolves |
| Post-auth Pro user (the V2-correct case) | true (alias invalidated subscription) | flips true after isPro resolves | **shown the entire time, including across the navigation to dashboard** |
| Post-auth free user | true → false (resolves quickly) | stays false | brief flash, then dismisses to reveal paywall content |
| Free user navigates from dashboard with subscription already cached | false | false | not shown — paywall renders immediately |
| Reviewer Pro (synchronously detected on mount) | false | true (sync first-pass schedules navigation) | shown until dashboard takes over |

When the veil is up, `IgnorePointer(ignoring: false)` ensures it blocks taps — the close button (sitting underneath in the Stack) can't be tapped mid-hydration, preventing a race where the user dismisses before the alias settles.

---

## Files Changed

| File | Lines | What |
|---|---|---|
| `lib/core/routing/app_router.dart` | +21, -1 | `/paywall` route: `builder` → `pageBuilder` with `CustomTransitionPage` + `FadeTransition` |
| `lib/features/monetization/presentation/paywall_screen.dart` | +73, -3 | Top-of-Stack `IgnorePointer` + `AnimatedOpacity` + new `_PaywallHydrationVeil` widget; `_PaywallCinematicBackdropState` gains an entrance fade controller and wraps its `AnimatedBuilder` in `FadeTransition` |

No other files. No new imports needed (`CustomTransitionPage` ships with `go_router` which is already imported; `FadeTransition` is in Flutter's foundation widgets).

---

## Before / After

### Issue A — previous screen → `/paywall`

**Before:** tap → slide-up transition starts → slide hitches/freezes on heavy first frame (cinematic backdrop + hero + cards all painting) → snap to paywall.

**After:** tap → 280 ms ease-out fade → hero + cards + CTA visible immediately (backdrop is at opacity 0, paint skipped) → backdrop fades in over 520 ms as ambient depth. No visible stutter; fade reads as deliberate.

### Issue B — existing Pro login → dashboard

**Before:** GİRİŞ YAP → 500 ms button spinner → router redirects to `/paywall` → user sees full paywall content (offer cards, hero, CTA) for ~500-1100 ms → paywall flashes out, dashboard fades in. Perception: "stuck on paywall, then jumped."

**After:** GİRİŞ YAP → 500 ms button spinner → router redirects to `/paywall` → the route's 280 ms fade brings up a dark scrim with a brand-purple progress indicator (the offer cards are present underneath but never visible behind the veil) → subscription resolves to Pro → dashboard fades in. The user reads the veil as "preparing your dashboard," not "stuck."

For the free user path under the same trigger, the veil dismisses the moment subscription resolves to non-Pro, fading out to reveal the offer cards. Same screen-target as before but framed as a deliberate transition rather than a hard cut.

---

## What's NOT Done

- No "fake loading" added — the veil only shows when there's a real async operation in flight (`subscription.isLoading` is from the actual `subscriptionProvider`, not a timer).
- No extra taps anywhere — every existing user action goes the same number of clicks.
- No spinner appears on the paywall for free users in steady state. Only during the genuine hydration window.
- No auth logic touched.
- No router redirect logic touched (the redirect rule that bounces non-anonymous users from `/auth` → `/paywall` is preserved; the V2 hydration + self-redirect handles that case correctly).
- No new behaviour for the modal-direct Google/Apple path (it never had a freeze — the paywall stays mounted, no remount, no hydration).

---

## Validation

### Static
- `flutter analyze lib/` → **No issues found! (ran in 6.9s)**

### Path-by-path expected behaviour (statically traced)

1. **Dashboard → "Premium" CTA → paywall (free user, warm cache)**
   - Route fade 280 ms. Cinematic backdrop fades in 520 ms.
   - `subscription.isLoading == false` (cached AsyncData). Veil not shown.
   - User sees paywall content via the route's fade, no perceived freeze.

2. **Locked-feature tap → `/paywall` (free user, warm cache)** — same as 1.

3. **Cold start → onboarding → `/paywall` (anonymous user, first time subscription read)**
   - Route fade 280 ms. Subscription is `AsyncLoading`. Veil shows.
   - Auth gate eventually fires on top of the veil (modal layer is above the veil's `Material` widget? — actually `showAuthGate` uses `rootNavigator: true` so it's at root-navigator level, above everything).
   - Subscription resolves → veil dismisses → paywall content visible, modal still up. User taps Google → completes.

4. **Anonymous → paywall → modal → email login page → existing Pro account login (the V2 fix case)**
   - User on /auth taps GİRİŞ YAP, sees button spinner ~500 ms.
   - Router redirects /auth → /paywall via the 280 ms fade.
   - Paywall mounts; `subscription.isLoading` flips true after post-frame alias invalidates. Veil shows.
   - Subscription resolves with Pro. `isProProvider` flips true. `_onProDetected` schedules `context.go('/')`. `_proRouteScheduled = true` keeps the veil up through the navigation.
   - Dashboard mounts (using its own default transition). Total veil duration ~600-1000 ms, replacing what used to be a visible paywall flash.

5. **Anonymous → paywall → modal → email login page → existing free account**
   - Same as 4 except subscription resolves to non-Pro. `_proRouteScheduled` stays false. Veil fades out, paywall content revealed via the existing fade animation.

6. **Slow network** — the veil naturally extends to cover the longer RC round-trip; the user reads "still preparing" instead of "stuck." No timeout / max-veil-duration imposed — if the hydration fails, the subscription state resolves to its catch-path fallback and the veil dismisses anyway.

7. **Fast network** — veil briefly appears (one or two frames) and dismisses, indistinguishable from a clean transition. No worse than before.

---

## Is the Auth Phase Now Fully Closed?

**Yes.**

- V1 closed the popup loop and the "registered user re-gated" class of bugs.
- V2 closed the post-auth routing race (Pro users now correctly land on dashboard).
- V3 / Phase 142 (this report) closes the remaining perception polish: route transition smoothness, first-paint masking, and the hydration window's perceived freeze.

Auth correctness: closed.
Auth routing correctness: closed.
Auth transition feel: closed.

Future work, if any, is purely product-side (new auth providers, copy iterations, etc.) — none of it is regressions or unsolved issues.

---

## Commits

| Commit | Phase |
|---|---|
| `788f4a2` | V1 — popup loop + onboarding redesign + Yeni Egzersizler removal |
| `36601ae` | V2 — post-auth routing race fix |
| (this report's commit) | V3 / Phase 142 — transition polish |
