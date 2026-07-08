# FormAI — Master Product Maturity Roadmap

**Date:** 2026-07-08 · **Branch:** `prisk/phase-1-tests` · **Baseline:** analyze 0 · 242/242 tests · cov 20.8% · version 0.1.0+12
**Sources merged:** `FINAL_PRE_STORE_AUDIT_REPORT.md` (P0-1…P0-6, P1-1…P1-21, P2 set) + `FINAL_PRE_LAUNCH_EXECUTION_PLAN.md` (Phase 0–6 plan) + **independent engineering re-review (2026-07-08, 5 parallel deep passes: async/state safety, resource lifecycle, error/offline behavior, dead code/duplication, release hygiene)**.
**Traceability:** every task carries its source — `[AUDIT x]` from the audit, `[REV-x]` from the fresh review, `[MEM]` from prior-session verified findings.

**Execution discipline (mission rules):** repo permanently green (`dart format` clean, `flutter analyze` 0, all tests pass) → commit → push, per phase. Nothing fabricated; anything unverifiable here is tagged **REQUIRES PHYSICAL DEVICE / REQUIRES APPLE ENVIRONMENT / REQUIRES STORE CONSOLE / REQUIRES PROD DB APPLY** and ledgered at the bottom — never silently skipped, never faked.

**Field key:** Effort S ≤ ~1h · M ≤ ~half-day · L = multi-day. Impact: Store / Retention / Revenue / UX each rated H/M/L/–.

---

## Phase 0 — Integrity & Safety (public-submission blockers)

