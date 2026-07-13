# FormAI — Founder Master Guide

**The single handbook for everything only *you* can do** — your accounts, your
money, your legal identity, your physical device. All engineering is finished:
`flutter analyze` is clean, **321 tests pass**, the Android release **AAB is
built and 16 KB-verified**, GitHub is clean, and CI is deterministically green.
What remains is account/console/money work, laid out here so **nothing requires
guessing.**

> Companion: `FINAL_PRODUCT_EVOLUTION_REPORT.md` explains *what was built and
> why*. This guide is *what you do next.*

---

## 0. The 60-second map

**Fastest path to a Google Play closed test** (the long pole is a 14-day
tester clock — start it on day one):

1. Rotate exposed secrets → §2
2. Bring Supabase prod to parity + make the reviewer account → §3
3. Confirm the support mailbox → §4
4. **Recruit 12 testers and start the 14-day clock TODAY** → §10
5. Configure RevenueCat + subscription products → §5
6. Create the Play app + file every declaration (answers pre-written) → §6
7. Refresh screenshots + record the reviewer video → §9
8. Upload the AAB → Internal → Closed → (14 days) → Production → §10

**iOS runs in parallel and needs no Mac** (~$99/yr) → §7.

### Costs (first year)

| Thing | Cost | Notes |
|---|---|---|
| Google Play Developer | **$25 once** | one-time registration |
| Apple Developer Program | **$99/yr** | required for iOS; individual is fine |
| Codemagic (iOS CI) | **$0** | 500 free macOS-min/mo covers a solo cadence |
| Supabase | **$0** free tier | free-tier auto-pauses after ~1 wk idle — see §3 |
| AWS (legal pages on CloudFront) | **~$0–1/mo** | already deployed |
| **First-year total** | **≈ $124 + cents** | plus your subscription price-testing |

### The exact string values you will need (never guess these)

| What | Value |
|---|---|
| Android application ID | `com.emredogan.formaifit` |
| iOS bundle ID | `com.emredogan.formai` |
| Supabase project ref | `xtvqhnjamwvmfcsahzxv` |
| RevenueCat entitlement | `FormAI Pro` **(exact — with the space)** |
| Subscription product IDs | `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual` |
| RevenueCat offering | `current` |
| iOS App Group | `group.app.formai.shared` |
| Privacy Policy URL | `https://d2srybp77lgcpy.cloudfront.net/privacy.html` |
| Terms of Use URL | `https://d2srybp77lgcpy.cloudfront.net/terms.html` |
| Support / DSR email | `support@formai.app` |
| Play title / ASC name | `FormAI — Fitness Koçu` |
| AAB to upload | `build/app/outputs/bundle/release/app-release.aab` (`1.0.0+14`) |
| Codemagic ASC key name | `FormAI ASC API Key` |
| Codemagic env group | `formai_ios_env` |
| Codemagic workflow | `FormAI iOS → TestFlight` |

> **Do not rename** the internal Dart package `sixpack_ai` or the `sixpack.`
> SharedPreferences prefixes. They are invisible to users and renaming them
> risks wiping existing on-device data. They are *not* the brand.

---

## 1. Accounts you need (create these first)

| Account | URL | Used for |
|---|---|---|
| Google Play Console | play.google.com/console | Android store |
| Apple Developer | developer.apple.com/programs | iOS store (§7) |
| App Store Connect | appstoreconnect.apple.com | iOS listing/review (§7) |
| RevenueCat | app.revenuecat.com | subscription entitlements (§5) |
| Codemagic | codemagic.io | Mac-free iOS builds (§7) |
| Supabase | supabase.com/dashboard | backend (already exists) |
| AWS Console | console.aws.amazon.com | legal pages CDN (already deployed) |

---

## 2. Security — rotate the exposed secrets (do this first, ~20 min)

None of these block a build, but do them before the repo goes public.

- **GCP service-account key** — moved off the repo to
  `~/.formai_secrets_quarantine/formai-494015-*.json`. In **GCP Console → IAM &
  Admin → Service Accounts → (the key) → Keys**, delete/rotate it, then shred the
  quarantined file. Nothing in the app consumes it — check the usage logs to
  confirm, then remove.
- **GitHub PAT** — the `.git/config` remote URL embeds a token. **GitHub →
  Settings → Developer settings → Personal access tokens**: revoke it and switch
  to a credential helper (`gh auth login` or a git credential manager).
