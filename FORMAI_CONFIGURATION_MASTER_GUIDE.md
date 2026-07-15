# FormAI — Configuration Master Guide

**Date:** 2026-07-15 · The definitive reference for every environment variable, secret, key, and external integration. Everything below marked ✅ was **live-verified from this machine today** — not assumed.

## 0. Verification snapshot (2026-07-15)

| Integration | Status | Evidence |
|---|---|---|
| Supabase REST API | ✅ | root probe 401-with-key = API alive & keyed |
| Supabase Auth (GoTrue v2.193) | ✅ | `/auth/v1/health` healthy |
| Supabase RLS | ✅ | anon read of `user_progress` → `[]` (policy-denied, no leak) |
| Edge Function `coach-chat` + **Anthropic** | ✅ | live call → `{"reply":"Merhaba! 👋"}` (auth, key, endpoint, timeout, fallback all exercised) |
| CloudFront legal pages | ✅ | privacy.html 200 · terms.html 200 |
| OpenAI key (`.env.local`) | ✅ | `/v1/models` → 200 |
| PostHog host | ✅ | `us.posthog.com` reachable |
| AWS CLI + Terraform state | ✅ | `terraform state list` → CloudFront + S3 resources |
| Android upload signing | ✅ | keystore opens; APK cert digest == keystore digest |
| **Google Sign-In** | ❌ **founder fix** | §2 — root cause captured verbatim from Google's server |
| RevenueCat | ⏳ by design | key present; paywall shows honest retry until products exist (founder creates products) |
| Sentry | ✅ config | DSN present, consent-gated init; symbol upload = optional CI secret |
| Firebase / OneSignal / Cloudflare / Vercel / dart-define | — | **NOT USED anywhere** (verified: no google-services.json, no plugin, no `String.fromEnvironment`) |

---

## 1. Where configuration lives (the model)

```
.env            → bundled INTO the APK/IPA as a Flutter asset. CLIENT-PUBLIC values only.
.env.local      → ops-only, gitignored, NEVER bundled (not in pubspec assets). CLI secrets live here.
.env.example    → committed template (names + comments, no values).
Supabase secrets→ server-side (Edge Functions): ANTHROPIC_API_KEY etc. Never touch the client.
GitHub Secrets  → release.yml signing/store steps (all optional; workflow skips when absent).
Codemagic vars  → iOS pipeline (group `formai_ios_env`) + ASC key integration.
key.properties  → android/key.properties (gitignored) → upload-keystore.jks (gitignored).
```

