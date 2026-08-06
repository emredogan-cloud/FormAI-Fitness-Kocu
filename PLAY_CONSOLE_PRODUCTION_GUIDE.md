# Play Console — Production Release Guide

**App:** FormAI — `com.emredogan.formaifit`
**Build ready to ship:** `1.0.0` versionCode **38** · AAB 116.1 MB
**Written:** 6 August 2026 · for build 38 and the Play Console as it stood then
**Assumes:** you have never shipped an app to production before. Nothing is skipped as "obvious".

---

## How to read this

Every step has four parts:

- **Why it exists** — what Google is actually trying to establish.
- **Where** — the exact Play Console path.
- **Choose** — what to enter for *this* app, not in general.
- **Mistakes & rejection risk** — what goes wrong here, and how badly.

Steps are in dependency order. **Do them in order.** Several sections gate
each other: you cannot submit a release until App content is complete, and
Data safety cannot be answered correctly until the privacy policy it must
match is live.

> **One document supersedes another.** `docs/store/PLAY_CONSOLE_ANSWERS.md`
> was written on 2026-07-10 and is still useful, but it is **wrong in three
> places** now — Data safety, the deletion URL, and the reasoning around
> content rating. Where the two disagree, **this document wins**, and §14
> lists exactly what changed and why.

---

## 0 · Current state — what is already done

You do not need to redo any of this.

| | Status |
| --- | --- |
| AAB built, signed, uploadable | ✅ `1.0.0+38`, upload key `CN=FormAI` |
| Play App Signing enrolled | ✅ Google re-signs on upload |
| Google Sign-In working on Play-signed builds | ✅ verified on device, both SHA-1s registered |
| Privacy policy live and **accurate** | ✅ `…/privacy.html`, updated 6 Aug 2026 |
| Terms live | ✅ `…/terms.html` |
| **Account deletion page live** | ✅ `…/delete-account.html` (HTTP 200) |
| Database migrations 001–027 applied | ✅ local ≡ remote, RLS verified on all 28 tables |
| In-app AI content reporting | ✅ shipped and filing rows in production |
| 14-day closed test completed | ✅ "Apply for production" is unlocked |
| Tests / analyze / gates | ✅ 1524 tests, 0 analyzer issues, 7/7 gates |

**The base URL for all three legal pages:**
`https://d2srybp77lgcpy.cloudfront.net/`

---

## 1 · Pre-flight — do these before you open Play Console

### 1.1 Confirm CI is green

**Why:** CI runs Flutter 3.44.8; your machine runs 3.41.9. That gap has
turned a green local build into a red CI run four times in this project's
history. A red CI does not block upload, but it means the artifact you are
about to ship was never validated by the stricter toolchain.

**Where:** GitHub → Actions → the run for commit `db93e22` (or later).

**Choose:** both workflows green (CI + Secret Scan). If red, stop and fix.

**Mistakes:** uploading first and checking later. You cannot un-publish a
release; you can only roll it back, and rollback on Play is halting a
rollout, not un-shipping a build.

### 1.2 Have these open in tabs

- `PLAY_STORE_ASO_PROMPTS.html` — the graphics you still need
- `docs/store/LISTING_TR.md` and `docs/store/LISTING_EN.md` — the approved copy
- `docs/store/PRICING_SETUP.md` — the approved price ladder
- This document

### 1.3 Decide one thing now: managed publishing

**Why:** With managed publishing **on**, everything you approve queues up
and nothing goes live until you press "Publish". With it off, each approved
change goes live as soon as Google finishes reviewing it — which can mean
your new store listing appears while your new build is still in review.

**Where:** Publishing overview → Manage publishing (top right toggle).

**Choose:** **ON.** Turn it on before you touch anything else. You want the
listing, the graphics and the build to go live as one coordinated change.

**Mistakes:** discovering half your changes went live mid-edit.

---

## 2 · Store listing

**Where:** Grow → Store presence → **Main store listing**

### 2.1 App name (title)

**Why:** 30 characters, indexed for search, and the single strongest ASO
signal you control.

**Choose:** `FormAI — Fitness Koçu` (21 chars, Turkish default listing)

> ### 🔴 THIS IS THE CHANGE THAT MATTERS MOST HERE
> The current live title is
> **`FormAI - Kişisel Fitness Koçu (Erken Erişim)`**.
> **Delete `(Erken Erişim)`.** "Early access" describes the closed test you
> have just finished. Shipping it to production advertises the app as
> unfinished to every user who finds it, and it is the kind of stale
> qualifier that reads as a listing nobody maintains. It is also simply
> untrue once you are on the production track.

**Mistakes:**
- Keyword-stuffing the title (`FormAI — AI Fitness Workout Gym Coach Trainer`). Play's Store Listing policy explicitly prohibits it and it is one of the most commonly enforced listing rules.
- Using emoji, ALL CAPS, or "#1", "Best", "Top" in the title. All prohibited.
- Putting a price or a promotion in the title ("50% OFF").

**Rejection risk:** Medium. Keyword stuffing and promotional text in the
title are routine takedowns, usually a listing rejection rather than a
suspension — but they cost you a review cycle.

### 2.2 Short description

**Why:** 80 characters, shown above the fold before the user taps "More".
It is what convinces someone to expand.

