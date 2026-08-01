# FormAI — Project Progress Summary

**Spec:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` (18 phases / 5 waves)
**As of:** 2026-08-01 · Phase 7 **complete** · build **1.0.0+29**

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
*Build 1.0.0+29 · 1051 tests · CI green · `PHASE_07_COMPLETION_REPORT.md`*
- **FormAI is no longer an English app with a Turkish pantry.** 392 recipes, 100 % translated: title, method steps, all 2,242 ingredient rows and their prep-state notes.
- **Most of the work was not translation**, as the plan predicted. A tag was a query key and display copy at the same time (migration 013 split it), ingredients were prose inside a text column (014 gave them a table), and the catalogue was culturally Turkish (015 gave it cuisine, diet flags and locale scope). All three applied to production and verified live.
- **100 new recipes** — 60 western bodybuilding, 40 international — authored in both languages through a pipeline whose model never writes to the database and whose rejected proposals are deleted rather than repaired.
- **The gate rejected seven of the first hundred**, all correctly. Three came from one check that classifies each ingredient's English and Turkish name independently and requires them to agree — the only thing that catches a mistranslated ingredient. Without it a casein pudding would have shipped labelled `dairy_free`.
- **Every cross-check found a defect in content that was already there.** The dietitian's hand tags versus the derived diet flags found a recipe tagged Vegan containing 10 g of honey, live since Phase 24. The pipeline's macro rule versus the old catalogue found six recipes whose stated calories are 11–16 % away from their own macros. Four recipes had been unreachable from every category screen since they were seeded.
- **`tool/recipe_translation_audit.dart`** now guards the catalogue the way the ARB gates guard the UI, ratcheting and wired into CI — and it found four bugs in itself while proving the first batch, including one where the check meant to prove 199 recipes were translated reported all of them as untranslated.
- **The coach can only name food the app actually has**, in the reader's language, verified live against the deployed function in both.
- **No device walk.** The primary device is not connected and the connected one is PIN-locked. A live read-path test covers the data half and found a real defect on its first run: every ingredient name was translated and none of the prep-state notes were.

---

# 2. Currently Working On

**Nothing. Phase 7 is closed.** `PHASE_07_COMPLETION_REPORT.md` §9 is
what it did not do and why.

Founder-side, carried and still open:

1. **Walk the nutrition surfaces on a device.** Six specific surfaces are
   listed in the Phase 7 report §9. Needs the Redmi Note 12 connected
   with "Install via USB" re-enabled.
2. **Decide the USD weekly price**, then do Play Console + RevenueCat per
   `docs/store/PRICING_SETUP.md`.
3. **Generate the meal and workout photographs** at your own pace, from
   `docs/nutrition/MEAL_IMAGE_REQUESTS*.md` and
   `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`. Nothing is broken while those
   directories are empty — both fall back to real photography.
4. **A native-speaker read of the English**, now covering 392 recipes as
   well as the UI and the store listing.

# 3. Remaining Roadmap

### Wave 2 — Global Reach *(continues)*
- **Phase 8 — Spanish, French, German & RTL Readiness.** Turn localization from a project into a repeatable capability and reach the markets the testers named. The recipe half is now a content cost rather than an engineering one: the resolver is locale-agnostic and the audit loops over `kShippedLocales`. **The exercise catalogue is not** — 138 rows of `name`, `description` and `short_tip` are still Turkish-only, and their instructional images carry burned-in text in two languages.

### Wave 3 — Measurable Progress & Universal Access
- **Phase 9 — Performance Analytics I.** Body metrics and trends: let users see their body change over time.
- **Phase 10 — Performance Analytics II.** Visual outcomes and shareable reports; make the store-listing promise of measurable results literally true.
- **Phase 11 — Accessibility Program.** Usable with visual, motor, auditory and cognitive differences, established as a standing definition-of-done.

### Wave 4 — Community & Content Engine
- **Phase 12 — Community I: Identity & Squads.** An identity worth showing and a small group worth showing up for.
- **Phase 13 — Community II: Leaderboards & Challenges.** Healthy competition on top of the identity layer, without making beginners feel bad.
- **Phase 14 — Content Freshness Engine.** Solve the structural problem that a 30-day program has a 30-day lifespan.

### Wave 5 — Scale, Depth & Platform
- **Phase 15 — Scale, Reliability & Continuous Discovery.** Sized for 10k–100k users, provably stable, driven by a permanent feedback loop.
- **Phase 16 — Video Form Analysis Completion.** Complete the partially-built video analysis feature — the strongest deepening of the core differentiator.
- **Phase 17 — Platform Expansion.** Beyond a single Android screen: iOS, wearables, home screen, and the parts of fitness that happen away from the phone.

---

# 4. Overall Progress

```
Wave 1 — Production-Access Commitments   ✅ Complete   (Phases 1–4 + 3b)
Wave 2 — Global Reach                    🔄 In Progress (5, 6, 7 done; 8 next)
Wave 3 — Measurable Progress & Access    ⏳ Not Started (Phases 9–11)
Wave 4 — Community & Content Engine      ⏳ Not Started (Phases 12–14)
Wave 5 — Scale, Depth & Platform         ⏳ Not Started (Phases 15–17)
```

**Phases complete:** 9 of 18 (0, 1, 2, 3, 3b, 4, 5, 6, 7) + the Phase 6 polish sprint · device surfaces still carried forward: the paywall interior, a clean-install onboarding, and the six Phase 7 nutrition surfaces

### Current quality state

| | |
|---|---|
| **Build** | 1.0.0+29 · APK 134.5 MB |
| **Tests** | **1051 passing** (baseline was 330) |
| **`flutter analyze`** | **0 issues** |
| **`dart format`** | clean |
| **CI** | **GREEN** (CI + Secret Scan) |
| **Hardcoded-string gate** | **0 in 0 files** · 244 allowlisted, reported per entry |
| **ARB** | **1532 keys** · `tr` 100% · `en` 100% · all referenced in `lib/` |
| **Recipe catalogue** | **392 recipes** · `en` 392/392 · 2242 ingredient rows · audit 0 findings |
| **Locales shipped** | `tr`, `en` |

### Standing constraints

- **CI Flutter is 3.44.8, local is 3.41.9.** Local green is not proof; only CI is a reliable gate.
- **Migrations 001–015 are all applied to production** and verified live. `016_drop_legacy_tags.sql` is deliberately unwritten — it drops `recipes.tags` and trims `instructions`, and both are safe only after a release carrying the new readers has been live long enough that the old client is gone.
- The local release build is upload-key signed, so device installs need `adb uninstall` first (loses session, requires a full onboarding re-walk).
- **MIUI's "Install via USB" lapses.** `INSTALL_FAILED_USER_RESTRICTED` is not a signing problem and no adb flag works around it; it needs a Mi-account re-authorization on the handset.
- **A green gate is a claim about its own heuristics.** Three phases running now. Phase 7's translation audit found four bugs in itself while proving its first batch — including one where the check meant to prove 199 recipes were translated reported every one of them as untranslated. Probe every widening.
- **The cross-check between two independent sources is where the defects are.** Every one of Phase 7's findings in pre-existing content came from comparing two things that had never been compared: hand tags against derived diet flags, English ingredient names against Turkish ones, the new macro rule against the old catalogue.
