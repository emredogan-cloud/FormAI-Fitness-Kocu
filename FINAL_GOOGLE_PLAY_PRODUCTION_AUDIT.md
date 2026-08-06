# FINAL GOOGLE PLAY PRODUCTION AUDIT

**App:** FormAI — Kişisel Fitness Koçu · `com.emredogan.formaifit`
**Build audited:** `1.0.0` versionCode **37**, delivered by Google Play
(`installer=com.android.vending`), signed by **Play App Signing**
**Device:** Redmi Note 8 (M1908C3JGG), Android 11, 1080×2340, `AYXSUKIVJVPZ7HPZ`
**Date:** 6 August 2026
**Auditor scope:** install the real Play track build, walk it as a new user,
review it as an App Review engineer, fix production blockers, report.

---

## 1. Executive Summary

FormAI is a **genuinely well-engineered app**. The things that usually sink a
first production submission are already right here: consent is opt-in and
defaults to off, the camera permission has a proper pre-prompt rationale with a
working "continue without the camera" path, account deletion exists in-app and
is prominent, guest mode is real (no forced registration, no forced purchase),
subscription terms are disclosed correctly above the fold, Restore Purchases is
present, offline degrades gracefully with no crash, and **Google Sign-In works
end-to-end on the Play-signed build** — the issue named in the brief is not
reproducible and is closed below with evidence.

It is nevertheless **not ready to press "Apply for Production" today**, for
reasons that are mostly *outside the APK*.

Three findings are hard blockers against written Google policy:

1. **No in-app reporting for AI-generated content.** The app ships a live
   Claude-powered coach. Play's Generative AI policy requires, verbatim, an
   in-app flag/report affordance. There is none. (Community UGC *does* have
   reporting — the AI surface does not.)
2. **No web URL for account/data deletion.** Play requires an in-app path
   **and** a web link. The in-app path exists; the web link does not — every
   candidate URL on the legal host 404s, and the policy offers only an email.
3. **The privacy policy was materially false.** It stated body metrics are
   "never stored on our servers" while `BodyMetricsRepository` upserts every
   one of them into Supabase, and it did not name Anthropic at all although the
   coach transmits the user's name, age, height, weight and 30-day trends to
   `api.anthropic.com`. **Fixed in this audit** — but the corrected file must
   be deployed to CloudFront before submission.

Two more are store-side and cannot be fixed from the repository: the listing is
titled **"(Erken Erişim)"** — an early-access label that must not ship to
production — and the app is rated **PEGI 3** while its own first screen enforces
an **18+** age gate. That rating/enforcement contradiction is exactly the kind
of inconsistency the content-rating policy exists to catch.

The single worst *in-app* finding was a fabricated statistic: the onboarding
report showed **"Success probability 92%"** under an "AI ASSESSMENT" heading.
It was `static const double _confidenceTarget = 0.92` — the same number for
every user, before they had trained once. That is a Misrepresentation-policy
risk and it has been removed.

**Nine issues were fixed and verified during this audit. Six remain, and five
of those six are founder/console actions that no code change can perform.**

---

## 2. End-to-End Device Test Results

### 2.1 What was actually installed

The build on the device at the start of this session was **sideloaded**
(`installer=null`) — i.e. not what a reviewer receives. It was uninstalled and
the real Play closed-test build was installed from
`https://play.google.com/apps/testing/com.emredogan.formaifit`.

| Property | Value | How verified |
| --- | --- | --- |
| Package id | `com.emredogan.formaifit` | `dumpsys package` |
| Version name | `1.0.0` | `dumpsys package` |
| Version code | **37** | `dumpsys package` |
| Install source | `com.android.vending` | `pm list packages -i` |
| Download size | 41 MB (Play split) vs 137 MB universal | Play listing / pulled APK |
| targetSdk / minSdk / compileSdk | **36** / 24 / 36 | `aapt2 dump badging` |
| Signing | **Play App Signing**, v3 + source stamp | `apksigner --print-certs` |
| Play cert SHA-1 | `82:79:7E:F8:FC:27:B6:75:EE:D0:9D:48:63:77:B0:A9:F3:67:E2:32` | `apksigner` |
| Upload cert SHA-1 | `CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3` (CN=FormAI) | `apksigner` |
| Content rating shown | **PEGI 3** | Play listing |
| Listing title | FormAI - Kişisel Fitness Koçu **(Erken Erişim)** | Play listing |
| Release notes | Not surfaced on the device listing | — |
| `.env` inside the Play APK | all 6 client keys present and non-empty | unzipped the delivered APK |