*Objective: no fabricated claims, no safety-false promises, no deceptive pricing, no broken legal guarantee. Gate for ANY public track.*

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact S/Ret/Rev/UX |
|---|---|---|---|---|---|---|---|---|
| 0.1 | Rebuild `social_proof_step.dart` honestly: delete 9 fabricated testimonials + ratings + recency stamps + "4.8 MEMNUNİYET" badge + "binlerce kişi" ×2 + decorative 5-star seals; replace with verifiable product-fact cards (138 exercise analyzers, on-device CV, real-time voice coach) + honest early-access framing. Also delete "10.000+ kişi" `_TrustBooster` (`nutrition_onboarding_sheet.dart:628` + `_AiIllusionScreen` usage) **and the missed "🔥 10.000+ kişi kullanıyor" on the paywall (`paywall_screen.dart:937`) [REV-E6]** | **P0** | [AUDIT P0-1] Apple 2.3.1 / Play Misrepresentation — highest-probability rejection; lying to first users | Conversion may dip — accepted, non-negotiable | M | — | grep: zero fabricated names/"binlerce"/"10.000"/"4.8" user-facing; analyze+tests green | H/M/M/M |
| 0.2 | Remove false allergen-safety claim AND the allergy collection step (feeds nothing; no allergen schema exists): drop `_AllergiesPage` from wizard, stop persisting `allergies`, remove orphaned wizard field + assets refs | **P0** | [AUDIT P0-5] Apple 1.4.1 physical-harm class; a nut-allergic user is told they're protected — they are not | Low — step removal shortens wizard | S-M | — | grep: no allergen promise; wizard 7→6 steps runs clean; tests green | H/L/–/M |
| 0.3 | De-deceptify paywall: (a) delete fictional "₺2.999,99 idi" `_decoy` anchor; (b) drive ALL trial copy (`_InlineTrialBadge`, `_NoPaymentBadge`, CTA "₺0,00 karşılığında dene", `_LegalFooter`) from the **selected package's real** `storeProduct.introductoryPrice` — hidden/priced copy when no trial; (c) add explicit renewal disclosure "seçili plan ₺X/dönem, iptal edilmedikçe otomatik yenilenir, mağaza hesabına yansıtılır" | **P0** | [AUDIT P0-4] Apple 3.1.1/3.1.2/2.3.1, Play Deceptive Behavior, TR/EU reference-price law | Trial copy disappears until RC SKUs configured (external) — safe direction | M | RC SKU config = external | With no intro price: no trial promise anywhere; with mocked package: copy matches; tests green | H/–/M/M |
| 0.4 | Ship `delete_user` RPC as checked-in migration `006_delete_user.sql` (SQL from `docs/ROADMAP.md:101-116`) + `redeem_referral`+`referrals` table as `007_referrals.sql` (`docs/ROADMAP.md:134-179`) | **P0** | [AUDIT P0-2, P1-14] Apple 5.1.1(v) / Play data-deletion / KVKK Art.7 — deletion path must exist in VCS; referral banner currently promises undeliverable reward | SECURITY DEFINER must revoke public — SQL already does | S | Prod apply = **REQUIRES PROD DB APPLY** | migration files lint-clean; ledger entry for prod apply + on-device round-trip | H/–/L/– |
| 0.5 | Add `com.apple.developer.applesignin` to `Runner.entitlements`; gate `_AppleButton` to `Platform.isIOS` so Android never shows a dead button | **P0** | [AUDIT P0-3, P1-10] Apple 4.8 — advertised Apple Sign-In is non-functional; on Android it throws into a toast | None on Android (button hidden); iOS runtime validation impossible here | S | Xcode capability + Service ID/key = **REQUIRES APPLE ENVIRONMENT** | entitlements plist valid; Android build shows no Apple button; tests green | H/–/–/M |
| 0.6 | Honest referral landing: replace unconditional "ilk ayını birlikte Pro yapın" success framing with "kod kaydedildi" truth (reward delivery is post-launch, `referral_landing_screen.dart:88`) | **P0** | [AUDIT G1] reward is undeliverable today → false promise | Low | S | 0.4 | copy states what actually happens; tests green | M/–/L/L |
| 0.7 | De-quantify guaranteed outcome claims: "12 haftada 4-8 kg yağ kaybı" / "%20-30 güç artışı" (`ai_personalization_engine.dart:278,281`, rendered `act_5_commitment_step.dart:405` + `act_4_revelation_steps.dart:560`) → non-numeric, non-guaranteed framing | **P0** | [REV-E2] Apple 1.4.1 / Play health-misrepresentation: specific promised results in an app with zero outcome data | Copy only | S | — | grep: no "kg"/"%%" outcome promises; tests green | H/–/–/L |
| 0.8 | **Resolve the ATT contradiction:** runtime `requestTrackingAuthorization` (`analytics_service.dart:322`, called `onboarding_screen.dart:340`) + `NSUserTrackingUsageDescription` vs `PrivacyInfo.xcprivacy` `NSPrivacyTracking=false` + privacy.html's explicit "no ATT prompt is shown". Chosen reality: **no tracking** — remove the ATT/IDFA request path + plist string; manifest & policy stay truthful | **P0** | [REV-E1] Apple auto-flags ATT-API-linked binaries declaring tracking=false; the published policy is falsified by the running app | PostHog install attribution loses IDFA — acceptable (first-party analytics unaffected) | S-M | — | grep: no ATT call; plist key gone; manifest/policy consistent | H/–/–/– |

**Phase exit:** grep-clean of all fabricated/false claims; analyze 0; tests green; commit+push.

---

## Phase 1 — Store Compliance & Platform Correctness

