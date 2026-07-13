# FormAI — Final Pre-Store Audit Report

**Audit date:** 2026-07-06
**Branch:** `prisk/phase-1-tests` · **Version:** `0.1.0+12`
**Scope:** Complete end-to-end review for App Store / Google Play submission readiness.
**Method:** Grounded in the actual codebase (177 Dart files, ~59.3K LOC lib/, Supabase migrations, native Android/iOS config). Every finding cites `file:line`. Nothing is assumed; unverifiable items are marked **UNVERIFIED**. Reviewer roles applied: Senior Flutter Architect, Mobile UX, Product, QA, Google Play reviewer, Apple reviewer, Fitness consultant.

> **This is a brutally honest engineering review. The tone is deliberately critical because the mission is to find every reason this app could be rejected or churn users before it reaches millions. The app also has genuine, real strengths — they are credited explicitly.**

---

# Executive Summary

## Overall readiness

| Dimension | Score |
|---|---|
| **Engineering quality / foundation** | **6.5 / 10** — well above indie-average |
| **Store-submission readiness (public)** | **3 / 10** — multiple hard rejection triggers |
| **iOS track readiness** | **1.5 / 10** — never built/validated end-to-end |
| **Android closed-beta readiness** | **6.5 / 10** — functional, testable |

FormAI is a **well-architected app with a broken storefront and a hollow middle**. The bootstrap resilience, security/RLS model, camera performance discipline, and voice-coach engine are genuinely strong. But the app currently ships **fabricated social proof, a deceptive paywall, a safety-false allergen claim, an unverified account-deletion path, and a non-functional Apple Sign-In on iOS** — any one of which is a store rejection. Underneath the polish, several headline features are *theater*: 5 of 7 nutrition preferences are collected and never used, the retention streak structurally caps at 3, and the progress charts render decorative fake data.

**It is not ready for public submission. It is ready for an Android closed beta once the two integrity/safety items (fake testimonials, false allergen claim) are removed.**

## Critical blockers (must fix before ANY public submission)

1. **Fabricated testimonials, ratings and user counts** in a zero-user app — `social_proof_step.dart:75-130` (Apple 2.3.1 / Google Misrepresentation).
2. **In-app account deletion is likely broken** — client calls `rpc('delete_user')` (`auth_provider.dart:378`) but the RPC exists in **no** migration and every project doc lists it as un-applied (`docs/ROADMAP.md:96,238`) (Apple 5.1.1(v) / Google Data-Deletion / KVKK Art.7 / GDPR Art.17).
3. **Apple Sign-In is non-functional on iOS** — no `com.apple.developer.applesignin` entitlement exists (`ios/Runner/Runner.entitlements` has only App Groups) while the button is advertised (Apple 4.8).
4. **Deceptive paywall pricing & trial claims** — a fictional strikethrough "was ₺2.999,99" the code itself labels a "fictional anchor" (`paywall_screen.dart:1318-1323`), and an unconditional "no payment now / 7 days free" shown for plans that may have no trial (`paywall_screen.dart:589,1571,1649`).
5. **False allergen-safety promise** — the app tells users "I completely remove ingredients that could harm you" but the collected `allergies` value has **zero consumers**; nut-allergic users are still recommended nut recipes (`nutrition_onboarding_sheet.dart:1040`).
6. **iOS has never been validated end-to-end** — no `Podfile`, no `GoogleService-Info.plist`, missing Apple entitlement, absent `GOOGLE_IOS_CLIENT_ID`. The App Store binary does not yet exist.

## Major strengths (real, verified)

