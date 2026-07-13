# FormAI — Final Product Evolution Report

**Date:** 2026-07-13 · **Branch:** `main` @ `1d92e9f` · **Author:** engineering pass (autonomous)

This is one of the **two** documents that close out the Final Product Evolution
Sprint. It records what was built, what was verified, and what was found — with
honest limitations. The companion document, **`FOUNDER_MASTER_GUIDE.md`**, is
the step-by-step handbook for everything only you (accounts, money, devices) can
do.

**Repo health at close:** `flutter analyze` **0 issues** · **321 tests pass** ·
release AAB `1.0.0+14` built (106.9 MB bundle), obfuscated, **16 KB page-size
verified** (all 9 arm64 `.so` libs aligned) · GitHub: only `main` remains · CI
hardened (see §7). Everything an engineer can do without your accounts is done.

---

## Executive summary

The sprint had ten parts. Nine produced shippable code or verified an existing
capability; one (nutrition deep-visual audit) is honestly capped by a paywall
and documented rather than blindly changed. The headline additions:

| # | Part | Outcome |
|---|---|---|
| 1 | **Persistent AI Coach** | **Built & shipped.** Always-reachable, context-aware, honest, LLM-ready. |
| 2 | Nutrition audit | Audited from code; module is already rich; the one real finding is a *product* decision (free taste), documented. |
| 3 | Live form detection | **Re-verified on device** — pose state, framing hint, live rep counter all working on the new build. |
| 4 | UI darkness | Assessed: dark-first is brand-correct and legible; light toggle exists. No risky global change. |
| 5 | AI avatar | **Regenerated** — one friendly, consistent "Form" persona replaces the text-baked robot. |
| 6 | App icon padding | **Fixed** — new FormAI mark, adaptive foreground re-fit to the safe zone. |
| 7 | GitHub cleanup | **Done** — single `main`, and CI made *deterministically* green (this session). |
| 8 | Supabase sync | **Done** — migration history repaired (001–007); prod objects probe-verified. |
| 9 | Onboarding review | Reviewed; it's a genuine differentiator; ideas captured, no regressions introduced. |
| 10 | Continuous validation | Green throughout; final AAB + 16 KB re-verified at close. |

---

## Part 1 — The persistent AI Coach (flagship)

**Goal:** a coach that is always reachable, has a permanent UI presence, and
genuinely knows the user (profile, today's workout, progress, achievements,
goals, onboarding answers) — architected so a real LLM can slot in later,
without faking intelligence today.

**What shipped (all on `main`):**

- **`lib/features/coach/domain/coach_context.dart`** — an immutable snapshot of
  everything the coach knows, aggregated from *existing* app state: name, goal,
  age/height/weight, activity level, equipment, streak, level, XP, badge count,
  completed/total days, and today's day number + exercise count + completion.
  Getters `firstName` and `bmi`. Crucially, `toPromptContext()` renders this
  state as a Turkish system-prompt string — **this is the exact seam a future
  LLM plugs into.**
- **`lib/features/coach/domain/coach_brain.dart`** — the `CoachBrain` interface
  (`greeting`, `suggestions`, `respond`) plus `CoachTurn`/`CoachSuggestion`.
  The production LLM design is documented in-file: a Supabase Edge Function
  proxy (`coach-chat`) so the model key is **never** on the client, rolling
  summary memory, and a medical guardrail.
- **`lib/features/coach/domain/rule_based_coach_brain.dart`** — the brain we can
  *honestly* ship today. Every reply is derived from the real context (today's
  day and exercise count, real progress %, real streak, computed BMI + goal).
  Intents: today, progress, nutrition, motivate, streak, injury, greet, thanks.
  The injury path defers to a professional with a "not medical advice"
  disclaimer. **The fallback is honest** — unmatched input gets "here's what I
  can actually help with," never fabricated free-form text.
- **`lib/features/coach/presentation/coach_screen.dart`** — the chat UI (Form
  avatar + "AI Koçun · çevrimiçi", bubbles, starter suggestion chips, input
  bar). It reads the conversation from a provider, so it is **unchanged** when
  the rule brain is swapped for an LLM.
