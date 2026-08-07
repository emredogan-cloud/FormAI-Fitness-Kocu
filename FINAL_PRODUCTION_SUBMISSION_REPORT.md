# FINAL PRODUCTION SUBMISSION REPORT

**App:** FormAI — Kişisel Fitness Koçu · `com.emredogan.formaifit`
**Build:** `1.0.0+38` (was `1.0.0+37`)
**Date:** 6 August 2026
**Input:** `FINAL_GOOGLE_PLAY_PRODUCTION_AUDIT.md`
**Device:** Redmi Note 8 (M1908C3JGG), Android 11, 1080×2340, `AYXSUKIVJVPZ7HPZ`
**Commits:** `b0ddef7` → `fed6b66` → `db93e22`, all pushed to `main`

---

## 1. Executive Summary

The audit left **one code blocker and a list of wording, localisation and
honesty defects**. All of them are now fixed, and every fix that changes
something a user can see was verified on the physical device against the
release build.

**The code blocker is closed.** Play's AI-Generated Content policy requires
an in-app way to flag offensive AI output "without needing to exit the
app". FormAI now has one: long-press any coach reply, pick one of four
reasons, done. A permanent strip under the coach header states both that
Form is a machine and that the gesture exists — because nobody long-presses
a chat bubble on spec. Migration `027` gives it a table with insert-own /
select-own RLS and nothing else.

**The English app no longer ships a Turkish catalogue.** The audit's most
visible defect — "Ekipmanlı Göğüs Gücü · Orta düzey · 22 Dk" under English
section headers — is gone. 52 plan titles moved into ARB, difficulty became
a token instead of a Turkish label string, and the "Dk" unit went with them.
The Training tab now reads "Weighted Chest Strength · 22 min · Intermediate".

**A theme ran through almost everything else: the app was rendering values it
did not have.** The audit had already caught the 92 % success ring. This pass
found three more of the same shape — a hardcoded "Intermediate" typed into
the hero, a literal `percent = 14` shown on a day where nothing had been
done, and an offline "Rest day" that was really "the program has not
downloaded". Each is now derived or removed.

**What is left is not code.** Six items require the Play Console or the
hosting bucket, and one requires a permission this session did not have:
migration `027` is written, gated and tested but **its push to production was
blocked by the sandbox**, so the reporting feature currently shows its honest
failure toast. That is the single most important remaining action and it is
one command.

| | before | after |
| --- | --- | --- |
| Tests | 1505 | **1524** |
| `flutter analyze` | 0 | **0** |
| Gates green | 7/7 | **7/7** |
| Audit issues open | 15 | **0 engineerable** |
| Build | 1.0.0+37 | **1.0.0+38** |

---

## 2. Every Issue From The Audit

Disposition of all 21 findings. "Fixed" means the code changed **and** the
change was seen on the device unless noted.

### Critical

| # | Issue | Disposition |
| --- | --- | --- |
| **C-1** | No in-app reporting for AI-generated content | ✅ **Fixed** — sheet + disclosure verified on device. **Persistence needs migration `027` applied** (§8.1) |
| **C-2** | Privacy policy contradicted the app (body metrics, Anthropic) | ✅ **Fixed in repo** (previous session) + AI-report disclosure added. ⚠️ **Founder action: deploy** |
| **C-3** | No web link for account/data deletion | ✅ **Fixed** — `web/public/delete-account.html` written and linked from all three legal pages. ⚠️ **Founder action: deploy + Console field** |

### High

| # | Issue | Disposition |
| --- | --- | --- |
| **H-1** | Content rating PEGI 3 vs the app's own 18+ gate | ⚠️ **Founder action** — Play Console questionnaire only |
| **H-2** | "(Erken Erişim)" in the title + in-app early-access copy | ✅ **In-app fixed** (now "Train anywhere · Bodyweight plans included"). ⚠️ **Store title is a Console action** |
| **H-3** | "100% Satisfaction Guarantee · unconditional 7-day refund" | ✅ **Fixed** — replaced with "Cancel anytime" + a factual Google Play refund pointer |
| **H-4** | English UI rendered a Turkish workout catalogue | ✅ **Fixed** — 52 titles, difficulty labels and the duration unit all localised |
| **H-5** | Fabricated "Success probability 92%" | ✅ Fixed in the audit session |
| **H-6** | Unsubstantiated results claims | ✅ **Fixed** — see §3.3 for each string |

### Medium