*Objective: technically submittable; permissions/metadata/legal channels correct; auth flows complete.*

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 1.1 | Resolve exact-alarm contradiction: adopt WIP manifest (perms removed) + switch both `zonedSchedule` sites (`notification_service.dart:252,329`) to `inexactAllowWhileIdle` + wrap in try/catch | **P0→P1** | [AUDIT P1-7] current code **throws** `exact_alarms_not_permitted` on Android 12+ → ALL reminders dead; inexact is Play-policy-safe for fitness reminders | Reminder timing loosens (~±15min in doze) — acceptable, documented | S | — | analyze; unit-testable via mode constant; device confirm = **REQUIRES PHYSICAL DEVICE** | H/H/–/– |
| 1.2 | Fix DSR email in `privacy.html` (3 sites) **+ align `terms.html`**: real monitored mailbox `formaisupport@proton.me` as BOTH `mailto:` href and visible text (current state: displayed `support@formai.app` ≠ href `formaisupport@proton.me`, no `mailto:` scheme [REV-E8]) + remove stray `.;` (line 288) | **P0→P1** | [AUDIT P1-15] the only data-subject-request channel is a broken link to a mismatched address — GDPR Art.12/KVKK | If `support@formai.app` is later provisioned, swap once — documented | S | — | link opens composer to real mailbox; text==href everywhere | H/–/–/– |
| 1.3 | Remove unused `NSMicrophoneUsageDescription` (`Info.plist:50`, camera runs `enableAudio:false`) | P1 | [AUDIT P2/A7] Apple 5.1.1(b) minimal-data; unused permission invites rejection questions | None | S | — | plist has no mic string; grep confirms no mic use | M/–/–/– |
| 1.4 | Version → `1.0.0+13` | P1 | [AUDIT P1-21] 0.1.0 signals unfinished to review + users | None | S | — | pubspec + builds carry 1.0.0 | M/–/–/L |
| 1.5 | Localization honesty: restrict `supportedLocales` to `tr` (drop implicit `en` claim; scaffold + ARB stay for the extended i18n track) | P1 | [AUDIT P1-17] declaring `en` ships a 6-EN/1300-TR hybrid on English devices | Store listing must say Turkish — external note | S | — | English-locale device renders consistent TR UI (widget test) | H/L/–/M |
| 1.6 | Password reset flow: `resetPasswordForEmail` + "Şifremi unuttum" UI on `auth_screen.dart` + confirmation state | P1 | [AUDIT P1-9] email users who forget are permanently locked out | Low — additive | M | — | unit/widget test: reset invoked, feedback shown; e2e mail = **REQUIRES PROD** (Supabase mail) | M/M/M/H |
| 1.7 | OAuth error hygiene: generic catches return `null` message (localized fallback used) instead of `e.toString()` raw `ClientException` toasts (`auth_provider.dart:294`); drop English `${e.message}` interpolation from password toasts (`profile_tab.dart:377`, `account_settings_screen.dart:216`) | P1 | [REV-C4, C5] raw/English errors in a Turkish store build read as broken | None | S | — | greps + existing auth tests | M/–/–/M |
| 1.8 | Gate `isDeveloperOverride` to debug builds (`monetization_provider.dart` read path honors it only in `kDebugMode`) | P1 | [AUDIT P2-mon] a stale flag from a side-loaded debug build unlocks Pro in release — revenue + review integrity | Devs keep the flag in debug | S | — | unit test: release-mode read ignores override | M/–/M/– |
| 1.9 | `.env.example`: add `GOOGLE_IOS_CLIENT_ID=` placeholder (read by `auth_provider.dart:207`) | P2 | [AUDIT P1-8] misconfig invisible to whoever sets up iOS | None | S | iOS OAuth client = **REQUIRES APPLE ENVIRONMENT** | template complete | L/–/–/– |
| 1.10 | Boot-retry auth-listener leak: store/cancel the `onAuthStateChange` subscription in `_BootGate._init` re-entry (`main.dart:307`) | P1 | [REV-B2] every failed-boot retry stacks a permanent listener | None | S | — | code inspection + analyze; boot tests green | –/–/–/L (stability) |
| 1.11 | Age-policy alignment: in-app gate is 18+ (`act_3_buildup_steps.dart:584`) but `terms.html:159` + `privacy.html:307` say 16 → set both legal docs to 18 | P1 | [REV-E3] store age-rating, Data-Safety and policy pages must agree; reviewer at 16-17 hits a contradiction | None | S | — | docs read 18; app unchanged | M/–/–/– |
| 1.12 | RevenueCat identity hygiene: call `Purchases.logOut()` (guarded) in `signOut()` + `deleteAccount()` (`auth_provider.dart:416,376`; today NO logOut exists anywhere) | P1 | [REV-E4] previous user's Pro entitlement bleeds to the next guest/user on a shared device | RC logOut throws if already anonymous — try/catch | S | — | unit: signOut path invokes logOut; tests green | M/–/M/– |
| 1.13 | Sign-out PII wipe: clear user-scoped prefs (metrics/goal/plan-cache/wizard) on `signOut()` — today only `deleteAccount` clears disk (`auth_provider.dart:399` vs `:416`) | P1 | [REV-E5] height/weight/age/goal of the previous account re-hydrate for the next user on shared devices | Preserve device-level consent/theme keys — selective wipe | S-M | — | unit: after signOut, user-scoped keys empty, consent intact | M/–/–/M |
| 1.14 | Guard `debugPrint('🔥 VIDEO_URL_DEBUG…')` with `kDebugMode` (`exercise_guide_player.dart:268` — executes in release) | P2 | [REV-E7] dev URL spam in release logs | None | S | — | grep: no unguarded debugPrint in lib/ | L/–/–/– |