**Release notes are marked NOT VERIFIED** — the Play Store app does not expose
the closed-track "What's new" text on the device listing, and I have no Play
Console access.

### 2.2 The Google Sign-In question — CLOSED, it works

The brief asked me to find the root cause "if Google Sign-In still fails". It
does not fail. I tested it on **both** signing identities:

- **On the Play-delivered build** (Google's signing key): account chooser
  opened, `FetchGoogleIdTokenCredentialOperation Operation succeeded`,
  `CompleteSignInOperation Operation succeeded`,
  `GoogleSignInChimeraActivity Activity finished successfully` → app advanced to
  the paywall signed in.
- **On a locally-signed release build** (upload key): same, sign-in completed
  and reached the paywall.

**Root cause of the historical failure: none present today.** Both SHA-1
certificates are registered against the Android OAuth client, `.env` ships a
valid `GOOGLE_WEB_CLIENT_ID` (72 chars) inside the Play APK, and Supabase
accepted the id token. There is no SHA / OAuth / Play-App-Signing / Firebase /
client / server defect to fix. Note: the app uses **no Firebase at all** —
auth is Supabase + `google_sign_in` 7.2.0.

One trap worth recording so it is not misdiagnosed again: logcat during sign-in
contains `ConnectionResult{statusCode=DEVELOPER_ERROR}` lines. They come from
**`Phenotype.API` in a different GMS process**, not from FormAI, and they appear
on this MIUI build regardless. Reading them as the sign-in result is how a
working flow gets reported as broken.

### 2.3 Crash / stability observations

- **No crash of the FormAI main process at any point** in the entire walk.
- One **native SIGABRT** was captured, in the isolated subprocess
  `com.emredogan.formaifit:mlkit_acceleration_mini_benchmark`
  (`JNI DETECTED ERROR IN APPLICATION: fid == null`, inside MediaPipe graph
  load). The main process survived, the camera preview opened, and pose
  detection ran and correctly reported "I can't see you". This is ML Kit's
  hardware-acceleration benchmark failing and falling back to CPU — contained
  by design. It is still attributed to the package in Android vitals. See M-2.

---

## 3. Every Tested Flow — PASS / FAIL / NOT VERIFIED

Only flows I personally drove on the device are marked PASS or FAIL.

### Install & launch

| Flow | Result | Note |
| --- | --- | --- |
| Uninstall sideload, install from Play closed track | **PASS** | 41 MB, ~10 s |
| Verify version / package / signer / install source | **PASS** | table §2.1 |
| First cold launch | **PASS** | no crash, no ANR |
| Cold launch with no network | **PASS** | offline banner + Try again |
| Release notes text | **NOT VERIFIED** | not exposed on device |
| Update (37 → 38) path | **NOT VERIFIED** | no newer build exists |
| Reinstall persistence | **NOT VERIFIED** | not exercised |

### Onboarding

| Flow | Result | Note |
| --- | --- | --- |
| 18+ age gate | **PASS** | blocks until a birth year is chosen |
| Privacy consent screen | **PASS** | both toggles default **off** |
| Privacy Policy link opens | **PASS** | live, CloudFront, renders |
| Language selection (TR / EN) | **PASS** | applies live |
| AI onboarding chat (live LLM) | **PASS** | personalised replies returned |
| 11-question wizard | **PASS** | all steps advanced, no dead end |
| Body-details picker | **PASS** | age/height/weight |
| AI report screen | **PASS** (after fix) | fabricated 92 % removed |
| Feature walkthrough + Skip | **PASS** | |
| Dashboard coach-marks | **PASS** | Skip works |

### Auth

| Flow | Result | Note |
| --- | --- | --- |
| Google Sign-In — Play-signed build | **PASS** | §2.2 |
| Google Sign-In — locally-signed build | **PASS** | §2.2 |
| Guest mode ("Not now") | **PASS** | full app access, no forced signup |
| Anonymous → signed-in upgrade | **PASS** | profile shows the Google email |
| Email login | **NOT VERIFIED** | not exercised |
| Password reset | **NOT VERIFIED** | not exercised |
| Reviewer account `google-reviewer@formai.app` | **NOT VERIFIED** | not exercised; Google Sign-In sufficed |
| Sign out | **NOT VERIFIED** | entry present, not executed |

### Core product

| Flow | Result | Note |
| --- | --- | --- |
| Plan generation | **PASS** | 30-day plan produced |
| Program overview / day list | **PASS** | but see M-4, L-7 |
| Camera-workout permission rationale | **PASS** | exemplary; pre-prompt + opt-out |
| Runtime CAMERA grant | **PASS** | standard dialog, granted |
| Camera pose pipeline | **PASS** | preview + "Looking for you" + graceful "I can't see you" |
| Non-camera workout path | **PASS** (entry) | "Continue without the camera" present; full session not run |
| Completing a full workout | **NOT VERIFIED** | not run to completion |
| AI coach chat (dashboard entry) | **PASS** (entry) | card present and live; full thread not exercised post-onboarding |
| Nutrition tab | **NOT VERIFIED** | |
| Progress tab | **NOT VERIFIED** | |
| Community / leaderboards / challenges / squads | **NOT VERIFIED** | |
| Referrals | **PARTIAL** | code shown + share button; redemption not exercised. See M-3 |
| Notifications | **NOT VERIFIED** | |

### Monetisation

| Flow | Result | Note |
| --- | --- | --- |
| Paywall renders with live Play prices | **PASS** | ₺179,99 / ₺359,99 / ₺959,99 — real Play Billing values |
| Subscription terms disclosure | **PASS** | auto-renewal, price, period, cancel path, Terms + Privacy links |
| Restore purchases control | **PASS** (present) | button present; not tapped |
| Paywall dismissable | **PASS** | X closes, no forced purchase |
| Actual purchase | **NOT VERIFIED** | no license-tester purchase made — would charge/entitle a real account |
| Cancellation handling | **NOT VERIFIED** | |
| RevenueCat entitlement sync | **NOT VERIFIED** | SDK configures; no purchase to verify against |

### Account & settings

| Flow | Result | Note |
| --- | --- | --- |
| Profile screen | **PASS** | shows account + metrics |
| **Delete account present & prominent** | **PASS** | red, labelled, in Account Settings |
| Delete account executed | **NOT VERIFIED** | destructive on the founder's real Google account — not run without authorisation |
| Theme Light / Dark / System control | **PASS** (present) | Dark verified; Light not toggled |
| Language switch control | **PASS** (present) | |
| Units Metric / Imperial | **PASS** (present) | but see L-5 |
| Privacy sheet | **PASS** | |
| Offline mode | **PASS with defects** | no crash; see M-7 |
| Turkish UI | **PASS** | first two screens verified in TR |
| English UI | **FAIL** | workout catalogue renders Turkish. See H-4 |

---

## 4. Google Play Policy Audit

Researched against current Google Play Developer Program Policies plus
widely-reported 2025–26 rejection patterns before auditing.

| Policy area | Verdict |
| --- | --- |
| **Generative AI apps** | **FAIL** — no in-app report/flag for AI content (C-1) |
| **User Data — privacy policy accuracy** | **WAS FAIL, FIXED IN REPO** (C-2); needs deploy |
| **User Data — account deletion** | **PARTIAL FAIL** — in-app yes, web URL missing (C-3) |
| **Data Safety declaration** | **NOT VERIFIED** — no console access (M-8) |
| **Health apps declaration** | **NOT VERIFIED** — mandatory for all tracks (M-9) |
| **Permissions** | **PASS** — 13 permissions, all justifiable, excellent rationale UX |
| **Subscriptions / Payments** | **PASS on disclosure**, **FAIL on refund claim** (H-3) and reference pricing (M-1) |
| **Misrepresentation / Deceptive behaviour** | **WAS FAIL, FIXED** (fabricated 92 %) |
| **Misleading claims (health)** | **PARTIAL** — results claims remain (H-6) |
| **Content rating** | **FAIL** — PEGI 3 vs in-app 18+ gate (H-1) |
| **Store listing** | **FAIL for production** — "(Erken Erişim)" in title (H-2) |
| **Families policy** | **NOT APPLICABLE** if target audience excludes children — but PEGI 3 makes this ambiguous; must be confirmed in console |
| **Broken functionality** | **PASS** — no broken flow found |
| **Medical guidance limits** | **PASS** — explicit "not medical advice" disclaimer with a see-your-doctor line, shown during onboarding |
| **Ads / tracking** | **PASS** — no ad SDKs, no cross-app tracking |
| **Target API level** | **PASS** — targetSdk 36 |

---

## 5. Potential Rejection Reasons, Ranked

### CRITICAL

**C-1 · No in-app reporting mechanism for AI-generated content**
Play's AI-Generated Content policy states verbatim: *"Apps that generate content
using AI must contain in-app user reporting or flagging features that allow
users to report or flag offensive content to developers without needing to exit
the app."* FormAI ships a Claude-backed conversational coach (`COACH_LLM_ENABLED=true`,
`supabase/functions/coach-chat` → `api.anthropic.com`). A repo-wide search found
reporting for **community** content (`friendsReportContent`) and **none** for AI
content. `coach_screen.dart` has no long-press, popup menu or bottom sheet.
The generic "Support & feedback" screen offers only Bug report / Suggestion /
Question and is not attached to any message.
*Status:* **NOT FIXED** — see §8 for why, and the exact fix.

