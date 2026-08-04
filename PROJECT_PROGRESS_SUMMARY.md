# FormAI — Project Progress Summary

**Spec:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` (18 phases / 5 waves)
**As of:** 2026-08-04 · Phase 8 **closed as split** · Phase 9 **complete** · pre-Phase-10 polish sprint complete · **Phase 10 complete** · **Phase 11 ⏸ deferred by founder** · **Phase 12 complete** · **Phase 13 complete** · pre-Phase-14 polish complete · **Phase 14 IN PROGRESS — 4 of 8 features shipped** · **migrations 001–026 ALL APPLIED** · build **1.0.0+36** · **1455 tests**

> **Three production defects were found and fixed on 2026-08-04, by the
> first live RLS pass ever run against this database.** Five community
> tables had been answering HTTP 500 since `019` was applied — squads
> and the whole activity feed had never worked; blocking a user did
> nothing to their view of you; and no user could create a squad,
> because `.insert().select()` makes Postgres apply the SELECT policy to
> the returned row. Fixed in `023` and `026`, each verified against
> production with real accounts. `PHASE_14_PROGRESS_REPORT.md` §0 is the
> record; `RESUME_GUIDE.md` §2.0.0k is the short version.

---

# 1. Completed

### Phase 0 — Verified Baseline ✅
- Pre-roadmap audit of what already shipped; established the 330-test / analyze-0 baseline every later phase is measured against.

### Phase 1 — Rate & Feedback Loop ✅
*Build 1.0.0+19 · 408 tests · CI green · `PHASE_01_COMPLETION_REPORT.md`*
- Settings "Rate app" row + 5 contextual rating triggers with 90-day cooldown, 3-prompt lifetime cap and a one-shot token ledger.
- Sentiment routing: 4–5★ → store, 1–3★ → feedback form.
- Feedback reward (50 XP + `voice_heard` badge) attached to **submitting feedback**, never to leaving a rating — Play policy.
- Declarative survey engine + day-14 NPS; searchable help centre with 17 FAQs.
- Migration `008` (feedback triage columns, `survey_responses`) — **not applied to prod**.

### Phase 2 — Dynamic Walkthrough I: Feature Tour ✅
*Build 1.0.0+20 · 482 tests · CI green · `PHASE_02_COMPLETION_REPORT.md`*
- Reusable `SpotlightTour` coach-mark system (transparent route, computed bubble placement, skip on every step, missing target drops its step, reduce-motion aware).
- 5-step dashboard tour after the welcome scene; replayable from Settings.
- 4-card post-paywall feature showcase.

### Phase 3 — Dynamic Walkthrough II: First-Workout Tutorial ✅
*Build 1.0.0+21 · 527 tests · CI green · `PHASE_03_COMPLETION_REPORT.md`*
- Guided camera setup screen: placement → calibration → ready, each stage with its own exit.
- Live framing validation (`FramingValidator`) with confidence ring and non-judgemental corrections.
- Camera-free path offered at **every** stage, framed as a legitimate choice rather than a failure exit.

### Phase 3b — Tutorial Completion & Device Verification ✅
*Build 1.0.0+22 · 629 tests · CI green · `PHASE_3B_COMPLETION_REPORT.md`*
- Guided practice rep driven by the **production** `SquatAnalyzer` over real landmarks, with tracked joints named on the user's body.
- In-session coach-mark layer (5 steps) + voice toggle + replayable setup guide.
- **P0 fixed:** AI report CTA was clipped and untappable on the Huawei test device — onboarding could not be completed. Fixed with the pinned-footer pattern plus a reachability test that asserts the callback actually fires.
- One gap remains physically unverifiable over adb: the practice rep and "I can see you" success stage need a human body in frame at ~2 m.

### Phase 4 — Progressive Disclosure & Feature Flags ✅
*Build 1.0.0+23 · 732 tests · CI green · `PHASE_04_COMPLETION_REPORT.md`*
- Feature-flag service: 10 flags with compiled-in defaults, TTL + disk cache, total/synchronous `isEnabled`, all errors swallowed.
- Deterministic sha256 experiment bucketing; anonymous users → control.
- Progressive disclosure: capabilities unlock on days **or** sessions, never block navigation, never re-lock, with grandfathering for existing users.
- Discovery hub listing every capability — nothing hidden, and every locked row offers an immediate manual override.
- Migrations `009`, `010` — **not applied to prod**.

### Phase 5 — Internationalization Infrastructure ✅ *device sweep done except 2 surfaces*
*Build 1.0.0+25 · 850 tests · CI green · `PHASE_05_COMPLETION_REPORT.md`*
- Hardcoded-string gate at **0 in 0 files**; ARB **1390 keys, 100% referenced and 100% resolved**.
- Pseudo-locale sweep (18 surfaces × 3 viewports) and RTL sweep (16 surfaces) in CI; the pseudo sweep found six real overflows on its first run.
- `docs/i18n/` — pipeline runbook, glossary, text-in-images inventory, adding-a-locale.

### Phase 6 — English Launch & Language Preference ✅
*Build 1.0.0+26 · 899 tests · CI green · `PHASE_06_COMPLETION_REPORT.md`*
- **FormAI is no longer a Turkish app.** `tr` and `en` both ship; the user picks at onboarding step 0 and in Settings, the change applies live with no restart, and it survives a reinstall through `user_metrics.locale`.
- The picker applies the language **as you tap it**, so its own title and CTA flip — the only feedback that works for someone who cannot read the current language.
- **English coach persona authored, not translated**, with the prompt scaffolding and the summariser moved with it: the summary becomes the coach's memory, so summarising in the wrong language poisons every later turn.
- The English draft was normalised to **American English** — 24 keys said "programme" and ten said "program" — and the rule is written into `GLOSSARY.md`.
- **The phase's real yield was defects.** Two more gate blind spots (ASCII Turkish, and `%` placement), one sweep blind spot (overflow is reported from paint, so anything below a viewport's cache extent was silently clean), **69 untranslated strings in shipped screens**, and **five layout overflows that were broken in Turkish too** — nothing had looked.
- See section 2 for what is founder-side.

---

### Phase 6 polish sprint — twelve founder items ✅
*Build 1.0.0+28 · 940 tests · CI green · `PHASE_06_POLISH_REPORT.md`*
- **Premium naming, migration 012, Metric/Imperial, the language picker, the coach's four language leaks, tour-before-popup** — the first six, delivered earlier in the sprint.
- **Paywall pricing.** The struck-through anchor hardcoded Turkish separators, so a US user saw `$9.99` beside `$119,88`; separators now come off the store's own string. The third plan card resolves against the live offering, so publishing `$rc_weekly` switches the paywall with **no app release**. `docs/store/PRICING_SETUP.md` carries the founder-side half — including that the target USD ladder is inverted ($2/wk = $8.67/mo against a $10/mo plan).
- **The four showcase screens**, rebuilt to the references. Found that `showcase_ai_coach.webp` shipped six English UI labels baked into the photograph while `TEXT_IN_IMAGES.md` recorded it as clean — the audit had read the filename, not the pixels.
- **Camera-free workout and rest**, rebuilt, filling the display instead of floating in the middle of it.
- **A background for all 138 exercises**, resolved from the asset manifest rather than a hand-kept list — dropping a correctly-named file in is the entire procedure. 51 still on category art, with prompts in `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`.
- **Phase 7 nutrition plan** written against the live catalogue, not started.
- **A two-language device walk found eight defects** that 934 tests and five gates were green across — a rest day labelled "Req.", "PREMIUM" white on white in light mode, a privacy claim cut mid-sentence, two badges ellipsised in English, two loader phrases cross-fading on top of each other, and `%82` in the English app. That last one had a rule written specifically to catch it; it failed for two independent reasons, and only a synthetic probe found the second.

---

### Phase 7 — Content & AI Localization ✅
*Build 1.0.0+29 · 1064 tests · CI green · `PHASE_07_COMPLETION_REPORT.md`*
- **FormAI is no longer an English app with a Turkish pantry.** 392 recipes, 100 % translated: title, method steps, all 2,242 ingredient rows and their prep-state notes.
- **Most of the work was not translation**, as the plan predicted. A tag was a query key and display copy at the same time (migration 013 split it), ingredients were prose inside a text column (014 gave them a table), and the catalogue was culturally Turkish (015 gave it cuisine, diet flags and locale scope). All three applied to production and verified live.
- **100 new recipes** — 60 western bodybuilding, 40 international — authored in both languages through a pipeline whose model never writes to the database and whose rejected proposals are deleted rather than repaired.
- **The gate rejected seven of the first hundred**, all correctly. Three came from one check that classifies each ingredient's English and Turkish name independently and requires them to agree — the only thing that catches a mistranslated ingredient. Without it a casein pudding would have shipped labelled `dairy_free`.
- **Every cross-check found a defect in content that was already there.** The dietitian's hand tags versus the derived diet flags found a recipe tagged Vegan containing 10 g of honey, live since Phase 24. The pipeline's macro rule versus the old catalogue found six recipes whose stated calories are 11–16 % away from their own macros. Four recipes had been unreachable from every category screen since they were seeded.
- **`tool/recipe_translation_audit.dart`** now guards the catalogue the way the ARB gates guard the UI, ratcheting and wired into CI — and it found four bugs in itself while proving the first batch, including one where the check meant to prove 199 recipes were translated reported all of them as untranslated.
- **The coach can only name food the app actually has**, in the reader's language, verified live against the deployed function in both.
- **The device walk is done** (2026-08-02) and **the connected Redmi was never PIN-locked** — its screen was off, and `wm dismiss-keyguard` opens it. Two phases of "physically unverifiable" rested on one misread `dumpsys` line.
- **The walk found six defects** that 1,051 tests and six CI gates were green across, and **four of them were defect classes this codebase had already fixed somewhere else** and never carried across: a chip that reported 12 high-protein recipes out of 175 because it filtered only the pages that had paginated in (Phase 83 fixed exactly this for the category screen); a raw `SNACK` token painted at a Turkish reader — with the screen's own test asserting `find.text('LUNCH')` in a Turkish host, pinning the defect in place; an English recipe printing its ingredient list twice because the instruction parser knew only `MALZEMELER:`; and tag badges at **1.24:1 contrast** in light mode, the "PREMIUM white on white" defect again. Plus `92%` where Turkish writes `%92`, and a language picker that applied live to chrome but left the whole recipe catalogue in the old language until restart.

---

### Phase 8 — RTL Readiness ✅ *(closed as split; languages deferred by founder)*
*Build 1.0.0+29 · 1070 tests · CI green · `PHASE_08_COMPLETION_REPORT.md`*
- **The engineering half is done.** The RTL sweep now covers the nutrition
  surfaces Phase 7 built — it had only ever rendered the onboarding funnel —
  and `tool/check_directional_layout.dart` is a CI ratchet armed at 177.
- It exists because **an `Alignment.centerLeft` does not overflow**: it lays
  out perfectly, on the wrong side, so no layout sweep can ever catch it.
  The sweep and the gate are complements, not duplicates.
- **The roadmap's headline RTL debt is not debt.** All 127
  `EdgeInsets.fromLTRB` call sites are horizontally symmetric, so none of
  them mirrors wrong. The real surface is 121 directional `Alignment` and
  55 `Positioned(left:/right:)`, and the ratchet stops it growing.
- Two of eighteen `CustomPainter`s laid out **ARB copy** with a hardcoded
  `TextDirection.ltr`. Both fixed; the geometry deliberately did not move
  with them — the pose skeleton's mirror is the selfie mirror, and a
  12-week time axis is not text.
- **⏸ Deferred by founder after English launch, 2026-08-02 — not cancelled:**
  Spanish, French, German, multilingual recipe and exercise content, new
  coach personas, per-locale ASO, regional pricing and the
  translation-quality monitor. Reasoning and resume trigger are in the
  roadmap's Phase 8 section and §0 of the phase report. **One reviewed
  language beats three unreviewed ones** — and Phase 6–7's English is
  still an unreviewed draft itself.

---

### Phase 9 — Performance Analytics I: Body Metrics & Trends ✅
*Build 1.0.0+30 · 1183 tests · CI green · `PHASE_09_COMPLETION_REPORT.md`*
- **The app can finally answer "is this working?"** Weight and five tape
  measurements, a chart over 7/30/90/all days, adherence, and an honest
  reconciliation against the user's target.
- **The roadmap asked for a goal weight the app is not allowed to have.**
  There is no onboarding target — `ai_personalization_engine.dart` carries
  a store-compliance rule against quantified outcome promises, which is
  exactly why the 12-week projection is qualitative. So the target is
  **stated by the user** and null stays a permanent, valid state.
- **Direction is never valence.** No red for a gain, no green for a loss,
  no confetti. The maths returns verdicts and one file turns them into
  sentences, so the tone can be read in a sitting.
- **A test found the card being cruel before a user did.** Seeded on its
  install day, adherence read 0 %. The week is now a count — "1 of 4" —
  and the 30-day percentage waits for a week of history.
- **Blind spot #6, and the worst so far: the layout sweeps were measuring
  a spinner.** A single `pump()` renders the frame where every async
  provider is still loading, so every sweep in the repo had been proving
  that loading states do not overflow. Found by injecting a 3000 px
  overflow into a screen all three suites claimed to cover. The honest
  sweeps immediately found a 143 px overflow on a Phase 8 surface that
  phase had signed off as clean.
- **The device walk found four defects** that 1,179 tests and seven gates
  were green across — including the app silently discarding the tenth of
  a kilogram the user typed, and the weekly retrospective saying every
  unit twice in both languages since it shipped.

---

---

### Pre-Phase-10 polish sprint — six founder tasks ✅
*Build 1.0.0+31 · 1189 tests · CI green · `PRE_PHASE10_POLISH_REPORT.md`*
- **The founder's report was right and the cause was a stale reader.** An
  earlier performance change moved the per-second rest tick into its own
  provider and left `restSecondsRemaining` holding the rest *duration*.
  The camera screen was moved across; the camera-free screen was not, so
  it showed the same "40" for forty seconds with the ring at full. Its
  own test seeded that field and asserted on it — written from the code's
  assumption, green for as long as the bug lived.
- **"Your body" rebuilt to the founder's reference.** Neon on black,
  cards at 91 % width, the comps' artwork cut out of the PNGs with the
  black converted to alpha. The six comps could not be shipped as images:
  every one has English text in the pixels, which is the exact problem
  Task 1 exists to fix elsewhere.
- **Blind spot #8, and it had been hiding four leaks.** `'dakika'` and
  `'padding'` are the same shape — one lowercase word — so the
  hardcoded-string gate's identifier exclusion discarded every lowercase
  label in the app while reporting zero. The gate now reads the parameter
  the literal is passed to. On its first honest run it found a fifth leak
  nobody was looking for: the sign-in email field labelled `E-posta`,
  with `authEmailLabel` already sitting unused in the ARB.
- **The device found what the suite could not, again.** Five defects
  across 1,183 tests and seven green gates — including the trend card
  claiming "vs 30 days ago" beside a sheet saying "over the last 13
  days", which was a claim about a weight the app has never been told.
- **All 87 exercise images carry burned-in text**, and they are
  infographics rather than captioned photos — the filmstrips carry the
  coaching content itself. `EXERCISE_IMAGE_REGENERATION_GUIDE.html` has a
  prompt for each, plus the media strategy: 9 holds and 59 single-plane
  movements are right as stills; 19 ballistic and locomotive ones need a
  loop, because the information is the path and a frame cannot carry one.

---

### Phase 10 — Performance Analytics II: Visual Outcomes & Reports ✅
*Build 1.0.0+32 · 1258 tests · CI green · `PHASE_10_COMPLETION_REPORT.md`*
- **The store listing's "measurable results" is now literally true.** A
  30-day outcome report aggregating sessions, minutes, reps, energy,
  streaks, badges and body deltas — pure, testable, and the single source
  the screen, the share card and any future narrative all read from.
- **Progress photos, and the promise is structural.**
  `ProgressPhotoRepository` has no Supabase client, no `http`, no bucket,
  no upload path — not behind a flag. The absence *is* the guarantee, and
  a release-gate test scans the source for any networking symbol as well
  as driving the whole cycle with every socket refused. Probed with a
  flag-guarded upload before being trusted.
- **The ghost overlay is the feature, not decoration.** Week two shot
  from a different distance shows the photographer moving rather than the
  person changing. Same pose only, 0.35 opacity.
- **Every refusal is tested.** No body grading (a delta is two ends, never
  a signed difference); no section it cannot support; no unhedged calorie
  claim; no photo on a share card unless switched on *that time*.
- **The device found one defect** across 1,252 tests and seven gates: two
  photos taken the same day rendered two identical picker chips.
  `recordedAt` is a moment and the formatter was throwing the time away —
  the two-controls-saying-the-same-thing class, third time in three
  phases.
- **Migration 018, not the roadmap's 014** (014 is Phase 7's). Metadata
  only; written and deliberately unapplied. Account deletion now reaches
  the handset, which neither the RPC nor `prefs.clear()` could.

---

# 2. Currently Working On

**Phase 14 — Content Freshness Engine.** Wave 4's closer.
`PHASE_14_PROGRESS_REPORT.md` is the record and §5 is the exact
remainder. **4 of 8 features shipped; the other 4 have their rules
built and tested and no surface.**

Shipped: migrations `024` (`content_releases`, `content_drops`) and
`025` (seven rotating challenges, 13 live), the What's New screen with
its route and dashboard trigger, `content_sync_service.dart`,
`program_progression.dart` (the day-31 rules),
`lifecycle_campaigns.dart` (the C50 journeys plus the global frequency
cap), `docs/CONTENT_OPS.md` BÖLÜM II, all six analytics events, and a
real release note live in production for build 36. +65 tests.

Remaining, each a screen or a wiring job on top of tested logic:
the **continuation-paths screen** (rules and all ARB copy already
exist), **difficulty-tier wiring** back into the plan generator, the
**new-content discovery surface**, and **campaign scheduling** (ledger,
ARB bodies, `NotificationService` methods).

**Not verified: no device walk this session** — `adb devices` was empty
throughout. The join-challenge fix is verified by reproducing the
client's exact PostgREST request as a real authenticated user, but
nothing was seen on a screen and What's New has never been rendered on
a device. No APK/AAB built; build not bumped.

Founder-side, carried and still open:

1. **Play Console + RevenueCat**, per `docs/store/PRICING_SETUP.md` §3–§4.
2. **Generate the meal, workout and exercise photographs**, per
   `docs/nutrition/MEAL_IMAGE_REQUESTS*.md`,
   `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` and
   `EXERCISE_IMAGE_REGENERATION_GUIDE.html`.
3. **A native-speaker read of the English.**
4. **Author the monthly content.** The cadence is documented and the
   tables are live: a challenge a month, a recipe batch a fortnight, a
   plan a month, seasonal content a quarter. `docs/CONTENT_OPS.md`
   BÖLÜM II is the runbook and `supabase/sql/seed_content_freshness.sql`
   is the paste-and-edit template. **None of it needs an app release.**
5. **Write the release note before each build ships.** It is keyed to
   `build_number`, so publishing early is safe and is the intended
   workflow — a user on the old build never sees it.

# 3. Remaining Roadmap

### Deferred by founder — resume after the English launch has data
- **Phase 8's content half.** ⏸ Spanish, French, German; multilingual recipe and exercise content; new coach personas; per-locale ASO and store listings; regional pricing; the translation-quality monitor; the documented market-selection method. **Full scope preserved — this is a pause, not a cut.** The recipe half is a content cost rather than an engineering one: the resolver is locale-agnostic and the audit loops over `kShippedLocales`. **The exercise catalogue is not** — 138 rows of `name`, `description` and `short_tip` are still Turkish-only, and their instructional images carry burned-in text in two languages.

### Wave 3 — Measurable Progress & Universal Access
- **Phase 9 — Performance Analytics I.** ✅ **complete** — Body metrics and trends. Followed by a six-task polish sprint (`PRE_PHASE10_POLISH_REPORT.md`).
- **Phase 10 — Performance Analytics II.** ✅ **complete** — Visual outcomes and shareable reports; the store-listing promise of measurable results is now literally true.
- **Phase 11 — Accessibility Program.** ⏸ **Deferred by founder** (2026-08-02). Usable with visual, motor, auditory and cognitive differences, established as a standing definition-of-done. **Full scope preserved in the roadmap — this is a pause, not a cut.** Wave 4 starts at Phase 12 instead.

### Wave 4 — Community & Content Engine
- **Phase 12 — Community I: Identity & Squads.** ✅ **complete** — an identity worth showing and a small group worth showing up for. Migration `019` applied.
- **Phase 13 — Community II: Leaderboards & Challenges.** ✅ **complete** — healthy competition on top of the identity layer, without making beginners feel bad. Migrations `020`–`022` applied.
- **Phase 14 — Content Freshness Engine.** 🟡 **in progress, 4 of 8** — solve the structural problem that a 30-day program has a 30-day lifespan. Migrations `023`–`026` applied. `PHASE_14_PROGRESS_REPORT.md` §5 is the remainder.

### Wave 5 — Scale, Depth & Platform
- **Phase 15 — Scale, Reliability & Continuous Discovery.** Sized for 10k–100k users, provably stable, driven by a permanent feedback loop.
- **Phase 16 — Video Form Analysis Completion.** Complete the partially-built video analysis feature — the strongest deepening of the core differentiator.
- **Phase 17 — Platform Expansion.** Beyond a single Android screen: iOS, wearables, home screen, and the parts of fitness that happen away from the phone.

---

# 4. Overall Progress

```
Wave 1 — Production-Access Commitments   ✅ Complete   (Phases 1–4 + 3b)
Wave 2 — Global Reach                    ✅ Complete   (5, 6, 7 done; 8 RTL done, languages ⏸ deferred)
Wave 3 — Measurable Progress & Access    ✅ Complete   (9, polish, 10 done; 11 ⏸ deferred)
Wave 4 — Community & Content Engine      🔄 In Progress (12 running; 13–14 not)
Wave 5 — Scale, Depth & Platform         ⏳ Not Started (Phases 15–17)
```

**Phases complete:** 11 of 18 (0, 1, 2, 3, 3b, 4, 5, 6, 7, 8-as-split, 9) + the Phase 6 polish sprint · device surfaces still carried forward: the paywall interior and a clean-install onboarding. The six Phase 7 nutrition surfaces are **walked and signed off**.

### Current quality state

| | |
|---|---|
| **Build** | 1.0.0+36 · APK 137.3 MB · AAB 116.0 MB |
| **Tests** | **1384 passing** (baseline was 330) |
| **`flutter analyze`** | **0 issues** |
| **`dart format`** | clean |
| **CI** | **GREEN** (CI + Secret Scan) |
| **Hardcoded-string gate** | **no regressions** · rendered-argument signal added |
| **ARB** | **1790 keys** · `tr` 100% · `en` 100% · all referenced in `lib/` |
| **Recipe catalogue** | **392 recipes** · `en` 392/392 · 2242 ingredient rows · audit 0 findings |
| **Locales shipped** | `tr`, `en` |

### Standing constraints

- **CI Flutter is 3.44.8, local is 3.41.9.** Local green is not proof; only CI is a reliable gate.
- **Migrations 001–015 are all applied to production** and verified live. `016_drop_legacy_tags.sql` is deliberately unwritten — it drops `recipes.tags` and trims `instructions`, and both are safe only after a release carrying the new readers has been live long enough that the old client is gone.
- The local release build is upload-key signed, so device installs need `adb uninstall` first (loses session, requires a full onboarding re-walk).
- **MIUI's "Install via USB" lapses.** `INSTALL_FAILED_USER_RESTRICTED` is not a signing problem and no adb flag works around it; it needs a Mi-account re-authorization on the handset.
- **A green gate is a claim about its own heuristics.** Three phases running now. Phase 7's translation audit found four bugs in itself while proving its first batch — including one where the check meant to prove 199 recipes were translated reported every one of them as untranslated. Probe every widening.
- **Every migration 001–026 is applied to production.** 016 is deliberately unwritten. Repository and production are in sync. `supabase db push` must run from a staging workdir — the CLI parses `.env.local` as dotenv and it is freeform notes.
- **An RLS predicate can be always-true and look correct.** `m.squad_id = squad_id` inside a policy binds to the alias, not the outer row. Four policies shipped that way; three were live from the day community launched, one was a write hole. Migration `022` fixed them and `rls_policy_test.dart` now catches the class. **The live penetration pass the roadmap asks for has still never been run**, and this is the strongest argument yet that it should be.
- **Leaderboard anti-gaming is a bound, not a guarantee.** XP is client-authoritative. `020`'s constraints make the implausible impossible; they cannot detect a plausible lie. Closing that needs server-side session recording (Phase 15) and the migration header says so.
- **The cross-check between two independent sources is where the defects are.** Every one of Phase 7's findings in pre-existing content came from comparing two things that had never been compared: hand tags against derived diet flags, English ingredient names against Turkish ones, the new macro rule against the old catalogue.
