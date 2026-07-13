# FormAI — Final AI Coach Report

**Date:** 2026-07-13 · **Branch:** `main` · **State:** the coach runs on **real Claude, deployed to production, verified live in the app on a physical device.** `flutter analyze` 0 · **329 tests** green.

---

## 1. Deployment — DONE (no founder action left)

The founder had placed `ANTHROPIC_API_KEY` in `.env.local`, which made deployment
engineerable this session:

- **Secret set:** `supabase secrets set ANTHROPIC_API_KEY=…` on project
  `xtvqhnjamwvmfcsahzxv` (first attempt carried two stray quote chars from the
  env file → Anthropic 401; re-set with strict cleaning → key verified directly
  against `api.anthropic.com` = **200**).
- **Function deployed:** `supabase functions deploy coach-chat --use-api`
  (the CLI chokes parsing the free-text `.env.local`, worked around by moving it
  aside during deploy; also must run from the repo root, not `supabase/`).
- **Endpoint verified** with authenticated calls: auth ✓, chat mode ✓,
  summarize mode ✓, error paths (bad JWT, empty message) ✓.
- **Fallback verified:** any function/model failure returns a typed error and
  the app silently answers with the rule-based coach (unit-tested: throw, null,
  empty, timeout).
- **Client flag flipped:** `COACH_LLM_ENABLED=true` (in `.env` and
  `.env.example` — safe-by-design because failure = rule-brain fallback; the
  flag is not a secret, the model key never ships).

## 2. Architecture (final)

```
CoachScreen ──▶ coachChatProvider (async send, sending flag, timestamps)
                  │
                  ▼
            CoachBrain (interface)
             ├─ RuleBasedCoachBrain  ← offline / fallback, honest
             └─ LlmCoachBrain        ← history compression (last 8 turns),
                  │                     15s timeout, falls back on ANY error
                  ▼
      Supabase Edge Function `coach-chat`   (ANTHROPIC_API_KEY server-side)
             ├─ chat mode:      persona (cacheable) + context + memory + turns
             └─ summarize mode: turns + prior digest → ≤8 durable bullets
                  │
                  ▼
            Claude Haiku (COACH_MODEL/COACH_MAX_TOKENS env-overridable)
```

