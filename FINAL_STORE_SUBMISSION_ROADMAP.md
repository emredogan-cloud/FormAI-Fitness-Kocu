# FINAL STORE SUBMISSION ROADMAP — FormAI (Fitness Koçu)

**Date:** 2026-07-10 · **Input:** `FINAL_STORE_SUBMISSION_CHECKLIST.md` (IDs referenced throughout) · **Baseline:** `prisk/phase-1-tests` @ `a9a8f4e`, analyze 0 / 293 tests / Flutter 3.41.9 / v1.0.0+13.

**Design intent:** when every phase below is DONE, FormAI enters **Play Internal Testing → Closed Testing → (Open) → Production** and **TestFlight → App Store Review** with no further engineering phase — only review-feedback handling.

**Environment legend:** 🖥 this Linux machine · 🌐 store console / prod DB / GCP · 🍎 macOS + Xcode required · 📱 physical device · 👤 user decision/legal.

---

## CRITICAL PATH & PARALLELIZATION

```
                        ┌────────────────────────────────────────────────┐
 Phase 0 (0.5d, 🖥)  →  │ Phase 1 (2d, 🖥) → Phase 2 (1d, 🖥) ─┐          │
 security/hygiene       │ Android code fixes   RC/SDK+pipeline │          │
                        └──────────────────────────────────────┼──────────┘
                                                               ▼
        Phase 3 (1.5d, 🖥+👤) listing assets + console answer packs
                                                               ▼
        Phase 4 (🌐+📱)  PLAY: internal upload → ★ 14-DAY CLOSED-TESTING CLOCK ★
                          (the calendar critical path — start it as early as possible)
                                   ║  runs concurrently with ↓
        Phase 5 (3–5d, 🍎)  iOS build-out on macOS
                                   ▼
        Phase 6 (1–2d, 🌐🍎📱)  ASC setup + TestFlight
                                   ▼
        Phase 7 (🌐)  Production submissions + staged rollout + monitoring
```

Total engineering effort: **~9–13 working days** of active work; **calendar** floor ≈ **3–4 weeks**, dominated by the Play 14-day closed-testing gate (if the account is personal, GP1) and store review latencies. Android and iOS tracks are independent after Phase 3 — run Phase 5 during the Phase 4 testing window.

---

## PHASE 0 — Security & Repo Hygiene

- **Objective:** no live credentials on disk or in git config; repo presentable for a store-bound main branch.
- **Tasks:**
  1. Delete `formai-494015-f262599d264a.json` from disk; rotate that service account key in GCP IAM (🌐 rotation). [P13]
  2. 👤 Rotate the GitHub PAT embedded in `.git/config`; switch remote to credential helper. [LG3]
  3. Untrack `logs.txt` (git rm --cached + ignore entry); replace LICENSE (proprietary notice, correct owner); fix stale README sections (CI, 7 migrations, buckets). [R4/LG5]
  4. Decide fate of untracked June audit `.md`s (commit as `docs/archive/` or leave untracked deliberately).
- **Dependencies:** none. · **Effort:** 0.5 day 🖥 + 👤 PAT/GCP.
- **Risk:** LOW. Key rotation could break an unknown consumer of that service account — check GCP usage logs before revoking (it appears unused by the app; `.env` holds no GCP key).
- **Validation:** `git ls-files` clean of creds (already true); no `formai-*.json` on disk; gitleaks CI green; fresh clone builds.
- **Acceptance:** all four tasks done; secret-scan workflow green on push.
- **Blocking:** P13/LG3 are security-blocking (self-imposed, do-first); rest non-blocking. · **Store impact:** indirect (credible repo, safe main).

## PHASE 1 — Android Policy & Quality Code Fixes

