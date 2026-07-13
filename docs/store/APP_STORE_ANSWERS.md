# App Store Connect — prepared answers (FormAI, com.emredogan.formai)

Prepared 2026-07-10 from the verified data inventory (checklist P6/§12).
Keep answers consistent with `PLAY_CONSOLE_ANSWERS.md` and privacy.html.
Items marked 🔎 must be read off the live ASC form (post-2025 questionnaires).

## 1. App record
- Bundle ID: `com.emredogan.formai` · Name: **FormAI** (30 chars max)
- Primary language: **Turkish** · Category: **Health & Fitness**
  (secondary: Lifestyle optional)
- Content rights: does not contain third-party content requiring rights → No
  third-party content claim needed (exercise media is own/licensed — confirm
  media licensing before answering; see ledger).

## 2. App Privacy (privacy nutrition labels)
Declare **Data linked to you** (all keyed to the Supabase user ID):
- Contact Info → Email Address — App Functionality, Account Management
- Identifiers → User ID — App Functionality
- Health & Fitness → Fitness — workout completion history — App Functionality
- Purchases → Purchase History — App Functionality (RevenueCat)
- Usage Data → Product Interaction — Analytics — **collected only after
  explicit in-app opt-in** (PostHog; off by default)
- Diagnostics → Crash Data — App Functionality/Analytics — **opt-in**
  (Sentry; off by default; IP/email scrubbed)

Declare **no tracking**: Data used to track you → **None** (no ads, no
cross-app tracking, `NSPrivacyTracking=false`, no ATT prompt).

Do NOT declare: Photos/Videos (camera frames on-device only, never stored/
transmitted), Audio, Location, Contacts, Browsing history, Search history,
Sensitive info. Body metrics live on-device only → not "collected".

## 3. Age rating 🔎
Complete the CURRENT questionnaire (reworked 2025; tiers 4+/9+/13+/16+/18+):
- Violence/sexual content/profanity/horror: None.
- Medical/Treatment information: answer "No" — the app gives general fitness
  guidance with medical disclaimers, not treatment/dosing information.
- Unrestricted web access: No. Gambling: No. UGC: No (no public content).
- Health topics questions 🔎: answer honestly that the app provides exercise
  and general wellness guidance.
- If an "age assurance / restrict to 18+" override is offered and desired,
  you MAY set a higher rating; the app already enforces an 18+ gate in-app.

## 4. Subscriptions (Monetization → Subscriptions)
- One subscription group ("FormAI Pro"), 3 auto-renewables with TR pricing:
  `formai_pro_monthly` (1 mo), `formai_pro_3month` (3 mo),
  `formai_pro_annual` (1 yr). Optional intro offer (e.g., 7-day free trial)
  on chosen products — paywall copy binds to whatever the store reports.
- **First-submission rule:** select these subscription products on the app
  version page so they are reviewed WITH the first binary (classic
  first-app rejection when forgotten).
- Each product needs a localized (tr) display name + description WITHOUT
  price text.
- App metadata must link: Privacy Policy URL
  (`https://d2srybp77lgcpy.cloudfront.net/privacy.html`) in the privacy
  field, and Terms of Use — Apple's standard EULA link
  (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) or
  the hosted terms (`…/terms.html`) in the App Description/EULA field.
- RevenueCat: entitlement **`FormAI Pro`** (exact string, with space),
  offering `current` with monthly/threeMonth/annual packages; App Store
  Connect API key + shared secret configured in the RC dashboard; App Store
  Server Notifications URL pointed at RevenueCat (recommended).

## 5. Agreements / banking (BLOCKING — start immediately)
Paid Applications agreement must be **Active** (banking + tax forms
processed) before a subscription app can be submitted. Processing can take
days — start it before the iOS build work finishes.

## 6. App Review Information
- Sign-in required: **Yes** → provide the reviewer account (same as Play:
  `reviewer@…` with the `reviewer` role = Pro unlocked without purchase;
  guest mode also available).
- Notes (paste-ready):
  > FormAI is a Turkish-language fitness coach. The core feature analyses
  > exercise form in real time using Google ML Kit pose detection running
  > ENTIRELY ON-DEVICE — no camera frame or pose data ever leaves the
  > device (see Privacy Policy §1.3). Testing the camera coach requires a
  > person fully visible in the frame, standing ~2–3 m from the device.
  > A demo video of the full workout flow: <LINK — record a 60–90 s
  > screen+person capture showing: dashboard → workout start → camera
  > permission → rep counting + voice coach → session complete>.
  > The reviewer account has Pro entitlements enabled without purchase.
  > Guest mode ("Misafir Olarak Devam Et") works without credentials.
- Contact: the single support mailbox chosen in ledger item P3.

## 7. Export compliance 🔎
- Info.plist ships `ITSAppUsesNonExemptEncryption = false` (standard
  HTTPS/TLS + platform crypto only, exempt). Answer the ASC questionnaire
  accordingly; no CCATS/France docs expected for exempt mass-market HTTPS
  usage — confirm on the live form.

## 8. Screenshots & metadata 🔎
- iPhone screenshot set for the current largest required size class
  (6.9-inch, 1320×2868 portrait) — ASC scales down where allowed; verify
  the exact required sets on the upload page.
- NO iPad screenshots needed once `TARGETED_DEVICE_FAMILY = 1` (iPhone-only)
  ships (roadmap I9).
- Name (30) / Subtitle (30) / Keywords (100) / Description / Promotional
  text: see `docs/store/LISTING_TR.md`.
- App Preview video: optional — skip for v1.

## 9. TestFlight
- Internal testing: available immediately after the first processed build
  (up to 100 internal testers, no review).
- External testing: requires Beta App Review (~1 day) — use for the wider
  beta while Play closed testing runs.

## 10. EU distribution (DSA) 🔎
Distributing in EU storefronts requires trader status verification (name,
address, email, phone published on the product page). Skip EU territories
at launch OR complete trader verification first (ledger).