**Choose (Turkish, default listing):** take option 1 from
`docs/store/LISTING_TR.md`.
**English:** `Open your camera: AI analyzes your form on your phone and calls out fixes.` (78)

**Mistakes:** repeating the title; writing a feature list instead of a
reason to care; exceeding 80 chars (the console truncates silently in some
locales).

### 2.3 Full description

**Why:** 4000 characters, indexed, and the place Google's automated review
looks hardest for prohibited claims.

**Choose:** paste from `docs/store/LISTING_TR.md` / `LISTING_EN.md`. That
copy was written against explicit anti-hype rules and is already compliant.

**Before pasting, re-read it against build 38.** The app's own claims were
softened in build 38. If the listing still says anything the app no longer
says, the listing is now the strongest claim in the product — which is
exactly backwards. Specifically **check the description does not contain**:

- "30 günde değişim" / "transform in 30 days" or any outcome-in-a-timeframe promise
- "garantili sonuç" / "guaranteed results"
- "%100 cihazında AI" / "100% on-device AI" — the *chat coach* is server-side
- "bilimsel olarak kanıtlanmış" / "evidence-based", "clinically proven"
- any number of users, downloads, or ratings

**Mistakes:**
- Health claims. A fitness app may describe exercise; it may not claim to treat, cure, prevent or diagnose anything, and it may not promise a specific body outcome.
- Mentioning other platforms ("Also on iOS!") — Play discourages cross-promotion of competing stores.
- Testimonials you invented.

**Rejection risk:** **High.** Misleading-claims enforcement in the full
description is one of the most common health-app rejections, and it is
assessed by automated scanning as well as human review.

### 2.4 Graphics

**Where:** same page, Graphics section.

| Asset | Spec | Required |
| --- | --- | --- |
| App icon | 512 × 512 PNG, 32-bit, ≤ 1 MB | ✅ yes |
| Feature graphic | 1024 × 500 PNG/JPEG, no alpha | ✅ yes |
| Phone screenshots | 2–8, 16:9 or 9:16, min 320 px | ✅ yes (min 2) |
| 7″ tablet screenshots | up to 8 | optional |
| 10″ tablet screenshots | up to 8 | optional |
| Promo video | YouTube URL | optional |

**Choose:** generate from `PLAY_STORE_ASO_PROMPTS.html`. Upload **8 phone
screenshots** in the order given there — the first two or three are what
appear in search results, so AI Coach and Form Detection lead.

**On tablet screenshots — a real decision, not a formality.** FormAI's UI
has never had a tablet-optimised layout in any shipped phase. If you upload
tablet screenshots showing a two-pane layout the app does not render, that
is a deceptive listing. If you upload phone-shaped screenshots on a tablet,
Google's large-screen quality checks will notice and your app may be marked
as not optimised for large screens. **The honest option is to upload none**
and accept the large-screen quality flag until a tablet layout ships.

**Mistakes:**
- iPhone frames or an iOS status bar in a screenshot. Flagged in the audit as an asset-quality and deception risk; also just embarrassing.
- Screenshots that are pure marketing art with no actual UI. Google requires screenshots to represent the app experience.
- A feature graphic with a fake "Install" button or a redrawn Play badge.
- Text in the outer 64 px of the feature graphic (cropped in some placements) or in the dead-center 250 px (covered by the ▶ overlay if you ever attach a video).

**Rejection risk:** Medium–High. Misleading screenshots are a named
enforcement category under Deceptive Behavior.

### 2.5 Localizations

**Why:** the app ships Turkish and English. A listing in only one of them
means half your users read a store page in a language the app does not
present to them.

**Where:** Main store listing → language dropdown → **Manage translations**
→ Add your own translation → `English (United States) – en-US`.

**Choose:** default language **Turkish (tr-TR)**; add **en-US** and paste
from `docs/store/LISTING_EN.md`.

**Mistakes:**
- Using Google's automatic translation for the store listing. It will produce a listing that does not match the app's own reviewed copy, and health/fitness wording is exactly where machine translation invents claims.
- Forgetting that graphics are per-locale too. If your screenshots carry Turkish text, upload English-text versions under en-US, or use text-free screenshots for both.

### 2.6 Store settings — category and contact details

**Where:** Grow → Store presence → **Store settings**

**Choose:**
- App category: **Health & Fitness**
- Tags: choose the fitness/workout tags that genuinely apply; do not select unrelated high-traffic tags
- Store listing contact: an email you actually monitor (`support@formai.app`)
- Website: `https://d2srybp77lgcpy.cloudfront.net/` (or a real marketing site if one exists)
- Phone: optional — leave blank rather than entering a number nobody answers

**Why the email matters:** it is public, it is where users write before they
leave a one-star review, and Google uses it to contact you about policy
issues. A dead address here is how developers discover a suspension a week
late.

**Rejection risk:** Low, but an unreachable contact email is a real
operational hazard.

---

## 3 · App content — the compliance section

**Where:** Policy → **App content**

This is the section that actually blocks production. Every item must show
a green tick before you can submit a release.

### 3.1 Privacy policy

**Why:** mandatory for every app that handles personal or sensitive user
data. Google fetches the URL and a human may read it.

**Where:** App content → Privacy policy.

**Choose:** `https://d2srybp77lgcpy.cloudfront.net/privacy.html`

