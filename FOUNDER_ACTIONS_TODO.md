# FOUNDER ACTIONS — FormAI

**This is the ONLY document you (the founder) need to act on.** Every task
here requires something an engineer cannot do: your Apple/Google/AWS accounts,
your money, your legal identity, or a physical device you control. All
*engineering* is done — the repo is green (`flutter analyze` 0, **313 tests**),
the Android release AAB is built and 16 KB-verified, the app is fully working on
a real device, and the legal pages are live and correct.

Ordered by what unblocks a Google Play **closed test** fastest. Each task lists:
priority · time · why · steps · files/links · what it blocks · can-it-wait.

---

## 🔴 P0 — BLOCKS ANDROID CLOSED TESTING (do these first)

### 1. Verify the account-deletion round-trip on production Supabase
- **Time:** 15 min · **Blocks:** Android ✅ · iOS ✅ · Production ✅ · Wait: **No**
- **Why:** Migrations `006_delete_user.sql` + `007_referrals.sql` must be applied
  to the *production* database, and the store Data-safety form claims deletion
  works — you must confirm it actually purges the account.
- **Steps:**
  1. `cd supabase && supabase link --project-ref xtvqhnjamwvmfcsahzxv` (password
     is in `.env.local` → `SUPABASE_DB_PASSWORD`).
  2. `supabase db push` (applies 006 + 007 if not already applied).
  3. In the app on a device: create a throwaway account → Profil → (account
     settings) → delete → confirm. Then in the Supabase SQL editor confirm the
     `auth.users` row and cascaded tables (`user_progress`, `user_metrics`,
     `pro_entitlements`, `referrals`) are empty for that id.
- **Files:** `supabase/migrations/006_delete_user.sql`, `007_referrals.sql`.

### 2. Create the reviewer / demo account
- **Time:** 10 min · **Blocks:** Android ✅ · iOS ✅ · Production ✅ · Wait: **No**
- **Why:** Both stores require working credentials so a human reviewer can get
  in. FormAI supports a `reviewer` role that unlocks Pro without paying.
- **Steps:**
  1. Sign up `reviewer@formai.app` (or any address you control) in the app.
  2. Supabase SQL editor: `update auth.users set raw_app_meta_data =
     raw_app_meta_data || '{"role":"reviewer"}' where email='reviewer@formai.app';`
  3. Record the credentials into the Play "App access" + ASC "App Review
     Information" (answer packs: `docs/store/`).

### 3. Confirm `support@formai.app` is a monitored mailbox
- **Time:** 10 min · **Blocks:** Production ✅ (DSR channel) · Wait: **No**
- **Why:** The in-app support flow AND the now-live legal pages all point here;
  data-deletion / privacy requests land here on a 30-day KVKK/GDPR clock. If it
  bounces, that's a compliance failure a reviewer can catch.
- **Steps:** Make sure the mailbox exists and forwards to an inbox you read
  (e.g., alias to your Gmail). If you can't create `@formai.app` mail, change
  the address in `web/public/{privacy,terms}.html` + `lib/core/utils/legal_urls.dart`
  to one you own, then re-deploy the pages (`cd terraform/legal_pages &&
  terraform apply`) — but keeping the branded address is better.

### 4. Recruit ≥12 closed-test users (Google Play gate)
- **Time:** ongoing (14-day clock) · **Blocks:** Android production ✅ · Wait: start **now**
- **Why:** If your Play account is personal + created after 2023-11-13, Google
  requires **12 testers opted-in for 14 continuous days** before you can apply
  for production. This is the single longest calendar item — start it first.
- **Steps:** Line up 12 people (friends/family/beta group) who will install and
  keep the app for 2 weeks. Add them as testers when you create the closed track.

---

## 🟠 P1 — BLOCKS FIRST STORE SUBMISSION (parallel with the above)

### 5. Google Play Console — create app + file all declarations
- **Time:** 2–3 hrs · **Blocks:** Android ✅ · Wait: **No**
- **Why:** Nothing publishes without the app record + Data-safety + Health +
  content-rating + subscriptions. **Every answer is pre-written for you.**
- **Steps:** Follow `docs/store/PLAY_CONSOLE_ANSWERS.md` top to bottom:
  create app (`com.emredogan.formaifit`, tr-TR) → enroll Play App Signing →
  upload `build/app/outputs/bundle/release/app-release.aab` to Internal testing
  → Data safety → Health apps ("Activity and Fitness") → IARC content rating →
  Target audience 18+ → Ads=No → subscriptions (3 products) → listing (copy in
  `docs/store/LISTING_TR.md`, assets in `asosystem/play_store_ready/`).
- **Files:** `docs/store/PLAY_CONSOLE_ANSWERS.md`, `docs/store/LISTING_TR.md`.

### 6. Configure RevenueCat + store subscription products
- **Time:** 1–2 hrs · **Blocks:** Android ✅ · iOS ✅ · Wait: **No**
- **Why:** The paywall reads live prices from RevenueCat; without configured
  products it shows the "Fiyatlar yüklenemedi" retry state (by design).
- **Steps:** In RevenueCat + Play/ASC create entitlement **`FormAI Pro`** (exact
  string, with the space) and products `formai_pro_monthly`,
  `formai_pro_3month`, `formai_pro_annual`. Deploy the RC webhook
  (`supabase/functions/revenuecat-webhook`) and set its auth secret. Do one
  sandbox purchase and confirm a `pro_entitlements` row appears.