- **Objective:** the Android build is policy-clean and visibly polished; every code-side checklist 🔧/⛔ for Android is closed.
- **Tasks (checklist IDs):**
  1. ⛔ Strip `RECORD_AUDIO` (+ `FOREGROUND_SERVICE`; optional `READ_EXTERNAL_STORAGE`) via `tools:node="remove"`; keep biometric/VIBRATE/WAKE_LOCK. Re-verify merged manifest. [A2]
  2. Backup rules: `dataExtractionRules` (+`fullBackupContent`) excluding metrics/consent keys, or `allowBackup=false`. [A7/P7]
  3. Notification small icon `ic_stat_formai` + wire FLN default & channels. [A8]
  4. Adaptive + monochrome launcher icon via flutter_launcher_icons regen. [A9]
  5. Paywall offerings-failure state: remove hardcoded ₺ fallbacks → price-less retry card; extend paywall tests. [M2]
  6. Turkish-ify 2 English auth-modal buttons [U1]; map common Supabase auth errors to TR [AC3].
  7. Unify residual cyan → brand purple in `_DeepLinkSplashScreen`/`ErrorCard`/`_PermissionCard`. [U7]
  8. Repository-level `.timeout(10s)` on Supabase reads → existing ErrorCard paths. [S2b]
  9. Global `textScaler` clamp (1.0–1.3) via `MaterialApp.builder`; overflow spot-fixes on auth/onboarding/paywall/dashboard. [U3]
  10. Visual "no person in frame" overlay on camera after N seconds of no pose. [U6]
  11. State-coverage upgrades on top screens (skeleton/ErrorCard for the worst bare spinners; pull-to-refresh where stale-prone). [U5]
  12. Semantic labels + tooltips for core journey; extend reduce-motion to remaining 7 motion primitives; fix 2 sub-48dp targets. [U4]
- **Dependencies:** Phase 0 merged (clean tree). · **Effort:** 1.5–2.5 days 🖥.
- **Risk:** MEDIUM-LOW. Each item is small; the risk is regression — mitigated by the 293-test suite + new tests for M2/A2-adjacent behavior.
- **Validation:** `dart format` · `flutter analyze` 0 · `flutter test` green (target: +8–15 new tests) · merged-manifest grep shows no RECORD_AUDIO/FOREGROUND_SERVICE · debug-build smoke on emulator.
- **Acceptance:** all 12 tasks committed (small commits, pushed per increment); analyze/tests green; screenshots of icon/notification fixes captured for L3 refresh.
- **Blocking:** task 1 is ⛔ for Play; rest are 🔧 but in-scope for "actually ready". · **Store impact:** Play Data-safety coherence; both stores' perceived quality.

## PHASE 2 — Monetization SDK & Release Pipeline

- **Objective:** the release artifact is future-proof (Billing Library 8), symbolicated, and reproducible from CI.
- **Tasks:**
  1. Upgrade `purchases_flutter` 8.1.1 → latest 9.x/10.x-compatible (BL8); read migration notes; full paywall/purchase regression via test suite. [M3]
  2. Add `--obfuscate --split-debug-info=build/symbols` to release builds; wire Sentry Dart Plugin symbol upload; upload Flutter native debug symbols to Play with each release. [S3]
  3. Enable `release.yml` Play-upload step (internal track) with keystore + `PLAY_SERVICE_ACCOUNT_JSON` secrets; keep debug-signing guard. [R2] *(Optional but recommended — manual upload acceptable for v1.)*
  4. Bump to `1.0.0+14`; build release AAB; re-run 16 KB alignment check + `--analyze-size`; install release build on device/emulator and smoke the R8-stripped paths (camera, purchase sheet, notifications). [R5/R6/A3]
  5. 👤 Change/regenerate upload-keystore passwords; back up keystore off-machine. [A4]
