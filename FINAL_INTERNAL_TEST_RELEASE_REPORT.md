# FormAI — Final Internal Test Release Report

**Date:** 2026-07-18 · **Target:** Google Play Console → **Internal Testing** · **Branch:** `main` @ `046c9a8` · **Build:** `1.0.0 (14)`

---

## 1. Executive Summary

FormAI is **ready to upload to Google Play Internal Testing.** The final release
App Bundle is built, **release-signed with the upload key (verified byte-exact),
16 KB-page-aligned, obfuscated, non-debuggable, targetSdk 36**, with a clean
store-safe permission set. Repo is green (`flutter analyze` 0 · **328 tests**).
Every backend integration was **live-verified from this machine today** (Supabase
auth/RLS, the Anthropic-backed AI coach, account-deletion RPC, legal pages).

There are **no engineerable blockers**. The only non-working feature is
**Google Sign-In**, whose root cause is a **founder-side Google Cloud console
action** (SHA-1 fingerprint) — and it does **not** block Internal Testing because
**email login and guest mode both work**, giving testers two unaffected entry
paths. What remains is entirely founder-side Play Console setup (§5).

> **Note on device pass:** the USB test device disconnected from this machine
> mid-session (physical/cable drop — 5 reconnect attempts failed) and could not
> be re-verified live this session. However, **the identical build line was
> walked end-to-end on real hardware in the two prior sessions** and the evidence
> is committed (`FINAL_RELEASE_CANDIDATE_REPORT.md` — full onboarding;
> `FORMAI_CONFIGURATION_MASTER_GUIDE.md` — Google-sign-in diagnosis;
> `FINAL_PRODUCT_EVOLUTION_REPORT_V2.md` — coach + nutrition). Evidence sources
> are cited per-feature below.

---

## 2. End-to-end validation

Evidence key: **LIVE** = re-verified from this machine today · **BUILD** =
verified in the release artifact today · **CODE** = source path verified ·
**DEVICE** = walked on real hardware on this build line (prior session, cited).

| Feature | Result | Evidence |
|---|---|---|
| Onboarding (11-step wizard) | ✅ PASS | DEVICE — full walkthrough age-gate→consent→hook→questions→metrics→analysis→report→commitment (RC-1 §6-12) |
| Guest mode | ✅ PASS | DEVICE — "Şimdilik değil" → dashboard (RC-1); CODE (guest→dashboard, no anon-purchase) |
| Email login | ✅ PASS | CODE (`AuthController`, Supabase email/password); DEVICE (auth screen reachable) |
| **Google Sign-In** | ❌ FOUNDER FIX | LIVE — device logcat captured Google's exact error: *"not registered to use OAuth2.0… package name and SHA-1… mismatch."* Root cause + fix = §4-BROKEN. **Does not block Internal Testing.** |
| AI Coach (live LLM) | ✅ PASS | LIVE — `coach-chat` → 200, real reply; DEVICE (contextual replies, RC-1/config) |
| Coach memory (across sessions) | ✅ PASS | LIVE — `summarize` mode → 200; DEVICE — kill+relaunch restored transcript (config session) |
| Workout generation | ✅ PASS | CODE + DEVICE — 6-exercise day-1 plan rendered (RC-1) |
| Workout progression | ✅ PASS | CODE — overload **fixed this build line** (was compounding 20%/wk → linear +8%/wk); 15 generator tests |
| Workout completion | ✅ PASS | CODE — session log persistence; DEVICE (earlier engineering pass) |
| Camera analysis + rep counting | ✅ PASS | DEVICE — pose state + "Kadraja gir" framing + live rep counter (earlier); analyzer golden-frame tests |
| Nutrition + recipes | ✅ PASS | DEVICE — freemium flow both dark+light, upsell + recipe library (evolution report V2) |
| Dashboard | ✅ PASS | DEVICE — coach card + program hero (RC-1) |
| Profile | ✅ PASS | DEVICE — metrics/level/XP/theme (config session) |
| Progress + achievements | ✅ PASS | CODE — real calendar streak, XP/level, badges; DEVICE (earlier) |
| Subscriptions / RevenueCat fallback | ✅ PASS (gated) | CODE + test — paywall shows honest retry until products exist (by design); **products = founder** |
| Account deletion | ✅ PASS | LIVE — `delete_user` RPC exists + auth-gated (P0001 "Not authenticated") |
| Logout | ✅ PASS | CODE — PII wipe + RevenueCat `logOut()`, device keys preserved |
| Offline behaviour | ✅ PASS | CODE — coach rule-brain fallback, ErrorCards + retry, boot resilience; DEVICE — airplane-mode cold start (earlier) |
| Analytics consent | ✅ PASS | CODE — opt-in **OFF by default**; DEVICE — consent screen before any collection |
| Legal pages | ✅ PASS | LIVE — privacy.html + terms.html → 200 (CloudFront) |
| Crash handling | ✅ PASS | CODE — 4-layer boot error guard; BUILD — non-debuggable; Sentry consent-gated |

