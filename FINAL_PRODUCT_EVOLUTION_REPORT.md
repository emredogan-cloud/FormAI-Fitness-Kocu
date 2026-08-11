# FormAI — Final Product Evolution Report

**Programme:** `FORM_AI_NEXT_PRODUCT_ROADMAP.md` (founder brief, 2026-08-11)
**Completed:** 2026-08-11 · **Release:** `1.0.0+40`
**Supersedes nothing.** The previous programme
(`TESTERS_COMMUNITY_PRODUCT_ROADMAP.md`) stays closed and untouched.

---

## 1. The original problems, and what they turned out to be

Three of the four workstreams had a root cause that was not the one the
brief assumed. That is the most useful thing in this report.

| reported | actual cause |
| --- | --- |
| "The Play Store icon and the installed icon are different" | The icon pipeline was **entirely correct** and faithfully rendering the wrong input. `tool/app_icon.png` still held the old *"AI FITNESS COACH"* marketing scene; the store listing had been re-cut during the ASO refresh and this side was never re-pointed. Nothing about mipmaps, adaptive layers or the manifest needed investigating. |
| "Production onboarding is extremely slow on a fresh device" | **One awaited platform call.** `await SystemChrome.setPreferredOrientations` measured **1982 ms** of a ~3.0 s first frame, against 2 ms for the dotenv load on the very next line. It is a platform-channel round trip issued while the Android main thread is still building the activity, and nothing in `main()` used its result. |
| "The app asks the user to select a language" | Device-language following **already shipped** (Phase 6 of the previous programme). Only the onboarding ask needed removing — plus one real decision: the unsupported-locale fallback was Turkish because `kSupportedLocales.first` was doing double duty as both picker order and fallback. |
| "Build an AI calorie tracker" | Genuinely new. But the risky half — a server-side Anthropic integration with the key off the device — was already built and in production as `coach-chat`. |

---

## 2. Research

Two decision documents, both ending in founder actions rather than
surveys.

**`docs/CALORIE_TRACKING_RESEARCH.md`** — recommends the hybrid
architecture. Three findings did the deciding: independent testing puts
AI calorie error at **15–25%** with a 2026 study finding a single meal off
by **345 kcal**, and the reported failure mode is composite dishes, which
is most of Turkish home cooking; `coach-chat` already solved key handling,
locale-aware prompting and error mapping; and at ~$0.004/scan, 1000 DAU
logging four meals is **~$480/month from a feature with no per-use
revenue**, scaling with success.

**`docs/FORM_AI_GROWTH_AND_ADVERTISING_STRATEGY.md`** — built on one
asymmetry: Turkey is a Tier-2 install market where the same annual
subscription sustains ~4.4× less than Germany, while Tier-1 Health &
Fitness CPI runs $4.30–5.50. Cheap installs where revenue is thin,
expensive installs where it isn't. Recommends **not starting paid yet** —
without D7 retention and trial-to-paid by locale, every campaign is
unreadable — and puts a measurement gate in front of the first dollar.
**No in-app advertising was proposed or built.**

---

## 3. What shipped

| phase | outcome | commit |
| --- | --- | --- |
| 0 | Baseline audit, roadmap, traceability matrix | — |
| 1 | Canonical F icon everywhere | `1e80cfb` |
| 2 | Cold start 4830 ms → ~2784 ms | `bc447e2` |
| 3 | Device language automatic; onboarding ask removed | `33056cd` |
| 4–5 | Two research documents | `5da96fa` |
| 6 | Migration 028 + `food-scan` edge function | `458cf70` |
| 7–10 | Dashboard, navigation, capture, recognition, correction | `4626d51` |
| 11–14 | Barcodes, post-save editing, history, EXIF | `3bda53d` |
| 15 | Final QA, `1.0.0+40`, release APK + AAB | this commit |

### Decisions worth keeping

**`meal_items` carries a denormalised `user_id`.** The natural policy —
"you may read an item if you own its parent meal" — is the exact shape
that took five tables down for a day in migration 023. Every policy in 028
is `auth.uid() = user_id` against a column on the row itself, with a
trigger that overwrites it from the parent so it cannot be forged.

**The scan quota lives in Postgres, not the edge function.** The limit
depends on entitlement, and only the database knows that authoritatively —
`pro_entitlements` is already maintained server-side by the RevenueCat
webhook. It checks `expires_at` as well as `is_active`, because migration
003 documents that a CANCELLATION leaves `is_active` true through the
paid-up period; `is_active` alone would keep granting 20 scans to a lapsed
subscriber. `claim_food_scan` takes a transaction-scoped advisory lock —
count-then-insert without one is a race two concurrent requests both win.