**Verify before saving:** open it in a private browser window. It must load
without a login, and it must say **"Last updated: 6 August 2026"** and
contain an **Anthropic** row in the processor table. If it says 11 July, the
CloudFront deploy did not take and you are about to declare a policy that
contradicts your own app.

**Mistakes:**
- Pointing at a Google Doc, a Notion page, or anything behind a login.
- A policy that does not name every third party receiving data. FormAI's are: Supabase, Anthropic, RevenueCat, Sentry, PostHog, and the app stores.
- A policy that contradicts the Data safety form. This is the single most-cited mismatch in modern Play rejections.

**Rejection risk:** **Critical.** A missing, broken or contradictory privacy
policy is a hard block.

### 3.2 App access

**Why:** reviewers must be able to see everything. If any part of the app is
behind a login they cannot pass, they will reject for "broken functionality"
having never reached the feature.

**Where:** App content → App access.

**Choose:** **"All or some functionality is restricted"**, then add an
instruction set:

- **Name:** `Reviewer account`
- **Username:** the reviewer mailbox you actually created
- **Password:** its password
- **Any other instructions:**

> Guest mode also works with no account: on the sign-in sheet tap "Not now"
> / "Şimdi değil" and the full app is available.
>
> The reviewer account has Pro unlocked without purchase.
>
> Camera form-coaching requires a person fully visible in frame at about
> 2 m. If that is not practical, tap "Continue without the camera" on the
> setup screen — the workout runs without it.
>
> The app enforces an 18+ age gate on first launch: choose any birth year
> before 2008 to continue.

> ### ⚠️ Resolve this before you fill it in
> Two different mailboxes appear in this project's documentation:
> `google-reviewer@formai.app` and `reviewer@formai.app`.
> **Confirm which one exists, that it can receive mail, and that you can
> sign into FormAI with it**, on a real device, before you paste it here.
> A credential that does not work is worse than no credential — it turns a
> review into a rejection with the note "we could not sign in".

**Mistakes:**
- Declaring "no restrictions" when a login exists. The reviewer hits the auth sheet and rejects.
- Providing a personal Google account. Google Sign-In inside a review harness is fragile; give an **email/password** account, and mention guest mode as the fallback — which FormAI genuinely has.
- Forgetting to add the same credentials under **Test and release → Pre-launch report → Settings**, so the automated crawler also gets in.

**Rejection risk:** **High.** "Reviewer could not access the app" is a very
common rejection and costs a full review cycle each time.

### 3.3 Ads

**Why:** determines whether the "Contains ads" badge appears and whether ad
policies apply.

**Where:** App content → Ads.

**Choose:** **No, my app does not contain ads.**

**Verified:** no ad SDK is in the dependency list.

**Mistakes:** answering "yes" because you plan to add ads later. Answer for
the build you are shipping; update it when that changes.

### 3.4 Content rating (IARC questionnaire)

**Why:** produces the age ratings shown per territory (ESRB, PEGI, USK,
etc.). It rates the **content** of the app.

**Where:** App content → Content rating → Start questionnaire.

**Choose:**
- Email address: yours
- Category: **Reference, News, or Educational** → or **Health & Fitness** if offered as a distinct category in the current questionnaire
- Violence: **No** to all
- Sexuality: **No** to all
- Language: **No**
- Controlled substances: **No**
- Gambling / simulated gambling: **No**
- **Does the app allow users to interact or exchange content?** — see below
- Shares user location: **No**
- Allows purchase of digital goods: **Yes**
- Collects personal information: **Yes**

**The user-interaction question deserves care.** FormAI has squads, friends,
an activity feed and a leaderboard. Users can see other users' display
names and presence events, and can send friend requests. There is **no free
text**, **no chat**, **no photo sharing** — the feed carries structured
events only, and this was a deliberate design decision precisely to avoid
a moderation surface.

Answer **Yes, users can interact**, then answer the follow-ups accurately:
users can share their profile name; the app does **not** share location;
content is **not** unmoderated free text. Under-declaring interaction is a
misrepresentation; over-declaring it drags your rating upward for no reason.

> ### ✅ A correction to an earlier internal report
> `FINAL_GOOGLE_PLAY_PRODUCTION_AUDIT.md` called the **PEGI 3** rating a
> "contradiction" with the app's in-app 18+ gate and recommended re-taking
> the questionnaire to produce a higher rating. **That framing was wrong and
> should not be acted on.**
>
> IARC rates *content*. A fitness app with no violence, no sexuality and no
> profanity legitimately rates 3+ / Everyone, and answering the content
> questions dishonestly to force an adult rating would itself be a
> misrepresentation.
>
> The 18+ requirement is enforced by a **different setting** — Target
> audience (§3.5) — and optionally by Restrict Minor Access. Do that
> instead. The genuine risk was never the PEGI number; it was a Target
> audience that included minors while the app gates at 18+.

**Mistakes:**
- Answering as though the app were adult content because of the age gate. Wrong axis.
- Skipping the questionnaire. Without it the app cannot be published at all.
- Not re-taking it after adding a feature that changes the answers (e.g. if you ever add chat).

**Rejection risk:** Medium. An inaccurate rating is an enforcement trigger
independent of everything else, and the fix requires a re-review.

### 3.5 Target audience and content

**Why:** decides whether Families policy applies and whether children see
your app. **This is where the 18+ requirement is actually expressed.**