- **Bulletproof bootstrap.** `main.dart` installs `FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`, `_envSafe` wrappers, 8s Supabase / 5s PostHog timeouts, and a branded retry screen — the Phase-94 black-screen hardening is textbook (`main.dart:49-157`).
- **Strong security posture.** Bundled `.env` carries only client-public keys (anon JWT decoded = `role:anon`, verified); real secrets are gitignored with 0 commits; RLS is owner-scoped on every user table; the RevenueCat webhook is secret-authed + idempotent (`revenuecat-webhook/index.ts:93-100`).
- **Excellent voice-coach architecture** — single-playing-utterance + 3-deep priority queue with pre-emption and per-phrase dedupe (`audio_feedback.dart:200-292`); rare in this category.
- **Camera performance discipline** — 15 FPS throttle, single-flight inference gate, inference skipped during rest/prep (`workout_camera_screen.dart:67,325-357`).
- **Correct image pipeline & lifecycle hygiene** — zero raw `Image.network` in real code, memory-downsampled `CachedImage`, all 44 AnimationControllers disposed (UI audit).
- **Compliance scaffolding done right** — 18+ age gate → KVKK/GDPR opt-in consent (default OFF) → onboarding, all *before* any analytics event fires (`app_router.dart:105-121`, `main.dart:120-135`); ATT on iOS; on-device ML disclosure before the camera prompt; `PrivacyInfo.xcprivacy` present.
- **Real macro engine** (Mifflin-St-Jeor + Atwater, 1200-kcal floor, `nutrition_calculator_service.dart:60-177`) and a **real Supabase recipe catalogue** — not placeholders.
- **RevenueCat integration is real** — localized store pricing, working **Restore Purchases**, Terms + Privacy links on the paywall (`paywall_screen.dart:635-686,1723-1733`).

## Major weaknesses (thematic)

- **"Theater" features** — data collected and never used: nutrition allergies, diet preference, nutrition goal, water intake, taste preference (5 of 7 onboarding answers); XP/level ladder computed and persisted but never surfaced; progress charts fabricated.
- **Broken retention flywheel** — the streak caps at 3 and isn't time-based; the level system is invisible; charts don't encode real progress. The day-2/day-7 hooks don't work.
- **The differentiator underdelivers** — form checks assume a side camera but the app opens the front camera only, so the headline "chest up / hip sag" corrections never fire; one form check is dead code, another nags on *good* reps; 87 exercises share approximate detectors; and the whole CV flow is hard-blocked offline.
- **Turkish-only reality vs English claim** — 6 of ~1,300 strings are externalized; declaring `en` support ships a broken hybrid UI.
- **Accessibility is a near-miss failure** — 0 `semanticLabel`s, ~4 `Semantics` wrappers across 206 tap targets, 0 reduced-motion checks in an animation-maximalist app, dynamic type clamped at 1.3×.
- **Low automated confidence** — ~20.8% coverage; the entire presentation layer (paywall, onboarding, workout camera, dashboard) has no widget tests; the highest-risk paths (OAuth, account deletion) are untested.

---

# Section Scores

| Area | Score | One-line justification |
|---|---:|---|
| **Architecture** | 7.5 | Clean feature-first + Riverpod + go_router; resilient boot; only dragged by 2,000-line widgets and out-of-band schema drift. |
| **UI (visual)** | 7.0 | Cohesive neon brand, real dark/light themes, branded fallbacks & skeletons; 499 ad-hoc font sizes, no spacing/type scale. |
| **UX (flow)** | 6.0 | Strong states & cinematic onboarding, but 21-screen → paywall wall, offline block, broken retention hooks. |
| **Performance** | 8.0 | Cached/downsampled images, clean disposes, RepaintBoundaries, lazy lists; only ~24% const-Text and huge files. |
| **Security** | 8.0 | Anon-only bundle, owner-scoped RLS, private video bucket, 2 CI secret gates; docked for schema/RPC drift. |
| **Backend** | 7.5 | RLS correct & complete, webhook gated/idempotent; docked because delete/referral RPCs + some tables live only in the dashboard. |
| **Privacy / Compliance** | 6.5 | Excellent opt-in consent + ATT + on-device processing; broken DSR email, deletion depends on unshipped RPC, promised export absent. |
| **Accessibility** | 3.0 | 0 semanticLabels, minimal Semantics, 0 reduced-motion, clamped dynamic type. Contrast tokens are the lone bright spot. |
| **Localization** | 2.0 | Delegate scaffold only; 6/~1,300 strings translated; claims English, ships Turkish. |
| **Onboarding** | 6.0 | Emotionally crafted, resumable, data used — but fabricated social proof + hard paywall ending. |
| **First Impression** | 5.0 | White-flash native splash, cyan-vs-purple brand split, launcher icon stretched as the hero. |
| **Product Vision** | 6.0 | Communicates "AI-calibrated plan" clearly but hides the real differentiator (live form coaching). |
| **Workout (UX)** | 6.0 | Polished session/rest/prep + Live Activity, undercut by offline block, front-only camera, phone-call timer drain. |
| **Pose / Form engine** | 5.0 | Reasonable for front-facing squats/curls/press; dead-code check, false-positive nag, inconsistent gating, 87 shared detectors. |
| **Voice coach** | 8.0 | Priority queue + pre-emption + dedupe + calibration; the strongest subsystem. |
| **Nutrition** | 5.0 | Real macro engine + catalogue + reactive UI over a hollow core: 5/7 prefs unused, round-robin "AI" plan, false allergen claim. |
| **Dashboard** | 5.0 | Good hierarchy & density, but streak/weekly-goal/kcal charts are broken, fake, or mislabeled. |
| **Progress** | 5.0 | Solid calendar + persisted XP, dragged by fake charts, capped streak, un-surfaced level system. |
| **Navigation / IA** | 7.5 | Clean 4-tab nav + state preservation + coherent routing + premium gating; minor dead-end taps. |
| **Premium / Paywall** | 6.0 | Compliance skeleton above-average, but decoy pricing + unconditional trial + undeliverable referral. |
| **Authentication** | 5.0 | Strong client engineering (anon recovery, RC aliasing, error taxonomy) blocked by 2 P0s + iOS misconfig + no password reset. |
| **Store readiness** | 3.0 | Five independent public-submission rejection triggers live today. |
| **Production readiness** | 4.0 | 20.8% coverage, iOS unvalidated, broken retention, theater features. |

