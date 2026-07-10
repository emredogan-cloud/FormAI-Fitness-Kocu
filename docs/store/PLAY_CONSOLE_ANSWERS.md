# Play Console — prepared answers (FormAI, com.emredogan.formaifit)

Prepared 2026-07-10 from the verified data inventory (checklist P6). Fill the
console forms EXACTLY from this sheet so Data safety ≡ App Privacy ≡
privacy.html ≡ actual SDK traffic. Source of truth for what the app really
transmits: `FINAL_STORE_SUBMISSION_CHECKLIST.md` §3.

## 1. Data safety form

**Does your app collect or share any of the required user data types?** Yes.

| Data type | Collected? | Shared? | Processed ephemerally? | Required or optional | Purposes |
|---|---|---|---|---|---|
| Personal info → Email address | Yes | No | No | Required (account apps; guests can skip sign-up) | App functionality, Account management |
| Personal info → User IDs | Yes | No | No | Required | App functionality, Account management |
| Health & fitness → Fitness info | Yes (workout **completion** days + timestamps) | No | No | Required for progress sync | App functionality |
| App activity → App interactions | Yes (PostHog events) — **only after in-app opt-in** | No | No | Optional | Analytics |
| App info & performance → Crash logs | Yes (Sentry) — **only after in-app opt-in** | No | No | Optional | Analytics (diagnostics) |
| App info & performance → Diagnostics | Yes (Sentry) — opt-in | No | No | Optional | Analytics (diagnostics) |
| Purchase history | Yes (RevenueCat entitlement state, transaction id) | No | No | Required for Pro | App functionality |

**Do NOT declare** (verified not collected / never leaves device):
- Photos & videos — camera frames are processed on-device by ML Kit and never
  stored or transmitted (Play's on-device processing exemption). There is no
  progress-photo feature in v1. `READ_MEDIA_*` permissions are absent.
- Audio — `RECORD_AUDIO` stripped from the merged manifest (`tools:node=remove`).
- Precise/approx location, contacts, calendar, SMS, files — not requested.
- Body metrics (height/weight/sex/age/goal) — stored ONLY in on-device
  SharedPreferences; never transmitted. On-device-only data is "not collected"
  per the Data safety definition.
- Name — display name only if the sign-in provider supplies it; we don't
  request it separately. (If you prefer maximal caution, declare Personal
  info → Name as optional/collected — keep consistent with App Privacy.)

**Security questions:**
- Data encrypted in transit: **Yes** (HTTPS/TLS only; cleartext disabled).
- Users can request deletion: **Yes** — in-app (Ayarlar → Hesap → Hesabı Sil)
  and web channel: `https://d2srybp77lgcpy.cloudfront.net/privacy.html`
  (Section 6 — deletion by email for uninstalled users).
- Account deletion URL field: use the privacy-policy URL above.

## 2. Health apps declaration
- Category: **Health & Fitness → Activity and Fitness** (add "Nutrition and
  Weight Management" if the console asks per-feature — the app ships a
  nutrition/recipe module).
- Health Connect: **not integrated** — answer No to Health Connect questions.
- Attestations: privacy policy present in console + in-app ✅; prominent
  consent for data collection ✅ (age-gate → consent screen before any
  collection); no ads ✅; permissions minimal ✅.

## 3. Content rating (IARC)
Answer sheet (expected outcome: rated for Everyone / 3+ class):
- Violence / sexuality / language / controlled substances: **No** to all.
- Gambling: No. User interaction/UGC: **No** (no public content, no chat).
- Shares user's current location: No.
- Allows purchase of digital goods: **Yes** (subscriptions).
- Collects personal data: **Yes** (email/account).
- Note: the app self-imposes an 18+ age gate as policy, which is stricter
  than the rating — do not answer rating questions as if content were adult;
  the CONTENT is fitness guidance (all-ages), the AUDIENCE we target is 18+.

## 4. Target audience & content
- Target age group: **18 and over ONLY**.
- Appeal to children: store assets contain adults + robot coach, no
  child-appealing elements → answer accordingly.
- Optionally enable **Restrict Minor Access** (blocks under-18 Google
  accounts from downloading).

## 5. Ads declaration
- Contains ads: **No** (no ad SDKs — verified dependency list).

## 6. App access (for review + pre-launch report)
- "All functionality is available without special access" → **No** (login
  required for full experience).
- Provide credentials (create before submission — see EXTERNAL_ACTION_LEDGER):
  - `reviewer@formai.app` (or chosen mailbox) / strong password
  - Note for reviewers: "Misafir Olarak Devam Et (guest) also works without
    credentials. The reviewer account has the `reviewer` role: Pro features
    are unlocked without purchase. Camera form-coaching requires a person
    fully visible in frame — see demo video: <LINK — record per
    docs/store/APP_STORE_ANSWERS.md §6>."
- Also set the same credentials under Test and release → Pre-launch report →
  Settings → Test-account credentials.

## 7. Subscriptions setup (Monetize → Products → Subscriptions)
Products expected by code/webhook (`003_create_pro_entitlements.sql`,
RC offering `current`):
- `formai_pro_monthly` — 1 month base plan
- `formai_pro_3month` — 3 month base plan
- `formai_pro_annual` — 12 month base plan
Rules: benefit lines must NOT contain price or trial wording (Play subs
policy); set TR pricing; intro/free-trial offers optional — the paywall
renders trial copy ONLY if the store product carries a zero-price intro
offer, so no code change either way. Link products to the RevenueCat app
(Play package + service credentials in RC dashboard).

## 8. Store listing inputs
See `docs/store/LISTING_TR.md` (copy) + `asosystem/play_store_ready/`
(9 screenshots + feature graphic 1024×500) + `photos/APP_ICON_512.png`.
Default language: **tr-TR**. Privacy policy URL:
`https://d2srybp77lgcpy.cloudfront.net/privacy.html`.

## 9. Countries
Start with **Türkiye** (+ any non-EEA markets you want). Adding EEA
countries requires the DSA trader declaration first (ledger item).

## 10. Release path
Internal testing (upload `app-release.aab` 1.0.0+14) → fix pre-launch-report
findings → Closed testing ("Kapalı test") with ≥12 testers opted-in for 14
continuous days (personal accounts created after 2023-11-13) → Apply for
production → Production (managed publishing ON for a controlled go-live).