**Where:** App content → Target audience and content.

**Choose:**
- Target age groups: **18 and over ONLY.** Do not tick 13–15 or 16–17.
- "Could your app be unintentionally appealing to children?" → **No**, and make sure the store assets support that answer: adults only, no cartoon mascots, no bright playful styling, no toy-like iconography.
- Families policy: will then show as **not applicable**. Good.
- Consider enabling **Restrict Minor Access** if offered in your territories — it blocks under-18 Google accounts from installing, which aligns the store with the in-app gate exactly.

**Mistakes:**
- Ticking a younger bracket "to reach more users". It triggers the entire Families policy — a separate, much stricter regime with its own ads, content and data rules — and FormAI would fail several of them immediately.
- Store graphics that read as child-friendly while you declare 18+.

**Rejection risk:** **High** if mis-set. Families policy violations are
among the harshest enforcement outcomes.

### 3.6 Data safety

**Why:** it becomes the public "Data safety" card on your listing. Google
audits it against your privacy policy **and against your app's observed
network traffic**. A mismatch is one of the most common causes of rejection
and of post-launch suspension.

**Where:** App content → Data safety.

> ### 🔴 THE PREVIOUSLY PREPARED ANSWERS ARE WRONG — DO NOT USE THEM
> `docs/store/PLAY_CONSOLE_ANSWERS.md` §1 states that body metrics are
> *"stored ONLY in on-device SharedPreferences; never transmitted"* and lists
> **no third-party sharing at all**.
>
> Both are false, and the production audit proved it:
> - `BodyMetricsRepository` **syncs every measurement to Supabase**
>   (`public.body_metrics` — weight, waist, chest, arm, thigh, hip).
> - The AI coach **transmits the user's first name, age, height, weight,
>   activity level, goal, streak, plan progress and 30-day weight/waist
>   change to Anthropic** in the United States.
>
> The privacy policy was corrected on 6 August 2026 to say so. **Data safety
> must now match the corrected policy**, which means declaring health data as
> both *collected* and *shared*.

**Choose — data types:**

| Data type | Collected | Shared | Ephemeral | Required/Optional | Purpose |
| --- | --- | --- | --- | --- | --- |
| Personal info → **Name** | **Yes** | **Yes** | No | Optional | App functionality *(sent to Anthropic with coach messages)* |
| Personal info → Email address | Yes | No | No | Optional* | App functionality, Account management |
| Personal info → User IDs | Yes | Yes | No | Required | App functionality, Analytics |
| **Health & fitness → Fitness info** | **Yes** | **Yes** | No | Required | App functionality *(Supabase sync; profile context to Anthropic)* |
| App activity → App interactions | Yes | Yes | No | Optional | Analytics *(PostHog, opt-in only)* |
| App info & performance → Crash logs | Yes | Yes | No | Optional | Diagnostics *(Sentry, opt-in only)* |
| App info & performance → Diagnostics | Yes | Yes | No | Optional | Diagnostics *(Sentry, opt-in only)* |
| Financial info → Purchase history | Yes | Yes | No | Required for Pro | App functionality *(Play + RevenueCat)* |

\* Email is *optional* because guest mode is a real, complete path — a user
can use FormAI without ever creating an account.

**Do NOT declare (verify each before ticking nothing):**
- **Photos and videos.** Camera frames are processed on-device by ML Kit and never transmitted — Play's on-device-processing exemption applies. Progress photos are stored on the handset only; `ProgressPhotoRepository` contains no networking code at all and a release-gate test enforces that.
- **Audio.** `RECORD_AUDIO` is removed from the merged manifest.
- Location, contacts, calendar, SMS, files — never requested.

**Security section:**
- Data encrypted in transit: **Yes** (HTTPS only; cleartext disabled)
- Users can request data deletion: **Yes**
- Deletion URL: `https://d2srybp77lgcpy.cloudfront.net/delete-account.html`

**Mistakes:**
- Declaring "not collected" for anything that leaves the device. If it hits your server, it is collected — even if you delete it immediately.
- Confusing "shared" with "sold". **Shared** means transferred to a third party, including your own processors like Anthropic and Sentry. Almost everyone under-declares this.
- Leaving the form as previously prepared. Google re-audits live apps forever; a mismatch found six months from now can suspend a shipping app.

**Rejection risk:** **Critical**, and uniquely dangerous because it persists
after launch.

### 3.7 Data deletion URL

**Why:** Play requires **both** an in-app deletion path **and** a web URL
that works for people who have already uninstalled.

**Where:** App content → Data deletion (may appear inside Data safety
depending on console version).

**Choose:** `https://d2srybp77lgcpy.cloudfront.net/delete-account.html`

**Verify:** it returns HTTP 200 (it does — deployed and checked 6 Aug 2026),
loads without a login, and explains both the in-app route and the email
route.

**Mistakes:** pointing this at the privacy policy. The earlier prepared
answers did exactly that. Google wants a page whose *purpose* is deletion.

**Rejection risk:** **High.** This is a named, checkable requirement.

### 3.8 Health apps declaration

**Why:** mandatory for every app with health features, on every track,
since August 2024. Not completing it blocks publishing.

**Where:** App content → **Health apps**.

