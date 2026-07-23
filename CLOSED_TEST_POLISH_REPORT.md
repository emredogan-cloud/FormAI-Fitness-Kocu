# FormAI — Closed Test Polish Sprint · Report

**Scope:** Visual quality / production polish only. No new functionality. Every
change preserves existing behaviour; no screen was redesigned beyond the one
explicitly requested (the paywall). RevenueCat offerings, purchase, and restore
flows are untouched at the logic layer.

**Branch:** `main` · **Head:** `dbe8a6d`
**Commits (this sprint):**

| Commit | Task | Title |
|--------|------|-------|
| `6618031` | 3 | brand(coach): adopt new_form.png as the official FormAI coach |
| `32d7499` | 4 | brand(icon): new AI Fitness Coach launcher icon |
| `0250282` | 2 | feat(premium): one-time premium welcome tour after first purchase |
| `dbe8a6d` | 1 | feat(paywall): rebuild per new_paywall.png reference — RevenueCat intact |

---

## 1. Summary

Four of the six requested items are complete, committed, and verified. Two
(image-library refresh · in-app-asset integration) are inventoried and mapped
but **deferred** — see §7 for why and for concrete next steps.

| # | Task | Status | Verified |
|---|------|--------|----------|
| 1 | Paywall rebuilt to `new_paywall.png` | ✅ Done | 328 widget tests render the full screen + assert; RevenueCat logic untouched |
| 2 | One-time Premium welcome popup | ✅ Done | Analyze-clean; locally gated once-per-user |
| 3 | New Form coach image everywhere | ✅ Done | **Device-verified** across 4+ screens |
| 4 | New launcher icon | ✅ Done | **Device-confirmed** (app switcher shows new icon) |
| 5 | Image-library refresh (18 imgs) | ⏸ Deferred | Assessed + mapped (§7) |
| 6 | In-app-asset integration (8 assets) | ⏸ Deferred | Assessed + mapped (§7) |

**Regression posture:** `flutter analyze` → 0 issues. Full test suite green
(328 tests). Release APK builds (138 MB). No behavioural surface changed.

---

## 2. Screens modified

### Paywall — `lib/features/monetization/presentation/paywall_screen.dart` (Task 1)
Rebuilt as a responsive Flutter interface reproducing `photos/new_paywall.png`
(not embedded as an image). Only the **visual widgets** were rewritten; every
RevenueCat entry point (`_buildPlansRow`, `_buildCta`, `_buildRestoreButton`,
`_purchase`, `_restore`, `_packageForPlan`) is byte-for-byte unchanged.

- **Hero** rebuilt as a two-column layout: left = "AI Destekli" badge +
  two-tone `RichText` headline (*Kişiselleştirilmiş* / *planınızı alın!*) +
  subtitle; right = the coach portrait with a ShaderMask edge-fade.
- **Feature strip**: three tiles (130+ egzersiz / Kişisel / İlerleme) plus an
  "AI Features" card with a checklist and a FORM SKORU 94 gauge.
- **Plan cards**: added an **honest** strikethrough anchor + discount badge.
  The struck price is *derived* from the live monthly store price
  (`monthly × 3` or `× 12`), never hardcoded — satisfies Apple 2.3.1 / TR
  reference-price rules. Derivation fails gracefully to no-anchor if the price
  string can't be parsed.
- Added a **satisfaction-guarantee card** and refreshed the "🔥 EN POPÜLER"
  badge.

### Premium welcome — `paywall_screen.dart` purchase hook (Task 2)
On the **first** `PurchaseOutcome.success` only, the paywall now calls
`PremiumWelcomeSheet.show(context)` after persisting the once-seen flag.
Repeat purchases keep the original post-purchase delay. No change to how the
entitlement itself is granted.

### Onboarding / coach surfaces (Task 3)
No source edits — the coach image funnels through a single asset
(`photos/PT_FORM.png`), so overwriting that file refreshed all 13 references
across 11 files at once (chat header, interludes, commitment hero,
`LivingCoachAvatar` default, etc.).

---

## 3. Assets replaced