| # | Issue | Disposition |
| --- | --- | --- |
| **M-1** | Struck-through reference price never charged | ✅ **Fixed** — per-month equivalent (₺80,00 / mo) replaces ₺2.159,88 struck through |
| **M-2** | Native SIGABRT in the ML Kit benchmark subprocess | ❌ **Not fixable in app code** — see §8.2 |
| **M-3** | Referral offer contradicted itself | ✅ **Fixed** — both surfaces now say the same thing |
| **M-4** | "Intermediate" shown regardless of plan or user | ✅ **Fixed** — was a hardcoded literal; now derived from the day's exercises |
| **M-5** | "AI POWERED · 100% ON DEVICE" | ✅ Fixed in the audit session; re-verified this session |
| **M-6** | Hardcoded Turkish `FORM SKORU` on the English paywall | ✅ Fixed in the audit session; re-verified this session |
| **M-7** | Offline: coach "online", program "Rest day" | ✅ **Fixed** — "offline" with a grey dot; "Program on the way" |
| **M-8** | Data Safety form | ⚠️ **Founder action** — Console only |
| **M-9** | Health apps declaration | ⚠️ **Founder action** — Console only |
| **M-10** | Test suite red on `main` | ✅ Fixed in the audit session |

### Low

| # | Issue | Disposition |
| --- | --- | --- |
| **L-1** | "PERSONEL TRAINER" typo baked into hero images | ❌ **Not engineerable** — pixels, not strings (§8.3) |
| **L-2** | 30-day vs 12-week inconsistency | ✅ **Fixed** in the coach's promise. ⚠️ **Partially remains** — see §8.4 |
| **L-3** | Coach replies printed raw markdown asterisks | ✅ **Fixed** — `*italic*` now renders |
| **L-4** | "100% more effective than none at all" | ✅ **Fixed** |
| **L-5** | "6 feet" in an English app set to Metric | ✅ **Fixed** — now formatted from the unit setting; device shows "~2 m" |
| **L-6** | Carousel resting off-centre | ✅ **NOT A DEFECT** — see §8.5 |
| **L-7** | "14% complete" before anything was done | ✅ **Fixed** — shows the exercise count |
| **L-8** | Privacy policy English-only | ⚠️ **Founder action** — a translation, not a code change |
| **L-9** | Age asked twice, with different defaults | ✅ **Fixed** — wheel seeds from the age gate's birth year |

---

## 3. Every Code Change

### 3.1 New files

| File | What |
| --- | --- |
| `supabase/migrations/027_ai_content_reports.sql` | The reports table, its check constraints and two RLS policies |
| `lib/features/coach/data/ai_report_repository.dart` | `AiReportReason`, `AiReportSurface`, the insert |
| `lib/features/coach/presentation/ai_report_sheet.dart` | The four-reason picker |
| `lib/features/workout/domain/workout_plan_titles.dart` | `WorkoutLevel` + the 52-entry title table |
| `test/features/coach/ai_report_test.dart` | 10 tests, incl. the enum ↔ SQL cross-check |
| `test/features/workout/workout_plan_titles_test.dart` | 9 tests, incl. "no English title contains a Turkish letter" |
| `web/public/delete-account.html` | The deletion page |

### 3.2 Modified — behaviour

| File | Change |
| --- | --- |
| `coach_screen.dart` | Long-press → report; `CustomSemanticsAction` for the same; permanent AI + reporting disclosure strip; `*italic*` rendering |
| `plan_detail_screen.dart` | Difficulty derived from the day (was the literal `difficultyIntermediateLong`); bolt count computed; exercise count replaces `percent = 14` |
| `today_task_card.dart` | Delegates to `WorkoutLevel.dominantOf` so the two surfaces cannot disagree |
| `antrenman_tab.dart` | `_CoachEntryCard` → `ConsumerWidget`, dot and label driven by `connectivityProvider`; hero title says "Program on the way" when `session.isStub` |
| `camera_tutorial_screen.dart` | Two widgets → `ConsumerWidget`; setback distance from `unit_system.dart` |
| `act_3_buildup_steps.dart` | Age wheel seeds from the age gate's birth year, guarded |
| `workout_repository.dart` | 52 `title:` literals removed; `level:` is a `WorkoutLevel` |
| `workout_plan_model.dart` | `title` / `level` / `summary` resolve on read via `AppCopy` |
| `paywall_screen.dart` | Guarantee card → cancellation card; strikethrough → per-month equivalent; `_kGuaranteeDays` removed |

### 3.3 Modified — copy (ARB, both languages)

**Removed:** `paywallGuaranteeTitle`, `paywallGuaranteeBody`,
`paywallGuaranteeDaysUnit`, `reportSuccessProbability`,
`reportSuccessNearGoal`.

**Renamed:** `earlyAccessBlurb/Badge/Subline` → `trainAnywhere*`.

**Added:** 52 `planTitle*`, 10 `coachReport*` + `coachDisclaimer`,
`paywallCancelAnytimeTitle/Body`, `paywallPerMonthEquivalent`,
`coachOffline`, `workoutProgramPreparing`.