**Choose:**
- Does your app have health features? **Yes**
- Category: **Health & Fitness** → tick **Activity and Fitness** and **Nutrition and Weight Management**
- Is it a medical device? **No**
- Does it use Health Connect? **No** — FormAI does not integrate it
- Is it for health-subject research / clinical trials? **No**
- Attestations: privacy policy present ✅ · prominent in-app consent before collection ✅ (age gate → consent screen, both analytics toggles default **off**) · no ads ✅ · minimal permissions ✅

**Mistakes:**
- Skipping it because "we're just a fitness app". Fitness is explicitly in scope.
- Declaring Health Connect because it sounds good. Declaring an integration you do not have is a misrepresentation, and Health Connect declarations carry extra data-justification requirements.
- Ticking "medical device". You are not one, and that answer routes you into regulated-software review.

**Rejection risk:** **High** — it is a hard publishing gate.

### 3.9 Government apps / financial features / news

**Where:** App content, lower down.

**Choose:** **No** to all three. FormAI is none of them.

### 3.10 Advertising ID

**Where:** App content → Advertising ID.

**Choose:** **No, my app does not use advertising ID.**

**Verify:** no ad SDK; PostHog is configured without a persistent
advertising identifier and the privacy policy says so. If a future SDK pulls
in the `AD_ID` permission, this answer must change and the manifest must
declare it.

### 3.11 Permissions review

**Why:** Play requires every permission to be necessary for a
user-facing feature, and asks for a declaration for sensitive ones.

**Where:** partly automatic from the manifest; sensitive permissions raise a
declaration form during release.

**FormAI's 13 permissions, and the justification for each:**

| Permission | Why it is there |
| --- | --- |
| `CAMERA` | Live pose/form analysis — the core feature |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Supabase, coach, content sync |
| `POST_NOTIFICATIONS` | Daily reminder the user schedules themselves |
| `RECEIVE_BOOT_COMPLETED` | Re-arm those reminders after a reboot |
| `VIBRATE` | Haptics during a set |
| `WAKE_LOCK` | Keep the screen alive mid-workout |
| `com.android.vending.BILLING` | Subscriptions |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Optional app lock |
| `c2dm.permission.RECEIVE` | Notification delivery |
| `WRITE_EXTERNAL_STORAGE` (maxSdk 28) | Legacy save path on old Android |
| `READ_EXTERNAL_STORAGE` | Legacy read path |

**Two housekeeping notes, neither blocking:**
- `USE_FINGERPRINT` was deprecated at API 28 and is superseded by `USE_BIOMETRIC`. Harmless, but it will show up in a permissions audit.
- `READ_EXTERNAL_STORAGE` carries no `maxSdkVersion`. On targetSdk 36 it does nothing. Bounding it would be tidier. **Do not change the manifest for this release** — it is cosmetic and this build is verified.

**No declaration form is required:** FormAI requests no All Files Access, no
SMS/Call Log, no background location, no `QUERY_ALL_PACKAGES`. Those are the
four that trigger the heavyweight declarations.

**Mistakes:** adding a permission "for later". Every unused sensitive
permission is a question you will be asked to answer.

---

## 4 · Monetization

**Where:** Monetize → Products → **Subscriptions**

### 4.1 Create the subscription products

**Why:** the paywall renders whatever the store returns. Nothing is
hardcoded — `price_format.dart` reads the store's own strings — so a product
that is not Active simply does not appear.

**Choose — product IDs the code and the webhook expect:**

| Product ID | Base plan | Turkish price | USD price |
| --- | --- | --- | --- |
| `formai_pro_monthly` | 1 month, auto-renewing | ₺100 | $9.99 |
| `formai_pro_3month` | 3 months, auto-renewing | ₺400 | — |
| `formai_pro_annual` | 12 months, auto-renewing | ₺1200 | $49.99 ← mark **Most Popular** |
| `formai_pro_weekly` | 1 week — **optional** | — | $3.99 |

`docs/store/PRICING_SETUP.md` is the source of truth and explains the USD
ladder in detail, including why a $2 weekly was rejected. Creating
`formai_pro_weekly` later makes a fourth card appear on the paywall **with
no app release** — that is by design.

**Benefit lines:** describe the benefit only. **Never put a price, a
duration or trial wording in a benefit line** — Play's subscription policy
prohibits it, and it is a frequent rejection.

**Free trial / intro offer:** optional. The paywall renders trial copy
**only** if the store product actually carries a zero-price introductory
offer, so adding or removing one needs no code change either way.

**Mistakes:**
- A typo in a product ID. The paywall silently shows fewer cards and you will hunt it in the app first.
- Leaving a product in Draft. Draft products are invisible to the SDK.
- Setting prices in only one currency and letting Play auto-convert. Auto-conversion produces exchange-rate numbers like `$4.37`, not prices. Set them explicitly per the ladder.

**Rejection risk:** Medium. Price/trial wording inside benefit lines is the
usual finding.

### 4.2 RevenueCat verification

**Why:** RevenueCat is the entitlement layer. If it cannot talk to Play, a
purchase succeeds and the user still sees the paywall — the worst possible
bug to ship.

**Where:** RevenueCat dashboard → Project → Apps → your Play app.