**Context the coach knows every turn:** name, goal, age/height/weight/BMI,
activity, equipment, streak, level/XP/badges, program progress, **today's real
exercise names**, and a **last-logged-session digest** (real reps + duration
from the camera pipeline's session log) — plus the rolling memory below.

## 3. System-prompt evolution (live-eval driven)

| Version | Change | Why (observed live) |
|---|---|---|
| v1 | Base persona: Form identity, Turkish, warm, medical guardrail | First deploy. Reply **fabricated a coaching history** ("seninle çalışmaya başladığımız beri en çok düşüş 3. gün oluyordu") |
| v2 | **GERÇEKLİK block**: only given context; inventing history/statistics banned; rich-format instructions (emoji sections, bullets, bold) | Fabrication gone across the 7-scenario sweep; structure appeared exactly as specified |
| v3 | Never-truncate + max 2-3 sections; **set/rep honesty** (use plan names verbatim, never invent numbers); clean-Turkish/charset rule; `MAX_TOKENS` 400→700 | v2 replies cut mid-sentence at 400 tokens; one CJK glyph leak ("D膝lerin"); it had invented "3x12" prescriptions not in the plan |

The persona lives in `supabase/functions/coach-chat/index.ts` (`PERSONA`) —
editable + `supabase functions deploy coach-chat` with **no app release**.

## 4. AI quality — live evaluation results (deployed function)

7-scenario sweep + retests, real HTTP calls:

- **Motivation:** empathetic, references the real streak/progress, one doable step. No fabricated anecdotes (v2+).
- **Injury** ("dizimde ağrı var, squat yapayım mı?"): **"Yapma"**, knee-safe alternatives, defers to a professional. No diagnosis.
- **Structured workout:** complete, sectioned, uses the plan's exercise names verbatim, honest "planında yazılı set/tekrar sayılarını yap".
- **Nutrition:** protein/carb/fat guidance tied to the goal, reasonable ranges, no prescriptions.
- **Identity:** "Ben **Form**'um… ChatGPT değilim" — never breaks character.
- **Off-topic (crypto):** polite refusal + redirect to training.
- **Plateau/overclaim:** honest timeline ("kas yapmak … en az 8-12 hafta"), zero "X haftada Y kilo" claims.
- **Memory mode:** returns crisp durable bullets (sleep-time preference, knee injury constraint, vegetarian diet) — exactly what should persist.

**In-app device verification (release build, Xiaomi):** asked "Bugün ne
yapmalıyım?" → the coach answered with a rich card listing the user's **actual
six plan exercises**, a 💡 tip section, and a next-step question — rendered with
bold emoji headers, neon bullets, and timestamps.

**Latency:** 2.8–6.5 s per turn (Haiku, 700-token cap). **Known tradeoff:**
Haiku's Turkish has occasional awkward phrasings; v3 instructions reduced them.
If quality ever outweighs cost: `supabase secrets set COACH_MODEL=claude-sonnet-5`
— no redeploy, no app change.

## 5. Long-term memory (shipped)

- **Rolling summary**, not transcripts: every 3 user turns the client
  fire-and-forgets the conversation + prior digest to `summarize` mode; the
  returned ≤8-bullet digest (goals, habits, constraints, injuries, diet,
  motivation) is stored in `SharedPreferences` (`sixpack.coach_memory_v1`).
- Every chat turn sends that digest as compact "ÖNCEKİ KONUŞMALARDAN NOTLAR" —
  so the coach **remembers across sessions** while old transcripts are never
  resent (token-minimal by construction).
- Failures are invisible (best-effort); memory can only improve a conversation,
  never break one.

## 6. Chat UX (premium pass)

- **Rich replies:** deterministic renderer for the persona's constrained format —
  emoji-headed **section headers**, neon-dot bullets, `**bold**` inline — no
  markdown dependency, and rule-brain plain text renders identically.
- **Typewriter reveal** on the newest reply (ChatGPT-style entrance; purely
  visual, text is final before it starts), capped ~1.4 s.
- **"Form yazıyor…"** pulsing-dots thinking indicator.
- **HH:mm timestamps** under bubbles.
- Natural-language suggestion chips; asymmetric bubble corners; left/right
  alignment; the always-dark chat aesthetic kept (deliberate, like the major
  chat products).
- Dashboard entry: the WHOOP-style **coach card** (prior sprint) + header avatar.

## 7. Camera/workout ↔ coach

The coach's context now includes the **session log** — the camera pipeline's
ground truth (per-exercise real rep counts + active duration). After any logged
workout the coach can say "dün 84 tekrar yaptın, 12 dakika sürdü" instead of
generic advice. Live per-set streaming into an *ongoing* set (mid-workout rep
warnings) stays out of scope: that state is intentionally local to the camera
screen, and the honest integration point (the completed-session log) is now
wired. Documented as a future opportunity.

## 8. Cost

Per chat turn: persona is **prompt-cached** (identical every call), context ≈
200–400 tokens, ≤8 recent turns, output ≤700 tokens on **Haiku** → a few
hundred effective tokens per turn; memory refresh adds one ≤250-token call per
3 user turns. Set a monthly spend limit in the Anthropic console as a backstop
(listed in `FINAL_FOUNDER_ACTIONS.md`).

## 9. Validation

- `flutter analyze` **0** · `dart format` clean · **329 tests** (coach suite: 15 —
  fallback matrix, history compression, greeting locality, context seams incl.
  today-exercises + last-session).
- Live endpoint eval (7 scenarios + retests) against the deployed function.
- In-app end-to-end on a physical device (release build): rich LLM reply with
  real plan data, timestamps, typing indicator, typewriter reveal.
- Gradle note: two release-build failures this sprint were both **concurrent
  `flutter test` vs Gradle daemon contention** — building alone succeeds; never
  run them simultaneously.

## 10. Remaining opportunities (documented, not blocking)

1. **True token streaming** (SSE from the Edge Function + incremental render) —
   the typewriter reveal covers the perceived-speed gap today.
2. **Mid-workout coach** — stream live analyzer events (current exercise, rep,
   form warnings) into a session-scoped coach overlay.
3. **Structured reply cards** — parse 🏋/🥗 sections into tappable workout/recipe
   cards that deep-link into the app.
4. **Server-side memory** — move the rolling summary to a Supabase table for
   cross-device continuity (client store is per-install today).
5. **Model upgrade lever** — `COACH_MODEL=claude-sonnet-5` if Turkish polish
   ever matters more than cost.
6. Nutrition (re-reviewed): freemium flow from the prior sprint is live and
   correct; next lever is funnel data on the free/Pro boundary (see
   `FINAL_FOUNDER_ACTIONS.md`), not more engineering.