- **Dependencies:** Phase 1 (manifest/paywall changes must be in the artifact). · **Effort:** 1 day 🖥 (+0.5 if the RC major bump has breaking API changes).
- **Risk:** MEDIUM. RC major upgrade is the riskiest diff of the plan — isolate in its own commit; fallback = ship BL7 now (legal until Aug 31) and schedule the bump immediately post-launch. Obfuscation can break reflectionful code — R8 rules already comprehensive; smoke release build.
- **Validation:** sandbox/emulator purchase flow against a test offering (as far as possible pre-console); 293+ tests green; symbol upload visible in Sentry; AAB passes 16 KB grep.
- **Acceptance:** release AAB `1.0.0+14` built with obfuscation, 16 KB PASS, size report saved, RC SDK on BL8 (or documented deferral), CI release workflow green end-to-end.
- **Blocking:** not submission-blocking today; BL8 becomes blocking 2026-08-31. · **Store impact:** Play billing deadline immunity; readable crash reports for rollout decisions.

## PHASE 3 — Listing Assets, Legal Text & Console Answer Packs

- **Objective:** every artifact and answer the consoles will ask for exists in final form before touching the consoles.
- **Tasks:**
  1. Regenerate stale screenshots against the current UI (asosystem pipeline + `tool/format_play_store_assets.py`); keep 9-frame Play storyboard; produce the current ASC iPhone size set. [L3]
  2. Rebrand + de-claim listing copy (Play short/full desc, ASC name/subtitle/keywords/description) from the May masterplans; Turkish primary. [L4/H2]
  3. 👤 Decide the single support/DSR mailbox → update `legal_urls.dart` **or** the hosted HTML to match. [P3]
  4. Edit `web/public/privacy.html` + `terms.html`: legal-entity block [LG1], on-device body-metrics wording [P4], renewal/cancel mechanics check [LG4]; `terraform apply`. 
  5. Write the two console answer packs as `docs/store/`: Data-safety answers (GP4) and App-Privacy answers (AS5) from the P6 data inventory; IARC + age-rating (H6) draft answers; reviewer-account script + camera demo-video plan. [AC5]
  6. 👤/legal: KVKK confirmations (VERBIS need, transfer basis, DPA signatures) kicked off — they don't block Play internal testing but should close before Production. [LG2]
- **Dependencies:** Phase 1 (UI final for screenshots), P3 decision. · **Effort:** 1–1.5 days 🖥 + 👤 inputs.
- **Risk:** LOW. Main risk is screenshot/policy drift — regenerate only after Phase 1 lands.
- **Validation:** rendered screenshots reviewed against live app side-by-side; policy pages redeployed and fetchable; answer packs peer-read against P6 (no contradiction between Data safety, App Privacy, and privacy.html).
- **Acceptance:** all assets in `asosystem/play_store_ready/` + ASC set; policies live with entity + single mailbox; `docs/store/` answer packs committed.
- **Blocking:** LG1/P3 are ⛔ for submission; assets are practical prerequisites for console work. · **Store impact:** direct — this is the metadata reviewers see.

## PHASE 4 — Google Play Launch Operations ★ starts the 14-day clock ★

- **Objective:** app live in Internal then Closed testing; every Play declaration filed; prod backend verified; Android device QA passed.
- **Tasks:** GP1–GP12 in checklist §11, in order: account/testing-gate confirmation → app record → first AAB to Internal → Data safety [GP4] → Health declaration [GP5] → IARC [GP6] → audience 18+ [GP7] → App access reviewer creds [GP8] → listing [GP9] → subscriptions [GP10] → countries (TR-first, EEA per P14) [GP11] → promote to **Closed testing, recruit ≥12 testers, keep them opted-in 14 continuous days** [GP1].
- Plus: **X1** apply migrations 006+007 to prod Supabase and verify the delete round-trip + referral RPC on prod; AC4 custom SMTP; M4 RevenueCat products/entitlement `FormAI Pro` + webhook secret deploy + sandbox purchase e2e; 📱 run QA matrix Q1–Q7 (Android) on at least one physical device, triage pre-launch report.
- **Dependencies:** Phases 2–3. · **Effort:** ~1 day of active work 🌐 + **14 calendar days** gate (if personal account; org account → gate vanishes) + tester recruitment (👤: 12 real people).
- **Risk:** MEDIUM. Tester count dropping below 12 resets the clock; Data-safety mismatch is the top rejection class (answer pack mitigates); pre-launch report may surface device-specific crashes (fix-forward during the window).
- **Validation:** internal testers install from Play; closed track shows 14-day/12-tester progress; sandbox purchase → RC webhook → `pro_entitlements` row on prod; delete-account on prod leaves zero rows.
- **Acceptance:** "Apply for production" available (gate satisfied) with all declarations filed and QA matrix items Q1–Q7 signed off; zero P0 findings open from pre-launch report.
- **Blocking:** ⛔ for Play production by definition. · **Store impact:** Play-only; runs concurrently with Phase 5.