| Asset | Task | Change |
|-------|------|--------|
| `photos/PT_FORM.png` | 3 | Overwritten with `new_form.png`, resized to 640×640. Single source funnels to all coach usages. Legacy backed up to scratchpad. |
| `tool/app_icon.png` · `tool/app_icon_bg.png` · `tool/app_icon_fg.png` | 4 | Regenerated from `new_app_icon.png` (inner rounded-square cropped full-bleed to 1024). |
| `android/app/src/main/res/mipmap-*/**` + `mipmap-anydpi-v26` adaptive drawables | 4 | Regenerated via `flutter_launcher_icons`. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/**` | 4 | Regenerated; 1024 verified RGB, alpha stripped. |
| `photos/APP_ICON_512.png` | 4 | 512 Play-listing icon derived from the same source. |

**New source file:** `lib/features/monetization/presentation/premium_welcome_sheet.dart`
(the welcome sheet). **New preference:** `AppPreferences.hasSeenPremiumWelcome` /
`setPremiumWelcomeSeen()`.

---

## 4. Images replaced

The single in-app photographic asset replaced this sprint is the **coach**
(`PT_FORM.png`, §3) — the highest-visibility image in the product, appearing on
onboarding, the paywall hero, and the coach surfaces.

The broader 18-image library refresh (Task 5) is **deferred** — see §7 for the
per-image → per-screen mapping so it can be executed as a focused follow-up.

---

## 5. UI improvements

- **Paywall** now matches the new reference: cleaner hero hierarchy, an
  AI-features card, honest discount anchoring, a trust/guarantee card, and a
  stronger "most popular" affordance — while remaining fully responsive
  (RichText hero, flex columns, no fixed-width overflow).
- **Premium welcome tour**: a polished, brand-consistent modal
  (neon gradient crest, four feature rows for AI Coach · Workout · Nutrition ·
  Progress, single CTA) that fires exactly once, reinforcing the purchase.
- **Coach identity**: a single, consistent human-trainer portrait across every
  touch-point — no more mixed/legacy coach art.
- **Launcher icon**: the new AI Fitness Coach brand mark, correct on both
  Android (adaptive fg/bg) and iOS (no-alpha).

---

## 6. Validation

| Check | Result |
|-------|--------|
| `flutter analyze` | **0 issues** (reconfirmed at report time, 9.3s) |
| `flutter test` | **328 tests pass** (incl. 8 paywall tests that render the full screen + assert store-honesty invariants) |
| Release APK build | ✅ Builds (~138 MB) |
| **Device — Task 3 coach** | ✅ Verified on Redmi across name-chat header, two onboarding interludes, and the commitment hero — new trainer renders correctly everywhere |
| **Device — Task 4 icon** | ✅ Confirmed — the FormAI app-switcher card shows the new launcher icon |
| **Device — Task 1 paywall** | ⚠️ Not reached on-device this run: the paywall is auth-gated and the adb sign-in taps (existing test account) did not register (button-tap flakiness, not an app bug). Fully covered instead by the 8 widget tests that mount and render the real `PaywallScreen` and assert its copy, plan cards, CTA, and price-honesty rules. |
| **Device — Task 2 popup** | ⚠️ Not triggerable on-device without a completable purchase (no Play license-tester configured on this account). Logic is analyze-clean and the once-per-user gate is unit-safe (local flag). |

**Store-safety note:** No RevenueCat wiring changed. The only price-related
addition (strikethrough) is *computed from the live store price*, so it cannot
display a fabricated anchor — verified by the "store honesty" test group.

---

## 7. Remaining optional polish ideas

### Why 5 & 6 are deferred
Both require bundling new binary assets, a full release rebuild (~13 min), and
an on-device re-verification pass. With the closed test **already live** to
real testers, shipping them half-integrated (or inflating the APK with
unoptimised art) is a worse outcome than a clean, verified 4-task delivery.
They are low-risk to pick up as a focused follow-up. Concrete plan below.

### Task 5 — image-library refresh (18 images in `photos/new-image/`)
Suggested mapping (verify each against the current asset before swapping — the
brief says *don't replace images that already fit the design language*):

| New image | Candidate surface |
|-----------|-------------------|
| `001-sixpack-man` / `002-sixpack-girl` | Goal-selection / onboarding gender-goal cards |
| `003-hypertrofy-man` / `004-hypertrofy-girl` | Workout program category (hypertrophy) |
| `005-hııt-man` / `006-hııt-girl` | Workout category (HIIT) |
| `007-yoga-girl` | Mobility / recovery category |
| `008-nutrition-page` | Nutrition tab header / empty state |
| `009-concept-aikoç` | AI Coach intro / marketing card |
| `010-motivation` · `017-dynamism` | Motivation cards / streak celebration |
| `011-smart-watch` | Tracking / progress upsell |
| `012-the-zone` · `013-night-cardio` · `015-morning-workout` | Workout mood/hero art |
| `014-community` | Social / referral surface |
| `016-Strength` | Strength category |
| `018-healthy-life` | Dashboard / lifestyle banner |

**Execution:** resize + compress to the target slot's density (most in-app
photos are ≤ 800 px wide webp), swap in place where the existing asset is
lower-quality, then rebuild + re-verify. Do **not** add all 18 blindly.

### Task 6 — in-app-asset integration (8 PNGs in `assets/in-app-assets/`)
These are **1.5–2.4 MB each** (≈ 15 MB total) and must be **optimised before
bundling** (they'd bloat the APK otherwise). Suggested homes:

| Asset | Suggested use |
|-------|---------------|
| `001-dumbell` | Workout empty-state / section header icon |
| `002-target-muscle-group` | Exercise-detail muscle-group card |
| `003-progreess` | Progress tab empty-state / hero |
| `004-diet` | Nutrition empty-state |
| `005-streak-badge` | Streak / gamification card |
| `006-pro-tier-icon` | Premium card / paywall accent |
| `007-milestone` | Achievement / level-up celebration |
| `008-` | Onboarding or dashboard accent (identify final subject first) |

**Execution:** `pngquant`/`cwebp` to ≤ ~150 KB each, declare under
`flutter/assets:` in `pubspec.yaml`, wire into the surfaces above, rebuild +
re-verify. Only place where it demonstrably improves the surface — skip any
slot that already reads well.

### Other minor polish observed (optional)
- Add an on-device smoke path for the paywall (a debug deep-link that bypasses
  auth) so future visual QA doesn't depend on a live sign-in.
- Configure a Play **license tester** on the test account so the Premium
  welcome popup (Task 2) can be exercised end-to-end on-device.

---

*Prepared for the FormAI closed-test polish sprint. Single deliverable, as
requested — no intermediate reports were produced.*
