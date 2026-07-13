# FormAI — Final Pre-Launch Execution Plan

**Companion to:** `FINAL_PRE_STORE_AUDIT_REPORT.md` (2026-07-06)
**Purpose:** Sequence every audit finding into executable phases with clear exit criteria, so the team can move from *closed-beta (Android)* to *production (both stores)* without guesswork.
**Discipline:** This is a plan, not an implementation. Each phase lists objective → affected files → implementation order → risks → validation checklist → expected impact. Effort estimates assume one experienced Flutter engineer; **UNVERIFIED** marks work that depends on macOS/console access not testable from this repo.

**Phase dependency map**
```
Phase 0  Critical blockers (integrity/safety/store)      ← gate for ANY public track
   ↓
Phase 1  Store compliance + iOS validation               ← gate for App Store binary
   ↓
Phase 2  Core-loop truth & retention                     ← gate for spending on growth
   ↓
Phase 3  Form-engine trust (the differentiator)
   ↓
Phase 4  UX improvements
   ↓
Phase 5  UI polish · accessibility · localization · perf
   ↓
Phase 6  Final QA & launch preparation
```
Phases 0–1 are strictly sequential and blocking. Phases 2–5 can partially overlap once 0–1 land. Keep the branch continuously green (`flutter analyze` = 0, tests pass) and commit + push per increment.

---

## Phase 0 — Critical Blockers (integrity, safety, store rejection)
**Objective:** Remove every item that is a store rejection, a legal/safety violation, or a lie to users. After this phase the Android build is honest and safe enough for a closed beta.
**Estimated effort:** 2–4 days (Android-testable); the Apple entitlement piece is prepared here, validated in Phase 1.

**Affected screens / files**
- `lib/features/onboarding/presentation/steps/social_proof_step.dart` (fabricated reviewers/ratings/counts)
- `lib/features/nutrition/presentation/widgets/nutrition_onboarding_sheet.dart:628,1040,234` (10.000+ claim; allergen safety claim)
- `lib/features/monetization/presentation/paywall_screen.dart:589,1318-1323,1451-1464,1571,1649-1721` (decoy price + trial copy)
- `lib/features/auth/providers/auth_provider.dart:378` + new `supabase/migrations/006_delete_user.sql`
- `ios/Runner/Runner.entitlements` + Xcode Signing & Capabilities (Apple Sign-In)

**Implementation order**
1. **Strip fabricated social proof (P0-1).** Delete the nine testimonials, star ratings, recency stamps, "4.8 memnuniyet", "binlerce kişi", and "10.000+ kişi". Replace with honest pre-launch framing or a value-restatement. No new user-count claim without data.
2. **Remove the false allergen-safety claim (P0-5).** Delete the "zarar verebilecek içerikleri tamamen çıkarıyorum" copy and the allergy capture step (it feeds nothing). Real allergen filtering is deferred to Phase 2/backlog (needs an allergen schema).
3. **De-deceptify the paywall (P0-4).** Remove the fictional strikethrough anchor. Bind all "free trial / no payment now" copy to the selected package's real `introductoryPrice`; hide it for plans without a trial. Add the explicit "₺X/period until cancelled, charged to your store account" line.
4. **Ship `delete_user` as a checked-in migration (P0-2).** Move the SQL at `docs/ROADMAP.md:101-116` into `supabase/migrations/006_delete_user.sql`, apply to prod, and confirm the round-trip from `account_settings_screen.dart` deletes the auth row + cascades user data.
5. **Add Sign-in-with-Apple entitlement (P0-3, prepared).** Add `com.apple.developer.applesignin` in Xcode + Service ID/key; gate the button with `Platform.isIOS`. Runtime validation happens in Phase 1 on macOS.

**Risks**
- Removing social proof may dent onboarding conversion — accept it; fabricated proof is non-negotiable.
- The `delete_user` SQL must `SECURITY DEFINER` correctly and revoke `public` — a wrong grant is itself a vulnerability; review before apply.
- Trial-copy binding depends on RC offerings being configured (Phase 6 external) — until then, show the *safe* "no free trial" copy rather than a false promise.

