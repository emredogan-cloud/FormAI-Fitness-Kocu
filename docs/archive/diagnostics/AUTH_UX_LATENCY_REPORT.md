# Auth UX Latency Report

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Scope:** Identify the perceived freeze in two transitions reported as still feeling janky after V2 routing fix.

---

## What the User Sees

### Issue A — Previous screen → /paywall

Tapping a locked-feature card, the dashboard "Premium" CTA, or any other surface that pushes `/paywall` produces a short freeze before the paywall appears. The previous screen visibly hangs for one or two long frames, then the paywall snaps in.

### Issue B — Existing Pro login → dashboard

After completing email login as an existing Pro user, the route correctly ends on the dashboard (V2 fix verified), but the journey **feels** delayed. There's a frozen moment where the user can't tell whether the app is processing or hung.

Both issues are pure perceived performance. Functional behaviour is correct in both cases.

---

## Why It Feels Frozen

### Issue A — heavy first frame on `/paywall`

GoRouter's default `MaterialPage` ships a slide-up + fade transition (Material 3 default, ~300 ms on Android). The transition runs against the new screen's first frame.

PaywallScreen's first frame is unusually expensive:

| Layer | Cost |
|---|---|
| Brand gradient (full-screen) | low |
| `_PaywallCinematicBackdrop` (dark mode) | **high** — 5 `Image.asset` decodes, 5 `Transform.rotate`, 5 `Opacity` save-layers, a bottom-weight gradient, all inside an `AnimatedBuilder` that immediately starts a 30 s `repeat(reverse: true)` controller |
| Hero composite (`_GenderBeforeAfter`) | medium — large gender-specific webp + glowing arrow + ribbon |
| Plan cards × 3 | medium — animated containers + shadow + skeleton boxes during loading |
| `_NoPaymentBadge` / CTA / restore / legal footer | low each |

On a mid-range Android (Redmi Note 11R baseline), the first frame paint regularly exceeds the 16 ms frame budget. The slide transition's interpolation stalls on that long frame, presenting as a "freeze" right at the start of the animation. The user reads this as "something is loading."

### Issue B — RC hydration latency between paywall mount and dashboard

After `signInWithPassword` succeeds, the router auto-redirects `/auth` → `/paywall` (because the user is no longer anonymous). The fresh PaywallScreen mounts and schedules `_hydrateSubscriptionForCurrentUser` post-frame (V2 fix). That call:

1. Awaits `Purchases.logIn(user.id)` against RC's native SDK (~150-400 ms).
2. Invalidates `subscriptionProvider`, which kicks off a fresh `Purchases.getCustomerInfo()` round-trip (~300-700 ms on a typical mobile network).
3. The provider transitions to `AsyncData(isPro: true)`.
4. The paywall's `ref.listen<bool>(isProProvider, _onProDetected)` fires, schedules `context.go('/')` on the next frame.

Between mount and the navigation, the user spends **500-1100 ms looking at the paywall offer cards** — exactly the content they shouldn't be seeing as a Pro user. There's no signal that anything is happening; the cards just sit there with their skeleton-to-real price hand-off. To the user, the app reads as "froze on the paywall for a beat, then suddenly jumped to dashboard."

---

## Root Cause Summary

Two distinct mechanisms, both rooted in normal Flutter / network latencies that we don't control:

1. **Paint cost vs. transition budget**: the paywall's first frame routinely overruns the 16 ms budget the route transition is interpolating against, so the slide animation visually hitches.
2. **Unmasked async hand-off**: the post-auth alias + customerInfo refetch is correct (it's how the dashboard correctly learns the user is Pro), but it happens with the paywall content fully visible underneath, so the user perceives that window as "stuck."

No auth-logic issue, no race, no missed event. Just perceptual artifacts of synchronous Flutter rendering meeting asynchronous RC calls.

---

## Where to Polish

| Symptom | Mask |
|---|---|
| Slide transition stutters on heavy first frame | Replace the route transition with a 280 ms fade — alpha ramps mask paint cost, and a fade is a more "premium" feel than a slide for a marketing surface |
| Cinematic backdrop is the largest first-paint cost | Skip painting it on the first frame (start at opacity 0), then ease it in over ~520 ms — the hero + cards land first, the ambient depth arrives second |
| Post-auth RC hydration shows raw paywall content for ~500-1100 ms | Overlay a clean dark veil with a single brand-purple progress indicator while `subscriptionProvider.isLoading == true` OR a Pro self-redirect is queued — for Pro users the veil masks the whole window; for free users it dismisses the moment subscription resolves to non-Pro |

All three are presentation-layer changes. None touch auth logic, routing logic, or the V2 redirect handling.

---

## Files Implicated

- `lib/core/routing/app_router.dart` — `/paywall` route's `builder` (default MaterialPage transition)
- `lib/features/monetization/presentation/paywall_screen.dart`:
  - The Stack composition (4 layers, no transitional overlay)
  - `_PaywallCinematicBackdrop` (starts `AnimationController.repeat()` immediately on first build)
  - No subscription-loading skeleton at the screen level (per-card skeleton exists but doesn't address the overall hand-off)
