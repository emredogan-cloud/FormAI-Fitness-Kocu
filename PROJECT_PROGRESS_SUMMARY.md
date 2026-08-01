# FormAI — Project Progress Summary

**Spec:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` (18 phases / 5 waves)
**As of:** 2026-08-01 · Phase 6 polish sprint, half done · build **1.0.0+27**

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

# 2. Currently Working On

**The Phase 6 polish sprint — six of twelve founder items done.**
`PHASE_06_POLISH_REPORT.md` §3 is the authoritative list and
`RESUME_GUIDE.md` §2.0 is the pick-up point. **Phase 7 is blocked** until
the remaining six land.

Done: Premium rename · migration 012 applied and verified · metric/
imperial in Settings · language picker rebuilt to the reference · the AI
coach's four language leaks · tour-then-popup ordering.

Not started: paywall regional pricing (highest value — a revenue path) ·
four showcase screens · camera-free workout + rest redesign · workout
background images and the request doc · the Phase 7 nutrition
localization plan · the full two-language device sweep.

## What Phase 6 handed off

Three of these are founder decisions, not engineering.

| Item | Who | Why it matters |
|---|---|---|
| **Play Console regional pricing** | founder | The app renders whatever the store reports, so the target pricing is a Play change, not an app change. Blocks verifying the paywall item. |
| English screenshots + feature graphic, and pasting `docs/store/LISTING_EN.md` into Play Console | founder | The copy is written. Turkish frames cannot be reused under an English listing. |
| A native-speaker read of the English | founder | It is a reviewed, internally consistent draft, not proofread copy. The listing is the highest-leverage hour. |
| **Unlock the Redmi `AYXSUKIVJVPZ7HPZ`** | founder | PIN-locked. adb can install to it but nothing can drive its UI. All device work moved to the Redmi Note 12. |

## Two device surfaces still unverified

Both carried from Phase 5, both blocked the same way — they destroy the
session the rest of a sweep depends on, so they go last.

- **The paywall interior.** Auth-gated; adb sign-in taps still do not
  register. The gate itself is verified live; the interior has 27 widget
  tests. Missing is visual confirmation.
- **A clean-install onboarding**, which now also means seeing the
  language step as an actual first screen. Six widget tests and the
  English sweep cover it; glass does not.

# 3. Remaining Roadmap

### Wave 2 — Global Reach *(continues)*
- **Phase 7 — Content & AI Localization.** Localize what the user actually consumes — exercise names, coaching cues, plans, recipes, and the AI's cultural frame — so English FormAI is native, not translated.
- **Phase 8 — Spanish, French, German & RTL Readiness.** Turn localization from a project into a repeatable capability and reach the markets the testers named.

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
Wave 2 — Global Reach                    🔄 In Progress (Phases 5–6 done)
Wave 3 — Measurable Progress & Access    ⏳ Not Started (Phases 9–11)
Wave 4 — Community & Content Engine      ⏳ Not Started (Phases 12–14)
Wave 5 — Scale, Depth & Platform         ⏳ Not Started (Phases 15–17)
```

**Phases complete:** 8 of 18 (0, 1, 2, 3, 3b, 4, 5, 6) · two device surfaces carried forward: the paywall interior and a clean-install onboarding

### Current quality state

| | |
|---|---|
| **Build** | 1.0.0+27 |
| **Tests** | **915 passing** (baseline was 330) |
| **`flutter analyze`** | **0 issues** |
| **`dart format`** | clean |
| **CI** | **GREEN** (CI + Secret Scan) |
| **Hardcoded-string gate** | **0 in 0 files** · 244 allowlisted, reported per entry |
| **ARB** | **1473 keys** · `tr` 100% · `en` 100% · all referenced in `lib/` |
| **Locales shipped** | `tr`, `en` |

### Standing constraints

- **CI Flutter is 3.44.8, local is 3.41.9.** Local green is not proof; only CI is a reliable gate.
- **Migrations 001–012 are all applied to production** and verified live.
- The local release build is upload-key signed, so device installs need `adb uninstall` first (loses session, requires a full onboarding re-walk).