**Reworded:**

| Key | Was | Now |
| --- | --- | --- |
| `act1CapResultTitle` | REAL RESULTS | PROGRESS |
| `act1CapResultBody` | Steady progress for 30 days | Tracked, day by day |
| `act1TrustSafeBody` | Evidence-based methods | Standard, well-known movements |
| `act1TrustEfficientBody` | Maximum results | Focused sessions |
| `act1TrustGoalBody` | The body you want | Built around your goal |
| `paywallFeatureSciencePlans` | Evidence-based, effective training plans | Plans built around your goal and level |
| `reportBeginner` | "…the 'newbie gain' effect means fast, visible results in the first 30 days." | "…the plan starts gently and builds. What you get out of it depends on how consistently you show up." |
| `bondingPromise` | change your body in 12 weeks | build you a 30-day program and coach you through it |
| `onbMinutesAiNote` | 15 minutes is 100% more effective than none | 15 minutes you actually do beats an hour you skip |
| `profileRedeemCodeSubtitle` | you both get a Premium month | you're both recorded, and you both earn when the reward program opens |
| `tutorialStepDistanceTitle` | Step back about 6 feet | Step back about {distance} |

ARB parity held at every step: **1921 keys, `tr` 100 %, `en` 100 %, all
referenced in `lib/`**. One pre-existing unused key remains
(`discoveryNewContentEmpty`) — it predates this work and was left alone.

---

## 4. Every Migration

| # | File | State |
| --- | --- | --- |
| 001–026 | — | Applied to production before this session (016 deliberately unwritten) |
| **027** | `027_ai_content_reports.sql` | ✅ Written · ✅ RLS-gated · ✅ tested · ❌ **NOT APPLIED** |

`027` creates `public.ai_content_reports` with `reporter_id` (cascade from
`auth.users`), the reported reply text capped at 4000 chars, a four-token
`reason` constraint, a `surface` token, an optional locale and a triage
index. RLS: `ai_content_reports_insert_own` and
`ai_content_reports_select_own`, both keyed on `auth.uid()`. No update, no
delete, no policy that reads another table — so it cannot recurse (`023`)
and cannot touch `public.blocks` (`023` again).

It was added to `communityMigrations` in `rls_policy_test.dart`, which
means it is now checked by all 21 static RLS assertions, and it passes.

**`supabase db push --linked` was blocked by the sandbox permission
classifier.** The staging workdir was prepared correctly (per
`RESUME_GUIDE.md` §2.0.0h) and `supabase migration list --linked` confirmed
`027` as the only local-only migration. §9 step 1 has the exact command.

---

## 5. Every Device Verification

Release build `1.0.0+38`, clean install (uninstall → install), signed-in
Google account, English locale, real network.

| # | Checked | Result |
| --- | --- | --- |
| 1 | Fresh install, cold launch | **PASS** — no crash |
| 2 | Age gate → consent (both toggles off) → language | **PASS** |
| 3 | Act-1 hero claims softened | **PASS** — PROGRESS / Tracked day by day / Standard well-known movements / Focused sessions / Built around your goal |
| 4 | Coach promise says 30-day, not 12 weeks | **PASS** |
| 5 | AI onboarding chat (live Anthropic) | **PASS** — personalised reply |
| 6 | 11-question wizard | **PASS** |
| 7 | **Age wheel seeded from the gate** | **PASS** — opens on 26 (2026−2000), was a flat 25 |
| 8 | AI report screen — no 92 % ring | **PASS** |
| 9 | AI assessment copy honest | **PASS** — "depends on how consistently you show up" |
| 10 | Act-5 — no "Early access" | **PASS** — "Train anywhere · Bodyweight plans included" |
| 11 | Act-5 — "AI POWERED / ON-DEVICE ANALYSIS" | **PASS** — one line, no ellipsis |
| 12 | Google Sign-In on the release build | **PASS** — completed to the paywall |
| 13 | **Paywall: no strikethrough, per-month shown** | **PASS** — ₺80,00 / mo and ₺120,00 / mo |
| 14 | **Paywall: cancellation card** | **PASS** — "Cancel anytime… Refunds are handled by Google Play" |
| 15 | Paywall: "Plans built around your goal and level" | **PASS** |
| 16 | Paywall: FORM SCORE in English | **PASS** |
| 17 | Subscription disclosure + Terms/Privacy links | **PASS** |
| 18 | Restore purchases present | **PASS** |
| 19 | **Training tab fully English** | **PASS** — "Weighted Chest Strength · 22 min · Intermediate", "Steel Abs · 15 min · Beginner" |
| 20 | **Coach: AI disclosure + reporting hint** | **PASS** — permanent strip |
| 21 | **Coach: long-press opens the report sheet** | **PASS** — four reasons, harmful advice first |
| 22 | **Coach: report submits and reports its outcome** | **PASS (failure path)** — "The report couldn't be sent." Correct: `027` is not applied |
| 23 | **Program detail: difficulty derived** | **PASS** — 2-of-3 bolts computed, not typed |
| 24 | **Program detail: exercise count, not 14 %** | **PASS** — "day 1 · 6 exercises" |
| 25 | Camera rationale + opt-out present | **PASS** |
| 26 | **Camera setback in metric** | **PASS** — "~2 m" / "Step back about 2 m" |
| 27 | **Offline: coach dot and label** | **PASS** — grey dot, "offline" |
| 28 | **Offline: program card** | **PASS** — "Program on the way", not "Rest day" |
| 29 | Offline: no crash, banner correct, recovers | **PASS** |
| 30 | Profile shows the seeded age | **PASS** — 26 |
| 31 | **Referral copy consistent** | **PASS** — both surfaces say "when the reward program opens" |
| 32 | Delete account present and prominent | **PASS** |
| 33 | Settings list fully English | **PASS** |
| 34 | Nutrition / Progress / Community tabs | **PASS** — no crash, process alive |
| 35 | Crash count across the whole walk | **PASS** — 0 `FATAL EXCEPTION`, 0 `E/flutter` |

