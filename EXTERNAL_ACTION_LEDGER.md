# EXTERNAL ACTION LEDGER — FormAI store submission

**Date:** 2026-07-10 · **State:** every engineering task executable on this
Linux machine is DONE (commits `811aae5..9a198b3` on `prisk/phase-1-tests`,
all pushed; analyze 0 · 293/293 tests · release AAB `1.0.0+14` built,
obfuscated, 16 KB-verified, release-signed). What remains is listed here —
each item names WHAT, WHY, WHO, and WHEN IT BLOCKS. Companion execution
detail lives in `FINAL_STORE_SUBMISSION_ROADMAP.md`, `docs/store/*`.

Legend: 👤 founder decision/action · 🌐 console/web account · 🍎 macOS+Xcode ·
📱 physical device · ⚖️ legal counsel

---

## 0. ⛔ CRITICAL PRECONDITION — the Supabase project is PAUSED (🌐 founder, ~2 min)

Discovered during the 2026-07-11 on-device E2E pass: the FormAI Supabase
project (`xtvqhnjamwvmfcsahzxv`) reports **status INACTIVE** in
`supabase projects list`, and its `xtvqhnjamwvmfcsahzxv.supabase.co` host
**does not resolve from anywhere** (this machine, the physical device, and
public DoH resolvers all return NXDOMAIN). Free-tier Supabase projects
auto-pause after ~1 week of inactivity and take their API subdomain offline.

**Consequence:** the app hard-requires a Supabase session (the router forces
`/auth` when `session == null`). With the backend paused, **nobody — reviewer,
tester, or user — can get past the login screen.** On-device, guest sign-in
correctly failed with the honest Turkish toast ("Giriş başarısız oldu.") and
did not crash, but the app is unusable beyond auth.

**Action (founder):** open the Supabase dashboard → FormAI project → **Restore/
Resume**. Then, because free-tier re-pauses, either keep it active (a nightly
ping / any traffic) or move to the Pro tier before public launch. This gates
**every** server flow (login, signup, catalogue→plan, purchases, deletion) and
therefore gates the entire C/E/F sections below and the device QA in G.

This is the single highest-priority external action. Everything server-side
was verified impossible-to-test today purely because of it.

---

## A. SECURITY — do first (not store-blocking, but urgent)

| # | Action | Detail | Blocks |
|---|---|---|---|
| A1 👤 | **Rotate the GCP service-account key** | The key file was moved off the repo to `~/.formai_secrets_quarantine/formai-494015-f262599d264a.json`. In GCP Console → IAM → Service Accounts → keys: delete/rotate it, then shred the quarantined file. Check usage logs first — nothing in the app consumes it. | Nothing downstream; do immediately. |
| A2 👤 | **Rotate the GitHub PAT** embedded in `.git/config` remote URL; switch to a credential helper. Then **merge `prisk/phase-1-tests` → `main`**. | PAT is plaintext on disk; merge makes `main` the store-build branch. | Store builds should cut from main; CI PR flow. |
| A3 👤 | **Change upload-keystore passwords** (currently `formai123`) via `keytool`, back the `.jks` up off-machine, and update `android/key.properties` (+ CI secrets in D1). | Weak dev-grade password on the key that signs every Play upload. | Before the keystore becomes load-bearing (first Play upload). |

## B. FOUNDER DECISIONS (blocking console work)