**Check:**
1. Package name is `com.emredogan.formaifit`.
2. **Play service credentials JSON uploaded and valid** (green in RC). This is a Google Cloud service account with Play Developer API access — it expires and it silently breaks.
3. Each Play product ID above is attached to a RevenueCat **Product**.
4. Every product is attached to the **`pro` entitlement**.
5. The **`current` Offering** contains the monthly / 3-month / annual packages.
6. The RevenueCat webhook points at your Supabase edge function `revenuecat-webhook`, and the function is deployed.

**Mistakes:**
- Products created in Play but never mapped in RC → paywall shows prices, purchase never unlocks Pro.
- Expired service-account credentials → entitlements stop refreshing days later.

### 4.3 Google Play Billing verification — the one test nothing can replace

**Why:** this is the only flow in the entire app that no automated check and
no code review can validate. It moves real money.

**Steps:**
1. Play Console → Setup → **License testing** → add the Google account you will test with. License testers are charged nothing and can repeat purchases.
2. That account must also be on an active test track (internal or closed) or have installed the app from Play.
3. On a real device, sign into FormAI with that account.
4. Open the paywall. Confirm: prices render in the right currency, the per-month equivalents look right (₺80,00/mo under the annual card), the "Cancel anytime" card is present, Restore purchases is present, and the auto-renewal disclosure is above the fold.
5. **Buy the monthly plan.** Confirm Pro unlocks immediately.
6. Confirm the entitlement appears in RevenueCat within a minute.
7. Force-quit, reinstall, sign in, tap **Restore purchases** — Pro must come back.
8. Cancel the subscription in Play → Payments & subscriptions. Confirm the app handles the cancelled-but-not-yet-expired state without locking the user out early.

**Mistakes:**
- Testing with the developer account that owns the Console. Its behaviour differs.
- Skipping restore. A broken restore generates refund requests and one-star reviews within days.

**Rejection risk:** Low for review; **very high for user harm**. A broken
purchase path is the fastest route to a wave of one-star reviews.

---

## 5 · Countries, pricing and distribution

**Where:** Release → Production → **Countries / regions**

**Choose:** start with **Türkiye**. Add others deliberately.

**Before adding any EEA country** you must complete the **DSA trader
declaration** (Play Console → Policy → App content, or the account-level
Payments profile, depending on console version). Selling to EU consumers
without it is a compliance problem, and it also changes what contact
information Play displays publicly about you.

**Mistakes:**
- Launching in 150 countries on day one. You get reviews in languages you cannot read, support requests you cannot answer, and pricing you never set.
- Forgetting that adding a country later is trivial; un-launching one is not.

---

## 6 · Testing and the pre-launch report

**Where:** Test and release → Pre-launch report

**Why:** Google runs your app on real physical devices in a lab and reports
crashes, ANRs, accessibility issues and security findings. It is free
QA and it runs automatically on every uploaded build.

**Choose:**
- Settings → add the **same reviewer credentials** as §3.2, so the crawler can get past the auth sheet.
- Read the report for build 38 before promoting. Expect one known finding: a native crash in `com.emredogan.formaifit:mlkit_acceleration_mini_benchmark`. That is ML Kit's own hardware-acceleration probe aborting in an isolated subprocess; the main app survives and pose detection falls back to CPU. It is not fixable in app code.

**Mistakes:** ignoring the report because the app "works on my phone". The
lab runs devices you do not own.

---

## 7 · Creating the production release

**Where:** Release → **Production** → Create new release

### 7.1 App integrity / signing

**Choose:** Play App Signing is already enrolled — nothing to do. Google
re-signs your upload with the app signing key
(`82797ef8fc27b675eed09d486377b0a9f367e232`). Both that key and your upload
key are registered against the OAuth client, which is why Google Sign-In
works on Play builds. **Do not "reset" the upload key.**

### 7.2 Upload the AAB

**Choose:** `build/app/outputs/bundle/release/app-release.aab`
· `1.0.0` versionCode **38** · 116.1 MB
· SHA-256 `f5a0143e75ad082b6ff93eaf1dfa218f3c7c8ee1bd3c0caecec14d5276302c65`

**Mistakes:**
- Uploading the APK. Production requires an AAB.
- Uploading a build with a versionCode ≤ one already on a track. Play refuses; you must rebuild with a higher number.

### 7.3 Release name

**Choose:** `1.0.0 (38)` — the default. Internal only; users never see it.

### 7.4 Release notes

**Why:** shown in the Play "What's new" section and, separately, keyed into
your own in-app What's New surface.

**Where:** the release form, per language. You must fill **tr-TR** and, if
you added it, **en-US**.

**Choose (English):**

```
• Report any AI coach reply — press and hold a message.
• Workout names, difficulty and durations now fully in English.
• Clearer subscription pricing with a per-month equivalent.
• Honest program difficulty and exercise counts.
• Various copy and layout fixes.
```

**Choose (Turkish):**

```
• Yapay zekâ koçunun herhangi bir yanıtını bildir — mesaja basılı tut.
• Antrenman adları, zorluk ve süreler artık tamamen çevrildi.
• Abonelik fiyatlarında aylık karşılığıyla daha net gösterim.
• Program zorluğu ve egzersiz sayıları artık gerçek verilerden geliyor.
• Çeşitli metin ve yerleşim düzeltmeleri.
```