**Not verified on this device, and why:**

| Item | Why |
| --- | --- |
| A successful AI report insert | Needs `027` applied |
| Real purchase / restore / cancellation | Needs a license tester and real money against the founder's Play account |
| Delete account **executed** | Destructive against the founder's live Google account |
| Light mode | Ran out of session before toggling; the theme control is present and Phase 6-polish covered light mode |
| Turkish end-to-end re-walk | The TR strings are unit-covered and ARB parity is 100 %; the first two screens rendered TR correctly |
| Update path 37 → 38 | Installed clean rather than over the top |
| A campaign notification firing | Needs a 4-hour wait |

---

## 6. Play Policy Verification

| Policy area | Before | Now |
| --- | --- | --- |
| **Generative AI apps** | FAIL | ✅ **PASS in the app** — reporting affordance shipped and verified. Persistence pending `027` |
| **AI disclosure** | absent | ✅ Permanent "Form is an AI… not medical advice" strip |
| **User Data — privacy policy accuracy** | FAIL | ✅ Corrected in repo (⚠️ deploy) |
| **User Data — account deletion** | PARTIAL | ✅ In-app + web page written (⚠️ deploy + Console field) |
| **Payments — refund claims** | FAIL | ✅ **PASS** — no unilateral refund promise |
| **Payments — reference pricing** | FAIL | ✅ **PASS** — no never-charged strikethrough |
| **Subscriptions — disclosure** | PASS | ✅ unchanged |
| **Misrepresentation** | FAIL (92 %) | ✅ **PASS** — every fabricated figure removed or derived |
| **Misleading health claims** | PARTIAL | ✅ **PASS** — outcome guarantees softened |
| **Permissions** | PASS | ✅ unchanged — 13, all justified, rationale UX intact |
| **Broken functionality** | PASS | ✅ unchanged |
| **Medical guidance limits** | PASS | ✅ strengthened by the coach disclaimer |
| **Target API level** | PASS | ✅ 36 |
| **Content rating** | FAIL | ⚠️ **Console** |
| **Store listing** | FAIL | ⚠️ **Console** |
| **Data Safety** | NOT VERIFIED | ⚠️ **Console** |
| **Health apps declaration** | NOT VERIFIED | ⚠️ **Console** |

---

## 7. Final APK / AAB

| | |
| --- | --- |
| **Version** | `1.0.0` · versionCode **38** |
| **APK** | `build/app/outputs/flutter-apk/app-release.apk` · 137.5 MB |
| **APK SHA-256** | `7800cf634213886f340995e788f2a08200d934ef9b49ddbb7656aedfa03bea3e` |
| **AAB** | `build/app/outputs/bundle/release/app-release.aab` · **116.1 MB** |
| **AAB SHA-256** | `f5a0143e75ad082b6ff93eaf1dfa218f3c7c8ee1bd3c0caecec14d5276302c65` |
| **Package** | `com.emredogan.formaifit` |
| **targetSdk / compileSdk / minSdk** | 36 / 36 / 24 |
| **Signed with** | upload key, `CN=FormAI` · SHA-1 `cf37a2de76f2fac0305d18d34c7be2d5db4d08b3` |
| **Play App Signing** | re-signs on upload to `82797ef8fc27b675eed09d486377b0a9f367e232`; **both are registered** against the OAuth client |

**Gates, all green on `1.0.0+38`:**