**The guard:** `tool/check_env_no_secrets.sh` runs in CI and at build; it FAILS the build if `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `*_API_SECRET` ever appear in `.env`/`.env.example`. The bundled `.env` can only ever hold publishable values.

---

## 2. 🔴 Google Sign-In — root cause + exact fix

**Symptom:** account picker opens, you pick an account, sign-in fails.
**Live diagnosis (device logcat, 2026-07-15):**

> `[GetTokenResponseHandler] Server returned error: This android application is not registered to use OAuth2.0, please confirm the package name and SHA-1 certificate fingerprint match what you registered in Google Developer Console.`

**Why it worked before and broke:** the Google Cloud **Android OAuth client** was registered with the SHA-1 of an **older keystore**. The repo later moved to a fresh upload keystore (`android/app/upload-keystore.jks`, alias `upload` — note `.env.local` history contains two different keystore passwords). Builds are now signed with the new certificate, so Google's token server no longer matches (package, SHA-1) at the **token-minting** stage. (The picker still opens because that stage doesn't enforce it.) The Web client used as `serverClientId` is fine — the missing piece is the **Android-type client** entry.

**Fix (founder, ~5 min, Google Cloud Console):**
1. https://console.cloud.google.com/apis/credentials → select the project that owns the existing Web client (`GOOGLE_WEB_CLIENT_ID`, id starting `516171494046-…`).
2. **Create Credentials → OAuth client ID → Android** (or edit the existing Android client):
   - Package name: `com.emredogan.formaifit`
   - SHA-1: `CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3`  ← current upload keystore (verified == the installed APK's cert)
3. Add a **second Android client** (or second fingerprint) for local debug builds:
   - Same package, SHA-1: `20:AE:CA:91:98:1B:EE:12:3A:CD:0A:CE:54:9E:BA:7F:D0:A3:04:CF` (this machine's debug keystore)
4. **After enrolling in Play App Signing:** Play Console → Test and release → Setup → **App signing** → copy the **App signing key certificate SHA-1** → add it as a third fingerprint. (Without this, sign-in breaks again for Play-installed builds — the classic "broke after Play upload" trap.)
5. No app change, no rebuild needed — propagation is minutes. Retest: app → Google ile Devam Et → pick account → should land in the app signed-in.

**Configuration facts (verified in code):** `signInWithGoogle` (lib/features/auth/providers/auth_provider.dart:194) uses google_sign_in v7 (`initialize → authenticate`) with `serverClientId = GOOGLE_WEB_CLIENT_ID` → Supabase `signInWithIdToken`. The **Web client ID** must ALSO be the one configured in **Supabase → Authentication → Providers → Google** ("Authorized Client IDs"), or Supabase rejects the token's `aud` — that half is currently consistent (no AuthException reached; failure is earlier, at Google).

---

## 3. Complete variable inventory

### 3.1 `.env` — bundled, client-public (all read via `flutter_dotenv`)

| Name | Purpose / used by | Required | Status | Belongs in |
|---|---|---|---|---|
| `SUPABASE_URL` | backend URL — `main.dart` boot | ✅ | ✅ set (40c) | .env + Codemagic + release.yml secret |
| `SUPABASE_ANON_KEY` | public API key (RLS enforces safety) — boot | ✅ | ✅ set | same |
| `GOOGLE_WEB_CLIENT_ID` | `serverClientId` for Google sign-in; must match Supabase Google provider | ✅ for Google | ✅ set (72c) | same |
| `GOOGLE_IOS_CLIENT_ID` | iOS-native Google client | iOS only | ⬜ absent locally (fine on Android; set in Codemagic before iOS Google) | Codemagic |
| `CDN_BASE_URL` | optional media CDN prefix (`media_url.dart`); empty → Supabase storage | optional | empty by design | .env |
| `SENTRY_DSN` | crash ingest (consent-gated init) | optional | ✅ set (95c) | .env |
| `POSTHOG_API_KEY` / `POSTHOG_HOST` | opt-in analytics | optional | ✅ set / `https://us.posthog.com` | .env |
| `REVENUECAT_ANDROID_KEY` | RC public SDK key (Android) — `monetization_provider.dart` | ✅ for IAP | ✅ set (32c, `goog_…`) | .env |
| `REVENUECAT_IOS_KEY` | RC public SDK key (iOS, `appl_…`) | iOS IAP | ⬜ EMPTY — create iOS app in RC first | .env + Codemagic |
| `COACH_LLM_ENABLED` | `true` → coach uses live Claude via Edge Function; any failure falls back to rule brain | ✅ | ✅ `true` | .env |

All of these are **publishable** (they ship in the binary by definition). Rotation = replace value → rebuild → release.

### 3.2 `.env.local` — ops-only, gitignored, never bundled

| Name | Purpose | Verified | Rotation |
|---|---|---|---|
| `SUPABASE_DB_PASSWORD` | `supabase link/db push` CLI | ✅ used for link | Supabase → Settings → Database → Reset password |
| `OPENAI_API_KEY` | local asset generation only (never runtime) | ✅ 200 | platform.openai.com → API keys |
| `ANTHROPIC_API_KEY` | source for the Supabase secret (deployed 2026-07-13) | ✅ via coach-chat | console.anthropic.com → revoke + `supabase secrets set` |
| (file also holds founder notes: service-role key, RC dashboard creds, keystore passwords, reviewer accounts) | — | — | keep this file OFF the repo forever; it is the founder's vault |

### 3.3 Server-side (Supabase secrets — `supabase secrets set …`)

| Name | Used by | Status |
|---|---|---|
| `ANTHROPIC_API_KEY` | `coach-chat` (chat + summarize) | ✅ live |
| `COACH_MODEL` (opt) | model override (default `claude-haiku-4-5-20251001`; set `claude-sonnet-5` for better Turkish at higher cost) | unset (default) |
| `COACH_MAX_TOKENS` (opt) | reply cap (default 700) | unset |
| `REVENUECAT_WEBHOOK_SECRET` | `revenuecat-webhook` auth | set when founder deploys the webhook |
| `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_URL` | auto-provided to functions | auto |