**Phase exit:** analyze 0; tests green; commit+push.

---

## Phase 2 — Core-Loop Truth & Retention

*Objective: the retention machinery becomes real — streak, charts, identity, nutrition personalization. This is what makes day-2/7/30 return mechanically possible.*

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 2.1 | **Real calendar-day streak.** New pure `StreakCalculator` over `SessionLog.completedAtIso` dates (consecutive active days; single-day gap tolerated = program rest day; 2+ missed days reset). One `currentStreakProvider`; re-point **all 9** duplicated `_streakOf` sites (widget_sync, badge_unlocks, badges, suggestions, session_complete_overlay, antrenman, workout_provider, profile, gelisim) | **P1** | [AUDIT P1-1 — "single most damaging quality bug"; REV-D confirms 9 copies not 6] streak caps at 3 forever; ≥7 badges/XP milestones dead; no loss-aversion loop | 9-surface regression area → unit-test the calculator FIRST, then rewire | M-L | — | unit tests: 5-day run→5; rest-day tolerated; 2-gap resets; badge ≥7 reachable; all tests green | –/**H**/M/H |
| 2.2 | **Honest charts.** `gelisim_tab.dart:1049-1057`: completion bars from real completions ✓ (keep), kcal line + waveform → real measured series (per-session duration × MET-lite from session logs) or true zero/empty state — no `i.isEven` fabricated baselines, no flat `×250` kcal claim presented as measurement (`app_constants.dart:24` stays only as badge predicate) | P1 | [AUDIT P1-2] "track your progress" renders decoration — trust erosion at the retention reward moment | Chart redesign touches gelisim tab only | M | 2.1 | charts render from SessionLog data; empty state when none; widget/unit tests | –/H/L/H |
| 2.3 | **Surface the identity system.** Level/title/XP chip on dashboard hero + Profile identity block (level, title, lifetime XP, next-level progress) from existing `levelProgressProvider`/`currentTitleProvider` | P1 | [AUDIT P1-3] 9-tier ladder computed+persisted, zero consumers — invisible investment | Additive UI | M | — | providers consumed; visible in widget tests | –/H/L/H |
| 2.4 | Unify badge + weekly-goal definitions: one "Kalori Avcısı" predicate (`badge_unlocks_provider.dart:169` vs `gelisim_tab.dart:87,1766`); weekly goal counts current calendar week, not lifetime (`antrenman_tab.dart:159`) | P1 | [AUDIT P1-4] same badge reads locked+unlocked simultaneously; "weekly" goal never resets | Low | S-M | 2.1 | unit tests on both predicates | –/M/–/M |
| 2.5 | **Real diet personalization** (data supports it: `Recipe.tags` incl. "Vegan"): filter/rank `daily_menu_provider` candidates by `dietPreference` tag match + calorie-fit to `macroTargetProvider`; graceful fallback when tags/filter empty; soften "AI optimize ediliyor" copy to honest "kişisel plan hazırlanıyor"; label guest default plan "örnek plan" (`nutrition_provider.dart:155`); in-context "tıbbi tavsiye değildir" disclaimer on nutrition surfaces; wire or remove `nutritionGoal`/`waterIntake`/`tastePreference` (wire goal→calc if trivial, else drop collection steps); remove dead `nutritionStreak` (always 0) or back it with real daily scores | P1 | [AUDIT P1-11,12,13, P2-theater] 5/7 collected prefs unused; vegan gets meat; "optimize" theater; prescriptive kcal with no disclaimer | Tag data on prod recipes UNVERIFIED from here → fallback path mandatory | M-L | — | unit tests: vegan pref → no meat-tagged mains when tags present; fallback sane; disclaimer visible | M/H/M/H |
| 2.6 | Kill silent nutrition/dashboard error swallows: discovery strip + equipment strip get `ErrorCard(retry)` instead of `SizedBox.shrink()` (`nutrition_tab.dart:116`, `equipment_strip.dart:63`); `loadMore` catch → retry footer (`nutrition_provider.dart:124`); connectivity short-circuit in `nutrition_repository` mirroring workout repo | P1 | [REV-C2,C3,C6] offline first-10-minutes UX: strips spin then vanish, no retry anywhere | Low | M | — | offline simulation: strips show retry; tests | L/M/–/H |