**The quota day comes from `now()`, never from the request.** A
client-supplied date means a loop with a different date each call has
infinite scans. It is evaluated in `Europe/Istanbul` so the reset lands at
local midnight for the home market.

**Barcodes are not gated by the quota**, and the check moved to *after*
the source choice so it gates only the paths that spend money. Reading a
barcode costs no model call, so it stays available to a user who has spent
every AI scan — which is what keeps the free tier usable rather than
merely limited.

**Navigation kept five tabs.** The brief's layout had no slot for
Community. Calories went inside Nutrition as a segment instead, with the
recipe view built lazily so a user who only opens Calories never pays for
the recipe catalogue's fetch.

---

## 4. Database

`supabase/migrations/028_calorie_tracking.sql`, **applied to production**.
Migrations are now 001–028 (016 deliberately unwritten).

`meal_entries` · `meal_items` · `food_scan_log`, all with RLS; two triggers
(user-id sync, totals recalculation); four functions
(`food_scan_daily_limit`, `food_scan_quota`, `claim_food_scan`,
`settle_food_scan`).

`supabase/functions/food-scan/` **deployed**.

---

## 5. AI cost controls

| control | value |
| --- | --- |
| model | `claude-haiku-4-5`, env-overridable |
| image | 1024 px long edge, JPEG q80, downscaled on-device |
| body cap | ~1.5 MB, rejected server-side |
| daily scans | free **2**, Pro **20**, enforced in Postgres |
| timeout | 20 s, then a typed error |
| retries | 1, only on 5xx/timeout — never on a refusal or a 400 |
| refunds | a failure that is ours returns the scan slot |
| caching | **deliberately none** — the system prompt is below Haiku 4.5's 4096-token cacheable minimum, so a breakpoint would pay a write premium and read nothing |

The order of operations in the function is itself a cost control: verify
JWT → validate image → claim slot → **then** call the model. Every
rejection that can happen for free happens before the money is spent.

---

## 6. Privacy and security

**EXIF stripping is now true by construction, not by side effect.** It
had been resting on `image_picker`'s resize re-encoding the file — almost
certainly enough, and "almost certainly" is not a basis for a policy
claim. `stripJpegMetadata` walks the JPEG segment table and drops every
`APPn` and `COM` marker (EXIF/GPS, ICC, IPTC, JFIF) while preserving
quantisation tables, frame headers and the entropy-coded scan byte for
byte. Seven tests, including one against a JPEG ImageMagick wrote and
re-decoded after stripping.

**Images are not retained.** The photo is sent, analysed, and not stored;
only the structured nutrition row persists.

**The model key never reaches the device.** `food-scan` forwards the
caller's own token rather than holding a service-role key — it never needs
to act as anyone but the caller.

**Verified adversarially against production:** user B injecting an item
into A's meal → `42501` (the trigger rewrote `user_id`, then the policy
rejected it); B writing `food_scan_log` directly → `42501`; a replayed
settle refunding twice → does not; B settling A's claim → does not.

> **⚠️ Founder action, outstanding.** The image leaves the device and is
> processed by a third-party model provider. **The privacy policy must say
> so, in both languages, before this ships.** The founder has taken this
> on manually. No code change substitutes for it.

---

## 7. Localization

88 new keys × 2 locales, all through ARB. Turkish is the authored copy;
English is the translation. Gates green: `arb_coverage --strict`,
`check_hardcoded_strings`, `gen_pseudo_localizations --check`.

Walked on a physical device in **both** languages. Food names stay in the
language they were captured in, which is correct — they are stored user
data, not chrome.

---

## 8. Tests

**1551 passing**, up from 1505 at the start of the programme.

New coverage is chosen for what breaks *silently*: confidence degrading
upward, a kJ-only European product reading as zero calories, a scan
failure collapsing into the wrong user-facing message, and a startup
regression no widget test can observe.

`test/startup/boot_critical_path_test.dart` is a **source** assertion on
purpose — `testWidgets` never runs `main()`, mocks the platform channel to
answer instantly, and cannot reproduce a busy Android main thread. Every
test that could observe that bug is one CI cannot run.

---

## 9. Device validation

Redmi Note 8 (Android 11), against production Supabase.