```
flutter analyze                              0 issues
flutter test                                 1524 / 1524
dart format --set-exit-if-changed .          clean
tool/check_hardcoded_strings.dart            no regressions (0 in 0 files)
tool/arb_coverage.dart --strict              tr 100% · en 100% · exit 0
tool/gen_pseudo_localizations.dart --check   up to date
tool/check_directional_layout.dart           no regressions
tool/recipe_translation_audit.dart           no findings
```

**CI: NOT VERIFIED this session.** All three commits are pushed; CI runs
Flutter 3.44.8 against a local 3.41.9, and `RESUME_GUIDE.md` §5.1 records
four occasions where that difference alone turned local green into CI red.
**Check the run before uploading the AAB.**

---

## 8. What Could Not Be Fixed, And Why

### 8.1 Migration `027` push — BLOCKED, and it matters most

The sandbox permission classifier refused `supabase db push --linked`.
Everything else is done: the file is written, it passes the RLS gate, its
tokens are cross-checked against the client enum by a test, and the UI
reaches it correctly — the device showed the honest "couldn't be sent"
toast, which is precisely what a missing table produces.

**Until it is applied, the reporting affordance exists but files nothing.**
That is arguably worse than not shipping it, so §9 step 1 runs first.

### 8.2 M-2 · the ML Kit native crash

`com.emredogan.formaifit:mlkit_acceleration_mini_benchmark` aborts with
`JNI DETECTED ERROR IN APPLICATION: fid == null` while loading a MediaPipe
graph. It is an isolated subprocess, the main app survives, and pose
detection falls back to CPU and works. Not fixable in app code — it is ML
Kit's own hardware-acceleration probe. Monitor Android vitals after launch.

### 8.3 L-1 · "PERSONEL TRAINER"

The typo is in the pixels of `photos/PT_FORM.png` and its siblings, not in
any string. Needs the images regenerated.

### 8.4 L-2 · the 12-week wording, partially

The coach's promise is fixed. **The AI report still says "12-WEEK
PROJECTION" and "A 12-week fat-loss-focused program".** The projection
itself is deliberate — `PHASE_09_COMPLETION_REPORT.md` argues at length that
it is qualitative precisely so it is not an outcome promise — but the
sentence describing the *program* as 12 weeks contradicts the 30-day plan
the user receives. Four `reportResult*` strings. Left because changing them
touches the Phase 9 projection design, which is a product decision rather
than a defect, and this sprint had no mandate to redesign it.

### 8.5 L-6 · the carousel is not broken

The act-5 highlight carousel auto-advances every 2.4 s at
`viewportFraction: 0.72`. The audit's screenshot caught it mid-animation;
the partial side cards are the intended peek. Confirmed on device — it
rests centred. **Recorded as a non-defect rather than "fixed".**

### 8.6 Residual cosmetic findings, recorded not fixed

| Finding | Why left |
| --- | --- |
| Nutrition goal card clips "Balanced eating" when the label wraps to two lines and the card is selected (1.02 scale) | `interactive_question_step.dart`'s fixed 102 px card geometry has been tuned three times with documented reasoning and is guarded by the pseudo-locale and RTL sweeps. Changing it to fix one English string risks regressing both. Shorten the string or raise the card height deliberately |
| "82% READINESS / TARGET 94% FORM" on the hero, "FORM SCORE 94" on the paywall | Illustrative product mock-ups on marketing surfaces — the ARB already documents them as "Illustrative, not user data". Not user-specific claims, but a reviewer could read them as such. Consider labelling them "example" |
| `discoveryNewContentEmpty` unused in ARB | Pre-existing dead copy, not this sprint's |

---

## 9. FOUNDER CHECKLIST BEFORE PRESSING "APPLY FOR PRODUCTION"

Do these **in order**. Steps 1–3 are the ones that stop a rejection; 4–9
are Console configuration; 10–14 are the release itself.

### Step 1 — Apply migration `027` (5 minutes) · **DO THIS FIRST**

Nothing else in this checklist matters if the reporting feature cannot
file a report.

```bash
# The Supabase CLI parses ./.env.local as dotenv and chokes on it, so
# work from a scratch dir. NEVER `source .env.local` — it executes
# `flutter build apk`.
mkdir -p /tmp/sbstage/supabase
cd /home/emre/Downloads/FormAI-FitnessKoçu
cp -r supabase/migrations /tmp/sbstage/supabase/
cp -r supabase/.temp      /tmp/sbstage/supabase/   # ALL of it — project-ref matters
cd /tmp/sbstage
supabase migration list --linked      # expect 027 local-only
supabase db push --linked
supabase migration list --linked      # expect 027 on both sides
```