### 3.4 GitHub Actions secrets (all OPTIONAL — steps skip when absent)

`ANDROID_KEYSTORE_BASE64` (`base64 -w0 android/app/upload-keystore.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`(=`upload`) → CI-signed releases · `PLAY_SERVICE_ACCOUNT_JSON` → auto-upload to Play Internal · `SENTRY_AUTH_TOKEN`/`SENTRY_ORG`/`SENTRY_PROJECT` → readable obfuscated stacks · plus the client-public set mirrored for release builds. Nothing is required for CI to be green (verified: all workflows green with none of them).

### 3.5 Codemagic (iOS)

Integration **`FormAI ASC API Key`** (ASC API key, App Manager role) + env group **`formai_ios_env`** = the §3.1 client-public list (+ `GOOGLE_IOS_CLIENT_ID`, `REVENUECAT_IOS_KEY` when created). `APP_STORE_APPLE_ID` (numeric) goes in `codemagic.yaml`. Full walkthrough: `docs/ios/CODEMAGIC_SETUP.md`.

### 3.6 Android signing

`android/key.properties` (gitignored): `storePassword`/`keyPassword`/`keyAlias=upload`/`storeFile=upload-keystore.jks`. Keystore: `android/app/upload-keystore.jks` (gitignored; **verified opens** and matches the shipped APK cert).
**Current cert:** SHA-1 `CF:37:A2:DE:76:F2:FA:C0:30:5D:18:D3:4C:7B:E2:D5:DB:4D:08:B3` · SHA-256 `6F:C8:0F:F1:AC:ED:8A:B7:D6:25:3F:E1:68:6B:87:9A:F2:A0:1B:53:85:AF:7E:A6:5F:E3:51:F0:3F:CF:7E:40`.
**Back the .jks up off-machine.** Losing it = Play key-reset support flow. After Play App Signing enrollment, Google's app-signing cert (different SHA-1!) signs store installs — register it per §2 step 4 and give it to RevenueCat/anything cert-pinned.

---

## 4. Integration runbooks

### 4.1 Supabase (project `xtvqhnjamwvmfcsahzxv`)
- **Console:** supabase.com/dashboard. **CLI:** logged in on this machine; `supabase link --project-ref xtvqhnjamwvmfcsahzxv` (DB password from `.env.local`).
- **Deployed objects:** migrations 001–007 tracked (history repaired 2026-07-13); functions `coach-chat` (live) + `revenuecat-webhook` (code committed; founder deploys with its secret).
- **CLI gotchas (real, hit here):** run `functions deploy` from the **repo root**; `mv .env.local` aside during deploy (CLI chokes parsing the free-text file); `--use-api` avoids Docker.
- **Auth providers:** Email ✓, Google (Web client id/secret configured — keep in sync with `GOOGLE_WEB_CLIENT_ID`), Apple (Services ID + key — do with iOS setup).
- **Ops:** free tier auto-pauses after ~1 week idle (locks ALL users out at login — happened once). Keep traffic or go Pro before launch. Custom SMTP before inviting testers (default ≈2 mails/hr).
- **Test:** `curl …/auth/v1/health` with the anon key.

### 4.2 Anthropic / AI coach (`coach-chat`)
- **Key:** console.anthropic.com → API Keys. Server-side ONLY: `supabase secrets set ANTHROPIC_API_KEY=sk-ant-…` (⚠️ strip quotes/whitespace — a stray quote caused a 401 here once; clean key length 108) → `supabase functions deploy coach-chat --use-api`.
- **Client flag:** `COACH_LLM_ENABLED=true` in `.env`. Fallback = rule brain on ANY failure (verified).
- **Tuning without app release:** persona = `PERSONA` in `supabase/functions/coach-chat/index.ts` → redeploy. Model/cost levers: `COACH_MODEL`, `COACH_MAX_TOKENS` secrets.
- **Cost:** Haiku + cacheable persona + 8-turn history + rolling memory ⇒ a few hundred tokens/turn. **Set a spend limit in the Anthropic console.**
- **Test:** the curl in §0, or `tool/coach_eval.md` scenarios.

### 4.3 Google Sign-In → §2. (No Firebase involved anywhere.)

### 4.4 Apple Sign-In (iOS)
Entitlements committed. Founder: App ID capability + Services ID + key in Apple Developer → configure in Supabase Google→Apple provider panel. Detail: `docs/ios/CODEMAGIC_SETUP.md` §5 + `FOUNDER_MASTER_GUIDE.md`.

### 4.5 RevenueCat
- **Now:** SDK integrated (purchases_flutter 10.4.1), Android key set, entitlement string **`FormAI Pro`** (exact, with space), offering `current` (monthly/threeMonth/annual → `formai_pro_monthly|_3month|_annual`). Paywall shows an honest retry state until products exist — **by design**, not a bug.
- **Founder:** create the products in Play/ASC, mirror in RC, connect store credentials, deploy `revenuecat-webhook` + secret, sandbox purchase → `pro_entitlements` row → restore → cancel. iOS: create the RC iOS app → put `appl_…` key into `REVENUECAT_IOS_KEY`.
- **Rotate:** RC public SDK keys are publishable; regenerate in RC → update `.env` → release.

### 4.6 Sentry & PostHog
Both **opt-in behind the consent screen** (KVKK). DSN/key are publishable. Sentry symbol upload for obfuscated builds needs the optional CI secrets (§3.4). Rotate by regenerating in each dashboard → `.env`.

### 4.7 AWS / CloudFront / S3 (legal pages)
- **State:** Terraform under `terraform/legal_pages` (state + credentials on this machine; **verified**). Distribution `d2srybp77lgcpy.cloudfront.net` serves `web/public/{privacy,terms}.html` (both 200 ✅).
- **Update flow:** edit HTML → `cd terraform/legal_pages && terraform apply` (invalidation included). Keep the AWS credentials only on the founder machine; nothing in the app calls AWS.

### 4.8 GitHub Actions
Workflows: `ci.yml` (format/analyze/test + debug APK on push; emulator job on PR/`workflow_dispatch` — KVM + disk-reclaim fixes included), `secret-scan.yml` (gitleaks binary over FULL history + `.env` guard — strict config, history was purged when the repo went public), `release.yml` (tag-driven obfuscated builds; every store step secret-gated). Public repo = free minutes. All green as of the last pushes.

### 4.9 Deep links
`formai://` custom scheme + `https://formai.app` intent filters in the manifest (App Links auto-verify deferred until `assetlinks.json` is hosted on formai.app — post-launch item).

### 4.10 Explicitly NOT used (don't go looking)
**Firebase** (no google-services.json — Google sign-in is direct OAuth + Supabase), **OneSignal** (notifications are local/scheduled), **Cloudflare**, **Vercel**, **dart-define / String.fromEnvironment** (all config flows through dotenv).

---

## 5. Security model (one paragraph you must not forget)
The bundled `.env` ships to every user — treat every value in it as public; safety comes from RLS (verified), server-side keys (Anthropic key lives ONLY in Supabase secrets), and consent gates. True secrets live in `.env.local` (founder vault, gitignored), Supabase secrets, GitHub/Codemagic secrets. The CI guard hard-fails any attempt to put model keys into the bundle, gitleaks scans full history on every push, and the repo history was rewritten before going public (old tokens purged; revocation ledgered as defense-in-depth).

## 6. If you rebuild from zero (disaster recovery, ordered)
1. Supabase: new project → run `supabase/migrations/*` → set secrets (§3.3) → deploy both functions → configure auth providers (§2 Web client + Apple) → SMTP.
2. Google Cloud: Web client (→ Supabase + `.env`) + Android clients with §2/§3.6 fingerprints (+ debug + Play App Signing).
3. RevenueCat: apps + entitlement `FormAI Pro` + offering `current` + 3 products + webhook secret.
4. `.env` from `.env.example` (values per §3.1) · `key.properties` + keystore from the off-machine backup.
5. AWS: `terraform apply` in `terraform/legal_pages` (re-hosts legal pages; update URLs if the distribution changes).
6. CI/Codemagic secrets per §3.4/§3.5. Build, run `tool/check_env_no_secrets.sh`, ship.

*Verified-today statements are reproducible: every probe in §0 is a one-line curl/keytool/terraform command documented inline above.*
