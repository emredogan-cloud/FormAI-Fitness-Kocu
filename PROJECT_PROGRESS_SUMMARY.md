# FormAI — Project Progress Summary

**Spec:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` (18 phases / 5 waves)
**As of:** 2026-08-01 · commit `12ab365` · build **1.0.0+25**

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

### Phase 5 — Internationalization Infrastructure 🔄 *engineering complete, device sweep ~1/3*
*Build 1.0.0+25 · 850 tests · CI green · `PHASE_05_COMPLETION_REPORT.md`*
- Hardcoded-string gate at **0 in 0 files**; ARB **1390 keys, 100% referenced and 100% resolved**.
- Pseudo-locale sweep (18 surfaces × 3 viewports) and RTL sweep (16 surfaces) in CI; the pseudo sweep found six real overflows on its first run.
- `docs/i18n/` — pipeline runbook, glossary, text-in-images inventory, adding-a-locale.
- See section 2 for what remains.

---

# 2. Currently Working On

## Phase 5 — Internationalization Infrastructure

**Goal:** extract every user-visible string into ARB, make the app locale-parametric end to end, and make reintroducing hardcoded strings structurally impossible — **while shipping zero visible change to Turkish users.**

### Finished inside this phase

**Infrastructure (complete)**
- `tool/check_hardcoded_strings.dart` — ratchet gate with a committed per-file baseline; fails only when a file's count rises. Enforced in CI.
- `tool/arb_coverage.dart` — key counts, missing keys per locale, unused keys, placeholder parity.
- `lib/core/utils/unit_system.dart` — exact metric/imperial conversion, fully unit-tested.
- `lib/core/utils/pseudo_locale.dart` — bracketing + 40% inflation, placeholders passed through verbatim.
- `localeResolutionCallback` scaffolding in `main.dart`; `locale` parameter threaded into the coach-chat edge function.
- Migration `011_content_localization_schema.sql` (schema only) — **not applied to prod**.

**Extraction (~19 slices, each committed and CI-verified separately)**
- Core widgets, auth, feedback, survey, help centre, referral, progress, badges, suggestions, churn, premium welcome, nutrition, workout widgets, manual workout, camera tutorial.
- Domain/service layer: pose analyzers, voice coach, badge catalogue, notifications, progressive disclosure.

**Two structural findings worth recording**

1. **The gate was measuring a subset and reporting it as the total.** It scanned only `/presentation/`. Extracting the camera tutorial to zero would have left its most-read line — the live "can I see you?" framing hint, six Turkish strings in `domain/` — untranslated behind a green gate. Scope widened to all of `lib/`: the count moved **701 → 1131 with nothing regressed**. The blind spot held ~540 literals: every analyzer's form warnings, the whole voice coach, notification bodies, badge names, FAQ answers, tips.

2. **A recurring architectural split.** Four subsystems now separate *what was decided* from *what to say about it*: `FramingIssue` → hint, `CoachLine` → text, `BadgeDefinition` → title, `Capability`/`UnlockHint` → copy. The mechanism differs per subsystem by constraint, not by pattern — `CoachLine` is an enum with exhaustive switches; badge IDs stay strings because they are persisted and keyed on by the XP calculator, so exhaustiveness is bought in a test instead.

### Remaining in Phase 5

Engineering is done. What is left is a **device sweep**, and it is the
only reason this phase is not closed.

| Item | Status |
|---|---|
| Extraction (283 → 0 this session) | ✅ gate reports 0 in 0 files |
| Pseudo-locale wiring + layout sweep | ✅ 18 surfaces × 3 viewports, in CI |
| RTL readiness | ✅ 16 surfaces, in CI |
| ICU plural audit | ✅ 19 English messages converted; audit reports the rest |
| Translation pipeline docs | ✅ `docs/i18n/` |
| `PHASE_05_COMPLETION_REPORT.md` | ✅ |
| **Device walk of phases 1–5** | 🔄 **all but two surfaces.** Done: dashboard, plan detail, live camera workout, rest overlay, exit dialog, nutrition tab, nutrition onboarding sheet, progress, profile, discovery hub (incl. a live manual unlock), help centre (incl. search + empty state), badges, paywall auth gate, auth screen. Remaining: the paywall **interior** (auth-gated; adb sign-in taps do not register) and a **clean-install onboarding** (needs `adb uninstall`, which destroys the session). |
| ARB → TMS round trip | deferred to Phase 6 — there is no second locale to round-trip yet |
| Image goldens | **deliberately not done.** The pseudo + RTL sweeps cover the same failure class; goldens add font-rendering fragility between CI and a workstation. Reasoning in `docs/i18n/README.md`. |

**Four defects found this phase that no test could have caught:** a
plan-screen heading rendering `Closure: (AppLocalizations) => String`
(an interpolation that called a tear-off); the live workout HUD showing
`UNKNOWN` beside the rep counter (a raw enum name); a selected nutrition
card overlapping its own subtitle; and the badge strip clipping
"30 Gün Şampiyonu" to "30 Gün Şampiy". The first came from widening the
scanner, the other three from a real screen.

Two of those share a root cause worth remembering: **`FittedBox` does
not make text fit.** It lays its child out unbounded, so the text never
wraps, and if the natural width already exceeds the slot the scale does
not save it — the result is a mid-word clip with no ellipsis.

### Two deviations to flag

- **Allowlist (194 literals, reported per entry on every run).** `lib/features/admin/` (96) is staff-only and router-gated. `workout_repository.dart` (98) is the seeded exercise catalogue — data identity mirroring database rows, which Phase 7 localises through migration 011's columns; putting it in ARB would fork the catalogue.
- **The roadmap's success criterion "all 330 existing tests green, unmodified" has not held literally.** Roughly eight assertions changed where an API genuinely changed — e.g. `expect(r.formWarning, 'Kolları tam yukarı uzat!')` became `expect(r.formWarning, CoachLine.armsFullyExtended)`. In each case the test was pinning wording as a proxy for a decision and now pins the decision directly. No assertion was weakened or deleted to make a test pass.

---

# 3. Remaining Roadmap

### Wave 2 — Global Reach *(continues)*
- **Phase 6 — English Launch & Language Preference.** Ship the first non-Turkish language end to end and give every user explicit control over it.
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
Wave 2 — Global Reach                    🔄 In Progress (Phase 5 engineering done)
Wave 3 — Measurable Progress & Access    ⏳ Not Started (Phases 9–11)
Wave 4 — Community & Content Engine      ⏳ Not Started (Phases 12–14)
Wave 5 — Scale, Depth & Platform         ⏳ Not Started (Phases 15–17)
```

**Phases complete:** 6 of 18 (0, 1, 2, 3, 3b, 4) · Phase 5 engineering complete, device sweep done except the paywall interior and a clean-install onboarding

### Current quality state

| | |
|---|---|
| **Build** | 1.0.0+23 |
| **Tests** | **790 passing** (baseline was 330) |
| **`flutter analyze`** | **0 issues** |
| **`dart format`** | clean |
| **CI** | **GREEN** on `4f11b7b` (CI + Secret Scan) |
| **Hardcoded-string gate** | 1004 in 66 files, ratcheting down · 194 allowlisted, reported per entry |
| **ARB** | 434 keys · `tr` 100% · 428 referenced in `lib/` |

### Standing constraints

- **CI Flutter is 3.44.8, local is 3.41.9.** Local green is not proof; only CI is a reliable gate.
- **Migrations 008–011 are written but not applied to production** — founder decision required.
- The local release build is upload-key signed, so device installs need `adb uninstall` first (loses session, requires a full onboarding re-walk).
