# FormAI · Onboarding Emotional Rebuild — Engineering Analysis

> **Document type:** Engineering-side rebuild analysis (companion to product audit).
> **Audience:** Implementing engineer / tech lead.
> **Scope:** Code architecture, motion system, asset strategy, refactor plan.
> **Date:** 2026-05-09.
> **Companion document:** `ONBOARDING_UX_MASTER_AUDIT_TR.md` — covers product strategy, copy, retention psychology, monetization. **This document does not repeat that ground.** Read both.

---

## 0 · Why this document exists (and why it is not the whole job)

A 1,092-line strategic audit (`ONBOARDING_UX_MASTER_AUDIT_TR.md`, dated 2026-05-09) already covers:

- 10 strategic gaps (TL;DR §0)
- 12-step + 7-step flow inventories (§1)
- Step-by-step UX critique with copy suggestions (§3)
- Retention gaps, identity declaration, habit anchor, push opt-in (§5)
- Competitor benchmark vs BetterMe / Noom / Cal AI / Fitbod / Duolingo (§6)
- 4-phase roadmap with ~38 prioritized items (§10)

This document **does not redo any of that**. It adds the engineering layer the audit deferred:

1. Component-level architecture map of the current code
2. Mapping the user's "5-act" emotional framework onto actual screens
3. Motion-system gap analysis (what primitives don't exist yet, what needs to be built)
4. Asset strategy decision (Lottie / Rive / hand-coded / hybrid)
5. Performance risk register
6. Engineering rebuild strategy (3 options, ranked)
7. Open decisions blocking the work

The user's prompt asks for a "complete experience rebuild." The CLAUDE.md guidelines counsel **simplicity-first, surgical changes**. Those two pull in opposite directions. §8 ("Engineering Rebuild Strategy") makes the trade-off explicit and asks the founder to choose.

---

## 1 · Architectural Inventory (what exists today)

### 1.1 Onboarding feature module

```
lib/features/onboarding/
├── presentation/
│   ├── onboarding_screen.dart          ← 3,485 lines · monolith
│   ├── prediction_screen.dart          ← Phase 60C dead code (commented-out route)
│   └── widgets/
│       ├── interactive_question_step.dart
│       ├── onboarding_image.dart       ← AssetImage + placeholder
│       ├── photo_option_card.dart
│       └── wheel_column.dart           ← Cupertino picker wrapper
├── providers/
│   └── wizard_provider.dart            ← 239 lines · WizardState (21 fields)
└── domain/
    └── ai_personalization_engine.dart  ← 235 lines · pure
```

**Routing entry:** `lib/core/routing/app_router.dart:148-150` registers `/onboarding`. `lib/core/routing/app_router.dart:87-89` redirects first-time users.

**Persistence:** `WizardState.toJson()` (`wizard_provider.dart:178-200`) flat-serialises into SharedPreferences via `AppPreferencesService.saveUserMetrics(...)`. No server round-trip, no Supabase row.

### 1.2 Screen choreography

`onboarding_screen.dart:248-261` — single `PageView` with a `PageController`, 12 hard-coded children. No route per step. No transition customization beyond `Curves.easeOutCubic`, 380 ms.

### 1.3 Coach component (today)

The "AI coach" is **not a reusable component**. It is two private widgets inside the monolith:

- `_PulsingCoachAvatar` (`onboarding_screen.dart:762-847`) — static `AssetImage('photos/kişiselyapayzekakoçfoto.webp')` inside a 220 px radial-gradient ring, alpha pulsing 0.35 → 0.75 over 1.8 s.
- `_CoachIntroStep` (`onboarding_screen.dart:551-690`) — typewriter chat bubble, ~28 ms/character, button gates on completion.

The coach has **no name**, no state, no memory of prior answers, no facial reactions, no voice. The audit calls this out as the highest-leverage product gap (§7.2 and §11).

### 1.4 Personalization engine (today)

`ai_personalization_engine.dart:84-171` — pure-function branching on `goal × activityLevel × experienceLevel × painPoint`. Critical engineering finding:

> **Free-text fields are written but never read.**
>
> `WizardState.experienceDescription`, `activityDescription`, `painPointDescription` (lines 83–95) are captured by the hybrid steps and persisted to JSON (lines 190–192) — but **`_assessment()` never references them** (only the categorical token).
>
> The audit flags this as a product issue (§3.3, §3.6). It is also a one-line fix: add an `if (s.experienceDescription != null) parts.add(...)` block that quotes the user's first sentence back. This is the single highest-leverage engineering change in the entire flow. **Phase 1 must include it.**

### 1.5 Animation primitives (today)

All hand-coded. No `lottie`, no `rive`, no `flutter_animate`, no `animations` package. The single motion dependency is `shimmer: ^3.0.0` (`pubspec.yaml:60-65`), used for skeleton loaders elsewhere.

| Animation | Where | Implementation |
|---|---|---|
| Stagger fade+slide | `_WelcomeStep` lines 287–321 | `AnimationController` + `Interval` |
| Typewriter | `_CoachIntroStep` lines 731–759 | `AnimatedBuilder` + substring |
| Breathing glow | `_PulsingCoachAvatar` lines 771–846 | repeating controller + `RadialGradient` alpha |
| Rotating ring | `_AnalysisIllusionStep` lines 1478–1562 | `Transform.rotate` + `SweepGradient` |
| Confidence bar tween | `_DynamicReportStep` lines 1740–1781 | `Tween<double>` + `easeOutCubic` |
| Card feedback banner | `interactive_question_step.dart:85-105` | `CurvedAnimation` + `Tween<Offset>` |

These are **competent baseline animations**. None is the cinematic, emotionally synced, layered-depth motion the user's brief asks for. There are no:

- Particle systems
- Lottie/Rive sequences
- Multi-element choreographed entrances
- Camera/parallax effects
- Silhouette morph or transformation visuals
- Avatar facial-state changes
- Haptic crescendos coupled to motion
- Breath-synced multi-element pulses

### 1.6 Theme tokens

`lib/core/theme/app_colors.dart` — neon palette (`#8E5BFF`, `#4DA6FF`, `#6A3DFF`), dark-bg `#0B0B12`. `lib/core/theme/app_theme.dart` — Material `ThemeData`. Typography is inlined per-screen (no central scale), letter-spacing 0.4–3.0. **No motion tokens** (no shared easing curves, no shared animation durations, no RepaintBoundary patterns). Adding a `lib/core/motion/` namespace is part of the rebuild.

### 1.7 Haptic system

`lib/core/utils/app_haptics.dart` — `primaryCta()` / `secondaryTap()` / `selectionClick()`. Disciplined; the audit (§8.4) wants a `crescendo()` pattern added (light → medium → heavy across the final 3 steps). This is a 30-line addition.

### 1.8 Asset inventory

`photos/` directory contains static `.webp` files (gender, goal, activity, coach face). **Zero animation assets** (no `.json` Lottie, no `.riv` Rive, no `.mp4`). The `assets/` directory has one stray `.mp4` from TikTok (`ssstwitter.com_*.mp4`, 3.3 MB) that is not referenced anywhere — should be deleted.

---

## 2 · Mapping the User's "5-Act" Framework onto Real Screens

The brief frames the rebuild as a 5-act emotional structure. Mapping that onto the existing 12-step flow plus the audit's recommended insertions:

| Act | Goal | Existing screens (keep / refactor) | New screens (insert) |
|---|---|---|---|
| **Act 1 — Emotional Hook** | Make user feel understood | `welcome` (refactor: numerical promise) | — |
| **Act 2 — AI Companion Bonding** | Make coach feel alive & trusted | `coach_intro` (refactor: 3-line, named coach) | `name_capture` (audit §5.4) |
| **Act 3 — Transformation Buildup** | Build hope & anticipation | `gender`, `goal`, `experience`, `daily_minutes`, `activity`, `physical_data`, `pain_point` (refactor: callbacks, free-text quote) | `habit_anchor` (audit §5.3), `push_opt_in` (audit §5.2) |
| **Act 4 — Future-Self Visualization** | Make user *want* the transformation | `analysis_illusion` (refactor: differentiated style), `dynamic_report` (refactor: visual projection) | `silhouette_projection` (audit §3.8 / §7.4), `identity_declaration` (audit §5.4) |
| **Act 5 — Commitment Moment** | Begin a real journey | `pre_paywall_summary` (refactor: dated promise, name) | `microcommitment` (audit §9.4), `first_workout_prompt` (audit §5.5) |

**Result:** 12 existing screens → 9 keep-and-refactor + 3 delete-or-merge + 6 insert. Net: ~18 screens, ~110–130 s total time. The audit (§13.1) flags this as borderline-too-long and recommends merging `identity_declaration + microcommitment` into one screen if A/B shows drop-off.

**The 5-act framework is the right narrative spine, but it is not a shipping plan.** The audit's Phase 1–4 prioritization is — Phase 1 cuts across all 5 acts with low-effort wins; Phase 4 ships the cinematic foto-snap demo. Use the audit roadmap as the actual schedule.

---

## 3 · Motion-System Gap Analysis

The brief says the rebuild must feel "alive, conversational, emotional, cinematic, fast." The current codebase ships about **20% of the motion vocabulary needed** to deliver that.

### 3.1 Primitives that do not exist yet

A reusable rebuild needs a `lib/core/motion/` namespace with primitives. None of these exist today:

| Primitive | Purpose | Estimated LOC |
|---|---|---|
| `MotionTokens` (durations, curves, intervals) | Single source of easing/duration | ~80 |
| `BreathingBox` | Wraps any child in a 2.4 s ease-in-out alpha pulse | ~60 |
| `KineticTextReveal` | Word-by-word, then character-by-character fade-up reveal | ~120 |
| `StaggerColumn` | Auto-staggers children with shared controller, configurable delay | ~100 |
| `ParticleBurst` | One-shot 8–12 neon particles on tap, GPU-friendly via `CustomPainter` | ~180 |
| `GlowPulse` | Ambient glow ring synced to a controller — coach avatar replacement | ~70 |
| `MorphingNumber` | Number that tweens 0 → target with `easeOutQuart` + spring | ~80 |
| `DepthLayer` | Wraps child in parallax-on-scroll + blur-on-distance | ~140 |
| `HapticCrescendo` | Schedules `light → medium → heavy` over a controller's progress | ~50 |
| `EmotionalEasing` | Curve set: `softReassurance`, `energeticReveal`, `calmReflection` | ~40 |

**Total motion library: ~920 LOC, isolated, unit-testable.** This is the foundation. Without it, every screen reinvents primitives and the rebuild becomes the kind of spaghetti the user asked us to avoid.

### 3.2 Sequence primitives

Beyond per-widget primitives, the rebuild needs **screen-level choreography**. Two abstractions:

- `OnboardingScene` — base widget that owns a master `AnimationController`, exposes named "beats" (`beat0_intro`, `beat1_question`, `beat2_feedback`, `beat3_exit`). Every step extends this so timings are consistent.
- `SceneTransition` — replaces `PageView`'s default snap-slide with a cross-fade-and-rise transition that holds the user's eye on the coach avatar across boundaries. Duolingo and Cal AI both use this to make screens feel like "moments in a session" rather than "pages in a form."

### 3.3 Living coach component

Replacing `_PulsingCoachAvatar` (static webp + alpha pulse) with a "living" coach is the brief's centerpiece. Three implementation paths, ranked by effort:

| Path | Effort | Fidelity | Recommendation |
|---|---|---|---|
| **A. Static webp + advanced shader** — Same image, but with a `CustomPainter` that adds breath, blink hint, eye glint, halo pulse | Low (~2 days) | 5/10 | **Ship Phase 1.** Cheapest path that lifts perceived life. |
| **B. Rive avatar** — Hire artist for ~$400–800; rig 8 facial states (idle, listening, thinking, surprised, encouraging, celebrating, reflecting, concerned). Drive states from wizard answers. | Medium (~5–7 days incl. art) | 9/10 | **Ship Phase 2 / 3.** This is the "living avatar" the brief asks for. |
| **C. AI-rendered video stitching** — Pre-render coach VO + face per language; play over a video texture | High (~3+ weeks, infra cost) | 10/10 | Skip until proven LTV. Cal AI did NOT do this. |

The audit (§14) names "Form" / "Demir" / "Eda" as candidate names. Path B is what makes a **named** coach worth doing.

### 3.4 Asset strategy decision

Right now: zero animation assets, no Lottie/Rive deps. The motion system needs **one** of:

- **Hand-coded only** — Everything in `CustomPainter` / Flutter's `AnimationController`. Pure code, no asset pipeline. Maintenance scales with screen count. **Best for primitives** (`ParticleBurst`, `BreathingBox`, glow effects). Bad for character animation.
- **Add Rive** — Pubspec adds `rive: ^0.13.x`. Single animation tool for both UI motion and character. State machines map 1:1 to Riverpod state. Asset pipeline = `.riv` files. **Best for the coach** and any silhouette morph.
- **Add Lottie** — `lottie: ^3.x`. After Effects pipeline. Bigger bundle than Rive, less interactive (no state machines). **Best for one-shots** (welcome confetti, milestone celebrations) where designers want AE-style polish.
- **Hybrid** — Lottie for one-shots, Rive for the coach + silhouette, hand-coded primitives for ambient motion. Bundle size ~1.5–2 MB combined. **Recommended.**

**Decision needed from founder before Phase 2 work begins.** The choice cascades into asset budget, designer hires, and the silhouette-morph approach (audit §7.4 has 3 fidelity tiers; the SVG tier needs hand-coded morph; the ML tier doesn't ship; Rive is the sweet spot).

### 3.5 Performance budget

The brief insists on 60 fps. Risks specific to the rebuild:

| Risk | Source | Mitigation |
|---|---|---|
| Compositing layer thrash | Multiple `BackdropFilter` + `BoxShadow` blurs per screen | Cap to 1 blur per screen; use `RepaintBoundary` around stable subtrees |
| Particle GC churn | `ParticleBurst` allocating per-frame | Object-pool 24 particles; reuse on next burst |
| Avatar Rive cost | State-machine evaluation on every frame | Pause Rive on screens where coach not visible |
| Image decode hitch | Background `.webp` swap during transition | Already mitigated by `precacheImage` (lines 91–105) |
| `setState` on PageView parent | Forces full rebuild every page change | Lift step state into Riverpod; child screens watch only what they need |
| Long lists in `_DynamicReportStep` | 5+ animated rows | `RepaintBoundary` per row, sliver-based not column-based |

**Performance-test gate:** Phase 1 complete = `flutter run --profile` shows zero `>16ms` raster frames during the full wizard on a 2-year-old Android (Pixel 6 / Galaxy A52 class). Add this as a CI check before unlocking Phase 2 motion work.

---

## 4 · Code Smells Forcing a Refactor

Even if the brief did not exist, the onboarding code base needs cleanup before more features land:

1. **3,485 lines in one file** (`onboarding_screen.dart`). 12 step widgets are private classes inside that file. Adding 6 more screens (audit Phase 1+2) without splitting first is unsustainable. **Refactor first**: each step into its own file under `presentation/steps/`.
2. **Inline copy strings** scattered across all 12 step widgets. Hard to A/B-test, hard to localise (the rest of the app runs `intl` per `pubspec.yaml`, but onboarding does not). **Centralise**: `lib/features/onboarding/copy/` with a single source per language.
3. **`prediction_screen.dart` is dead code** (Phase 60C comment at `onboarding_screen.dart:210`). Delete it or document why it stays. Audit §1.3 calls this out.
4. **`WizardState` lacks fields that Phase 1 needs**: `name`, `bestTime`, `weekdays`, `pushPermitted`, `signedDeclaration`. Adding them is a `copyWith` extension; downstream `toJson()` and the `userMetrics` consumer adapt cleanly.
5. **`AiPersonalizationEngine` does not consume free-text fields** — confirmed at `ai_personalization_engine.dart:84-171`. This is the highest-impact one-line bug fix in the codebase.
6. **No tests on the onboarding feature**. `test/` directory has nothing under `features/onboarding/`. Before doing a rebuild, lock the current personalization engine behaviour with a golden-text test so we can refactor without regression.

---

## 5 · The 5 Reports the Brief Asks For — What Each Will Cover

The brief mandates 5 reports before code changes. What each report should contain (and what will be redundant if I write all 5 without checking in first):

### 5.1 `reports/onboarding-emotional-rebuild-analysis.md` — THIS DOCUMENT.

### 5.2 `reports/onboarding-rebuild-roadmap.md`
Re-statement of the audit's Phase 1–4 with engineering effort estimates, file-level deltas, and CI gates per phase. **High value if engineering-translated.** ~500 lines.

### 5.3 `reports/onboarding-animation-system.md`
The motion library spec from §3.1 above, fully fleshed out: API for each primitive, `MotionTokens` source, `OnboardingScene` base class, `SceneTransition` protocol, performance budget. **Required before any cinematic work.** ~600 lines.

### 5.4 `reports/onboarding-emotional-copywriting.md`
Voice guide for the (named) coach: tone rules, do/don't, line length, example responses. Plus ~80 specific lines covering all step states. **Risk:** the audit already has scattered copy. This document needs to consolidate, not duplicate. **Should be written in Turkish** to match production strings. ~400 lines.

### 5.5 `reports/onboarding-retention-psychology.md`
Largely redundant with audit §5 ("Retention Psikolojisi Analizi") and §10 (roadmap). **Recommend skipping** in favor of one-page deltas added to the audit. If the founder insists on a separate file, it should be a *summary* (~150 lines) not a fresh analysis.

**Recommendation:** ship 5.1, 5.2, 5.3 as separate files. Fold 5.4 into the existing audit as a new section. Drop 5.5 as redundant. **Net deliverable: 3 reports + audit append.** That covers the same surface area without bloat.

---

## 6 · The Implementation — What "Rebuild" Actually Means

The brief reads "complete experience rebuild." The CLAUDE.md guidelines say "surgical changes." Three real options:

### 6.1 Option A — Surgical (Phase 1 only)
- All audit Phase 1 items (12 items, ~1–2 sprints, 2 engineers)
- Refactor `onboarding_screen.dart` into per-step files (1 sprint)
- Build motion primitives library (~920 LOC, ~3–5 days)
- Quote free-text in personalization engine (1 hour)
- Coach gets a name (1 day, copy + 5 line code change)
- Numerical welcome promise (1 day)
- Fix multi-select allergies (1 day, audit §4.2.C — actually a bug, not enhancement)
- Identity-based goal options (1 day, copy + asset)
- Habit-anchor + push-opt-in screens (3 days)

**Total: 2–3 sprints. Onboarding completion +6–10%, paywall trial +8–12% per audit estimate.** No animation library, no coach rebuild, no silhouette morph.

### 6.2 Option B — Cinematic (Phase 1 + 2)
Everything in A, plus:
- Rive coach avatar with 8 facial states (5–7 days incl. art)
- Silhouette projection (low-effort SVG tier, audit §7.4) (~3 days)
- Identity declaration screen (~2 days)
- First-workout prompt with 5-min warmup flow (~5 days)
- Free-text quote in dynamic report (~1 hour)
- Trust booster on analysis illusion (~2 hours)

**Total: 5–7 sprints. Day-1 retention +10–15%, Day-7 +8–12%.** This is what the brief actually wants.

### 6.3 Option C — Full Rebuild (Phase 1 + 2 + 3 + 4)
Everything in B, plus AI photo-snap demo, two-illusion differentiation, voiceover, particle library, ML photo morph, video onboarding hero, multi-coach personas, voice-input, etc.

**Total: 6+ months. App Store rating +0.3–0.5, premium conversion +18–25%.** This is what the brief *aspires* to.

### 6.4 Recommendation

**Ship Option B over 6 weeks.** Then evaluate metrics. Phase 3 items unlock based on data (the AI demo costs $1–3K/month at scale per audit §13.2 — needs proven conversion lift first).

Doing Option C in one continuous push is what causes apps to ship buggy / never ship at all. The audit's closing note (§14, "Stratejik Soru — kurucuya") makes this point explicitly.

---

## 7 · Performance Risk Register

| # | Risk | Severity | Mitigation | Owner |
|---|---|---|---|---|
| P1 | Coach Rive avatar burns CPU on slower Android | High | Pause Rive on backgrounded screens; profile on Galaxy A52 | Eng |
| P2 | Multiple `BackdropFilter` blur layers tank fps | High | Cap 1 blur per screen; use `RepaintBoundary` | Eng |
| P3 | `ParticleBurst` GC churn | Medium | Pool 24 particles; reuse on next burst | Eng |
| P4 | `_DynamicReportStep` 5+ row animation kills middle-tier devices | Medium | Sliver list + `RepaintBoundary` per row | Eng |
| P5 | Asset bundle bloat (Rive + Lottie added) | Medium | Compress to <2 MB combined; lazy-load | Eng |
| P6 | Free-text quote-back hits LLM latency budget | Low | First-sentence regex extraction (no LLM); template-based | Eng |
| P7 | Haptic crescendo during background app state | Low | Guard with `WidgetsBinding.lifecycleState` | Eng |
| P8 | Onboarding flow grew to 18 screens; perceived too long | Medium | A/B test merging `identity_declaration + microcommitment` | PM |

---

## 8 · Open Decisions Blocking the Work

The brief is detailed about *what* but silent on *how much / how fast / what trade-offs*. The founder needs to answer these before the rebuild starts:

1. **Coach name.** Audit suggests `Form`. Brief implies "AI companion." Pick now — flows into copy, push notifications, marketing.
2. **Animation asset strategy.** Hand-coded only / +Rive / +Lottie / hybrid? Cascades into bundle size, designer hires, timeline.
3. **AI photo-snap demo.** Phase 3 high-impact item. Yes / no / pilot at 10% / wait?
4. **Identity declaration cultural fit.** Audit §13.4 flags Turkish users may find "Söz veriyorum" heavy. A/B or skip?
5. **Loss-framing ethics.** "Plan deletes in 24h" only ships if data actually deletes. Engineering policy needed before copy ships.
6. **Existing `prediction_screen.dart` dead code.** Delete or document?
7. **Existing `ONBOARDING_UX_MASTER_AUDIT_TR.md` language.** Audit is Turkish. New reports proposed in English. Pick a primary language for the artifact set.
8. **Scope: A / B / C** from §6 above. **This is the single most important question.** Without this answer, the next 4 reports are speculative.
9. **Risk tolerance for shipping during release freeze.** Recent commits (`fc696a8`, `d12e7a9`) show the project is mid-monetization-launch. Onboarding rebuild during paywall stabilization is risky. Sequence?
10. **Multi-select allergies.** Audit §4.2.C calls this a bug — `allergies` is `String` (single value) but real users have multiple intolerances. Recipe filter is broken for them. Phase 1 priority? (engineering: ~1 day)

---

## 9 · What I Recommend Doing Next

Given the conflict between "complete rebuild" (brief) and "surgical changes" (CLAUDE.md), my recommendation is:

1. **Founder picks Scope A / B / C** from §6.
2. If A or B:
   - Write `reports/onboarding-rebuild-roadmap.md` (Phase 1+ engineering schedule with effort estimates per item)
   - Write `reports/onboarding-animation-system.md` (the motion primitives spec from §3)
   - Append "Coach Voice Guide" section to `ONBOARDING_UX_MASTER_AUDIT_TR.md` instead of new copywriting file
   - Drop `onboarding-retention-psychology.md` as redundant
   - Then start Phase 1 implementation, one screen-pair at a time, with fps-profile gate per merge
3. If C: agree on a 6-month roadmap, hire/brief a Rive animator, and book the founder's calendar against the launch freeze.

**The smallest meaningful first commit** — independent of A / B / C — is the personalization-engine fix (`ai_personalization_engine.dart:84-171` quotes user's free-text). One line, untestable in isolation, immediately raises the perceived AI intelligence on the dynamic-report screen. Audit §3.3 makes this case. Recommend shipping it before any rebuild work begins, as a separate small PR.

---

**End of analysis.** Ready for founder decision on §8 / §6 before producing remaining reports or writing implementation code.