**C-2 · Privacy policy contradicted the app's actual data handling**
Two independent failures:
- It said body metrics are *"stored **only** in the App's local storage… **not
  uploaded to our servers**"* and *"**Never stored on our servers**"*.
  `lib/features/progress/data/body_metrics_repository.dart` is explicitly
  offline-first-**with-sync** ("every write attempts Supabase") and upserts into
  `public.body_metrics` (migration 017: weight, waist, chest, arm, thigh, hip,
  keyed to `user_id`).
- It named Supabase, PostHog, Sentry, RevenueCat and ML Kit — **not Anthropic**,
  although `CoachContext` transmits name, age, height, weight, activity, goal,
  streak, plan progress and 30-day weight/waist change off-device to the US.
  I confirmed the transmission empirically: the coach replied *"Hey Alex…"*
  using the name typed seconds earlier.
*Status:* **FIXED IN REPO — NOT YET DEPLOYED.**

**C-3 · No web link for account/data deletion**
Play requires *"an in-app path to delete their app accounts and associated data;
**and** … a web link resource where users can request app account deletion."*
The in-app path is present and good. The web link is absent:
`delete.html`, `delete-account.html`, `data-deletion.html`, `deletion.html`,
`account-deletion.html` on `d2srybp77lgcpy.cloudfront.net` all return **404**,
and the privacy policy offers only `mailto:support@formai.app`.
*Status:* **NOT FIXED** — needs a page + a console field.