---

# Critical Blockers (P0)

> Every item here is either a **store rejection**, a **legal/safety violation**, or a **broken core guarantee**. None may ship to a public track unresolved.

### P0-1 · Fabricated social proof (highest rejection probability)
`social_proof_step.dart:75-130,191,204,217-219,708` · `nutrition_onboarding_sheet.dart:628`
Nine named reviewers ("Ayşe K., 32"), star ratings, "3 gün önce" recency stamps, "4.8 KULLANICI MEMNUNİYETİ", "binlerce kişi", "🔥 10.000+ kişi bu sistemi kullanıyor" — for an app with **zero users**. The code comment itself admits "FormAI is pre-launch with no user base." Weight-loss quotes ("12 haftada 6 kilo") compound this as unsubstantiated health claims.
**→ Apple 2.3.1 (accurate metadata) · Google Play "Misrepresentation / Deceptive Behavior."**
**Fix:** remove all fabricated reviewers, ratings, and counts, or replace with honest pre-launch framing ("Yeni çıktı — ilk sen dene").

### P0-2 · Account deletion is not proven to work
`auth_provider.dart:378` (`rpc('delete_user')`) · `docs/ROADMAP.md:96,238` · `docs/MASTER_LAUNCH_ROADMAP.md:163`
The client-side deletion UX is fully built and reachable (type-`DELETE` confirm, `signOut`, `prefs.clear`), **but the `delete_user` Postgres function is defined in no migration or edge function**, and every project doc lists it as an un-applied external task. If it is not applied to prod, "Hesabımı Sil" throws → the user cannot delete their account.
**→ Apple 5.1.1(v) · Google Data-Deletion policy · KVKK Art.7 / GDPR Art.17.**
**Fix:** apply the `delete_user` RPC to prod as a checked-in migration (the SQL exists at `docs/ROADMAP.md:101-116`), then verify end-to-end on a real account. *If already applied out-of-band, downgrade to a version-control/reproducibility fix.*

### P0-3 · Apple Sign-In non-functional on iOS
`ios/Runner/Runner.entitlements` (App Groups only) · `auth_screen.dart:351`
The "Apple ile Devam Et" button is shown, and Google (third-party social) is offered — so Apple **requires** a functional Sign-in-with-Apple option. The `com.apple.developer.applesignin` entitlement is absent from all of `ios/`, so the native flow fails at runtime on device/TestFlight.
**→ Apple 4.8.**
**Fix:** add the Sign in with Apple capability/entitlement in Xcode, configure the Service ID + key, and gate the button to iOS (`Platform.isIOS`) so Android testers don't hit a dead feature.