- **Upload keystore password** — currently the dev-grade `formai123`. Change it
  with `keytool`, update `android/key.properties`, and **back the `.jks` up
  off-machine** (losing the upload key is only recoverable via Play's key-reset
  flow, which takes days).
- **OpenAI key** — engineering already moved it out of the bundled `.env` into
  `.env.local` and added a build guard (`tool/check_env_no_secrets.sh`) so it
  can never ship in the APK again. Because it briefly lived in a bundleable file,
  rotate it in the **OpenAI dashboard → API keys** to be safe.
- **Session tokens in old `logs.txt` history** — a debug adb-logcat capture
  (`logs.txt`) was committed early on and later removed from the tree +
  gitignored (Phase 0). Its old commits still contain **live auth tokens** from a
  dev login (Google/Supabase refresh + access tokens). Revoke them so the
  historical copies are inert: **Google Account → Security → Third-party access →
  remove FormAI/Google Sign-In**, and **Supabase → Authentication → Users → sign
  out / rotate** any lingering dev session. (CI's secret scan allowlists this
  one remediated path — see `.gitleaks.toml` — so it won't red on already-known
  history; revocation is what actually closes the exposure.)

---

## 3. Supabase production (~30 min) — project `xtvqhnjamwvmfcsahzxv`

The app **requires** a Supabase session, so backend parity gates every server
flow (login, plan generation, purchases, deletion).

### 3.1 Keep the project awake
Free-tier Supabase **auto-pauses after ~1 week idle** and takes its API
subdomain offline — which locks *everyone* out at the login screen. Either keep
it active (any traffic / a nightly ping) or move to the **Pro tier** before
public launch. (This already bit us once; the project is currently active.)