| checked | result |
| --- | --- |
| Icon: launcher, recents, App Info | F icon, matching the store |
| Cold start, release, cleared data | **3017 / 2579 / 2541 ms** (baseline 4830) |
| Locale `tr-TR` / `de-DE` / `en-US` | Turkish / **English fallback** / English |
| Portrait lock after un-awaiting it | `user_rotation=1` left the app at ROTATION_0 |
| Manual entry | ring 320, Kahvaltı 320, quota **unchanged** |
| AI scan of a mixed plate | five items in Turkish; oily pilav `low`, chicken/potatoes `medium`, white cheese `high` |
| Saving a scan | ring flipped to the over-target gradient; quota 2 → 1 |
| Post-save edit | 380→300, dot red→green, meal total recomputed, caveat line disappeared |
| History | average 1660 from one logged day — **not** 118 |
| Barcode scanner | camera preview, reticle, Turkish hint, permission prompt |
| Open Food Facts, live | full product, a nameless one (correctly rejected), and a genuine miss |
| English walk | dashboard, meals, history — no untranslated keys, no overflow |
| Release build end to end | fresh account, quota resolved server-side, all surfaces render |

---

## 10. CI

**Green on `main` at `baa6979`.** All 9 gates: format, env-secret guard,
analyze, hardcoded strings, ARB coverage, recipe translation audit,
pseudo-localisations, directional layout, tests + coverage.

**Two commits in this programme went red and are red in history.**
`3bda53d` and `6bb9c45` both failed on the same defect, and it was mine:
the EXIF test cross-checks the stripper against a JPEG ImageMagick wrote,
and guarded for ImageMagick's absence with
`if (made.exitCode != 0) markTestSkipped`. That is the wrong shape —
`Process.run` raises `ProcessException` when the executable cannot be
found, so the guard never executed on a machine without ImageMagick. It
passed locally for precisely the reason it failed on CI: this machine has
ImageMagick and the runner does not. A guard that only runs on machines
that don't need it is not a guard.

Fixed in `baa6979` and verified in both directions rather than assumed —
with the binary renamed to something nonexistent the suite reports
`+6 ~1` and passes; with it restored the test actually runs and reports
`+7`. The release artifacts were then rebuilt from the green commit.

Two gates also caught real defects during this work, and both were fixed
rather than suppressed: a `Positioned(left:)` in the barcode overlay, and
the Open Food Facts protocol constants.

---

## 11. Known limitations

**Production-ready:** everything in §3.

**Verified partially:**
- **Barcode decode from a physical package was not tested.** The screen,
  camera preview, permission flow and reticle were verified on device, and
  the Open Food Facts lookup was verified against the live API with three
  real barcodes. The camera-to-barcode decode step itself needs a real
  package in front of a phone.

**Intentionally unimplemented:**
- Image retention and re-analysis — the MVP stores no images by design.
- TürKomp integration — licence unconfirmed; the MVP was designed not to
  block on it. Open Food Facts sits behind `FoodDatabase`, and
  `FoodDatabaseChain` exists so a Turkish source can be put *in front* of
  it without touching a call site.
- Multi-photo scanning, restaurant menus, connected scales.

**Founder / external:**
- **The privacy policy update (§6). This is a ship blocker.**
- The live Play Store 512 icon still carries a 1 px light-grey column down
  its right edge (measured mean 38 against 8.8 interior) — the same defect
  class as the bottom "white stripe" fixed in `b216fb9`, which was fixed
  on that edge only. The app now shaves it; the listing needs a re-upload.
- `ANTHROPIC_API_KEY` in the Supabase **function** environment.
- `photos/First_opening.png` (1.9 MB) appears unreferenced and ships in
  every install. **Unverified — left alone deliberately.**

---

## 12. Future roadmap

1. Read the onboarding funnel data. `onboardingStepCompleted` fires on all
   19 steps and has been collecting the whole time. It will name the step
   losing the most users, and that is worth more than any channel decision
   in the growth document.
2. Turkish free tools (BMR/TDEE/macro) on the existing `web/` — they rank
   for exactly the queries a future user types.
3. Barcode field test, then consider a Turkish composition database in
   front of Open Food Facts.
4. Watch `was_edited` on `meal_items`. A food with a high edit rate is one
   the prompt or the nutrition source is wrong about; that flag is the
   feature's most useful diagnostic and nothing reads it yet.

---

## 13. Final artifacts

| | |
| --- | --- |
| version | **1.0.0+40** |
| built from | `baa6979` (CI green) |
| APK | `build/app/outputs/flutter-apk/app-release.apk` — 155.2 MiB |
| **AAB** | **`build/app/outputs/bundle/release/app-release.aab` — 126.9 MiB** |
| tests | 1551 passing |
| gates | 9 / 9 green |
| migrations | 001–028, applied |
| edge functions | `coach-chat`, `revenuecat-webhook`, `food-scan` |
| device validation | passed — see §9 |