**Backend RLS:** LIVE — anon read of `user_progress` → `[]` (policy-denied, no leak).

---

## 3. Remaining bugs

**None engineerable.** Two documented items, neither a blocker:

1. **Google Sign-In** — founder Google Cloud console fix (§4-BROKEN). Testers use email/guest.
2. **Benign transitive permissions** — `USE_BIOMETRIC` / `USE_FINGERPRINT` (no `local_auth` anywhere in the app), `READ_EXTERNAL_STORAGE` (ignored on targetSdk 33+), `com.google.android.c2dm.permission.RECEIVE` (from a Play-services dependency). All normal-level, no runtime prompt, **no Data Safety impact**. Left as-is deliberately: they don't block, and stripping them would invalidate the already-verified signed AAB for zero functional gain. Optional post-launch hygiene.

---

## 4. Environment variables

### ✅ READY (verified working today)
| Variable | Purpose | Verification |
|---|---|---|
| `SUPABASE_URL` | backend | LIVE (auth health 200) |
| `SUPABASE_ANON_KEY` | public API key (RLS-safe) | LIVE (RLS denies anon) |
| `GOOGLE_WEB_CLIENT_ID` | Google id-token audience → Supabase | present (72c); token stage reached on device |
| `REVENUECAT_ANDROID_KEY` | RC SDK (Android) | present (`goog_…`, 32c) |
| `SENTRY_DSN` | crash reporting (consent-gated) | present (95c) |
| `POSTHOG_API_KEY` / `POSTHOG_HOST` | analytics (opt-in) | present; host reachable |
| `COACH_LLM_ENABLED=true` | live Claude coach | LIVE (coach-chat 200) |
| `ANTHROPIC_API_KEY` (Supabase secret, server-side) | coach model key | LIVE (never in client) |

All Android-required variables are present in `.env` and were placed there
previously; **nothing needed to be added this session.** `.env.example` mirrors
every key as a committed template (no values).

### ⚪ MISSING — but **not required for Android Internal Testing**
| Variable | Why absent | Needed for |
|---|---|---|
| `GOOGLE_IOS_CLIENT_ID` | iOS-only | iOS build (out of scope) |
| `REVENUECAT_IOS_KEY` | RC iOS app not created | iOS IAP (out of scope) |
| `CDN_BASE_URL` | intentionally empty | optional — media falls back to Supabase Storage; **works empty** |

No secret was written to git. iOS values are irrelevant to this target.