### 3.2 Confirm migrations are applied
Engineering repaired the migration **history** (001–007 now tracked) and
probe-verified the objects the app calls. To be fully sure the schema is
complete on prod:
```
cd supabase
supabase link --project-ref xtvqhnjamwvmfcsahzxv     # password: .env.local → SUPABASE_DB_PASSWORD
supabase db push                                      # applies anything missing (safe if already applied)
```
The two that matter most for store compliance are `006_delete_user.sql`
(account deletion) and `007_referrals.sql` (`redeem_referral(referrer_code)`,
which matches the app's call).

### 3.3 Create the reviewer / demo account (both stores require it)
1. In the app, sign up an address you control (e.g. `reviewer@formai.app`).
2. In **Supabase → SQL Editor**, run:
   ```sql
   update auth.users
     set raw_app_meta_data = raw_app_meta_data || '{"role":"reviewer"}'
   where email = 'reviewer@formai.app';
   ```
   The `reviewer` role unlocks Pro without a purchase (the app honours it).
3. Record the credentials — you'll paste them into Play "App access" (§6) and
   ASC "App Review Information" (§7).

### 3.4 Verify the delete round-trip (Data-safety truthfulness)
Create a throwaway account in the app → **Ayarlar → Hesabı Sil** → confirm.
Then in the SQL Editor confirm the `auth.users` row **and** the cascaded tables
(`user_progress`, `user_metrics`, `pro_entitlements`, `referrals`) are empty for
that id. The store forms claim deletion works — this is you proving it.

### 3.5 Before inviting 12 testers: custom SMTP
Supabase's default mailer is rate-limited to ~2 mails/hour — 12 testers signing
up at once will hit it. In **Supabase → Project Settings → Authentication →
SMTP**, configure a real sender (Resend / Postmark / SES) with a verified
domain. Also confirm **Site URL + Redirect URLs** cover the mobile deep-link so
password-reset returns into the app.

---

## 4. Legal pages (already live — just verify)

The privacy policy and terms are **deployed to CloudFront** and are the
production source of truth:
- Privacy: `https://d2srybp77lgcpy.cloudfront.net/privacy.html`
- Terms: `https://d2srybp77lgcpy.cloudfront.net/terms.html`

**Confirm `support@formai.app` is a monitored mailbox** (or a forwarding alias
to an inbox you read). Both legal pages and the in-app support flow point here,
and data-deletion / privacy requests land here on a **30-day KVKK/GDPR clock** —
a bounce is a compliance failure a reviewer can catch.

If you can't own `@formai.app` mail, change the address in
`web/public/privacy.html` + `web/public/terms.html` + `lib/core/utils/legal_urls.dart`
to one you control and re-deploy:
```
cd terraform/legal_pages && terraform apply
```
(The AWS state + credentials are already on the machine.) Keeping the branded
address is better if you can.

---

## 5. RevenueCat + subscription products (~1–2 hrs)

The paywall reads **live prices from RevenueCat**; with no products configured
it shows the honest "Fiyatlar yüklenemedi" retry state (by design).

1. **Create the products in the stores** (see §6.7 for Play, §7 step for ASC),
   using EXACTLY these IDs:
   - `formai_pro_monthly` — 1-month base plan
   - `formai_pro_3month` — 3-month base plan
   - `formai_pro_annual` — 12-month base plan
2. **RevenueCat dashboard:** create the entitlement **`FormAI Pro`** (exact
   string, with the space). Attach all three products to the offering `current`
   as the monthly / threeMonth / annual packages.
3. Connect the store credentials in RC (Play service-account JSON; App Store
   Connect API key + shared secret).
4. **Deploy the webhook** `supabase/functions/revenuecat-webhook` and set its
   auth secret, so entitlement changes write to `pro_entitlements`.
5. **Test:** one sandbox purchase → confirm a `pro_entitlements` row appears →
   restore → cancel.

> Subscription benefit lines must **not** contain price or trial wording (Play
> and Apple both reject that). A free-trial intro offer is optional — the paywall
> renders trial copy **only** if the store product carries a zero-price intro
> offer, so it's purely a store-side toggle, no code change either way.

---

## 6. Google Play Console — full walkthrough

Work top-to-bottom; every answer below is verified against what the app actually
transmits (so Data-safety ≡ App Privacy ≡ privacy.html ≡ real SDK traffic).

### 6.1 Create the app
- **Create app** → name `FormAI — Fitness Koçu`, default language **tr-TR**, app
  (not game), free.
- Confirm your **account type**. If it's *personal* and created after
  2023-11-13, the **12-testers-for-14-days** closed-test gate applies (§10).
  Organisation accounts skip it.

### 6.2 Upload the build
- Enroll in **Play App Signing** (let Google manage the app-signing key; you keep
  the upload key from §2).
- **Testing → Internal testing → Create release** → upload
  `build/app/outputs/bundle/release/app-release.aab` (`1.0.0+14`).

### 6.3 Data safety (Policy → App content → Data safety)
Declare **Yes, the app collects data**, then:

| Data type | Collected | Shared | Required? | Purpose |
|---|---|---|---|---|
| Personal info → **Email address** | Yes | No | Required | App functionality, Account management |
| Personal info → **User IDs** | Yes | No | Required | App functionality, Account management |
| Health & fitness → **Fitness info** (workout *completion* days + timestamps) | Yes | No | Required | App functionality |
| App activity → **App interactions** (PostHog) | Yes | No | **Optional** | Analytics — *only after in-app opt-in* |
| App info & performance → **Crash logs / Diagnostics** (Sentry) | Yes | No | **Optional** | Diagnostics — *opt-in* |
| Financial → **Purchase history** (RevenueCat) | Yes | No | Required | App functionality |

**Do NOT declare** (verified never collected / never leaves device):
Photos/Videos (camera frames are processed on-device by ML Kit and never stored
or sent — Play's on-device exemption; no progress-photo feature in v1), Audio
(`RECORD_AUDIO` is stripped from the merged manifest), Location, Contacts,
Calendar, SMS, Files, and **body metrics** (height/weight/age/goal live only in
on-device SharedPreferences → "not collected").

Security answers: **Encrypted in transit = Yes** (HTTPS/TLS only); **Users can
request deletion = Yes** (in-app *Ayarlar → Hesabı Sil* + the privacy-page email
channel). Put the privacy URL in the account-deletion URL field.

### 6.4 Health apps declaration
- Category: **Health & Fitness → Activity and Fitness** (add "Nutrition and
  Weight Management" if asked per-feature — there's a nutrition module).
- **Health Connect: not integrated** → answer No to Health Connect questions.
- Attestations: privacy policy present ✓, prominent consent before any
  collection ✓ (age-gate → consent screen), no ads ✓, minimal permissions ✓.

### 6.5 Content rating (IARC questionnaire)
- Violence / sexuality / language / controlled substances / gambling: **No** to
  all. UGC / user interaction / shares location: **No**.
- Purchase of digital goods: **Yes** (subscriptions). Collects personal data:
  **Yes** (email/account).
- The content is all-ages fitness guidance; the app *self-imposes* an 18+ gate
  as audience policy (below) — don't answer the rating questions as if the
  content were adult.

### 6.6 Target audience, ads
- Target age: **18 and over only**. No child-appealing elements.
- Optionally enable **Restrict Minor Access**.
- **Contains ads: No** (no ad SDKs — verified).

### 6.7 Subscriptions (Monetize → Products → Subscriptions)
Create the three products from §5 (`formai_pro_monthly`, `formai_pro_3month`,
`formai_pro_annual`) with TR pricing. Benefit lines: **no price or trial text.**
Link the products to the RevenueCat app.

### 6.8 App access (for the reviewer + pre-launch report)
"All functionality available without special access" → **No** (login required).
Provide the reviewer credentials from §3.3, plus this note:
> "Misafir Olarak Devam Et (guest) also works without credentials. The reviewer
> account has the `reviewer` role: Pro is unlocked without purchase. Camera
> form-coaching needs a person fully visible in frame — see demo video: <LINK>."

Set the same credentials under **Test and release → Pre-launch report →
Settings → Test-account credentials.**

### 6.9 Store listing
Copy from `docs/store/LISTING_TR.md` (title / short / full description — all
claim-disciplined, no fabricated numbers). Assets: `photos/APP_ICON_512.png`
(512 icon) + the screenshot set (regenerate from the CURRENT UI first — §9).
Privacy URL as above. Default language **tr-TR**.

### 6.10 Countries & release path
Start with **Türkiye** (adding EEA countries first requires the DSA trader
declaration — §11). Then: Internal → **Closed testing** (start the 14-day clock)
→ triage the pre-launch report → **Apply for production** → Production with
**managed publishing ON** for a controlled go-live.

---

## 7. iOS — Mac-free via Codemagic (~$99/yr, no Mac needed)

Everything the pipeline needs is committed (`ios/Podfile`,
`Runner.entitlements`, `PrivacyInfo.xcprivacy`, target 15.5, iPhone-only,
`codemagic.yaml`). **One genuinely Mac-only task exists — the Widget/Live-
Activity extension — so ship v1 WITHOUT it** (the Dart calls no-op harmlessly)
and add it in v1.1 via a code-gen target or a one-off ~$25 MacinCloud session.

**Ordered checklist:**

0. **Apple Developer Program** ($99/yr) — enroll at
   developer.apple.com/programs (individual matches "Emre Doğan, individual
   developer" on the legal pages). Blocks all of iOS.
1. **App ID + capabilities** (browser): Certificates, Identifiers & Profiles →
   Identifiers → new App ID, bundle `com.emredogan.formai`. Enable **Sign in
   with Apple** and **App Groups** (create `group.app.formai.shared`).
2. **App Store Connect record**: Apps → + → New App → bundle above, primary
   language **Turkish**, name **FormAI**. Copy the numeric **Apple ID** into
   `codemagic.yaml` (`APP_STORE_APPLE_ID`). Start **Agreements, Tax & Banking →
   Paid Applications → Active** NOW (banking can take days and blocks any
   subscription app).
3. **ASC API key** (this is what removes the Mac): Users and Access →
   Integrations → App Store Connect API → generate a key with **App Manager**
   access → download the `.p8` (once), note **Key ID** + **Issuer ID**.
4. **Codemagic**: sign in with GitHub → add this repo. Team → Integrations → App
   Store Connect → add the key, name it **exactly** `FormAI ASC API Key`.
   Environment variables → group **`formai_ios_env`** (mark Secure): add the
   client-public keys `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`,
   `GOOGLE_IOS_CLIENT_ID`, `CDN_BASE_URL`, `SENTRY_DSN`, `POSTHOG_API_KEY`,
   `POSTHOG_HOST`, `REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`. **Never** add
   `OPENAI_API_KEY`, the service-role key, or DB passwords — the build guard will
   fail the build if you do.
5. **Google Sign-In on iOS** (optional, post-first-build): create an iOS OAuth
   client for `com.emredogan.formai` in Google Cloud → put the reversed client
   id as a URL scheme in `ios/Runner/Info.plist` and set `GOOGLE_IOS_CLIENT_ID`.
   Until then, Sign in with Apple + email work; the Google button just fails on
   iOS.
6. **Run the build**: Codemagic → **`FormAI iOS → TestFlight`** → Start new build
   (pub get → pod install → sign → analyze/test → `flutter build ipa` → upload).
   First run ~20–30 min. Add yourself as an internal TestFlight tester.

**ASC listing/review answers** (mirror Play; from `docs/store/APP_STORE_ANSWERS.md`):
- **App Privacy labels** — Data *linked to you*: Email, User ID, Fitness
  (completion history), Purchase History; Product Interaction + Crash Data as
  **opt-in analytics**. **Tracking: None** (`NSPrivacyTracking=false`, no ATT).
  Do not declare Photos/Audio/Location/body metrics.
- **Age rating** — complete the current questionnaire; Medical/Treatment info =
  **No** (general fitness guidance with disclaimers, not treatment).
- **Subscriptions** — one group ("FormAI Pro"), the 3 auto-renewables, each with
  a localized (tr) name + description **without price text**. **Attach them to
  the first submission** (classic first-app rejection when forgotten).
- **App Review Information** — reviewer account from §3.3 + the demo video (§9) +
  the paste-ready camera note in `docs/store/APP_STORE_ANSWERS.md` §6.
- **Export compliance** — Info.plist declares `ITSAppUsesNonExemptEncryption =
  false` (standard HTTPS, exempt); answer accordingly.
- **Metadata links** — Privacy URL in the privacy field; Terms (hosted terms.html
  or Apple's standard EULA) in the description/EULA field.

---

## 8. Store listing copy (approve before entry)

Full claim-disciplined TR copy is in **`docs/store/LISTING_TR.md`**. Highlights:

- **Title / ASC name:** `FormAI — Fitness Koçu`
- **ASC subtitle (recommended):** `Kameranla formunu düzelt`
- **Play short (recommended):** `Kameranı aç: yapay zekâ formunu cihazında
  analiz eder, sayar ve sesli düzeltir.`
- **Full description:** the "GERÇEK ZAMANLI FORM ANALİZİ / SANA ÖZEL 30 GÜNLÜK
  PROGRAM / BESLENME REHBERİ / GİZLİLİK ÖNCE GELİR / FORMAI PRO" body in the doc.

**Claim discipline (do not regress):** no fabricated numbers/testimonials, no
"X haftada Y kg" outcome claims, no generative-AI implication — "yapay zekâ"
refers only to what ships (on-device pose analysis + rule-based coaching).
"130+ egzersiz" = 138 analyzer slugs; "yüzlerce tarif" = 293 recipes (undersell,
never oversell). This matches the in-app honesty pass and both stores'
misleading-claims policies.

---

## 9. Reviewer access + demo video + screenshots

- **Reviewer account** — §3.3, recorded into both consoles.
- **Demo video (60–90 s, host unlisted)** — dashboard → workout start → camera
  permission → live rep counting + voice → session complete. It pre-empts the
  reviewer's "how do I test a camera app" question (Apple 2.1). Script in
  `docs/store/APP_STORE_ANSWERS.md` §6.
- **Screenshots** — the existing frames are May-era (pre-honesty-pass, pre-dark
  UI). Regenerate from the CURRENT app with the backend up, then run
  `python3 tool/format_play_store_assets.py`. Store policy requires screenshots
  to match the shipping app.

---

## 10. Testing tracks + rollout timeline

**The 14-day tester clock is the schedule — start it first.**

1. **Recruit ≥12 testers** (friends/family/beta group) who will install and keep
   the app opted-in for **14 continuous days** (personal Play accounts created
   after 2023-11-13). This is the single longest calendar item.
2. **Android:** Internal testing (immediate) → **Closed testing "Kapalı test"**
   (starts the clock) → fix pre-launch-report findings → **Apply for
   production** after 14 days → Production (managed publishing).
3. **iOS:** TestFlight **internal** (immediate after first processed build, up to
   100 testers, no review) → **external** (Beta App Review ~1 day) for a wider
   beta while Play's clock runs → submit for App Review with **manual release**.

Run the 10-check "FINAL READY-TO-SUBMIT GATE" in
`FINAL_STORE_SUBMISSION_ROADMAP.md` before each store's submit. Code-side it
already passes (analyze 0 · 321 tests · signed 16 KB-clean AAB · lean merged
manifest · console packs consistent with real data flows).

---

## 11. Legal / compliance (confirm before *production*, not before testing)

- **Support mailbox** — §4 (30-day DSR clock).
- **KVKK VERBIS** — a solo developer below the employee/turnover thresholds is
  typically exempt; confirm against current guidance and document the
  assessment.
- **Cross-border transfer basis (KVKK Art.9 / GDPR)** — keep signed DPAs/SCCs
  with Supabase (EU), Sentry (EU), PostHog, RevenueCat (US). The policy already
  describes the mechanism; architecture minimizes exposure (body metrics never
  leave the device).
- **EU/DSA trader status** — distributing in the EU requires publishing a trader
  name/address/email/phone. **Launch Turkey-first to skip it**, or complete
  trader verification in both consoles.
- **Formal registered address** — the privacy page names you as an individual
  data controller with "address on request," which is fine for a sole developer.
  Add a business address only if you incorporate (then `terraform apply`).
- **Exercise-media licensing** — ASC's content-rights question asks whether you
  have rights to shown content; confirm the exercise media is your own/licensed.

---

## 12. Product decisions that are *yours* (not engineering)

These are genuine judgement calls surfaced by the audit — decide, then an
engineer can implement quickly:

1. **Free nutrition taste?** Today the entire Beslenme tab is Pro-gated, so free
   users get zero nutrition value before paying and reviewers only see it via the
   reviewer account. Consider unlocking 2–3 sample recipes or a read-only calorie
   ring to drive conversion. (Revenue trade-off — your call.)
2. **Theme coherence.** Onboarding is always-dark (cinematic); the rest follows
   the system theme, so a light-mode device jumps dark→light after onboarding.
   Either default `themeMode` to dark (brand is dark-first; keep the toggle) or
   add a light onboarding variant.
3. **Free-trial intro offer?** Purely a store-side toggle — the paywall adapts
   automatically. Decide per product.
4. **Mascot evolution.** Evolving "Form" from a friendly-but-generic avatar into
   a distinctive character is a retention lever and a design investment (post-
   launch).

---

## 13. Turning the Coach into a real LLM (when you're ready)

The coach was built so this is a *swap*, not a rewrite:

1. Write a Supabase **Edge Function** `coach-chat` that holds the model key
   server-side (the key never touches the client) and takes the context +
   message, returns the reply.
2. Implement `LlmCoachBrain implements CoachBrain` that calls that function and
   uses `CoachContext.toPromptContext()` (already written) as the system prompt.
3. Change **one line** — `coachBrainProvider` in
   `lib/features/coach/providers/coach_providers.dart` — to return the LLM brain.
   The screen, the context aggregation, and the tests are unchanged.
4. Add the documented production concerns from `coach_brain.dart`: rolling
   summary memory and a medical-safety guardrail (defer to a professional, no
   diagnoses/dosing).

Keep the honesty contract the tests pin: context-aware, and no fabricated
free-form claims.

---

## 14. Quick reference — the blocking matrix

| # | Task | Android | iOS | Production | When |
|---|---|:--:|:--:|:--:|---|
| Recruit 12 testers (14-day clock) | §10 | — | — | ✅ | **Start today** |
| Rotate secrets | §2 | — | — | before public repo | Soon |
| Supabase parity + delete round-trip | §3 | ✅ | ✅ | ✅ | Now |
| Reviewer account | §3.3 | ✅ | ✅ | ✅ | Now |
| Support mailbox live | §4 | — | — | ✅ | Now |
| RevenueCat + products | §5 | ✅ | ✅ | ✅ | Now |
| Play app + all declarations | §6 | ✅ | — | ✅ | Now |
| Screenshots + demo video | §9 | — | — | ✅ | Before submit |
| Codemagic + TestFlight | §7 | — | ✅ | iOS | Parallel |
| ASC setup + Paid Apps | §7 | — | ✅ | iOS | Start banking now |
| Legal / DSA / KVKK | §11 | — | — | ✅ | Before production |

**When the "Now" rows are done, FormAI can enter Google Play closed testing.**
iOS follows via §7 (~$99, no Mac). Everything an engineer can do is done.

---

*Questions this guide should have answered without guessing: which button, which
exact string, which value, in which dashboard, in what order, and what it blocks.
If any step still feels ambiguous, the deeper source docs are `docs/store/*`,
`docs/ios/CODEMAGIC_SETUP.md`, and `FINAL_STORE_SUBMISSION_ROADMAP.md`.*
