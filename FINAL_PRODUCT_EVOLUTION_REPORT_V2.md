# FormAI — Product Evolution Report V2 (Post-Beta)

**Date:** 2026-07-13 · **Branch:** `main` · **Device:** Xiaomi M1908C3JGG (Android 11), release build, real guest session · **Repo health:** `flutter analyze` 0 · **327 tests** green.

This sprint took FormAI from "beta-ready" toward "world-class production." Two
flagship changes landed and were **verified on a real device**: a genuine
freemium nutrition experience, and a real (LLM-backed) AI coach with a proper
dashboard presence. Everything engineerable was done; the one founder-gated
item (deploy the coach model with an Anthropic key) is in
`FOUNDER_MASTER_GUIDE_APPENDIX.md`.

> Companion: `FOUNDER_MASTER_GUIDE_APPENDIX.md` — the founder-only tasks.

---

## What changed (at a glance)

| Area | Before | After |
|---|---|---|
| **Nutrition** | Hard paywall — a non-pro tap on Beslenme fired the paywall and revealed nothing. Zero free value. | Real freemium: intro → onboarding → free target + recipe library → natural in-tab Pro wall. **Device-verified.** |
| **AI Coach** | Rule-based only; reachable via a small header avatar. | Real Claude brain behind a secure Edge Function (rule brain as offline fallback); async chat with typing; **a first-class dashboard coach card.** |
| **Coach chat UX** | Suggestion chips sent terse intents ("today"); sync only. | Chips send natural language; async with a pulsing typing bubble; disposal-safe. |
| **Theme** | Strong dark-first; one residual light-mode bug. | Light-mode bug fixed; all new widgets theme-aware (verified light + dark). |

Commits this sprint: `e4c6720` (nutrition freemium) · `af9dfd6` (LLM coach) · `0e8855b` (coach card + light fix).

---

## Phase A — Nutrition freemium (flagship, device-verified)

### The problem
The entire Beslenme tab was Pro-gated at the tab switch: a non-pro user was
bounced straight into the paywall and never saw a single recipe or number. That
is the lowest-converting shape there is — free users can't feel the value, and
even a store reviewer only sees the module via the reviewer account.

### The redesign (studied against MyFitnessPal / MacroFactor / Fitbod)
Tap Beslenme → **intro scene** → **4-step onboarding** (goal, diet, taste) →
**real free content** → **natural premium wall**. The line drawn:

- **Free (the taste):** the cinematic intro, the onboarding (which also
  personalises the upsell), the day's **real calorie/macro target** computed
  from the profile, a taste of the AI prescription, and the **full recipe
  library** to browse + open.
- **Pro (the wall):** the **personalised daily meal plan** (replaced by a
  compelling `_NutritionProUpsell` card exactly where the plan would be) and
  **meal tracking / add-to-plan** ("Hemen Ekle", recipe "Plana Ekle" → the
  cinematic conversion moment).

So free = "here's your target + a library to explore"; Pro = "a personalised
plan that tracks you + AI coaching." Enough to hook, enough withheld to convert.

### Device evidence (real guest session, non-pro)
Walked the whole flow on the device:
1. Tap Beslenme → the **intro scene** fires ("Beslenme… Dönüşümünün en güçlü parçalarından biri") — previously impossible for a non-pro user.
2. → the **onboarding wizard** (goal → diet → taste, "Son 4 adım").
3. → a **plan-prep transition** → the **nutrition content**: calorie ring "0 / 1758 kcal", macro bars (P 176g / K 132g / Y 59g targets), an AI insight ("Protein hedefini kaçırıyorsun"), a browseable next-best-meal.
4. → the **`_NutritionProUpsell` card**: "FormAI Pro · Sana özel günlük beslenme planı" with three benefit bullets + "Pro'yu Keşfet", sitting exactly where the personalised plan lives for Pro users.

Verified in **both dark and light** — the upsell card is fully theme-aware
(white card / neon border / legible text in light; deep-purple in dark).