| # | Action | Detail | Blocks |
|---|---|---|---|
| B1 👤 | **Pick ONE support/DSR mailbox** | `support@formai.app` (in-app, `lib/core/utils/legal_urls.dart:25`) vs `formaisupport@proton.me` (hosted policies ×4 sites). Update the losing surface: either the one Dart constant, or the mailto links in `web/public/privacy.html` + `terms.html`. Must be a mailbox checked at least every few days (30-day GDPR/KVKK response clock). | Console support-email fields; policy coherence at review. |
| B2 👤 | **Legal-entity block on policy pages** | Add to `web/public/privacy.html` (top, "Data Controller / Veri Sorumlusu") and `terms.html`: legal name (sole proprietor or company), registered address, contact email (=B1). KVKK Art.10 requires controller identity. Then deploy: `cd terraform/legal_pages && terraform apply` (state + AWS creds already on this machine; the P4 wording fixes are committed and will deploy with it). | Submission (both stores link this policy). |
| B3 👤 | **Approve listing copy + trial decision** | Review `docs/store/LISTING_TR.md` (title/short/full/keywords); decide whether monthly/annual carry a free-trial intro offer (paywall auto-adapts either way). | Store listing entry (GP9/AS4). |
| B4 👤 | **EEA distribution decision** | Ship Turkey-first (skip EEA, no DSA trader needed) or complete trader verification in BOTH consoles (publishes name/address/email/phone on the listing). | Country selection step only. |
| B5 👤 | **Confirm exercise-media licensing** | ASC "content rights" question asks whether the app shows third-party content you have rights to. Exercise videos/images in Supabase storage + bundled webp assets must be own/licensed work. | ASC submission questionnaire. |
| B6 👤 | **Recruit ≥12 closed-test users** (family/friends/beta community) who will keep the app installed and opted-in for 14 continuous days. | Play personal-account production gate (verify in Console whether the account is personal/post-Nov-2023 — org accounts skip this). | Play production timeline (the calendar critical path). |

## C. SUPABASE PROD (🌐 — ~30 min)

| # | Action | Detail | Blocks |
|---|---|---|---|
| C1 | **Apply migrations 006 + 007 to prod** | Project `xtvqhnjamwvmfcsahzxv`. Either `supabase db push` (CLI is linked; `SUPABASE_DB_PASSWORD` in `.env.local`) or paste `supabase/migrations/006_delete_user.sql` + `007_referrals.sql` into the SQL editor. | Account deletion + referrals in production → BLOCKS first Internal-testing build that real users touch. |
| C2 | **Verify delete round-trip on prod** | Create a throwaway account in the app → Ayarlar → Hesabı Sil → confirm `auth.users` row and all cascaded tables are empty. | Data-safety form truthfulness. |
| C3 | **Custom SMTP for auth mail** | Supabase default SMTP is rate-limited (≈2/hr) — configure a real sender (e.g. Resend/Postmark/SES) + sender domain for signup/reset mails. | Closed testing at any scale (12 testers signing up will hit the limit). |
| C4 | **Auth redirect URLs** | Confirm Site URL + additional redirect URLs cover the mobile deep-link flow (password-reset back into app). | Q4 device test. |
| C5 | **Create the reviewer account** | Sign up `reviewer@<B1-domain>` in the app, then in SQL: `update auth.users set raw_app_meta_data = raw_app_meta_data || '{"role":"reviewer"}' where email='reviewer@…';` → Pro unlocks without purchase (`monetization_provider.dart` honors it). Record credentials into GP8/AS8 forms. | Play App access + ASC App Review Information. |

## D. CI SECRETS (🌐 GitHub repo settings — optional but prepared)