**Separately — the in-app release note.** FormAI has its own What's New
screen fed from Supabase `content_releases`, **keyed to build number, not to
a date**. Publish the note for build 38 there as well; publishing it before
the rollout reaches anyone is safe and is the intended workflow, because a
user still on build 37 never sees it. See `docs/CONTENT_OPS.md` BÖLÜM II.

**Mistakes:**
- Release notes that promise features not in the build.
- Leaving the default "Bug fixes and performance improvements" — a wasted, and slightly insulting, communication slot.

### 7.5 Staged rollout

**Why:** a staged rollout limits the blast radius of a bad build. You cannot
un-ship a release; you can only halt it. Starting small is the only
protection you have.

**Choose:** **20%.**

Why 20% and not 100%: it is large enough to surface a crash within hours
(you need real volume for Android vitals to be statistically meaningful) and
small enough that four out of five users are untouched if something is
wrong. For a first production release of an app with a live LLM dependency,
a billing integration and a brand-new reporting feature, this is the right
trade.

**Then press "Apply for production"** if the console still shows that
button, and submit the release for review.

**Timeline:** first production reviews commonly take **a few days**, and can
take up to seven. Health-adjacent apps with a Data safety declaration that
includes shared health data are not fast-tracked. Do not plan a marketing
push around an exact date.

---

## 8 · After you submit — what to watch, and for how long

### 8.1 The first 48 hours

**Where:** Quality → **Android vitals** → Overview.

**Watch:**

| Metric | Play's bad-behaviour threshold | What to do |
| --- | --- | --- |
| User-perceived **crash rate** | 1.09% | Above it, halt the rollout |
| User-perceived **ANR rate** | 0.47% | Above it, halt the rollout |

**Expect one specific finding.** The ML Kit acceleration benchmark
subprocess (§6) will appear in your crash list attributed to
`com.emredogan.formaifit`. It should be classified as **not**
user-perceived, because the main process survives. If it *is* being counted
as user-perceived, or if it dominates your crash list, that changes the
calculus — halt and investigate.

**Where else to look:**
- Quality → Android vitals → **Crashes and ANRs**, filtered to versionCode 38
- **Sentry** — your own crash reporting sees things Play does not, and sees them sooner
- **Supabase logs** — a spike in 4xx/5xx from PostgREST means an RLS or schema problem reaching real users

### 8.2 Reviews

**Where:** Quality → **Reviews** → Review management.

**Do:** read every review for the first two weeks and reply to the negative
ones. Reply rate materially affects rating recovery, and the first fifty
reviews set the tone of the listing for months.

**Watch for these specific signals**, each of which maps to a known risk in
this app:
- "I paid and nothing unlocked" → RevenueCat entitlement mapping (§4.2)
- "The coach doesn't answer" → the Anthropic edge function or its API key
- "It's in Turkish" from English users → a localisation gap survived
- "Camera doesn't see me" → expected; the app needs ~2 m and good light. Consider a canned reply pointing at "Continue without the camera".

### 8.3 Policy status

**Where:** Policy → **App status** / Policy status.

Check it weekly for the first month. Google re-audits live apps
continuously, and Data safety mismatches surface here rather than as an
email you will notice.

---

## 9 · Expanding the rollout

**Where:** Release → Production → the active release → **"Update rollout"**.

**Suggested schedule, assuming vitals stay clean:**

| When | Rollout | Gate before proceeding |
| --- | --- | --- |
| Launch | 20% | — |
| +48 h | 50% | Crash rate < 1.09%, ANR < 0.47%, no billing complaints |
| +4 days | 100% | Rating not collapsing, no unresolved review theme |

**Do not** expand on the same day you launch, however good it looks. Vitals
lag; a crash that only fires on a specific OEM/Android combination needs a
day of real traffic to show up.

**Mistakes:** expanding over a weekend or the night before you are away.
Expand when you are available to halt it.

---

## 10 · Emergency rollback

Read this **before** you need it.

### What Play can and cannot do

**It cannot un-ship a build.** Users who already updated keep the bad
version. There is no remote uninstall and no forced downgrade.

**It can stop the bleeding**, three ways:

### 10.1 Halt the rollout — the fastest lever

**Where:** Release → Production → active release → **Halt rollout**.

**Effect:** immediate; no further users receive the build. Users who already
have it keep it. **This is the first thing you do, before diagnosing
anything.** It is reversible — you can resume the same rollout later.

### 10.2 Roll forward to the previous build — the actual fix

Play will not let you re-publish versionCode 38 or lower. So:

1. `git revert` the offending commit, or fix it directly.
2. Bump to `1.0.0+39` in `pubspec.yaml`.
3. Rebuild the AAB, run the gates.
4. Create a new production release at a **small** rollout (10–20%).
5. Expand once vitals recover.

**Keep the previous AAB.** If you must ship the *old* code, rebuild the
previous commit with a **higher** versionCode. That is the only way "roll
back" exists on Play.

### 10.3 Server-side mitigations — often faster than any release

FormAI can fix several classes of problem **with no app release at all**,
and in an incident that is worth remembering:

| Problem | Server-side lever |
| --- | --- |
| Coach producing bad output | Undeploy or gate the `coach-chat` edge function — the app falls back to the rule-based brain by design |
| A challenge or content drop is wrong | Edit or delete the row in Supabase; clients pick it up within the 1-hour cache window |
| A feature misbehaving | Its feature flag, if one covers it |
| A bad release note | Delete the `content_releases` row |