## PHASE 5 — iOS Build-Out (macOS) 🍎

- **Objective:** a signed, honest, feature-complete iOS build exists — the entire checklist §2 cleared.
- **Tasks (order matters):**
  1. Flutter/Xcode env on the mac (`flutter doctor` vs Xcode 26 gate [I10]); create `ios/Podfile` (platform 15.5/16.0 [I2]) with `permission_handler` macro block [I11]; `pod install`; first `flutter run` on simulator. [I1]
  2. 👤 Signing: team, automatic signing [I13].
  3. Wire `Runner.entitlements` (SIWA + App Group) [I3]; add `PrivacyInfo.xcprivacy` to Resources [I4].
  4. **Decision I6:** add FormAIWidget (+Live Activity) extension target (bundle id, App Group, embed) **or** descope (strip `NSSupportsLiveActivities`, gate Dart calls). Recommended: attempt target add (~½ day); descope if it fights back.
  5. Google Sign-In iOS: GCP iOS OAuth client → `GIDClientID` + reversed scheme + `GOOGLE_IOS_CLIENT_ID` in `.env` [I5]; Supabase Apple provider (Services ID + key) [AS7].
  6. Branded launch screen #0A0612 [I7]; `ITSAppUsesNonExemptEncryption=false` [I8]; `CFBundleLocalizations=[tr]` + InfoPlist.strings [I12]; `TARGETED_DEVICE_FAMILY=1` (recommended) [I9]; defensive photo-library string decision [I11].
  7. 📱 Device pass: camera+pose on a real iPhone (thermals, FPS), SIWA + Google sign-in live, local notifications, deep links, TTS Turkish voice, widget/LA if kept — QA matrix Q1–Q8 iOS column.
  8. `flutter build ipa` → upload to ASC (validates privacy manifest, SDK gate, icons).
- **Dependencies:** Phase 1 code (shared Dart), Phase 3 assets; independent of Phase 4 — run during the closed-testing window. · **Effort:** 3–5 days 🍎📱 (first-ever iOS build; buffer for pod/toolchain friction).
- **Risk:** HIGH (most unknowns of the plan): ML Kit pod vs deployment target, extension provisioning, SIWA↔Supabase config, first-build plugin surprises. Mitigation: strict task order above; descope lever I6; SIWA is the only *required* login fix (Google button may be hidden on iOS as a fallback lever [I5]).
- **Validation:** archive + upload passes ASC automated checks (no ITMS privacy/SDK errors); all Q-matrix iOS items green on a physical iPhone.
- **Acceptance:** TestFlight-ready build in ASC; `Podfile.lock` + pbxproj changes committed; every §2 checklist item ✅ or consciously descoped with code made honest.
- **Blocking:** ⛔ for the entire Apple track. · **Store impact:** Apple-only.

## PHASE 6 — App Store Connect Operations + TestFlight