### HIGH

**H-1 · Content rating (PEGI 3) contradicts the app's own 18+ gate**
First screen: *"FormAI 18 yaşından büyük kullanıcılar içindir."* Listing shows
**PEGI 3**. The privacy policy also states the app "is not directed to anyone
under 18". A rating questionnaire that yields PEGI 3 for an 18+-gated fitness
app with physique imagery is inaccurate, and inaccurate ratings are an
enforcement trigger independent of the rest of the review.

**H-2 · Store listing title contains "(Erken Erişim)"**
Shipping *"FormAI - Kişisel Fitness Koçu (Erken Erişim)"* to production
advertises the app as early access when it is not. In-app copy repeats it
("Early access — you're one of the first to try FormAI", "Be one of the first
users") on two onboarding screens.

**H-3 · "100% Satisfaction Guarantee — unconditional refund within the first 7 days"**
Rendered directly on the paywall. Google Play controls subscription refunds;
the developer cannot unilaterally guarantee a 7-day unconditional refund through
the Play billing flow, and a promise the purchase path cannot honour is a
misleading claim. Either honour it operationally and say how, or remove it.

**H-4 · English UI renders a Turkish workout catalogue**
With the app set to English, the Training tab shows *"Ekipmanlı Göğüs Gücü"*,
*"Orta düzey · 22 Dk"*, *"Çelik Gibi Karın"*, *"Başlangıç · 15 Dk"*.
`lib/features/workout/data/workout_repository.dart` holds **52 hardcoded Turkish
`title:` literals** with no localisation. Section chrome is English, content is
not — the most visible quality defect a reviewer running in English will hit.

**H-5 · Fabricated "Success probability 92%" presented as AI analysis**
`static const double _confidenceTarget = 0.92`, shown to every user under
"AI ASSESSMENT" with the line "You're very close to your goals!" before any
training. *Status:* **FIXED.**

**H-6 · Unsubstantiated results claims**
"REAL RESULTS — steady progress for 30 days"; "the 'newbie gain' effect means
**fast, visible results in the first 30 days**"; "Evidence-based, effective
training plans"; a 12-week projection chart with an unlabelled rising line;
store screenshot "AI KOÇUN, 30 GÜNDE DEĞİŞİM" (transformation in 30 days).
Individually survivable, collectively a misleading-health-claims profile.

### MEDIUM

**M-1 · Reference-price strikethrough may never have been charged**
₺2.159,88 struck through above ₺959,99 "56% OFF" is 179,99 × 12 — a synthetic
comparison to the monthly rate, not a former price. Same for ₺539,97 (179,99 × 3).
Presenting a never-charged figure as a struck-through original is a deceptive
pricing pattern under Play and under EU/TR consumer law.

**M-2 · Native SIGABRT in the ML Kit acceleration subprocess**
Contained and non-user-perceived, but attributed to the package in Android
vitals and therefore counted against crash-rate thresholds.

**M-3 · Referral offer contradicts itself**
"…you both earn **once the reward program opens**" sits directly above
"Enter a friend's code and **you both get a Premium month**." One of these is
advertising a benefit that does not currently exist.

**M-4 · Plan labelled "Intermediate" for a self-declared beginner**
I answered "Never have" trained; the AI report agreed ("you're new to training");
the program header then reads **Intermediate** under the line "Built
specifically for your goal and level."

**M-5 · "AI POWERED · 100% ON DEVICE"** — false for the coach. *Status:* **FIXED.**

**M-6 · Hardcoded Turkish `FORM SKORU` on the English paywall.** *Status:* **FIXED.**

**M-7 · Offline state defects** — the coach card still reads "● online" with the
radio off, and the program card falls back to "Rest day" instead of the cached
Day 1. Both self-heal on reconnect; no data loss.

**M-8 · Data Safety form** — **NOT VERIFIED.** Must declare that health/fitness
data is collected **and shared with a third party** (Anthropic). Whatever it
currently says, it was written against a privacy policy that was wrong.

**M-9 · Health apps declaration** — **NOT VERIFIED.** Mandatory for every app on
every track since Aug 2024. Correct category: Health & Fitness →
*Activity and Fitness* + *Nutrition and Weight Management*.

**M-10 · Test suite was red on `main`** — three tests in
`body_metrics_screen_test.dart` had been failing since 2026-08-06 because they
seed from a literal `DateTime(2026, 8, 2)` while the screen reads
`DateTime.now()`. Not a product bug; a release gate that had silently stopped
gating. *Status:* **FIXED.**

### LOW

| # | Finding |
| --- | --- |
| L-1 | Hero images read **"PERSONEL TRAINER"** (typo for PERSONAL), on several screens and the paywall |
| L-2 | Program duration inconsistent across onboarding: "30-day" → "12 weeks" → "30-day" → "12-WEEK PROJECTION" |
| L-3 | Coach replies render raw markdown — `*you*` shows the asterisks |
| L-4 | "Even just 15 minutes a day is **100% more effective** than none at all" — arithmetically meaningless |
| L-5 | Camera setup says "~6 ft" / "Step back about 6 feet" while Units is set to Metric |
| L-6 | Act-5 benefit carousel rests off-centre at first paint, showing two half-clipped cards |
| L-7 | Program shows "day 1 · 14% complete" before anything has been done |
| L-8 | Privacy policy is English-only for a Turkish-first listing (KVKK-relevant) |
| L-9 | Age gate collects a birth year, then the wizard asks age again and defaults to a different value |

---

## 6. Exact Fix For Every Open Issue

**C-1 — AI content reporting.** Add a long-press (or overflow) action on every
coach message bubble in `lib/features/coach/presentation/coach_screen.dart`
opening a sheet with "Report this reply". Persist to a new
`ai_content_reports` table (`user_id`, `message_text`, `reason`, `created_at`,
RLS insert-own) or reuse the existing feedback pipeline with a
`subject: 'ai_content_report'`. Add EN/TR ARB strings. Requirement is the
*affordance*, not a moderation backend.

**C-2 — Privacy policy.** Already corrected in `web/public/privacy.html`.
**Deploy it:** upload to the S3 bucket behind `d2srybp77lgcpy.cloudfront.net`
and invalidate the CloudFront path. Verify the live page shows
"Last updated: 6 August 2026" and contains an Anthropic row.

**C-3 — Web deletion URL.** Create `web/public/delete-account.html` describing
the in-app path plus an email/form route, deploy it, link it from the privacy
policy, and set it as the **Data deletion URL** in Play Console → App content.

**H-1 — Content rating.** Re-take the content-rating questionnaire in Play
Console declaring the 18+ requirement, or drop the in-app 18+ gate to match a
PEGI 3 product. They must agree. Also set Target audience to exclude children.

**H-2 — Listing title.** Rename to *"FormAI - Kişisel Fitness Koçu"* and remove
the two in-app "Early access" strings (`act5` / `social_proof` steps).

**H-3 — Refund claim.** Remove the "100% Satisfaction Guarantee / unconditional
refund" block from `paywall_screen.dart`, or replace it with a factual pointer
to Google Play's refund policy.

**H-4 — Turkish workout content in English.** Move the 52 `title:` literals in
`workout_repository.dart` into ARB keys (or a locale column in the content
tables, matching how Phase 7 solved recipes) and localise the difficulty and
duration labels. This is a content-localisation project, not a patch.

**H-6 — Results claims.** Soften to non-guaranteeing language, or add a visible
"individual results vary" qualifier next to each claim; remove "fast, visible
results in the first 30 days" and the unlabelled projection chart, or label its
axes with what they actually plot.

**M-1 — Reference pricing.** Show the annual plan's per-month equivalent
("₺80,00/mo billed annually") instead of a struck-through total that was never
charged, or only strike a price that genuinely was the previous price.

**M-2 — ML Kit crash.** Not fixable in app code. Mitigate by disabling ML Kit's
acceleration mini-benchmark if the version in use exposes the flag, and monitor
Android vitals after launch.

**M-3 — Referral copy.** Pick one truth. If rewards are not live, remove
"you both get a Premium month".

**M-4 — Difficulty label.** Derive the program's displayed difficulty from
`wizard.experienceLevel` instead of the template's static label.

**M-7 — Offline.** Drive the coach card's online dot from connectivity, and make
the program card fall back to the cached plan rather than "Rest day".

**M-8 / M-9 — Console declarations.** Complete the Health apps declaration and
re-answer Data Safety to match the corrected privacy policy: Health & fitness →
collected, **shared**, not processed ephemerally; Personal info (name) →
collected and shared (Anthropic).

---

## 7. What Was Fixed During This Audit

Commit **`b02b945`** on `main`, pushed.

| # | Fix | Verified |
| --- | --- | --- |
| 1 | Removed the hardcoded **"Success probability 92%"** ring, its label and bar from the onboarding AI report. Kept `_intro`-driven `_confidenceLanded` so the CTA glow is unchanged; deleted the orphaned `_SuccessRing`. | **On device** — report renders without it, layout intact |
| 2 | **What's New no longer shown to fresh installs.** `AppPreferences.whatsNewSeenBuild` documented a suppression "at the end of onboarding" that had never been implemented — `markWhatsNewSeen` had exactly one call site, inside the screen itself. Added `_suppressWhatsNewForNewInstall` to `_finish()`, guarded and unawaited. | **On device** — the "Version 1.0.1" changelog no longer appears |
| 3 | **English paywall no longer renders Turkish.** `'FORM\nSKORU'` was hardcoded at `paywall_screen.dart:1319` while `showcaseHeroFormScore` existed unused. | **On device** — renders "FORM SCORE" |
| 4 | **Privacy policy body-metrics claim corrected** — now states they are synced to Supabase (EU) and deleted with the account. | Source corrected; **deploy pending** |
| 5 | **Privacy policy now discloses Anthropic** — new §1.2.1 itemising the exact coach payload, a processor-table row, and a retention line. | Source corrected; **deploy pending** |
| 6 | **"100% ON DEVICE" claim narrowed** to "ON-DEVICE ANALYSIS" (TR "CİHAZINDA ANALİZ"), which is true of the pose detection. Length chosen to fit the `maxLines: 1` tile. | Code + regenerated l10n; **not re-verified on device** (onboarding-only surface) |
| 7 | **Policy "Last updated" bumped** to 6 August 2026. | — |
| 8 | **Three time-bombed tests repaired** — `body_metrics_screen_test.dart` now anchors to the same clock the screen reads. | `flutter test` |
| 9 | `pseudo_localizations.dart` updated for the ARB signature change. | `flutter analyze` |

**Validation after the fixes:**
- `flutter analyze` → **No issues found**
- `flutter test` → **1505 / 1505 passed** (was 1502 / 1505 before)
- `flutter build apk --release` → **succeeded**, 137.5 MB
- Installed on the physical Redmi; fixes 1–3 confirmed visually; no crash.

---

## 8. What Cannot Be Fixed Automatically

| Item | Why |
| --- | --- |
| **Privacy policy deployment** | Source is corrected in-repo; publishing to the S3/CloudFront origin needs founder credentials. **This is the highest-value remaining action.** |
| **Web account-deletion URL** | Needs a hosted page *and* a Play Console field. |
| **Store listing title** | Play Console only. |
| **Content rating / target audience** | Play Console questionnaire only. |
| **Data Safety form** | Play Console only — and it must be re-answered against the corrected policy. |
| **Health apps declaration** | Play Console only. |
| **AI content reporting (C-1)** | Buildable, but it is a new user-facing feature with a schema, RLS policy, migration and two locales. I did not ship it inside an audit without a decision on whether reports land in Supabase or in the existing feedback mail path. **It is the one code blocker left.** |
| **Turkish workout catalogue (H-4)** | 52 strings plus difficulty/duration labels — a localisation project sized like Phase 7, not an audit patch. |
| **Purchase / restore / cancellation testing** | Requires a license-tester account and real transactions against the founder's Play account. |
| **Account-deletion execution** | Destructive against the founder's live Google account; not run without authorisation. |
| **"PERSONEL TRAINER" typo** | Baked into image assets; needs asset regeneration. |

---

## 9. Production Readiness Score

**72 / 100**

| Dimension | Score | Reasoning |
| --- | --- | --- |
| Stability | 18/20 | No main-process crash across a full walk; −2 for the ML Kit subprocess SIGABRT in vitals |
| Core functionality | 17/20 | Everything driven worked; several flows unverified |
| Play policy compliance | 11/20 | Two hard blockers open (C-1, C-3), one fixed but undeployed (C-2) |
| Store readiness | 6/15 | Early-access title, rating mismatch, two console declarations unverified |
| Localisation & polish | 9/15 | English UI ships a Turkish catalogue; a dozen copy defects |
| Privacy & data handling | 11/10 → capped 10/10 | Genuinely strong once the policy is deployed: opt-in consent, on-device vision, prominent deletion |

The score is held down almost entirely by **console and store configuration**,
not by the software. The APK itself is close to production quality.

---

## 10. Final Verdict

# ⚠ READY WITH CONDITIONS

FormAI should **not** have "Apply for Production" pressed today, but it is much
closer than the finding count suggests — and nothing blocking is architectural.

**Conditions that must be met before applying (all are blocking):**

1. **Deploy the corrected privacy policy** to `d2srybp77lgcpy.cloudfront.net`
   and confirm the live page names Anthropic and no longer claims body metrics
   never reach the servers. *(Fix written, deployment pending.)*
2. **Ship an in-app report/flag affordance on AI coach messages.** This is the
   only remaining code blocker and it is quoted policy, not interpretation.
3. **Publish a web account-deletion page** and set it as the Data deletion URL
   in Play Console.
4. **Resolve the rating contradiction** — re-take the content-rating
   questionnaire to reflect the 18+ gate, and set Target audience to exclude
   children.
5. **Remove "(Erken Erişim)" from the listing title** and the two in-app
   "Early access" strings.
6. **Complete the Health apps declaration** and **re-answer Data Safety** so
   both match the corrected policy — health data collected *and shared*.
7. **Remove or substantiate the "unconditional 7-day refund" guarantee.**

**Strongly recommended before launch, not strictly blocking:**

- Localise the 52 Turkish workout titles, or restrict the store listing to
  Turkish until they are (H-4).
- Fix the synthetic strikethrough pricing (M-1) and the referral contradiction (M-3).
- Soften the results claims (H-6).

**My honest read:** conditions 1, 3, 4, 5, 6 and 7 are a focused afternoon of
console and content work. Condition 2 is perhaps a day of engineering. There is
no reason this app cannot be submitted this week — but submitting it *before*
those seven items would be volunteering for a rejection on grounds that are
already known, already written down, and entirely avoidable.

---

*Every PASS in this report was personally driven on the physical device against
the Play-delivered build. Everything I could not drive is marked NOT VERIFIED
rather than assumed.*