| # | Action | Detail | Blocks |
|---|---|---|---|
| D1 | Add release secrets | `ANDROID_KEYSTORE_BASE64` (`base64 -w0 android/app/upload-keystore.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` (=`upload`) → release.yml signs in CI. | Nothing (local signed builds work); enables tag-driven releases. |
| D2 | `PLAY_SERVICE_ACCOUNT_JSON` | Play Console → API access → service account with release permission. Activates the auto-upload-to-Internal step. | Optional automation. |
| D3 | `SENTRY_AUTH_TOKEN` + `SENTRY_ORG` + `SENTRY_PROJECT` | Activates the symbol-upload step so obfuscated crash stacks are readable. | Recommended before production rollout. |

## E. GOOGLE PLAY CONSOLE (🌐 — execute `docs/store/PLAY_CONSOLE_ANSWERS.md` top-to-bottom)

1. Confirm account type → testing-gate applicability (B6).
2. Create app (`com.emredogan.formaifit`, tr-TR), enroll Play App Signing, upload the built `build/app/outputs/bundle/release/app-release.aab` (1.0.0+14) to **Internal testing**.
3. Data safety · Health apps ("Activity and Fitness") · IARC · Target audience 18+ · Ads=No · App access (C5 creds) — all answers pre-filled in the doc.
4. Store listing: copy from `docs/store/LISTING_TR.md`; assets `photos/APP_ICON_512.png` + `asosystem/play_store_ready/*` (regenerate stale frames first — item G2).
5. Subscriptions: `formai_pro_monthly` / `formai_pro_3month` / `formai_pro_annual` (+ offers per B3); no price/trial text in benefit lines.
6. Countries per B4 → promote to **Closed testing** → start the 14-day/12-tester clock → pre-launch report triage → Apply for production.

**Blocks:** everything Play. **Start the closed-testing clock as early as possible — it is the schedule.**

## F. APPLE (🍎 + 🌐 — execute `docs/store/APP_STORE_ANSWERS.md`)

1. 🌐 **Start Paid Applications agreement (banking/tax) NOW** — it processes in days and blocks any subscription app review (AS2).
2. 🍎 macOS: `flutter doctor` vs installed Xcode (26+ SDK gate) → `flutter pub get` → `cd ios && pod install` (Podfile committed: platform 15.5, permission macros) → first build. Set the signing team.
3. 🍎 Developer portal: App ID `com.emredogan.formai` with **Sign in with Apple** + **App Groups** (`group.app.formai.shared`) capabilities (entitlements are already wired in the pbxproj); Services ID + key → **Supabase Apple provider** config.
4. 🌐 Google Cloud: iOS OAuth client → put `GIDClientID` + reversed-scheme URL type into `ios/Runner/Info.plist`, client id into `.env` `GOOGLE_IOS_CLIENT_ID` (+ CI secret). Until done, the Google button on iOS will fail — SIWA + email still work.
5. 🍎 **Widget/Live-Activity decision (I6):** add the FormAIWidget extension target in Xcode (Swift sources are complete under `ios/FormAIWidget/` + `ios/FormAILiveActivity/`; bundle id `com.emredogan.formai.FormAIWidget`, App Group, embed) — ~½ day; OR descope v1: delete the two `NSSupportsLiveActivities*` keys from Info.plist and ship without (Dart calls no-op harmlessly).
6. 🍎 Device smoke (Q-matrix iOS) → `flutter build ipa` → upload (validates privacy manifest + SDK gate + icons).
7. 🌐 ASC: app record (TR primary) → subscription group + 3 products **attached to the first submission** → App Privacy labels → age-rating questionnaire → review info (C5 creds + G3 demo video + on-device note) → export compliance (plist already declares exempt) → screenshots → TestFlight internal → external (Beta App Review) → Submit with manual release.

**Blocks:** everything Apple. Estimated 3–5 working days of 🍎 time.

## G. PHYSICAL DEVICE (📱)

**Device-QA results (2026-07-11, Xiaomi M1908C3JGG, Android 11 / API 30):**
the pre-auth surface + all of MY engineering changes were verified on real
hardware and PASS. The post-auth surface is blocked by item 0 (paused backend).

*Verified PASS on device:* first-run age gate (18+), consent (opt-in default
OFF), full 11-step onboarding wizard (name chat, feelings multi-select, pain
point, activity, body metrics, interludes, plan generation, AI report, honest
social proof, equipment), auth screen platform gating (no Apple button on
Android ✓), client-side validation (Turkish errors + red borders), honest
Turkish error handling on backend-down (AC3, live), **font-scale 1.3 no
overflow (U3 clamp)**, **rotation stays portrait under OS-forced landscape**,
**reduce-motion renders cinematic scenes instantly + preserves onComplete
CTA gating (U4)**, **airplane-mode cold start degrades gracefully — no black
screen / crash / infinite spinner (boot resilience)**, SharedPreferences
state persistence across force-stop, zero crashes/ANRs throughout.

| # | Action | Detail | Blocks |
|---|---|---|---|
| G1 | **QA matrix Q1–Q8 — SERVER-DEPENDENT REMAINDER** (`FINAL_STORE_SUBMISSION_CHECKLIST.md` §14) | Blocked by item 0 until the backend is resumed: login/signup/reset, dashboard, **camera + pose + workout flow** (session-gated; ML is on-device but entry needs a plan from Supabase), nutrition, progress, achievements, sandbox purchase→restore→cancel, prod delete round-trip, 19:00 reminder + reboot, notifications. Non-server device tests already PASS (see above). | Track promotions. |
| G1b | **Android 15/16 edge-to-edge sweep** | The test device is API 30, so the targetSdk-35+ edge-to-edge enforcement can't be exercised on it. Needs an Android 15/16 device or an API-35 emulator. Everything else in the sweep (dark/light, font-scale 1.3) passed on API 30. | Not blocking (Flutter handles insets by default); verify before public rollout. |
| G2 | **Regenerate stale screenshots** from the CURRENT UI | The 9 Play frames + ASC renders in `asosystem/` are May-era (pre-honesty-pass UI). Needs the backend up (item 0) to stage real dashboard/workout/nutrition content, then re-render via asosystem + `python3 tool/format_play_store_assets.py`. The 2026-07-11 device screenshots of onboarding/auth are current and usable as reference. Metadata policy requires screenshots to match the shipping app. | Store listing upload. |
| G3 | **Record the reviewer demo video** (60–90 s) | Script in `docs/store/APP_STORE_ANSWERS.md` §6: dashboard → workout start → camera permission → live rep counting + voice → complete. Needs the backend up (item 0) to reach the workout. Host at an unlisted URL. | ASC review notes (pre-empts camera-app 2.1 questions); also useful for Play App access notes. |

## H. LEGAL (⚖️ — confirm before PRODUCTION, not before testing tracks)

| # | Action | Detail |
|---|---|---|
| H1 | KVKK: VERBIS applicability for the chosen entity (solo dev below employee/balance-sheet thresholds is typically exempt — confirm against current guidance); document the assessment. |
| H2 | KVKK Art.9 cross-border basis: DPAs/SCC-equivalents with Supabase (EU), Sentry (EU), PostHog, RevenueCat (US); keep signed copies. Policy §9 already describes the mechanism. |
| H3 | Position memo: workout-completion records treated as activity metadata, not özel nitelikli health data (body metrics never leave the device — architecture minimizes exposure). |

## I. EXPLICITLY DEFERRED ENGINEERING (post-launch backlog — NOT blockers)

- U5 leftovers: ~30 bare spinners → skeletons, more pull-to-refresh surfaces (needs per-screen visual verification on device).
- Monochrome (Android 13 themed) icon layer — auto-deriving a silhouette from the photographic icon art would look bad; needs a designed glyph.
- `com.google.android.c2dm.permission.RECEIVE` in the merged manifest (from a Play-services library; benign, not store-sensitive) — provenance cleanup someday.
- Full i18n extraction (~1,316 strings), iPad layouts, `assetlinks.json` App Links, video-analysis MVP, in-app updates API, preview videos, accessibility deep pass beyond the core journey.

---

### Ready-to-run gate (repeat before each store's submit)
`FINAL_STORE_SUBMISSION_ROADMAP.md` → "FINAL READY-TO-SUBMIT GATE" (10 checks).
Code-side they pass today: analyze 0 · 293/293 · signed 16 KB-clean AAB ·
merged manifest lean · policy/console packs consistent with verified data
flows. The remaining gate items map 1:1 to the ledger rows above.