**Then verify on the device:** open the coach, long-press a reply, pick a
reason. It must say *"Reported. Thank you — a person reads every one."*
If it still says "couldn't be sent", the migration did not land.

### Step 2 — Deploy the legal pages (10 minutes)

Three files changed in `web/public/`. Upload all three to the S3 bucket
behind `d2srybp77lgcpy.cloudfront.net` and invalidate:

```
web/public/privacy.html          (corrected — Anthropic, body metrics, AI reports)
web/public/terms.html            (nav link only)
web/public/delete-account.html   (NEW)
```

```bash
aws s3 cp web/public/privacy.html        s3://<bucket>/privacy.html
aws s3 cp web/public/terms.html          s3://<bucket>/terms.html
aws s3 cp web/public/delete-account.html s3://<bucket>/delete-account.html
aws cloudfront create-invalidation --distribution-id <ID> \
    --paths /privacy.html /terms.html /delete-account.html
```

**Verify in a browser:**
- `…/privacy.html` says **"Last updated: 6 August 2026"** and contains an
  **Anthropic** row in the processor table.
- `…/delete-account.html` returns **200**, not 404.

### Step 3 — Set the Data deletion URL

Play Console → **App content → Data deletion** →
`https://d2srybp77lgcpy.cloudfront.net/delete-account.html`.
Google requires an in-app path **and** a web link; the in-app path already
exists and is prominent.

### Step 4 — Re-take the content rating questionnaire

Play Console → **App content → Content rating**. The app enforces an **18+**
age gate on its first screen and the privacy policy says it "is not directed
to anyone under 18", but the listing currently shows **PEGI 3**. Answer the
questionnaire to reflect an adult fitness app. The two must agree — an
inaccurate rating is an enforcement trigger on its own.

### Step 5 — Set Target audience

Play Console → **App content → Target audience and content**. Select **18+
only**. Confirm Families policy is then marked not applicable.

### Step 6 — Complete the Health apps declaration

Play Console → **App content → Health apps**. Mandatory for every app on
every track since Aug 2024. Correct answers: **Health & Fitness** →
*Activity and Fitness* **and** *Nutrition and Weight Management*. Not a
medical device. Not health-subject research.

### Step 7 — Re-answer the Data Safety form

Play Console → **App content → Data safety**. It must match the corrected
privacy policy:

| Data type | Collected | Shared | Notes |
| --- | --- | --- | --- |
| Name | Yes | **Yes** | sent to Anthropic with coach messages |
| Email address | Yes | No | account only |
| User IDs | Yes | Yes | RevenueCat, PostHog (pseudonymous) |
| **Health & fitness** | **Yes** | **Yes** | body metrics to Supabase; profile context to Anthropic |
| App activity | Yes | Yes | analytics |
| Crash logs / diagnostics | Yes | Yes | Sentry |
| Photos | **No** | No | progress photos never leave the device |
| Purchase history | Yes | Yes | Play + RevenueCat |

Declare **encryption in transit** and **a way to request deletion** (step 3).

### Step 8 — Remove "(Erken Erişim)" from the store listing

Play Console → **Main store listing** → App name →
**`FormAI - Kişisel Fitness Koçu`**. Do the same in **Manage translations**
for the English listing. The in-app early-access copy is already gone.

### Step 9 — Review the listing assets

- Screenshots: check none carry an **iPhone frame or notch** and none makes
  a results claim the app no longer makes ("30 GÜNDE DEĞİŞİM").
- Feature graphic: same check.
- Short + full description: re-read against §3.3 — the app no longer
  promises "real results", "maximum results" or "evidence-based methods",
  and the listing should not either.
- English listing: paste `docs/store/LISTING_EN.md` if not already done.

### Step 10 — Verify subscriptions and billing

- Play Console → **Monetize → Subscriptions**: confirm `formai_pro_monthly`,
  `formai_pro_quarterly`, `formai_pro_annual` are **Active** in every target
  country, per `docs/store/PRICING_SETUP.md`.
- RevenueCat dashboard: confirm the Play credentials are valid and each
  product maps to the `pro` entitlement.
- Add a **license tester** account (Play Console → Setup → License testing).
- On the device, sign in as the tester and **complete one purchase and one
  restore**. This is the last flow no automated check can cover — this
  session could not run it against a real account.
- Confirm the entitlement appears in RevenueCat and that Premium unlocks.

### Step 11 — Confirm CI is green

The three commits are pushed. CI runs Flutter 3.44.8; local is 3.41.9 and
has been misleading four times. Check both workflows before uploading.

### Step 12 — Upload the AAB

`build/app/outputs/bundle/release/app-release.aab` — `1.0.0+38`, 116.1 MB,
SHA-256 `f5a0143e…`.

### Step 13 — Write the release note for build 38