**Validation checklist**
- [ ] `grep` for testimonial names / "binlerce" / "10.000" / "4.8" returns nothing user-facing.
- [ ] No allergen/safety claim remains; app never implies allergen protection.
- [ ] Paywall shows no price the store won't charge; trial copy matches `introductoryPrice` for each plan.
- [ ] Real device: create account → delete account → account is gone, re-login fails, data cascade-deleted.
- [ ] `flutter analyze` = 0; existing tests green.

**Expected impact:** Eliminates the five highest-probability rejection/safety triggers. Android build becomes closed-beta-safe and legally honest.

---

## Phase 1 — Store Compliance & iOS Validation
**Objective:** Make the app submittable to both stores: validate the untested iOS target, reconcile permissions, fix the legal contact channel, and resolve the localization claim.
**Estimated effort:** 3–5 days + **UNVERIFIED** macOS time.

**Affected screens / files**
- `ios/` target as a whole (no `Podfile`, no `GoogleService-Info.plist` today)
- `.env` / `.env.example` (`GOOGLE_IOS_CLIENT_ID`), `ios/Runner/Info.plist:50,67`
- `android/app/src/main/AndroidManifest.xml` + `lib/core/services/notification_service.dart:252,329`
- `web/public/privacy.html:294,307,316` + in-app export
- `pubspec.yaml` version; `lib/l10n/*.arb`, `main.dart:633-634`, `app_localizations.dart`

**Implementation order**
1. **iOS end-to-end build (P0-6, UNVERIFIED here).** On macOS: `flutter build ios`, `pod install`, add the iOS OAuth client + reversed-client URL scheme + `GoogleService-Info.plist`, set `GOOGLE_IOS_CLIENT_ID`. Device-smoke every flow. Verify Apple Sign-In (from Phase 0) actually authenticates.
2. **Resolve the exact-alarm contradiction (P1-7).** Choose: (a) re-declare `USE_EXACT_ALARM` and complete the Play exact-alarm declaration, or (b) switch both `zonedSchedule` calls to `inexactAllowWhileIdle`. Recommend (b) for a fitness reminder — inexact is policy-safe and doze-tolerant. Wrap both calls in try/catch regardless.
3. **Fix the DSR email (P1-15).** `href="mailto:formaisupport@proton.me"` with matching visible text, in all three `privacy.html` locations; remove the stray `.;`.
4. **Reconcile permissions.** Remove the unused `NSMicrophoneUsageDescription` (`Info.plist:50`). Confirm Android manifest matches actual usage.
5. **Localization decision (P1-17).** Ship **TR-only** now: remove `en` from `supportedLocales` and from store metadata (fastest, honest). Full extraction is a Phase 5 track.
6. **Set version `1.0.0` (P1-21).**
7. **Password reset + Apple/Google platform gating (P1-8..10).** Add `resetPasswordForEmail` flow; gate Apple button to iOS; pass `webAuthenticationOptions`.

**Risks**
- iOS may surface new plugin/pod issues never seen on Linux — budget slack.
- Switching to inexact alarms slightly loosens reminder timing — acceptable; document it.
- Removing `en` must be mirrored in store listings or it re-triggers metadata mismatch.

**Validation checklist**
- [ ] iOS builds, installs on device, and every flow (onboarding, auth incl. Apple+Google, camera, paywall, deletion) works.
- [ ] Reminders schedule without throwing on an Android 12+ device; a scheduled ping actually fires.
- [ ] Privacy-policy email link opens a composer to the correct address.
- [ ] No unused permission strings; Data Safety / App Privacy forms match actual collection.
- [ ] English device shows a consistent (TR-only) UI; no 6-EN/1,300-TR hybrid.
- [ ] Password reset works; Apple button hidden on Android.

**Expected impact:** The app becomes technically submittable to both stores; the iOS unknown is closed; permission/metadata/legal mismatches cleared.

---