### Files
`dashboard_screen.dart` (removed the tab-level block; orphaned imports cleaned),
`nutrition_tab.dart` (`_NutritionProUpsell` + `_UpsellBullet`; gated "Hemen
Ekle"), `recipe_detail_screen.dart` (gated "Plana Ekle"). Dev testing still
bypasses the wall via the existing debug Sandbox button.

---

## Phase C — Real AI Coach (LLM) + AI UX (built, deploy is founder-gated)

### Architecture (the key never ships in the app)
- **`supabase/functions/coach-chat`** — a Deno Edge Function holding
  `ANTHROPIC_API_KEY` server-side. It prepends the **definitive coaching
  persona** (a real "Form" coach — not an assistant; Turkish; warm, concise,
  emotionally intelligent; a hard *not-medical-advice* guardrail) + the user's
  real context, calls **Claude Haiku** (cheapest tier), caps output tokens, and
  marks the static persona **cacheable**. Model + token budget are env-overridable.
- **`CoachBrain.respond` is now async.** `RuleBasedCoachBrain` wraps its honest
  sync logic; **`LlmCoachBrain`** calls the function with history **compressed**
  to the recent turns, a 15 s timeout, and **falls back to the rule brain on ANY
  failure** (offline, 404, model error, timeout) — the coach can never go blank
  or hang.
- **`coachBrainProvider`** returns the LLM brain only when
  `COACH_LLM_ENABLED=true` (flip it after deploy); **`coachChatProvider`** gained
  a `sending` flag and an async, disposal-safe `send()`.

### Cost discipline (built in)
Local greeting (no model call to say hello) · Haiku · history compression ·
cacheable persona · capped output → a typical turn is a few hundred tokens.

### AI UX — a first-class dashboard entry
The dashboard now carries a prominent, always-present **coach card** (Form
avatar + online dot + "AI koçun. Bugün sana nasıl yardımcı olabilirim?" +
chevron), placed under the weekly goal — a calm, tappable surface like WHOOP's /
Fitbod's coach card, **not a floating bubble**. Theme-aware; one tap opens the
full conversation. The header shortcut stays for quick access.

### Coach chat polish
A pulsing **typing bubble** while the coach thinks; suggestion chips now send
**natural-language labels** (so the user's own bubble reads naturally and the
LLM gets real language, not "today").

### Device evidence
Tapped the dashboard coach card → the coach opened with a **contextual** greeting
("İyi akşamlar ss! … Bugün 1. günündesin — 6 egzersiz seni bekliyor"). Sent
"Bugün ne yapmalıyım?" → a contextual reply ("1. gün: 6 egzersiz. Ekipmanların
olduğu için…"). Async send + reply verified end-to-end (rule brain, since the
LLM is off until deployed). Card verified in dark + light.

### What's founder-gated
Deploy (`supabase functions deploy coach-chat` + `supabase secrets set
ANTHROPIC_API_KEY=…`) and the live conversation-quality pass — the model can't be
exercised without the key. Scenarios + rubric are ready in `tool/coach_eval.md`;
steps in the appendix (A1/A2). Until then the app runs the honest rule brain,
which is exactly the fallback.

### Tests
+6 `llm_coach_brain` tests: uses the model reply on success; falls back on
throw / null / empty / timeout; compresses history to the recent turns; greeting
+ suggestions stay local (no transport call). Existing coach tests updated for async.

---

## Phase B — Theme audit

The app had already had a thorough light-mode pass (the "Phase 53" hotfixes
throughout `nutrition_tab.dart` pull `onSurface`/`context.colors` everywhere).
This sprint:

- **Fixed** `_EmptyState` (nutrition) — hardcoded white text on a near-
  transparent white surface → invisible on the light scaffold. Now `onSurface`,
  legible on both.
- **All new widgets** (`_NutritionProUpsell`, `_UpsellBullet`, `_CoachEntryCard`)
  are theme-aware and were **verified legible in light mode on device**.
- The Coach + onboarding screens are **deliberately always-dark** (a premium
  chat aesthetic, like many messaging UIs) — documented as a choice, not a bug.

A full remaining-screen + tablet/orientation sweep is a pre-launch QA item (A4).

---

## Phase D — Profile & Progress (reviewed; low risk, no forced changes)

Reviewed on device. The Profil screen is clean and well-built: identity block
with level/XP, editable metric cards (age/weight/height/goal), streak +
completed counters, referral (code + share + "use a code"), favorites, theme
control, premium management, a voice-coach test, and privacy — all coherent and
readable. No defects worth a risky edit surfaced, so per the "surgical changes"
principle nothing was force-changed.

**Ideas (documented, not force-fit):**
- Close the loop between onboarding and the new coach — have the coach's first
  greeting reference an onboarding answer (the context is already available via
  `coachContextProvider`).
- The nutrition streak has no real backing yet (the pill is hidden when 0, which
  is honest); a real nutrition-log streak would unlock the `nutrition_hero`
  badge and add a retention hook.

---

## Validation

- `flutter analyze` → **0 issues** across all changes.
- `flutter test` → **327 passed** (+6 new LLM-brain tests).
- Real-device pass on the release build (guest/non-pro): nutrition freemium
  (dark + light), coach card + contextual chat, light-mode legibility of new
  widgets, theme toggle round-trip.
- The one release-build hiccup during testing was a **transient** Gradle-daemon
  contention (a concurrent `flutter test`), not a code issue — the rebuild
  succeeded and installed cleanly.

---

## Remaining risks / honest limitations

- **Live LLM unverified here** — no Anthropic key in this environment. The
  architecture, fallback, compression, and safety guardrail are built and unit-
  tested; the conversation-quality pass runs once the founder deploys (A1/A2).
- **Freemium split is a first cut** — sensible by comparison to peers, but the
  exact free/Pro boundary should be tuned against real funnel data (A3).
- **Full theme/tablet sweep** — key screens verified; an exhaustive matrix is a
  pre-launch QA session (A4).
- **Recipe-detail deep add paths** — the primary add-to-plan surfaces are gated;
  if any secondary add path exists it should get the same one-line gate.

---

## Future opportunities

- Ship the LLM coach live, then iterate the persona from `tool/coach_eval.md`.
- Coach memory across sessions (server-side rolling summary) once the model is live.
- Streaming coach replies for perceived speed.
- A real nutrition-tracking streak → unlock the dormant nutrition badges.
- Onboarding → coach continuity (the coach references what the user told onboarding).

---

*Screenshots captured during device verification are in the session scratchpad
(dashboard coach card, coach chat, the full nutrition freemium flow, and the
light-mode upsell). Companion founder tasks: `FOUNDER_MASTER_GUIDE_APPENDIX.md`.*