- **Objective:** every ASC declaration filed; beta running via TestFlight; submission package complete.
- **Tasks:** AS1–AS13 in checklist §12: agreements/tax/banking [AS2] → app record TR-primary [AS3] → subscription group + products **attached to the first submission** [AS4] → App Privacy from answer pack [AS5] → age rating [AS6] → review info: reviewer account + camera demo video + on-device note [AS8] → export compliance [AS9] → screenshots [AS10] → EULA/privacy links [AS11] → internal TestFlight immediately; external group w/ Beta App Review for wider beta [AS12] → EEA/trader decision [AS13/P14].
- **Dependencies:** Phase 5 build uploaded; Phase 3 answer packs/assets. · **Effort:** 1–2 days 🌐 (+ ~1 day Beta App Review latency for external TF).
- **Risk:** MEDIUM. First-app friction concentrates here: banking/tax verification delays (start AS2 the moment the developer account exists — it can run during Phases 1–5), subscription-product review coupling [AS4], age-rating questionnaire surprises (🔎 items).
- **Validation:** TestFlight internal build installable; external beta approved; ASC "Prepare for Submission" shows zero missing-metadata warnings.
- **Acceptance:** submission page complete with build, subs, privacy, rating, screenshots, review notes; ≥1 week of TestFlight feedback triaged (overlap with Phase 4's window).
- **Blocking:** ⛔ for App Review. · **Store impact:** Apple-only.

## PHASE 7 — Production Submission, Rollout & Monitoring

- **Objective:** both stores submitted; controlled rollout with defined halt/rollback playbook.
- **Tasks:**
  1. **Play:** Apply for production (post-gate) → after grant, promote the tested build to Production. First publish is full-visibility; subsequent updates use staged rollout 10→20→50→100 with halt criteria: user-perceived crash > 1.09% or ANR > 0.47% (vitals bad-behavior thresholds), Sentry new-fatal spike, purchase-success collapse. Managed publishing for a chosen go-live moment.
  2. **Apple:** Submit for review with **manual release** selected; respond to reviewer questions within hours (camera demo video pre-empts the common ones); on approval, release manually after Play looks healthy (or simultaneously — 👤 choice).
  3. Monitoring live: Sentry alert rules, RC revenue/refund dashboard, Play vitals + pre-launch report on updates, ASC crashes/metrics; support mailbox monitored daily [P3].
  4. Hotfix readiness: `1.0.1+15` branch protocol — Phase 2 pipeline makes a same-day patch possible; both consoles' review-expedite paths documented.
  5. Post-launch backlog (explicitly deferred, not blockers): full i18n extraction, iPad/tablet layouts, video-analysis MVP, assetlinks.json App Links, adaptive-icon A/B, accessibility deep pass, EEA/DSA expansion, in-app updates API.
- **Dependencies:** Phases 4+6. · **Effort:** submission ~0.5 day; then review latency (Play new-app ~up to 7 days; Apple typically 24–48 h) + rollout attention.
- **Risk:** review rejection → the checklist maps each guideline to evidence; any rejection is answered with a pointed reply or a ≤1-day fix via the hotfix protocol.
- **Validation/Acceptance:** both apps **Approved**; Android at 100% rollout with vitals green for 7 days; iOS released; zero unanswered support/DSR mail; External Ledger empty.
- **Blocking:** none — this IS the ship gate. · **Store impact:** both.

---

## FINAL "READY TO SUBMIT" GATE (run top-to-bottom before each store's submit button)

1. `flutter analyze` 0 · full test suite green · version bumped, changelog line written.
2. Release artifact: obfuscated, 16 KB PASS, size report, installed-and-smoked on a physical device.
3. Merged manifest / Info.plist audited (no stray permissions/strings) — A2/I11 greps.
4. Paywall live-prices verified against console products on a device; restore works; entitlement `FormAI Pro` flips all gates.
5. Delete-account round-trip on prod; reviewer account works; demo video link valid.
6. Data safety ≡ App Privacy ≡ privacy.html ≡ actual traffic (P6 single source).
7. Policy pages live with legal entity + single mailbox; store listing URLs resolve.
8. Console checklists §11/§12 show no unfiled declaration; agreements Active.
9. Monitoring alerts firing to a checked channel; halt criteria written down.
10. External Ledger (X1, AC4, M4, LG2, P13-rotation, LG3) — all closed.

*Execution rule (unchanged from prior phases): keep the branch green per increment — format → analyze → test → commit → push. Never fabricate completion; anything impossible from this machine stays tagged 🌐/🍎/📱/👤 until genuinely verified.*