### P0-4 · Deceptive paywall pricing & trial claims
`paywall_screen.dart:1318-1323,1451-1464` (decoy anchor) · `:589,1571,1649-1650,1718-1721` (trial copy)
(a) The yearly card shows a lined-through "₺2.999,99 idi" the code comment calls a "fictional anchor … not a discounted price the store reports." (b) "Şimdi ödeme yok! / 7 gün ücretsiz" is static and **plan-independent** — `introductoryPrice`/`PeriodType` is never read — so users on a plan without a configured trial are told "no payment now" but charged immediately.
**→ Apple 3.1.1 / 3.1.2 / 2.3.1 · Google "Deceptive Behavior" · EU/Turkish reference-price consumer law.**
**Fix:** remove the fictional strikethrough; drive all trial copy from the actual RC package `introductoryPrice`; add the explicit "renews at ₺X/period until cancelled, charged to your store account" line.

### P0-5 · False allergen-safety claim (safety + rejection)
`nutrition_onboarding_sheet.dart:1040` (screen) · `:234` (stored) — zero downstream consumers
The allergy screen states "Sana zarar verebilecek içerikleri tamamen çıkarıyorum" ("I completely remove ingredients that could harm you"). Nothing reads `allergies`; recipes carry no allergen column; a nut-allergic user is still served and recommended nut recipes.
**→ Apple 1.4.1 (physical harm) · Google Play Health · consumer-safety liability.**
**Fix (minimum):** delete the safety claim and the allergy step until real allergen filtering (allergen schema + query filter) exists. Do not ship a safety promise the code cannot keep.

### P0-6 · iOS build has never been validated (App Store track only)
No `ios/Podfile`; no `GoogleService-Info.plist`; missing Apple entitlement (P0-3); `GOOGLE_IOS_CLIENT_ID` absent from `.env`/`.env.example`; `auth_provider.dart:207` reads it.
There is no evidence the iOS target has ever been pod-installed, built, or run. The App Store binary does not exist yet, and iOS Google Sign-In is misconfigured (P1-8).
**Fix:** on macOS, `flutter build ios`, resolve pods, add the iOS OAuth client + reversed-client URL scheme + `GoogleService-Info.plist`, and run a full device smoke of every flow before any TestFlight/App Store submission.

---

# High Priority Improvements (P1)

**Retention & core-loop correctness**
- **P1-1 · Streak structurally caps at 3 and is not time-based.** Rest day every 4th day can never be completed, so the leading-run counter always breaks at day 4 (`workout_generator_service.dart:102-109`, `workout_provider.dart:633`, `gelisim_tab.dart:186-196`). It also counts program-day slots, not calendar days — no daily-habit loss-aversion. The 7-day streak badge, "Champion" copy, and every streak-XP milestone ≥7 are dead. Shown on 3 surfaces. **The single most damaging quality bug.**
- **P1-2 · Progress charts render fabricated data.** Completion bars are binary `completed?1.0:0.25`; the kcal line is `completed?1.0:0.2`; the "ANTRENMAN" waveform alternates even/odd baselines purely for shape; kcal value is `completedDays × 250` flat (`gelisim_tab.dart:1049-1057`, `app_constants.dart:24`). "Track your progress" rewards nothing real.
- **P1-3 · XP / level / title identity system is invisible.** `levelProgressProvider`/`currentTitleProvider` have zero UI consumers; the 9-tier ladder is computed, persisted, and never shown outside a transient level-up cinematic (dashboard audit). Profile shows no level/title/XP.
- **P1-4 · "Weekly goal" is a lifetime count** (`antrenman_tab.dart:159`) and **"Kalori Avcısı" badge has 3 inconsistent unlock definitions** (`badge_unlocks_provider.dart:169` vs `gelisim_tab.dart:87,1766`) — the same badge can read unlocked in one place and locked in another.

**Workout / camera**
- **P1-5 · On-device workout is hard-blocked offline** for a demo-video stream, though the CV pipeline needs no network (`plan_detail_screen.dart:327,1620`). Kills the differentiator in gyms/planes.
- **P1-6 · App-lifecycle interruption drains the timer & tears down the camera on `inactive`** (Control Center, calls, shade) without pausing — the coach keeps speaking to a dead camera and a plank timer drains; can briefly paint a disposed controller (`workout_camera_screen.dart:588-597,985`).