## Phase 2 — Core-Loop Truth & Retention
**Objective:** Make the retention machinery real. Today the streak caps at 3, charts are fake, and the level system is invisible — the day-2/day-7/day-30 hooks don't function.
**Estimated effort:** 1–2 weeks.

**Affected screens / files**
- Streak: `gelisim_tab.dart:186-196`, `workout_provider.dart:633,710`, `workout_generator_service.dart:102-109`, `app_preferences.dart` (add `lastWorkoutDate`), + the 6 copy-pasted `_streakOf` sites
- Charts: `gelisim_tab.dart:1049-1057`, `app_constants.dart:24`, `weekly_retrospective_card.dart:28-29`
- Level surface: `profile_tab.dart:137-157`, `dashboard_screen.dart` hero, `xp_provider.dart`
- Badges/goal: `badge_unlocks_provider.dart:169`, `antrenman_tab.dart:159`, `weekly_goal_card.dart`
- Nutrition: `daily_menu_provider.dart:111-135`, `nutrition_provider.dart:155-161,268-274`, `nutrition_onboarding_sheet.dart` (unused prefs)

**Implementation order**
1. **Real, time-based streak (P1-1).** Introduce a single calendar-day streak keyed off `lastWorkoutDate`; count consecutive days, tolerate rest days, and centralize the one implementation (delete the 6 copies). Re-point the streak badges and streak-XP milestones at it.
2. **Real charts or honest empty states (P1-2).** Feed measured data (per-exercise MET → calories; completed volume) or, until that exists, render a true zero/empty state instead of fabricated waveforms.
3. **Surface the level/title/XP (P1-3).** Add a level chip to the dashboard hero and a Profile identity block (level, title, lifetime XP, next-level progress) — the system is already computed and persisted.
4. **Unify metrics (P1-4).** One definition for "Kalori Avcısı"; make "weekly goal" use the real calendar week.
5. **Nutrition honesty (P1-11..13, P2 theater).** Either wire `dietPreference`/`nutritionGoal` into `daily_menu_provider` and macro calc, or remove the collection steps and the "AI optimize ediliyor" copy. Add an in-context "not medical advice" disclaimer. Label guest plans "örnek".

**Risks**
- The streak touches 7 surfaces — high regression area; add unit tests around the single new implementation first.
- Real calorie estimation needs an exercise→MET table; scope it or ship the honest empty state meanwhile.

**Validation checklist**
- [ ] A user training 5 real days in a row shows "🔥 5"; skipping a day resets appropriately; rest days don't break it.
- [ ] 7-day streak badge and streak-XP milestones ≥7 are now reachable (unit-tested).
- [ ] Charts reflect real activity or show a clean empty state; no fabricated baselines.
- [ ] Level/title/XP visible on dashboard + profile.
- [ ] Every collected nutrition preference either changes output or is removed.

**Expected impact:** Turns a built-but-idle retention system into a working flywheel; removes the "theater" that erodes trust; makes day-2/7/30 return mechanically possible.

---

## Phase 3 — Form-Engine Trust (the differentiator)
**Objective:** Make the pose/form feedback trustworthy. This is the product's reason to exist; today an attentive athlete will catch wrong counts and phantom corrections.
**Estimated effort:** 1–2 weeks + **UNVERIFIED** real-device/video validation.

**Affected screens / files**
- `lib/features/workout/presentation/workout_camera_screen.dart:192-195,501,527,588-597`
- `lib/features/workout/services/back_legs_analyzers.dart:68-70,204-208`, `chest_analyzers.dart:81`, `shoulders_arms_cardio_analyzers.dart:177`, `core_analyzers.dart:736-746`, `crunch_analyzer.dart:187-194`, `analyzer_factory.dart:96-97`
- `lib/features/workout/presentation/plan_detail_screen.dart:327,1620` (offline block)