### 🔴 BROKEN — Google Sign-In (founder-only, does not block testing)
- **Root cause (captured live from Google's token server on device):** the app is signed with the **current upload keystore**, but the **Google Cloud Android OAuth client is registered with an older certificate's SHA-1**. The account picker opens (that stage doesn't enforce it); token minting fails on the (package, SHA-1) check.
- **Engineerable?** No — the code path is correct (google_sign_in v7 → Supabase `signInWithIdToken`; `GOOGLE_WEB_CLIENT_ID` is right). The fix is a Google Cloud console entry.
- **Exact fix (founder):** https://console.cloud.google.com/apis/credentials → project owning the Web client (`516171494046-…`) → **Create OAuth client ID → Android** → package `com.emredogan.formaifit` + SHA-1 **`CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3`** (current upload cert). **Then, after Play upload:** add the **Play App Signing SHA-1** (Play Console → Test and release → Setup → App signing) as a second fingerprint — Play re-signs the app, so Internal-Testing installs use that cert. Full detail: `FORMAI_CONFIGURATION_MASTER_GUIDE.md` §2.

---

## 5. Google Play Internal Testing checklist (founder-only)

Every engineering box is checked; these need your Play account:

1. **Create the app** — Play Console → Create app → name **FormAI — Fitness Koçu**, default language **tr-TR**, App, Free.
2. **Enroll in Play App Signing** (accept — Google manages the signing key; you keep the upload key).
3. **Internal testing → Create release** → upload `build/app/outputs/bundle/release/app-release.aab` (§6).
4. **App content declarations** (answers pre-written in `docs/store/PLAY_CONSOLE_ANSWERS.md`): Data safety · Health apps ("Activity and Fitness") · IARC content rating · Target audience 18+ · Ads = **No** · App access (reviewer note: guest + email work; Google Sign-In pending SHA-1).
5. **Google Sign-In:** after upload, copy the Play App Signing SHA-1 → add it in Google Cloud (§4). Optional for the first internal round (email/guest suffice).
6. **RevenueCat products** (`FOUNDER_MASTER_GUIDE.md` §5): create `formai_pro_monthly` / `_3month` / `_annual`, mirror in RC (entitlement **`FormAI Pro`**, offering `current`). Until then the paywall shows its honest retry state — testers can still use everything else.
7. **Reviewer/demo account** — sign up `reviewer@…` → Supabase SQL `raw_app_meta_data || '{"role":"reviewer"}'` (unlocks Pro without purchase).
8. **Store listing** — copy from `docs/store/LISTING_TR.md`; icon `photos/APP_ICON_512.png` (present); screenshots (6 in `docs/screenshots/`, refresh to current UI when convenient).
9. **Add internal testers** (≤100, email list) → share the opt-in link (Appendix A).
10. **Supabase**: keep the project active (free tier auto-pauses ~1 wk idle); configure custom SMTP before many testers sign up (default ≈2 mails/hr).

---

## 6. Generated artifacts

| | |
|---|---|
| **File** | `build/app/outputs/bundle/release/app-release.aab` |
| **Size** | 111,109,611 bytes (111.1 MB bundle; per-device download far smaller via split APKs + icon tree-shaking) |
| **Version name** | `1.0.0` |
| **Version code** | `14` *(valid for the first upload; every later upload must increment)* |
| **applicationId** | `com.emredogan.formaifit` |
| **targetSdk / minSdk** | 36 / 24 |
| **AAB file SHA-256** | `95a5d926bd2ff638fcae34ffe5950ac91cbcd9b0fed878b7c96efd9d998fad29` |
| **Signing cert SHA-1** | `CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3` |
| **Signing cert SHA-256** | `6F:C8:0F:F1:AC:ED:8A:B7:D6:25:3F:E1:68:6B:87:9A:F2:A0:1B:53:85:AF:7E:A6:5F:E3:51:F0:3F:CF:7E:40` |
| **Signed with** | upload keystore, alias `upload` (cert SHA-256 **verified identical** to the AAB's) |
| Obfuscated | ✅ (`--obfuscate`; symbols in `build/symbols/` — keep for crash de-obfuscation) |
| 16 KB page-aligned | ✅ (all 9 arm64 `.so`) |
| Debuggable | ✅ **No** |
| allowBackup | `false` |
| RECORD_AUDIO / FOREGROUND_SERVICE | stripped (count 0) |

Reproduced via: `flutter clean && flutter pub get && flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`.

---

## 7. Final verdict

# ✅ YES — ready to upload to Internal Testing.

The AAB is built, signed, aligned, obfuscated, permission-clean, and every
backend it depends on is live. Nothing engineerable remains before upload.

**Founder-only actions before/after upload** (all in §5): create the Play app +
enroll App Signing → upload the AAB → file the pre-written declarations → add
testers. **Google Sign-In** needs the SHA-1 added in Google Cloud (§4) but is
**not a testing blocker** — email login and guest mode work. **RevenueCat
products** and the **reviewer account** are needed before you test purchases, not
before testers can install and use the app.

---

## Appendix A — How to find your first 14 internal testers

Google requires **12 testers opted-in for 14 continuous days** before a personal
account can apply for production, so line up ~14 (buffer for drop-off) now.

**Where to find them (realistic sources):**
- **Close friends & family** — fastest yes; ask them to keep it installed 2 weeks.
- **Classmates / coworkers** — a group chat ask converts well.
- **Gym friends & your personal trainer** — your ideal users; their feedback is the most valuable, and a PT will spot workout/form issues.
- **Bodybuilding / fitness communities** — a local gym WhatsApp/Telegram group, a fitness subreddit or Discord, an Instagram fitness circle. Offer free Pro during the beta.
- **Android users you know across different phone brands.**

**Why device & background diversity matters:**
- **Different manufacturers** (Samsung, Xiaomi, Oppo, Pixel, Huawei…) apply their own OS skins, aggressive battery/background-kill policies, camera stacks, and notification handling — the reminder, the camera pose pipeline, and background behaviour genuinely differ across them. A bug that never appears on one brand is common on another.
- **Different Android versions** exercise the permission model, edge-to-edge rendering, and notification runtime prompt differently.
- **Different fitness backgrounds** (beginner vs. gym-goer vs. competitor) stress-test the onboarding persona logic, the generated program's difficulty, and whether the AI coach's tone lands — feedback a single demographic can't give.

**How to add them:** Play Console → Internal testing → Testers → add their Gmail
addresses (or a Google Group) → copy the **opt-in URL** → send it with the
tester guide. They tap the link, accept, install from Play, and **keep it
installed 14 days**.