**Phase exit:** analyze 0; all tests (incl. new streak/menu suites) green; commit+push.

---

## Phase 3 — Form-Engine Trust & Session Stability

*Objective: the differentiator stops lying and stops crashing. Count what's countable, cue only what's measurable, survive interruptions, work offline.*

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 3.1 | **Unblock offline workouts:** replace both hard network gates (`plan_detail_screen.dart:327,1620`) with informational "çevrimdışısın — videolar yüklenmeyebilir, koçluk çalışır" snackbar + proceed (CV is fully on-device; video tiles already degrade gracefully) | **P1** | [AUDIT P1-5] headline feature dead in gyms/planes/basements for the sake of demo videos | Video-less session UX — already handled by fallback tiles | S | — | flight-mode session starts + counts (analyzer tests prove counting); device confirm = **REQUIRES PHYSICAL DEVICE** | M/H/M/H |
| 3.2 | **Interruption-safe session:** `didChangeAppLifecycleState` → on `inactive`: stop image stream (guarded), pause workout timer + coach TTS, dispose camera, **null `_controller`**, `setState`; on `resumed`: restart + resume; handle `paused`/`hidden` | **P1** | [AUDIT P1-6 + REV-B1] current path disposes without stream-stop or null-out → disposed-controller crash + timer drain + coach talking to dead camera on every call/shade-pull | Camera lifecycle is finicky — mirror the proven `dispose()` ordering | M | — | lifecycle unit test where feasible; manual matrix = **REQUIRES PHYSICAL DEVICE** | M/H/–/**H** |
| 3.3 | Fix ShoulderPress unreachable partial-rep warning: raise `partialRatio` 0.55 → ~1.3 (bar ≈0.9×shoulderWidth, above the 0.7 entry threshold) + correct doc + tests for shallow-warns/deep-passes | P1 | [MEM/AUDIT P2] warning is mathematically dead code today | Threshold judgement — synthetic-pose tests anchor it | S | — | new unit tests both directions | –/M/–/M |
| 3.4 | Fix HipHinge partial-ROM false positive: evaluate `_peakAngle` at the **next DOWN transition** (full-cycle peak), not at commit-frame (~165° by construction) | P1 | [AUDIT P2] nags users who DO reach full lockout — anti-trust on good reps | Same | S | — | unit tests: peak 179→silent; peak 168→cue on descent | –/M/–/M |
| 3.5 | Fix Crunch neck-cue seed: 10s seed vs >15s gate → seed = cooldown so first bad-form frame can fire (matches Plank pattern) | P2 | [MEM] "fire immediately" comment is false by 5 seconds | None | S | — | existing crunch tests extended | –/L/–/L |
| 3.6 | Consistent landmark-confidence gating: apply the 0.4 likelihood floor to crunch/leg-raise/plank family (`core_analyzers.dart:736-746`) | P2 | [AUDIT P2] older analyzers count ghost reps from low-confidence frames | Could reduce counted reps on poor lighting — that's the point | S-M | — | unit tests with low-likelihood poses reject | –/M/–/M |
| 3.7 | Suppress unmeasurable sagittal cues in front-camera view + add "telefonu yan tarafına koy" guide copy for squat-lean/push-up-hip-sag class checks (`workout_camera_screen.dart:192` front-only today) | P2 | [AUDIT P2 — "core feels-fake risk"] cues promised that geometrically cannot fire | Copy/gating only — no analyzer surgery | M | — | gating unit tests; visual = **REQUIRES PHYSICAL DEVICE** | –/M/–/M |
| 3.8 | Consume `isStub` degraded flag: "Program senkronize ediliyor — tekrar dene" state on antrenman+gelisim instead of silently rendering a 30-rest-day fake program (`workout_provider.dart:212`, promised banner never built) | P1 | [REV-C1] offline onboarding → user sees an all-rest-day "program" with no explanation | Low | S-M | — | stub session → banner visible (widget/unit) | L/M/–/H |
| 3.9 | `ref.mounted`/`mounted` guards on state-after-await races: `nutrition_provider.dart:136` (loadMore), `workout_provider.dart:421,514` (complete/reset), `monetization_provider.dart:113,158`, admin form pickers ×3 | P1 | [REV-A1..A4] invalidation mid-flight → StateError (zone-caught): Sentry noise + silently dropped completion/page updates — worst case a lost final-set completion | None — one-line guards | S | — | analyze; existing suites green | –/M/–/L (stability) |

**Phase exit:** analyzer suite green incl. new tests; analyze 0; commit+push.

---

## Phase 4 — UX Honesty & Friction

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 4.1 | Persist ML-disclosure acknowledgement (stop re-showing every workout entry) | P2 | [AUDIT UX-10] repeat modal = friction at the core loop | None | S | — | pref persisted; shown once (test) | –/M/–/H |
| 4.2 | Anon→email upgrade copy: don't declare "yükseltildi" before confirmation; state "doğrulama sonrası e-postanla giriş" | P2 | [AUDIT P2-auth] optimistic claim pre-confirmation | None | S | — | copy review | L/–/–/M |
| 4.3 | Notification value-priming step in onboarding (opt-in framing before OS prompt), reusing existing notification service | P2 | [AUDIT UX-8] buried retention lever | Onboarding length +1 — keep skippable | M | — | step shows, opt-in tracked | –/M/–/M |
| 4.4 | **Paywall placement experiment** (first-value demo before wall) — *documented as product decision*: existing PostHog funnel should arbitrate; restructuring 21-step onboarding unilaterally = regression risk without widget-test net | P2 | [AUDIT UX-1] value-after-wall resentment vs conversion | High without tests → **DEFERRED-DECISION** (extended track) | L | Phase 6 harness | funnel metrics post-launch | –/H/H/H |

---

## Phase 5 — Structure, Accessibility, UI Polish

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 5.1 | Delete 4 confirmed-dead files (`next_best_meal_card.dart`, `ai_insight_banner.dart` ~700 LOC, `wheel_column.dart`, `photo_option_card.dart`) + dead `meal_plan_timeline` import in nutrition_tab | P2 | [REV-D-a] zero external refs verified incl. router strings | None — evidence-based | S | — | analyze green post-delete; grep 0 refs | –/–/–/– (debt) |
| 5.2 | Consolidate duplications: Google logo painter ×2 → shared; `_EditProfileSheet`/`_ChangePasswordSheet` ×2 → account_settings canonical; recipe `_Thumb` ×4 + `_EmptyState` ×3 → shared widgets (streak ×9 already centralized in 2.1) | P2 | [REV-D-b] ~600+ LOC copy-paste; sheets already diverging | Medium — UI regression risk, migrate screen-by-screen | M | — | analyze+tests; visual parity | –/–/–/L (debt) |
| 5.3 | Brand-color unify + splash: boot wordmark cyan `0xFF00F0FF` → brand purple (`main.dart:187` vs `app_colors.dart:23`); add `flutter_native_splash` branded background (kills white flash) | P2 | [AUDIT UI-1] first-frame brand split + white flash = cheap premium loss | Splash pkg touches native configs — verify builds | M | — | APK build; first-frame check = **REQUIRES PHYSICAL DEVICE** for true flash | L/L/–/H |
| 5.4 | A11y floor: `Semantics`/labels + button roles on primary CTAs (paywall buy/restore, onboarding continue, workout start/stop, tab bar, auth buttons); honor `MediaQuery.disableAnimations` in the core motion primitives (`glow_pulse`, `ambient_particles`, carousels) | P1(a11y) | [AUDIT P1-18,19] 0 semanticLabels / 0 reduced-motion in an animation-maximal app — near-fail | Wide but mechanical; start with the money+core paths | M-L | — | semantics widget tests on wrapped CTAs; reduce-motion flag calms primitives (test) | M/L/–/H |
| 5.5 | Onboarding hero: stop stretching the launcher icon full-bleed (`act_1_hook_step.dart:138`) — use existing brand asset treatment | P3 | [AUDIT UI-2] first screen looks broken-stretched | Low | S | — | visual sanity | L/–/–/M |
| 5.6 | Mega-widget splits (gelisim 2079 / paywall 1996 / profile 1914) per REV-D split map | P3 | maintainability | High without widget tests | L | Phase 6 harness | **EXTENDED** — after harness | debt |

---

## Phase 6 — QA, CI, Builds (continuous gate)

| ID | Task | Prio | Reason | Risk | Effort | Deps | Validation | Impact |
|---|---|---|---|---|---|---|---|---|
| 6.1 | Consolidate CI: merge `flutter_ci.yml` into `ci.yml` (keep coverage + secret-scan + integration jobs; one workflow of record) | P2 | [AUDIT P2] two overlapping workflows drift | Low | S | — | single workflow valid YAML; CI green on push | –/–/–/– |
| 6.5 | Loud debug-signing warning: `release.yml` + gradle emit an unmissable warning when `key.properties` is absent and the "release" artifact is debug-signed (`build.gradle.kts:93-97`) | P2 | [REV-E10] silently debug-signed "release" artifacts are un-uploadable and easy to mis-distribute | Keep fallback (local builds need it) — warn, don't fail local | S | — | CI log shows warning; local build unaffected | M/–/–/– |
| 6.2 | Tests for every change in Phases 0–5 (streak calculator, paywall trial logic, menu diet filter, analyzer fixes, notification mode, stub banner…) — suite grows with each phase, target every new pure-logic path covered | P1 | mission: no unvalidated change | — | rolling | each phase | suite green, coverage ↑ from 20.8% | – |
| 6.3 | Build `APK` + `AAB` release artifacts post-phases; emulator boot-smoke if stable | P1 | prove shippable binaries | emulator flaky under load (known) | M | phases done | both builds succeed locally | H/–/–/– |
| 6.4 | Widget-test harness (ProviderScope + mock repos) + presentation coverage toward 45–60% | P1 | [AUDIT Phase-6] paywall/onboarding/auth/dashboard untested — the real coverage unlock | Large | L | — | **EXTENDED** — begin, don't finish here | – |

---

## Extended Tracks (real work, beyond this execution window — explicitly NOT abandoned)

| Track | Scope | Why not now | First step (done in this execution where possible) |
|---|---|---|---|
| Full i18n extraction | ~1,300 hardcoded TR strings → ARB | multi-day mechanical; TR-only decision (1.5) removes the store risk | scaffold live; locale honesty shipped |
| Widget-test harness → 45-60% cov | mock-provider harness + screen suites | multi-day | 6.4 begins it |
| Video analysis MVP (Roadmap B Faz 1-6) | upload→frames→BlazePose batch→score→history | needs real device + real videos to validate honestly | schema (005) + models + form_score shipped earlier |
| MET-based calorie engine | per-exercise MET table × duration × weight | needs nutrition/product sign-off on formula | 2.2 ships duration-based honest series |
| Side-camera analyzers for 87 shared exercises | hinge/jump detectors, "rep-count beta" labels | needs labeled clip set (physical device) | 3.7 suppresses false cues meanwhile |
| Paywall placement experiment | first-value before wall | product decision + funnel data | 4.4 documented |
| HealthKit / Google Fit, progress photos, data export | table-stakes competitive set | new feature tracks | policy export promise noted in ledger |

## External / Non-executable-here Ledger (NEVER faked — each blocks the marked scope only)

1. **REQUIRES PROD DB APPLY:** run `006_delete_user.sql` + `007_referrals.sql` on Supabase prod; verify delete round-trip on a real account. *(Blocks: public submission.)*
2. **REQUIRES APPLE ENVIRONMENT:** Xcode Sign-in-with-Apple capability + Service ID/key; `pod install` / first iOS build; `GoogleService-Info.plist` + `GOOGLE_IOS_CLIENT_ID`; reversed-client URL scheme; full device smoke. *(Blocks: App Store track only.)*
3. **REQUIRES STORE CONSOLE:** RevenueCat products/entitlements with real prices+trials (both consoles); Play Data-Safety + App Privacy forms; signing keys; prod DSNs; store listings language=TR. *(Blocks: public submission.)*
4. **REQUIRES PHYSICAL DEVICE:** reminder fire on Android 12+; flight-mode workout; call-interruption resume; camera/pose accuracy on real bodies; splash first-frame; TalkBack pass. *(Blocks: release confidence, not code completion.)*
5. **Rotate GitHub PAT in `.git/config`** + rotate Supabase DB password if any pre-Phase-0 APK ever shipped `.env`. *(Security hygiene — user action.)*
6. **Legal-entity identity on terms/privacy pages** [REV-E9]: KVKK requires a named data controller + address; only the user can supply the real legal name. *(Blocks: full KVKK compliance of the policy pages.)*
7. **Support-mailbox decision** [REV-E8]: pages will point at `formaisupport@proton.me` (the monitored box); if `support@formai.app` is provisioned later, swap in one commit.

---

## Sequencing & gates

```
Phase 0 (honesty/safety) ─┬─ blocking: any public track
Phase 1 (compliance)      ─┴─ blocking: store submission
Phase 2 (retention truth) ── growth gate
Phase 3 (trust/stability) ── retention gate
Phase 4 (UX)              ── recommended
Phase 5 (structure/a11y)  ── recommended
Phase 6 (QA/CI/builds)    ── continuous, final gate
```

Each phase: implement → `dart format` → `flutter analyze` (0) → `flutter test` (all green) → commit → **push** → next. Final deliverable after all executable phases: `FINAL_PRODUCT_MATURITY_EXECUTION_REPORT.md` with readiness scores and the external-task ledger.