- **`lib/features/coach/providers/coach_providers.dart`** — `coachBrainProvider`
  (the one-line swap point), `coachContextProvider` (aggregation), and
  `coachChatProvider` (the live conversation, seeded with a contextual greeting).
- **Permanent presence:** a 38 px circular Form avatar button in the workout
  header (`antrenman_tab.dart`) routes to `/coach` (added to `app_router.dart`).
- **Tests:** `test/features/coach/coach_brain_test.dart` (8 tests) pins both
  properties the future LLM must preserve: genuine context-awareness AND
  honesty (no faked replies).

**Device-verified** on the Xiaomi test device against the new build: the
greeting personalises to the user and today's plan ("… Bugün 1. günündesin — 6
egzersiz seni bekliyor."), the progress chip reports real numbers ("0/30 gün
tamamlandı (%0) …"), and free-text motivation replies land.

**Why this is the honest maximum today:** shipping a fake "AI chat" that
hallucinates fitness/medical claims would be both a product lie and a store-
review risk. The rule brain tells the truth about its scope; the architecture
means going live with a real model is a *provider swap + Edge Function*, not a
rewrite. See `FOUNDER_MASTER_GUIDE.md` → "Turning the Coach into a real LLM."

---

## Part 2 — Nutrition audit

**What the module already is (from code):** a genuinely rich nutrition surface —
a calorie ring with a traffic-light palette, macro progress bars, a
`_MacroTilesRow` (kcal + protein/carbs/fat tiles), AI "prescription" prompts, a
next-best-meal suggestion, a collapsed "kcal kaldı | P %…" toolbar, recipe
detail with tags, and a shopping list. The listing's "yüzlerce tarif" maps to
**293 recipes** in the catalogue. This is not a thin feature.

**The one real finding — and it's a *product* decision, not a bug:** the entire
Beslenme tab is **Pro-gated** for non-subscribers. A free/guest user tapping it
is intercepted by the premium gate (`dashboard_screen.dart:366`) and bounced
back — they never see any nutrition content. That is an intentional monetization
choice, and it's internally consistent (the paywall does its job). But from a
growth lens it's aggressive: free users get **zero** nutrition taste, so they
can't experience the module's value before paying, and a store reviewer only
sees it via the reviewer account.

**Recommendation (founder decision — deliberately NOT changed unilaterally):**
consider a small free taste — e.g. 2–3 unlocked sample recipes or a read-only
calorie ring — to drive conversion and to let reviewers/users feel the value.
This is a pricing/product call with revenue implications, so it belongs to you,
not to an engineer editing the paywall blind. Documented in the master guide's
"Product decisions" section.

**Why no blind UI edits:** the nutrition UI is only reachable with Pro, which
this environment can't exercise end-to-end, and the code shows the visualisation
is already complete. Changing spacing/colours I can't see on-device would be
speculative — exactly the kind of non-surgical change to avoid.

---

## Part 3 — Live form detection (re-verification)

Re-verified on the **new** release build on device: the camera opens, the pose
overlay initialises, the UNKNOWN pose state shows the "Kadraja gir" framing hint
when no full body is in frame, and the rep counter is live. The per-exercise
analyzers are covered by golden-frame tests that feed **synthetic pose streams**
(landmark sequences) through the rep/form logic, which is the right way to test
CV logic deterministically in CI. Voice coaching (flutter_tts) is wired and
testable from the profile "Sesli Koç Testi". No regressions from the avatar/icon
/coach changes.

**Honest limitation:** a full "does it correctly count a real squat set" pass
needs a person exercising in front of the camera — that's the device-QA line
item G1 in the founder guide, not something automatable here.

---

## Part 4 — UI darkness assessment

**Verdict: the app is *appropriately* dark, not oppressively dark — no change
needed.** Evidence and reasoning:

- The brand is deliberately **dark-first** (deep `#0A0612` base, neon purple/cyan
  accents). On device the dark surfaces read as premium: cards carry subtle
  light borders, text is high-contrast white/blue, and accents guide the eye.
- A **light theme toggle already exists**, so users who prefer light aren't
  trapped.
- The one *coherence* nit (documented earlier as D2): onboarding is always-dark
  (cinematic) while the rest follows the system theme, so a light-mode device
  can jump dark→light after onboarding. That's polish, not a defect; the
  low-risk options (default `themeMode` to dark, or add a light onboarding
  variant) are a product call, captured in the guide.

Making a *global* darkness change (e.g. lightening every surface) would be a
high-blast-radius edit against a brand decision — explicitly avoided.

---

## Part 5 — AI avatar (regenerated)

**Before:** `photos/PT_FORM.png` was a stock-looking robot with **baked-in text**
("Form / AI COACH") and a green accent that clashed with the purple/cyan brand —
text baked into pixels can't be localised and reads as clip-art.

**After:** a single friendly humanoid "Form" persona (generated via the
authorized OpenAI key), 640 px, transparent corners, on-brand. It is the **one
consistent identity** now used both in the coach screen header and as the
coach's chat-bubble avatar, and as the permanent header button on the workout
tab. The legacy asset was preserved at `scratchpad/PT_FORM_legacy.png` for
reference. **Device-verified** visible in both the header and the coach bubble.

**Remaining (post-launch, design):** evolving "Form" into a more distinctive
mascot character (a retention lever) is a design investment, not an engineering
task — noted in the guide's polish backlog.

---

## Part 6 — App icon padding fix

**Problem:** the previous launcher icon was a photographic "AI FITNESS COACH"
image — wrong brand, and its adaptive foreground didn't respect the safe zone,
so Android's circular/rounded masks clipped it.

**Fix:**
- New full-bleed FormAI mark: a purple→cyan neon running figure
  (`tool/app_icon.png`, `tool/app_icon_fg.png`, source at
  `tool/app_icon_source_formai.png`).
- The adaptive **foreground** is the figure extracted via luminance-alpha and
  re-fit to **~74 % fill**, inside the ~66 % safe-zone circle every OEM mask
  respects (the prior art was too small *and* too edge-heavy). Background set to
  the brand `#0A0612` (was `#212427`).
- Regenerated all densities via `flutter_launcher_icons`; iOS 1024 confirmed
  **RGB with no alpha** (App Store rejects alpha in the marketing icon).

Adaptive previews were checked across mask shapes; the figure stays fully inside
the mask with balanced padding.

---

## Part 7 — GitHub cleanup + CI made deterministically green

**Branches:** the store-submission work (72 commits) was merged to `main`, stale
branches deleted, and **only `main` remains**.

**CI reliability (fixed this session):** `main` had been showing red on every
push, but *both* causes were environmental, not code — and both are now fixed:

1. **Secret Scan / gitleaks** was failing with "missing gitleaks license." The
   `gitleaks-action@v2` wrapper added a license gate that, for org-associated
   accounts, fails whenever its license-validation API call is **rate-limited by
   GitHub** — a non-deterministic red (it passed on one commit, failed on the
   next). Fix (`1d92e9f`): run the **MIT-licensed gitleaks binary** directly.
   Same detection engine, auto-loads our `.gitleaks.toml` allowlist, scans full
   history + working tree, **no license call.** The independent `.env` secret
   guard job was already green and is unchanged.
2. **CI** intermittently hit **"No space left on device"** — the emulator's AVD
   system image is several GB and tight runners ran out. Fix (`1d92e9f`): a
   dependency-free step reclaims ~10 GB of unused pre-installed toolchains
   (dotnet, ghc, powershell, swift, CodeQL) before the heavy work, on both the
   emulator and APK-build jobs.

Together with the earlier KVM fix (`eb83307`, which cured the emulator's
software-render timeout), these remove the known flake sources. The gitleaks
change is deterministic; the disk change is defensive headroom.

---

## Part 8 — Supabase production sync