### 7. Rotate the exposed secrets (security)
- **Time:** 20 min · **Blocks:** nothing, but **do before making the repo public** · Wait: soon
- **Why:** Housekeeping from earlier audits.
- **Steps:**
  - **GCP service-account key:** it's quarantined at
    `~/.formai_secrets_quarantine/formai-494015-*.json` — delete it and rotate
    that key in GCP IAM if it was ever real.
  - **GitHub PAT:** the `.git/config` remote URL embeds a token — rotate it and
    switch to a credential helper. Then merge `prisk/phase-1-tests` → `main`.
  - **Upload keystore password:** currently `formai123` — change it and back the
    `.jks` up off-machine (losing the upload key is only recoverable via Play's
    key-upgrade flow).
  - **OpenAI key:** was found in the bundled `.env` (would have shipped in the
    APK) — engineering already moved it to `.env.local` and added a build guard.
    Rotate it in the OpenAI dashboard to be safe, since it briefly existed in a
    bundleable file.

### 8. Physical-device final QA + restage screenshots + demo video
- **Time:** 2–3 hrs · **Blocks:** submission quality ✅ · Wait: **No**
- **Why:** Screenshots must match the *current* (now much-improved) UI; the
  reviewer video pre-empts the camera-app "how do I test this" question.
- **Steps:** With the backend live, walk the full flow on your device; capture
  fresh screenshots (dashboard now dark + new hero) via the `asosystem` pipeline
  + `python3 tool/format_play_store_assets.py`; record a 60–90 s demo (dashboard
  → workout → camera permission → live rep counting → done) and host it
  unlisted. Confirm: sandbox purchase → restore → cancel; a reminder fires;
  deep links land.

---

## 🍎 P1 — iOS (parallel track; does NOT block Android)

### 9. Stand up Codemagic and ship the first TestFlight build
- **Time:** 2–4 hrs setup + ~30 min/build · **Blocks:** iOS ✅ · Wait: after Android if resources are tight
- **Why:** You have no Mac — and don't need one. The pipeline is committed.
- **Steps:** Follow `docs/ios/CODEMAGIC_SETUP.md` exactly (Apple Developer
  Program $99 → App ID + Sign in with Apple / App Groups in the browser → App
  Store Connect API key → Codemagic env group → run the `FormAI iOS → TestFlight`
  workflow). **Ship v1 without the widget extension** to stay 100% Mac-free.
- **Cost:** ~**$99 first year** (Apple Developer only; Codemagic free tier
  covers a solo build cadence).
- **Files:** `codemagic.yaml`, `docs/ios/CODEMAGIC_SETUP.md`.

### 10. Apple App Store Connect setup
- **Time:** 2–3 hrs · **Blocks:** iOS ✅ · Wait: with #9
- **Steps:** `docs/store/APP_STORE_ANSWERS.md` — Paid Apps agreement (start
  early, banking is slow) → App Privacy labels → age rating → subscription
  products attached to the FIRST submission → review notes (reviewer account #2
  + demo video #8).

---

## 🟡 P2 — POLISH (can wait until after the first closed test)

### 11. Design: regenerate a few remaining legacy/low-quality assets
- **Time:** design work · **Blocks:** nothing (production polish) · Wait: **Yes**
- **Details:**
  - The **paywall before/after images** (`photos/kişiselleştirilmişplandabugünkühal*`
    / `…30.gün*.webp`) are AI-rendered cartoons with garbled text — replace or
    rethink (note: literal before/after body claims draw store scrutiny; consider
    de-emphasizing).
  - The **app launcher icon** (`tool/app_icon.png`) reads "AI FITNESS COACH", not
    "FormAI" — a designed FormAI mark would strengthen store presence.
  - Evolve the **"Form" coach mascot** into a more distinctive character
    (retention lever — see `FINAL_RELEASE_CANDIDATE_AUDIT.md` §3).
  - *(Engineering already replaced the flagship dashboard hero and removed the
    SixPack "S2" shield from it.)*

### 12. Legal: formal registered address (only if you incorporate)
- **Time:** n/a · **Blocks:** nothing for an individual · Wait: **Yes**
- **Why:** The privacy page names you as an individual data controller with
  "address available on request", which is fine for a sole developer. If you
  register a company, add its address and re-deploy (`terraform apply`).

### 13. KVKK / GDPR confirmations (legal counsel)
- **Time:** consult · **Blocks:** nothing immediate · Wait: before scaling
- **Details:** VERBIS registration applicability for your entity; signed DPAs
  with Supabase, Sentry, PostHog, RevenueCat. The architecture already minimizes
  exposure (body metrics never leave the device).

### 14. EU / DSA decision
- **Time:** decision · **Blocks:** EU distribution only · Wait: **Yes**
- **Why:** Distributing in the EU requires a DSA "trader" declaration (published
  name/address/phone). Launch Turkey-first to skip it, or complete trader
  verification in both consoles.

---

## Quick blocking summary

| # | Task | Android | iOS | Production | Wait? |
|---|---|---|---|---|---|
| 1 | Delete round-trip (prod DB) | ✅ | ✅ | ✅ | No |
| 2 | Reviewer account | ✅ | ✅ | ✅ | No |
| 3 | Support mailbox | — | — | ✅ | No |
| 4 | 12 testers / 14 days | — | — | ✅ | Start now |
| 5 | Play Console + declarations | ✅ | — | ✅ | No |
| 6 | RevenueCat + products | ✅ | ✅ | ✅ | No |
| 7 | Rotate secrets | — | — | (before public repo) | Soon |
| 8 | Device QA + screenshots + video | — | — | ✅ | No |
| 9 | Codemagic + TestFlight | — | ✅ | iOS | With resources |
| 10 | ASC setup | — | ✅ | iOS | With #9 |
| 11–14 | Polish / legal / EU | — | — | — | Yes |

**When 1–8 are done, FormAI can enter Google Play closed testing.** iOS follows
via 9–10 (~$99, no Mac). Everything an engineer can do is done.