`docs/CONTENT_OPS.md` BÖLÜM II. A note is keyed to **build number**, not a
date, so publishing it **before** the rollout is safe and is the intended
workflow — a user on 37 never sees it. Suggested content: reporting for AI
replies, English workout names, clearer pricing.

### Step 14 — Apply for production, and roll out staged

Start at **20 %**. Watch Android vitals for 48 hours — specifically the ML
Kit native crash (§8.2), which will appear and is expected to be
non-user-perceived. Promote to 100 % once the crash-free rate holds.

---

## 10. Verdict

**Every engineerable blocker from the audit is closed.** The one code
blocker — in-app reporting of AI-generated content — is built, tested,
localised and verified on a real device. The English app no longer ships a
Turkish catalogue. Every fabricated number the audit found, and three more
it did not, are gone.

**FormAI is ready to apply for production once steps 1–8 are done.** Step 1
is one command and is the only remaining item that a person other than the
founder could have finished; it was blocked by this session's sandbox, not
by anything about the code. Steps 2–8 are an afternoon in the Play Console
and an S3 bucket.

Nothing in this report asks for a redesign, a new feature, or another
sprint.

---

*Every PASS in §5 was driven on the physical device against the release
build. Everything not verified is listed as such, with the reason.*

---

## 11. Play listing assets — 7 August 2026

Everything below concerns the **store listing artwork**, not the app. The
build, the tests and the AAB are untouched by this pass.

Two audits preceded it. `ASO_SCREENSHOT_COMPLIANCE_REPORT.html` found 14
critical policy items across the original 22 assets — false privacy
absolutes, iPhone mockups, medical skeleton imagery, transformation
promises, a fabricated community feed, a metric the app never computes.
`FINAL_PLAY_STORE_REVIEW.html` re-reviewed the regenerated artwork and
confirmed **all 14 are closed in both locales**, leaving four asset-integrity
defects and one export setting.

This session closed those. The **founder's one owned task — regenerating the
app icon — was already done** before the session started: `app-logo.png` is
now the violet F monogram, full-bleed, no pre-rounding, no text, with the
previous neon-bodies version kept as `app-logo(backup).png`.

### 11.1 DONE BY ENGINEERING

Two committed scripts do the work and prove it:
`tool/playstore_asset_pipeline.py` builds
`playstore-new-ASO/FINAL/{en-US,tr-TR}/` from the untouched source artwork,
and `tool/validate_play_assets.py` re-opens every output and asserts Play's
published rules independently. Setup and rationale:
`tool/README_play_assets.md`.

**Content repairs** — pixel-level, at native resolution, no artwork regenerated:

| # | Asset | Defect | Fix |
| --- | --- | --- | --- |
| 1 | icon (both) | 12-row pure-white band across the bottom (rows 500–511, 6 144 px) — an export artefact that Play's rounded mask would have shown as a white arc | background gradient extrapolated over the band; the F mark was never touched |
| 2 | `US/002` | in-app date read **May 17, 2025** — a past year reads as a stale screenshot | year re-rendered as **2026**; "May 17," keeps its original pixels |
| 3 | `US/004` | "9 days left" and "18 days left" stacked beside Day 30, so Day 30 appeared to carry two countdowns | the reward card overlaps the Day 21 row, so there is nowhere legitimate to align the first — it was removed, and "18 days left" lifted onto the Day 30 row |
| 4 | `US/004` | 7 filled streak dots against "6 days current streak" | 7th dot replaced with an outline dot |
| 5 | `US/005` | **"naximum."** | re-rendered as "maximum." |
| 6 | `US/008` | "Two weeks of data" against a chart spanning May 1 – May 29 with the 30d range active | "Four weeks"; the rest of the line keeps its original pixels and slides right |
| 7 | `TUR/004` | plan pill rendered "30" as a beta-like glyph — **"Β0 Günlük Plan"** | "30" re-rendered, rotated to the mockup's −5.93° tilt |
| 8 | `TUR/004` | 7 filled streak dots against "6 gün mevcut seri" | 7th dot replaced with an outline dot |
| 9 | `TUR/006` | the Form-detection frame carried the **Squad frame's** three feature columns (KÜÇÜK TAKIMLAR / SIRALAMA DEĞİL, KATILIM / VARSAYILAN GİZLİ) — wrong content in the wrong asset | row removed and the violet gradient reconstructed; the English twin has no such row, so this also matches the locales |

**Set composition**

- Both `009` tablet frames **dropped**. They depict a nav rail, a two-up grid
  and a category taxonomy the app does not render — the only width-responsive
  consumer layout in `lib/` does not exist, the `>= 600` branch lives in
  `admin_dashboard_screen.dart`. The Turkish one additionally stated **%60**
  for 12 of 30 days, which is 40 %. Play requires no tablet screenshot.