**Implementation order**
1. **Unblock offline workouts (P1-5).** Separate the demo-video network check from the CV entry; degrade the video, keep the coaching.
2. **Interruption-safe session (P1-6).** Handle `paused`/`hidden`, pause the timer + coach on `inactive`, null the controller after dispose, resume cleanly.
3. **Fix the two broken form checks (P2).** Make the ShoulderPress partial-rep warning reachable; evaluate HipHinge peak-ROM on the DOWN transition, not at commit.
4. **Camera orientation for sagittal exercises (P2).** Add a front/side toggle or a "place phone to your side" guide for lean/sag exercises so those corrections can fire; otherwise suppress corrections that can't be measured in the current view.
5. **Consistent likelihood gating + diagnostics (P2).** Apply the 0.4 landmark-confidence floor uniformly; log swallowed per-frame failures; add a visual "get your body in frame" overlay.
6. **Real analyzers for the 87 shared exercises (P2, backlog).** At minimum stop routing deadlift/box-jump to `SquatAnalyzer`; add hinge/jump detectors or mark those exercises "rep-count beta".

**Risks**
- Analyzer changes need real-device + real-video validation (impossible on Linux — **UNVERIFIED**); build a labeled good/bad-form clip set before touching thresholds.
- Camera-orientation UX is non-trivial; a guide may be enough for v1.

**Validation checklist**
- [ ] Workout starts and counts reps in airplane mode.
- [ ] A phone call mid-plank pauses the timer; returning resumes without drain; no disposed-controller paint.
- [ ] ShoulderPress partial-rep cue fires on a short rep; HipHinge no longer nags full-lockout reps.
- [ ] On a labeled clip set, rep counts and form cues match ground truth within an agreed tolerance.

**Expected impact:** Converts the headline feature from "feels fake sometimes" to "I trust the count and the cue" — the single biggest driver of paid retention for this product.

---

## Phase 4 — UX Improvements
**Objective:** Reduce onboarding drop-off and remove friction from first-value.
**Estimated effort:** ~1 week.

**Affected screens / files**
- `lib/features/onboarding/presentation/onboarding_screen.dart:342` (paywall placement), `steps/*`
- `workout_camera_screen.dart:147,229` (ML disclosure persistence)
- `lib/core/services/notification_service.dart` + an onboarding notification-priming step
- `lib/features/auth/presentation/auth_screen.dart:113-128` (optimistic upgrade routing)

**Implementation order**
1. **First-value before paywall.** Insert a 20-second live form-analysis demo or a first free workout ahead of `/paywall`.
2. **Notification value-priming step** in onboarding (opt-in, not the OS prompt).
3. **Persist the ML disclosure** acknowledgement (stop re-showing every workout).
4. **Fix anon→email routing** so users aren't told "yükseltildi" before confirmation.
5. **Guest-plan labeling** ("örnek/tahmini") and clearer empty states.

**Risks:** Moving the paywall later can reduce immediate conversion but improves trust + trial quality; measure via the existing PostHog funnel.

**Validation checklist**
- [ ] A new user sees the product working before any paywall.
- [ ] ML disclosure appears once, then never again.
- [ ] Notification opt-in framed with value; grant rate measurable.

**Expected impact:** Lower drop-off, higher-intent trials, less "value-after-wall" resentment.

---

## Phase 5 — UI Polish · Accessibility · Localization · Performance
**Objective:** Raise craft to premium and clear the accessibility near-failure.
**Estimated effort:** 1–2 weeks (accessibility + full i18n are the long poles).

**Affected screens / files**
- Splash/brand: `main.dart:187`, `app_router.dart:409`, `android/.../values/styles.xml`, add `flutter_native_splash`
- Design tokens: `lib/core/theme/` (add TextTheme + spacing scale), 499 `fontSize:` sites
- A11y: add `Semantics`/`semanticLabel` to the ~206 tap targets; `MediaQuery.disableAnimations` in `lib/core/motion/`; dynamic-type reflow
- i18n: `lib/l10n/*.arb` extraction (if English is re-added later)
- Structure: split the 2,000-line widgets (`gelisim_tab.dart`, `paywall_screen.dart`, `profile_tab.dart`)