**Remember the cache:** content is deliberately up to **one hour stale**, and
reinstalling the app does not clear it. A server-side fix is not instant.

### 10.4 If Google suspends or rejects

- **Rejection** (pre-publish): read the exact policy cited, fix precisely that, resubmit. Do not resubmit with unrelated changes bundled in — it muddies the next review.
- **Suspension** (post-publish): the app is off the store. Use the appeal form linked in the notice, be specific and factual, and do not resubmit the same build hoping for a different reviewer.
- **Either way:** the cited policy is the only thing that matters. Fix that, not what you think they meant.

---

## 11 · Final pre-submission checklist

Print this. Tick every line.

**Store listing**
- [ ] Title is `FormAI — Fitness Koçu` — **`(Erken Erişim)` removed**
- [ ] Short description ≤ 80 chars, no keyword stuffing
- [ ] Full description contains no outcome promise, no "evidence-based", no "100% on-device AI", no invented numbers
- [ ] Icon 512×512 uploaded
- [ ] Feature graphic 1024×500 uploaded, no fake Install button, center clear
- [ ] 8 phone screenshots uploaded, **no iPhone frames**, real UI
- [ ] Tablet screenshots uploaded **or deliberately omitted**
- [ ] en-US localization added with matching graphics
- [ ] Contact email is monitored

**App content**
- [ ] Privacy policy URL set and showing "Last updated: 6 August 2026" with Anthropic named
- [ ] App access: reviewer credentials **tested on a real device**, guest mode noted
- [ ] Ads: No
- [ ] Content rating questionnaire completed, user-interaction answered accurately
- [ ] Target audience: **18 and over only**
- [ ] Data safety: **Health & fitness = collected AND shared**; Name = collected AND shared
- [ ] Data deletion URL = `…/delete-account.html`
- [ ] Health apps declaration completed (Activity and Fitness + Nutrition and Weight Management)
- [ ] Advertising ID: No
- [ ] Government / financial / news: No

**Monetization**
- [ ] `formai_pro_monthly`, `formai_pro_3month`, `formai_pro_annual` all **Active**
- [ ] No price or trial wording in any benefit line
- [ ] RevenueCat: credentials valid, products mapped, `pro` entitlement, `current` offering
- [ ] **A real license-tester purchase completed and restored on a device**

**Release**
- [ ] CI green
- [ ] AAB `1.0.0+38` uploaded
- [ ] Release notes written in tr-TR and en-US
- [ ] In-app release note published to `content_releases` for build 38
- [ ] Rollout set to **20%**
- [ ] Managed publishing reviewed — publish everything as one change

---

## 12 · What is genuinely blocking, ranked

If you only have an hour, do these:

1. **Data safety** — health data as *collected and shared*. Highest risk, and it stays risky after launch.
2. **Target audience = 18+.** One dropdown; the difference between "fine" and "Families policy violation".
3. **Health apps declaration.** A hard publishing gate.
4. **Remove `(Erken Erişim)` from the title.**
5. **Data deletion URL.** Named requirement, page is already live.
6. **App access credentials, tested.** The most common avoidable rejection.
7. **A real purchase test.** The only thing no automation covers.

---

## 13 · Things you do **not** need to do

Stated explicitly so you do not burn time:

- **Re-take the content rating questionnaire to force an adult rating.** See §3.4. The earlier internal recommendation was wrong.
- **Fix the ML Kit subprocess crash.** Not fixable in app code.
- **Fix the `PERSONEL TRAINER` typo before launch.** It is baked into image pixels, it is cosmetic, and it does not block anything. Fix it when you regenerate the hero art.
- **Upload tablet screenshots.** Optional, and dishonest ones are worse than none.
- **Add a promo video.** Optional. If you skip it, no ▶ overlay covers your feature graphic.
- **Ship a new build.** `1.0.0+38` is verified: 1524 tests, 0 analyzer issues, 7/7 gates, 35 device checks, 0 crashes.

---

## 14 · Where this supersedes `docs/store/PLAY_CONSOLE_ANSWERS.md`

That file is dated 2026-07-10 and remains a useful record. These three
sections are now wrong and this document replaces them:

| Section | What it says | Why it is now wrong |
| --- | --- | --- |
| §1 Data safety | Body metrics "never transmitted"; nothing shared with anyone | `BodyMetricsRepository` syncs to `public.body_metrics`; the coach sends profile context to Anthropic. Both confirmed in the production audit and now disclosed in the privacy policy. |
| §1 deletion channel | "Account deletion URL field: use the privacy-policy URL" | A dedicated deletion page now exists and is live. Play wants a page whose purpose is deletion. |
| §3 Content rating | Frames the 3+ rating as something to manage around | Correct as far as it goes, but the operative control is Target audience (§3.5). Do not answer content questions to manipulate the rating. |

Also note §7 lists the product IDs as `formai_pro_monthly` /
`formai_pro_3month` / `formai_pro_annual` — **those are correct**, and
supersede the `formai_pro_quarterly` name that appeared in
`FINAL_PRODUCTION_SUBMISSION_REPORT.md` §9 step 10.

---

*Written against build `1.0.0+38`, commit `db93e22`. Play Console labels
move — if a section name here does not match what you see, search the
console for the nearest equivalent rather than skipping the step.*
