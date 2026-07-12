# iOS via Codemagic — Mac-free setup (FormAI)

You have **no macOS machine**, and you don't need one. This is the exact,
ordered checklist to get FormAI onto TestFlight and the App Store entirely from
a browser + the `codemagic.yaml` in this repo. Rationale + cost comparison:
`FINAL_RELEASE_CANDIDATE_AUDIT.md` §7 (primary: Codemagic, ~$99 first year).

Everything the pipeline needs is already committed: `ios/Podfile`,
`Runner.entitlements` (Sign in with Apple + App Group), `PrivacyInfo.xcprivacy`
wired into the build, deployment target 15.5, iPhone-only, and `codemagic.yaml`.

> **One genuinely Mac-only task:** creating the WidgetKit / Live-Activity
> **extension target**. Recommendation: **ship v1 WITHOUT the widget** (remove
> the `NSSupportsLiveActivities*` keys from `ios/Runner/Info.plist` and gate the
> Dart `home_widget` / `live_activities` calls) so v1 is 100% Mac-free. Add the
> extension in v1.1 via a code-gen target (XcodeGen/Tuist) or one ~$25 MacinCloud
> session. Nothing else below needs a Mac.

## Step 0 — Apple Developer Program ($99/yr) — REQUIRED
- Enroll at https://developer.apple.com/programs/ (individual is fine — matches
  the "Emre Doğan, individual developer" data-controller on the legal pages).
- Blocks: iOS submission entirely. Do first.

## Step 1 — App ID + capabilities (browser, no Mac)
- Apple Developer → **Certificates, Identifiers & Profiles → Identifiers** → new
  App ID, bundle `com.emredogan.formai`.
- Enable capabilities: **Sign in with Apple**, **App Groups** (create group
  `group.app.formai.shared`). (Entitlements already reference these.)
- (Later, for the widget) a second App ID `com.emredogan.formai.FormAIWidget`.

## Step 2 — App Store Connect app record
- https://appstoreconnect.apple.com → **Apps → +** → New App → bundle above,
  primary language **Turkish**, name **FormAI**.
- Copy the app's **numeric Apple ID** → put it in `codemagic.yaml`
  (`APP_STORE_APPLE_ID`).
- **Agreements, Tax & Banking → Paid Applications: make it Active** (needed for
  subscriptions; can take days — start now).

## Step 3 — App Store Connect API key (this is what removes the Mac)
- App Store Connect → **Users and Access → Integrations → App Store Connect API**
  → generate a key with **App Manager** access. Download the `.p8` (once only),
  note the **Key ID** and **Issuer ID**.

## Step 4 — Codemagic
- https://codemagic.io → sign in with GitHub → add this repo.
- **Team → Integrations → App Store Connect** → add the key from Step 3; name it
  **exactly** `FormAI ASC API Key` (matches `codemagic.yaml`).
- **Environment variables** → group **`formai_ios_env`** (mark Secure), add the
  CLIENT-PUBLIC keys (same set as `.github/workflows/release.yml`):
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`,
  `GOOGLE_IOS_CLIENT_ID`, `CDN_BASE_URL`, `SENTRY_DSN`, `POSTHOG_API_KEY`,
  `POSTHOG_HOST`, `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`.
  **Never** add `OPENAI_API_KEY`, service-role, or DB passwords — the build
  guard (`tool/check_env_no_secrets.sh`) will fail the build if you do.

## Step 5 — Google Sign-In on iOS
- Google Cloud Console → create an **iOS OAuth client** for bundle
  `com.emredogan.formai` → gives a client id + reversed client id.
- Put the reversed client id as a URL scheme in `ios/Runner/Info.plist`
  (a `CFBundleURLTypes` entry) and set `GOOGLE_IOS_CLIENT_ID` (Step 4).
- Add the Apple provider in Supabase Auth (Services ID + key) for Sign in with
  Apple. Until Google iOS config exists, the Google button fails on iOS but
  SIWA + email work — acceptable for the first TestFlight.

## Step 6 — Run the build
- Codemagic → the **`FormAI iOS → TestFlight`** workflow → **Start new build**.
- It runs pub get → pod install → signing → analyze/test → `flutter build ipa`
  → uploads to TestFlight. First run ~20–30 min.
- Add yourself as an internal TestFlight tester → install on any iPhone.

## Blocking matrix
| Step | Blocks Android? | Blocks iOS? | Blocks production? | Can wait? |
|---|---|---|---|---|
| 0 Apple Program | No | **Yes** | iOS only | No |
| 1 App ID/caps | No | **Yes** | iOS only | No |
| 2 ASC record + Paid Apps | No | **Yes** | iOS only | Start now (banking is slow) |
| 3 ASC API key | No | **Yes** | iOS only | No |
| 4 Codemagic | No | **Yes** | iOS only | No |
| 5 Google iOS sign-in | No | No (SIWA works) | No | Yes — post first TestFlight |
| 6 Build | No | **Yes** | iOS only | No |

## Cost
- Apple Developer Program: **$99/yr** (required).
- Codemagic: **500 free macOS-M2 min/mo** (~20–30 builds) → **$0** for a solo
  cadence; overflow $0.095/min pay-as-you-go.
- **First-year iOS total ≈ $99.**