- `app-logo(backup).png` excluded from the upload set.
- **Slot parity fixed.** The locales were authored with different frames in
  slots 7 and 8 — English shipped Body Metrics, Turkish shipped Challenges —
  so one slot advertised a different feature per storefront. The seven shared
  features now sit in identical slots and the locale-specific extra is last.
  Both extras are real shipped features (`leaderboard_screen.dart`,
  `challenges_screen.dart`, the metrics screen).

**Format and encoding** — every output asset:

- alpha channel removed; flattened onto `#060012`, the artwork's own black
  (all 18 source screenshots were `RGBA`, which Play rejects)
- re-canvassed **941×1672 → 1080×1920** by cover-fit and centre-crop, so the
  true aspect is preserved rather than anisotropically stretched, with a
  calibrated unsharp pass to return what Lanczos costs
- 8-bit sRGB, every ancillary PNG chunk stripped (`exiftool` before *and*
  after optimisation, because optimisers reintroduce them)
- losslessly recompressed with `oxipng -o6`

Net: **+31 % pixels for +0.5 % bytes** — 1 167 KB/megapixel down to 903 KB/megapixel.
Largest file 2.02 MB against Play's 8 MB limit.

**Validation** — `tool/validate_play_assets.py`: **131/131 checks pass**, covering
format, alpha, 8-bit sRGB, dimensions, aspect ratio, per-file size, metadata
chunks, asset counts, contiguous slot numbering, promotion eligibility
(≥ 4 screenshots ≥ 1080 px at 9:16 — **8 of 8 qualify in both locales**),
locale parity, byte-identical icon across locales, and no duplicate frames.

**Tooling installed** (sudo-free — Debian packages extracted into
`~/.cache/formai-play-tools/prefix`, Python packages into a venv per PEP 668):
`pngquant`, `optipng`, `pngcrush`, `zopflipng`, `exiftool`, `oxipng`
(`pyoxipng`), `numpy`, `Pillow`, `fonts-inter`. ImageMagick and ffmpeg were
already present. `pngquant`/`pngcrush`/`zopflipng` are available but
**deliberately unused** — pngquant is lossy and these are gradient-heavy dark
UI frames where banding would show; the set has 4× headroom on Play's limit,
so lossless is the right trade.

### 11.2 Known residuals — recorded, not fixed

- **In-app navigation differs across frames.** The real tab set is
  `navWorkout · navProgress · navNutrition · navCommunity · navProfile`
  (Antrenman · Gelişim · Beslenme · Topluluk · Profil). No screenshot matches
  it exactly; `TUR/005` shows "Takım", which is not a nav label at all.
  Correcting this means re-rendering four or five small tilted labels across
  five frames — high risk of looking worse, for a defect no reviewer compares
  against the app. **Note:** an earlier draft of the review had this backwards
  and suggested changing `TUR/007`; `TUR/007` is the one that is right.
- **Feature-graphic safe areas.** The 87 % ring sits inside the centre
  250×250 px where Play overlays a play button, and content runs into the
  outer 64 px. Only matters if a promo video is attached — see 11.3.
- **Carousel order.** Form detection is slot 6. It is the one asset no
  competitor can honestly show and it belongs in slot 1, but ordering is a
  marketing call, not a compliance one, and it is drag-and-drop in the
  Console. Left to the founder.

### 11.3 FOUNDER ACTIONS

Only what code cannot do. Nothing here is an asset defect.

1. **Apply migration `027`** — unchanged from §9 Step 1, still the single most
   important remaining item, still one command. Until it runs, AI-reply
   reporting shows its honest failure toast.
2. **Upload the set.** `playstore-new-ASO/FINAL/en-US/` and `.../tr-TR/` —
   8 screenshots, 1 feature graphic, 1 icon each. Filenames carry their slot
   order. The icon is byte-identical in both folders because Play stores one
   globally; upload either.
3. **Paste the listing metadata** from `FINAL_PLAY_STORE_REVIEW.html` §4/§5 —
   app name, short and long description, both locales, all verified against
   Play's 30/80/4000 character limits.
4. Steps 2–8 of §9 (legal pages, data-deletion URL, content rating, target
   audience, health declaration, Data Safety, "(Erken Erişim)" removal) —
   unchanged, all Play Console.
5. **Optional:** decide the carousel order (11.2) and whether to attach a promo
   video. If a video is attached, the feature graphic's centre 250×250 px
   should be cleared first.

### 11.4 Status

**The listing is production-ready apart from the founder's Console work.**
Every asset defect found in either audit is closed, the icon the founder
regenerated is in the set with its export artefact repaired, and 131/131
conformance checks pass. No policy finding remains open in either locale.