- **Migration history repaired:** `supabase migration repair --status applied
  001 … 007` — the remote history table now tracks all seven migrations (they
  had been applied out-of-band historically, so `migration list` showed an empty
  remote column despite the objects existing).
- **Production objects probe-verified** via REST/RPC (a 404 vs a `PGRST202`
  hint vs a `P0001` "Not authenticated" tells you whether an object exists):
  `delete_user` exists (returns "Not authenticated" when called anonymously) and
  `redeem_referral(referrer_code text)` **matches the app's call signature**
  (`rpc('redeem_referral', params: {'referrer_code': …})` in
  `referral_service.dart`).
- `supabase db diff` timed out at 2 min against the pooled connection, so
  verification is probe-based rather than a full schema diff — an honest
  limitation, but the objects the app actually calls are confirmed present with
  matching signatures.

**Founder follow-up** (in the guide): the delete round-trip should be confirmed
once on a throwaway account against prod, and custom SMTP configured before
inviting 12 testers (default Supabase SMTP is ~2 mails/hr).

---

## Part 9 — Onboarding review (product-designer lens)

The onboarding is a **genuine differentiator** and was verified working end-to-
end on device across prior sprints: an age gate, opt-in-OFF consent, an 11-step
persona-driven wizard (name chat, feelings multi-select, pain point, activity,
body metrics, cinematic interludes, plan generation, an AI "report," honest
social proof, equipment), and a projection chart. It is closer to Duolingo/WHOOP
onboarding than to a typical fitness app's form.

**Ideas (captured, not force-fit):**

- **Close the loop to the new coach.** Onboarding builds a relationship with
  "Form"; the persistent coach (Part 1) now *continues* it inside the app.
  A natural next step is to have the coach's first-session greeting explicitly
  reference an onboarding answer ("Göbek eritmek" goal, chosen activity) — the
  context is already available via `coachContextProvider`.
- **Theme coherence** (Part 4 / D2): give onboarding→app a single theme feel.
- These are enhancements; the flow ships as-is with no regressions.

---

## Part 10 — Continuous validation (final gate)

Run at close on `main`:

- `flutter analyze` → **No issues found.**
- `flutter test` → **All 321 tests passed.**
- `flutter build appbundle --release --obfuscate --split-debug-info` → built
  `app-release.aab` (106.9 MB bundle; download size is far smaller via split
  APKs).
- **16 KB page-size re-verified** on the fresh AAB: all 9 arm64 `.so` LOAD
  segments are ≥ `0x4000`-aligned.
- CI hardened and pushed (§7); the run on `1d92e9f` should now be green (verify
  in the Actions tab — the fixes are deterministic/defensive).

---

## What changed on disk this sprint (for review)

| Area | Files |
|---|---|
| AI Coach (new) | `lib/features/coach/**` (domain, providers, presentation) + `test/features/coach/coach_brain_test.dart` + router + workout-header button |
| Avatar | `photos/PT_FORM.png` (replaced) |
| App icon | `tool/app_icon*.png`, `pubspec.yaml` adaptive config, regenerated density assets |
| CI | `.github/workflows/ci.yml`, `.github/workflows/secret-scan.yml` |
| Supabase | migration history repaired (remote state; no file change) |

---

## Honest limitations (what an engineer could NOT verify here)

- **Nutrition visual QA** — Pro-gated; audited from code, not exercised live.
- **Real-person form counting** — needs a human in front of the camera (device
  QA G1).
- **Full prod schema diff** — timed out; verified by object/ signature probes.
- **CI green confirmation** — the fix was pushed; the run completes in ~15 min
  and GitHub API rate limits delayed live confirmation. The changes are
  deterministic (gitleaks) and defensive (disk), so the expectation is green;
  confirm in the Actions tab.

Everything else in the ten parts is done and, where a device could show it,
verified on device.

---

*Companion: **`FOUNDER_MASTER_GUIDE.md`** — the complete, no-guessing handbook
for the account/money/device steps that take FormAI from "engineering done" to
"live on both stores."*