**Notifications**
- **P1-7 · Exact-alarm regression will break reminders on Android 12+.** The uncommitted manifest removed `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM`, but the scheduler still calls `zonedSchedule(... AndroidScheduleMode.exactAllowWhileIdle)` with no try/catch (`notification_service.dart:252,329`). The code comment wrongly believes `exactAllowWhileIdle` "gracefully degrades" — it throws `exact_alarms_not_permitted`. Result: all reminders silently fail on the majority of devices.
**Fix:** decide one path — either re-declare `USE_EXACT_ALARM` (accepting Google's exact-alarm policy scrutiny) **or** switch both call sites to `inexactAllowWhileIdle`. The manifest and code must agree.

**Authentication**
- **P1-8 · iOS Google Sign-In misconfigured** — missing `GOOGLE_IOS_CLIENT_ID`, `GoogleService-Info.plist`, and reversed-client URL scheme (`auth_provider.dart:207`, `Info.plist:67`). Android is OK.
- **P1-9 · No forgot/reset-password flow** — `resetPasswordForEmail` is never called; an email/password user who forgets is locked out (`auth_screen.dart`).
- **P1-10 · Apple button not platform-gated / no `webAuthenticationOptions`** — throws on Android into a generic error toast (`auth_provider.dart:305-311`).

**Nutrition integrity**
- **P1-11 · Diet preference collected, never applied** — a vegan still gets meat mains (`nutrition_onboarding_sheet.dart:978`, `daily_menu_provider.dart:158-174`).
- **P1-12 · Meal plan is not personalized** — deterministic round-robin `candidates[offset % len]`, never reads calories/goal/diet (`daily_menu_provider.dart:111-135`); the onboarding "planın optimize ediliyor" AI illusion oversells it.
- **P1-13 · No medical disclaimer in the nutrition flow** — prescriptive kcal directives ("$overage kcal fazla aldın", `nutrition_tab.dart:725`) with no "not medical advice" line. (A disclaimer exists on the consent screen but not in-context.)
- **P1-14 · Referral reward undeliverable** — `redeem_referral` RPC exists in no migration (`referral_service.dart:78`), yet the landing shows "1 ay Pro hesabınıza tanımlandı" (`referral_landing_screen.dart:88-89`). Either every redemption fails or the success banner is false.

**Compliance / legal**
- **P1-15 · Privacy-policy contact email is broken and self-contradictory** — `href="formaisupport@proton.me"` (no `mailto:`) with visible text `support@formai.app` at `privacy.html:294,307,316`. This is the only data-subject-request channel (export, post-uninstall deletion, child-data). GDPR Art.12 / KVKK.
- **P1-16 · Promised data export is not implemented** — `privacy.html:289` claims machine-readable export; only deletion exists in-app.

**Localization / accessibility**
- **P1-17 · i18n is scaffold-only** — 6 strings externalized, ~1,323 hardcoded Turkish literals, 29 `AppLocalizations` usages; `supportedLocales` claims `en`+`tr` with no forced locale → an English device shows a broken 6-EN/1,300-TR hybrid. Either ship TR-only honestly or extract strings.
- **P1-18 · No reduced-motion support** — 0 `MediaQuery.disableAnimations` checks in an app running ~10 always-on animators.
- **P1-19 · Screen-reader support minimal** — 0 `semanticLabel`s, ~4 `Semantics` across 206 tap targets; bespoke `InkWell`+`Ink` CTAs carry no button role.
- **P1-20 · Dynamic type overflows above 1.3×** — scaling clamped at 1.3× in 2 spots, 499 raw `fontSize:` untested at OS large-text.

**Hygiene**
- **P1-21 · Version is `0.1.0+12`** — set a real `1.0.0` marketing version before submission.

---

# Nice To Have (P2)

**Form-engine correctness (trust)**
- Form checks assume a **side camera** but the app opens the **front camera only** — squat forward-lean (`back_legs_analyzers.dart:68-70`) and push-up hip-sag (`chest_analyzers.dart:81`) are sagittal-plane faults that never fire in a selfie view (`workout_camera_screen.dart:192-195`). This is the core "feels fake" risk.
- **ShoulderPress partial-rep warning is unreachable dead code** (`shoulders_arms_cardio_analyzers.dart:177`).
- **HipHinge partial-ROM warning false-positives on good reps** — `_peakAngle` read at commit (~165°) before lockout, so it nags users who *are* reaching full extension (`back_legs_analyzers.dart:204-208`).
- 87 Phase-96 exercises reuse approximate analyzers (deadlift/box-jump → `SquatAnalyzer`) → systematic undercount (`analyzer_factory.dart:96-97`).
- Inconsistent likelihood gating — crunch/leg-raise/plank lack the 0.4 reject floor newer analyzers enforce (`core_analyzers.dart:736-746`); `z`-axis depth signals are ML-Kit-experimental (UNVERIFIED); per-frame detection failures swallowed silently (`workout_camera_screen.dart:527`).
- No visual "get your whole body in frame" guidance (voice-only); ML Kit disclosure re-shown every entry.

**First impression / brand**
- App icon reused as a stretched full-bleed onboarding hero (`act_1_hook_step.dart:138-139`).
- Unbranded native splash → white flash on light-mode devices (no `flutter_native_splash`); boot wordmark is **cyan** `0xFF00F0FF` (`main.dart:187`) while the brand primary is **purple** `0xFF8E5BFF` (`app_colors.dart:23`).
- Unused `NSMicrophoneUsageDescription` (`Info.plist:50`, `enableAudio:false`) — remove to shrink the privacy surface (Apple 5.1.1(b)).
- Notifications never primed during onboarding (buried retention lever).

**Nutrition theater**
- `nutritionGoal`, `waterIntake`, `tastePreference` stored and never read; `nutritionStreak` always 0 (`nutrition_provider.dart:268-274`); guest users silently get a stranger's 70kg default plan (`:155-161`); ~700 lines of dead code (`next_best_meal_card.dart`, `ai_insight_banner.dart`).

**Design system / structure**
- No typography or spacing tokens; 499 hardcoded `fontSize:`; touch targets unenforced (~8 explicit sizings / 206 handlers); 2,000-line widget files; `_streakOf` copy-pasted across 6 files.

**Monetization / backend hygiene**
- `isDeveloperOverride` honored in release builds — a value from a prior side-loaded debug build unlocks Pro (`monetization_provider.dart:197`).
- Entitlement gating is client-trusted; the webhook-populated `pro_entitlements` table is never read by the client (acceptable, but the "server source of truth" gates nothing).
- Schema/RPC drift — `recipes`/`categories`/`feedback` tables + both RPCs live only in the dashboard; `categories` RLS **UNVERIFIED**.
- `lib/scripts/sync_recipes_db.dart:63` references `SUPABASE_SERVICE_ROLE_KEY` under `lib/` (smell; not shipped).
- Rating prompt is a soft-ask (custom stars → native `requestReview`) — acceptable but against Apple's spirit; two overlapping CI workflows (`ci.yml` + `flutter_ci.yml`).

---

# Store Rejection Risks

## Apple App Store

| # | Guideline | Trigger | Evidence |
|---|---|---|---|
| A1 | **2.3.1** Accurate metadata | Fabricated testimonials/ratings/"binlerce kişi" | `social_proof_step.dart:75-130` |
| A2 | **5.1.1(v)** Account deletion | `delete_user` RPC unverified/absent | `auth_provider.dart:378`, `docs/ROADMAP.md:96` |
| A3 | **4.8** Sign in with Apple | Entitlement missing → button dead on iOS | `ios/Runner/Runner.entitlements` |
| A4 | **3.1.1 / 3.1.2** IAP | Decoy anchor price + unconditional trial claim | `paywall_screen.dart:1318-1323,589` |
| A5 | **1.4.1** Physical harm | False allergen-removal claim; undisclaimed kcal targets | `nutrition_onboarding_sheet.dart:1040` |
| A6 | **2.1** App completeness | iOS Google/Apple sign-in dead; broken referral; offline workout block | `auth_provider.dart:207`, `referral_service.dart:78` |
| A7 | **5.1.1(b)** Minimal data | Declared-but-unused microphone permission | `Info.plist:50` |
| A8 | **4.2** Minimum functionality | Theater features (unused prefs) if a reviewer probes | `nutrition_provider.dart:160` |
| — | 5.1.2 ATT / privacy manifest | **OK** — ATT implemented, `PrivacyInfo.xcprivacy` present | `analytics_service.dart:313` |

## Google Play

| # | Policy | Trigger | Evidence |
|---|---|---|---|
| G1 | **Misrepresentation / Deceptive Behavior** | Fake social proof; decoy price; false trial; false "1 ay Pro" banner | `social_proof_step.dart:75`, `paywall_screen.dart:1318`, `referral_landing_screen.dart:88` |
| G2 | **Account Deletion** | In-app deletion must actually work | `auth_provider.dart:378` |
| G3 | **Subscriptions / Paid content** | Trial + auto-renew disclosure incomplete/inaccurate | `paywall_screen.dart:589,1718` |
| G4 | **Health content / Health claims** | False allergen safety; medical-claim wording; no in-context disclaimer | `nutrition_onboarding_sheet.dart:1040`, `ai_personalization_engine.dart:278` |
| G5 | **Data safety form** | Must declare body metrics/health + camera; deletion channel (email) is broken | `privacy.html:294` |
| G6 | **Exact alarm / SCHEDULE_EXACT_ALARM** | Reminders throw on Android 12+ after perm removal | `notification_service.dart:252` |
| — | Target API level 36 · 18+ age gate | **OK** | `build.gradle`, `age_gate_screen.dart` |

---

# UX Improvements

1. **Demo the magic before the paywall.** The 21-screen onboarding ends at a hard paywall before the user sees a single rep counted — move a 20-second live form-analysis demo (or a first free workout) ahead of the wall (`onboarding_screen.dart:342`).
2. **Make the streak real and time-based** so returning tomorrow visibly matters (P1-1).
3. **Surface the level/title/XP** on the dashboard hero + profile so the persisted identity system actually pulls users back (P1-3).
4. **Let workouts run offline** — split the demo-video gate from the CV entry (P1-5); show a "video unavailable offline, coaching still works" note instead of blocking.
5. **Pause the session on call/interruption** and show a resume sheet instead of draining the timer (P1-6).
6. **Add a visual body-framing overlay** ("get your legs in frame") so users understand why reps aren't counting (voice-only today).
7. **Add in-app password reset** and an anon→email confirmation state that doesn't optimistically route to the paywall (P1-9, auth audit P2).
8. **Prime notifications with a value-first pre-permission** step during onboarding, not only from the Profile tab.
9. **Guest-plan honesty** — label the default nutrition plan "örnek / tahmini" until the user completes setup (`nutrition_provider.dart:155-161`).
10. **Stop re-showing the ML disclosure** every workout; persist the acknowledgement.

# UI Improvements

1. **Fix the first frame** — add `flutter_native_splash` with a branded background to kill the white flash, and unify the boot wordmark to the purple brand (or commit to cyan everywhere) (`main.dart:187` vs `app_colors.dart:23`).
2. **Design a real onboarding hero** instead of the stretched launcher icon (`act_1_hook_step.dart:138`).
3. **Introduce a typography scale + spacing tokens**; replace the 499 inline `fontSize:` and ad-hoc `SizedBox` gaps.
4. **Give charts a true empty/zero state** and feed them real data, or remove the fabricated waveforms (P1-2).
5. **Unify badge thresholds** across the gallery and the Gelişim strip (P1-4).
6. **Reduce the neon-accent count** — the palette carries purple/blue/cyan/neon-green/pink; pick a disciplined 2-3 accent system for premium calm.
7. **Add a Profile identity block** (avatar, level, title, member-since) — currently only streak + completed count.
8. **Skeletons everywhere** — the antrenman tab uses a bare spinner while gelisim uses skeletons (`antrenman_tab.dart:111`).

# Product Improvements ("this feels premium")

1. **Deliver on the AI promise** — make the meal plan actually consume calories/goal/diet, or rename it "kural tabanlı" and stop the "optimize ediliyor" theater (P1-12).
2. **Make form feedback trustworthy** — support/guide the side camera for sagittal exercises, add real analyzers for the 87 shared ones, and fix the two broken form checks. Trust is the whole product.
3. **Real progress analytics** — measured calories (per-exercise MET), volume trend, PBs — the charts are the reward for returning.
4. **Post-workout intelligence** — "your squat depth improved 8% this week" is the kind of insight that justifies a subscription.
5. **Honest, earned social proof** post-launch (real ratings via the existing `in_app_review` flow) to replace the fabricated set.
6. **Apple Watch / HealthKit / Google Fit** integration is table-stakes for the competitive set (Fitbod, Freeletics, Whoop).

# Missing Features (expected in a modern AI fitness app)

- Real personalization engine wired to collected data (currently theater).
- Wearable / HealthKit / Google Fit sync.
- Progress **photos** and body-measurement tracking over time.
- Apple Sign-In that works on iOS; password reset; email verification UX.
- Real allergen & dietary filtering (blocks the current false claim).
- Data **export** (promised in policy, absent in app).
- Offline workout mode (the CV engine already supports it — just unblock it).
- Post-workout analytics / trends; social or coach-share loop beyond referral.

# Launch Checklist

**Blocking (public submission)**
- [ ] Remove all fabricated testimonials/ratings/user counts (P0-1).
- [ ] Apply + verify `delete_user` RPC in prod as a checked-in migration (P0-2).
- [ ] Add Sign-in-with-Apple entitlement; gate button to iOS (P0-3).
- [ ] Remove decoy price; drive trial copy from real SKU; add renewal disclosure (P0-4).
- [ ] Remove the allergen-safety claim (or implement real filtering) (P0-5).
- [ ] Build + device-validate the entire iOS target (P0-6).
- [ ] Resolve the exact-alarm manifest/code contradiction (P1-7).
- [ ] Fix the privacy-policy DSR email (`mailto:` + matching address) (P1-15).
- [ ] Set version to `1.0.0` (P1-21).
- [ ] Decide: ship TR-only (drop `en`) or complete string extraction (P1-17).

**Strongly recommended (quality/retention)**
- [ ] Real time-based streak + surfaced level system (P1-1, P1-3).
- [ ] Real chart data or honest empty states (P1-2).
- [ ] Offline workout + interruption-safe session (P1-5, P1-6).
- [ ] Wire or remove the unused nutrition prefs; add in-context medical disclaimer (P1-11..13).
- [ ] Apply/verify `redeem_referral` or hide the referral reward (P1-14).
- [ ] Password reset + iOS Google config (P1-8, P1-9).

**External / operational (cannot be verified from code — UNVERIFIED here)**
- [ ] RevenueCat products + entitlements configured with matching prices/trials in both consoles.
- [ ] Play Console Data Safety + App Store Privacy "nutrition labels" filled to match actual collection (body metrics, camera).
- [ ] Signing keys (Android upload keystore, iOS distribution cert/profile) in place.
- [ ] Sentry/PostHog/RevenueCat **prod** DSNs/keys; live Privacy + Terms URLs.
- [ ] Rotate the Supabase DB password if any pre-Phase-0 APK containing the old `.env` was ever distributed.

---

# Final Verdict

## ⚠️ CLOSED BETA READY (Android) — NOT READY for public store submission

**Reasoning.** The Android app builds, signs, and runs; the foundation (boot resilience, security/RLS, performance, voice coach) is genuinely strong; and the core flows are functional enough to gather real user feedback. That is exactly what a **closed beta** is for — and FormAI clears that bar on Android, **provided the two integrity/safety items are removed first**: the fabricated testimonials (you'd be lying to your own testers) and the false allergen-safety claim (a real safety risk).

It is **not** ready for **open beta or production** on either store. Five independent public-submission rejection triggers are live today (fabricated social proof, deceptive pricing, dead Apple Sign-In, unverified account deletion, false allergen claim), the **iOS binary has never been built or validated**, the **retention flywheel is broken** (capped streak, fake charts, invisible levels), and the **headline differentiator underdelivers** (front-camera-only form checks, dead-code/false-positive analyzers, offline block).

Encouragingly, **none of the P0s are deep** — they are removals, a one-file entitlement, an RPC apply, and honest copy. A focused **~1–2 week Phase 0 + Phase 1** (below) clears every public-submission blocker on Android; iOS needs an additional Mac-based validation pass. The quality/retention work (Phase 2) is what separates "passes review" from "keeps users."

> **Bottom line:** great bones, dishonest storefront, hollow middle. Fix the honesty and safety items now; fix the retention and form-engine truth before you spend a dollar on acquisition.

---
*Companion roadmap: `FINAL_PRE_LAUNCH_EXECUTION_PLAN.md`.*