**Implementation order**
1. **Kill the white flash + unify brand color** (`flutter_native_splash`, one wordmark color).
2. **Real onboarding hero** (replace the stretched launcher icon).
3. **Typography + spacing tokens**; migrate high-traffic screens off inline sizes.
4. **Accessibility pass (P1-18..20):** semantic labels + button roles, a reduced-motion switch honored by the motion primitives, dynamic-type reflow above 1.3×, verify 48×48 touch targets.
5. **(Optional) Full string extraction** if English is a launch market.
6. **Structural cleanup:** split mega-widgets; delete the ~700 lines of dead nutrition code.

**Risks:** Accessibility retrofits touch many widgets; do it screen-by-screen with a checklist. Mega-widget splits risk regressions — lean on Phase 6 widget tests.

**Validation checklist**
- [ ] No white flash on a light-mode device; one brand color on the first frame.
- [ ] TalkBack/VoiceOver can identify and activate primary controls.
- [ ] "Reduce Motion" visibly calms the UI; large-text (2.0×) doesn't clip hero cards.
- [ ] Type/spacing come from tokens on migrated screens.

**Expected impact:** Moves the app from "polished in places" to "consistently premium"; removes a likely accessibility complaint surface.

---

## Phase 6 — Final QA & Launch Preparation
**Objective:** Prove it works end-to-end, raise automated confidence off 20.8%, and complete the external/console setup.
**Estimated effort:** ongoing; gate for public submission.

**Affected areas:** whole app; `test/`, `integration_test/app_test.dart`, CI (`ci.yml`, `flutter_ci.yml`), both store consoles (**UNVERIFIED** external).

**Implementation order**
1. **Widget-test harness.** Build the reusable Riverpod `ProviderScope` + mock-repository harness the presentation layer lacks; cover paywall, onboarding, auth (incl. delete + reset), workout entry, dashboard. Raise coverage toward a real gate (target 45–60% with the presentation layer included).
2. **Device matrix smoke** (low-end Android + iOS): boot, onboarding, camera/pose, paywall purchase (sandbox), restore, deletion, notifications, offline.
3. **Consolidate CI** (`ci.yml` vs `flutter_ci.yml`); keep the secret-scan + coverage gates.
4. **External/console (UNVERIFIED here):** RC products/entitlements with matching prices+trials; Data Safety / App Privacy forms; signing keys; prod DSNs/keys; live Privacy+Terms URLs; rotate the Supabase DB password if any pre-Phase-0 APK shipped the old `.env`.
5. **Submit to closed → open testing → production**, watching Sentry crash-free rate and the PostHog funnel at each ring.

**Risks:** Sandbox IAP + store review are external and time-variable; leave calendar slack. Coverage work is large — prioritize the money/deletion/auth paths first.

**Validation checklist**
- [ ] Green CI: analyze 0, tests pass, secret-scan clean, coverage gate met.
- [ ] Full device smoke passes on both platforms.
- [ ] Sandbox purchase + restore + deletion verified on device.
- [ ] Store console forms match actual data collection; all prod credentials live.
- [ ] Crash-free sessions ≥ 99.5% on the closed-testing cohort before promotion.

**Expected impact:** Converts "should work" into "verified working," with the automated safety net to keep it that way post-launch.

---

## Summary timeline (indicative)

| Phase | Focus | Effort | Public-submission gate? |
|---|---|---|---|
| 0 | Integrity / safety / rejection removals | 2–4 d | **Blocking** |
| 1 | Store compliance + iOS validation | 3–5 d + macOS | **Blocking** |
| 2 | Core-loop truth & retention | 1–2 wk | Growth gate |
| 3 | Form-engine trust | 1–2 wk | Retention gate |
| 4 | UX improvements | ~1 wk | Recommended |
| 5 | UI · a11y · i18n · perf | 1–2 wk | Recommended |
| 6 | Final QA & launch prep | ongoing | **Blocking (public)** |

**Fastest honest path to a public Android release:** Phase 0 → Phase 1 → Phase 6 (money/deletion/auth tests + console setup). Phases 2–5 are what make the launch *succeed* rather than merely *pass review*. iOS requires Phase 1's macOS validation before any App Store submission.
