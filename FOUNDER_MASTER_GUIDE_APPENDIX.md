# Founder Master Guide — Appendix (Post-Beta Evolution)

Founder-only tasks discovered during the post-beta product-evolution sprint.
These need your accounts, keys, money, or a decision an engineer can't make.
Everything *engineerable* around them is already done — this list is only the
human-gated remainder. See `FOUNDER_MASTER_GUIDE.md` for the base handbook.

---

## 🔴 A1 — Provide `ANTHROPIC_API_KEY` and deploy the AI Coach backend

**Why:** The AI Coach was upgraded from rule-based to a real LLM. For security,
the model key must **never** ship in the app (the `.env` guard enforces this and
the `.env` is a bundled asset). The key lives server-side in a Supabase **Edge
Function** (`coach-chat`) that the app calls. The entire function + client are
built and committed; it just needs your key + a deploy.

**Steps (~10 min):**
1. Get an Anthropic API key: https://console.anthropic.com → API Keys.
2. Set it as an Edge Function secret (never in the repo):
   ```
   cd supabase
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   supabase functions deploy coach-chat
   ```
   (The CLI is already linked to project `xtvqhnjamwvmfcsahzxv`; the DB password
   is in `.env.local`.)
3. In the app, open the Coach and send a message — it now routes through Claude.
   If the function is unreachable or the key is unset, the app **automatically
   falls back** to the honest rule-based coach (no crash, no blank screen).

**Cost control (already built in):** the function uses **Claude Haiku** (the
cheapest tier), compresses history into a rolling summary, and caps output
tokens — so a typical coaching turn is a few hundred tokens. Set a monthly spend
limit in the Anthropic console for safety.

**Blocks:** the live LLM coach only. Everything else (UI, fallback, context) works
without it.

---

## 🟠 A2 — Live LLM validation pass (needs A1)

Once A1 is deployed, run the conversation-quality pass that can't be done without
the key: have real conversations covering motivation, nutrition, injury, plateaus,
missed workouts, travel, equipment, sleep, hydration. Confirm tone, no
hallucinations, no medical over-reach, latency, and per-message cost. The system
prompt is production-tuned and documented in `supabase/functions/coach-chat/`; if
you want tweaks, edit the prompt there and re-deploy — no app change needed. A
ready-to-run local harness lives at `tool/coach_eval.md` (scenarios + rubric).

---

## 🟡 A3 — (Decision) Tune the nutrition free/Pro boundary

Nutrition is no longer a hard paywall. Free users now get: the intro scene, the
4-step onboarding, their real daily calorie/macro target, a taste of the AI
prescription, and the full recipe library to browse + open. The premium wall
sits on the **personalised daily meal plan** and **meal tracking / add-to-plan**
(the `_NutritionProUpsell` card + gated "Hemen Ekle"/"Plana Ekle").

That split is a business lever, not a fixed law. If conversion data later says
you're giving too much (or too little), the boundary is a small code change in
`nutrition_tab.dart` / `recipe_detail_screen.dart` (e.g. cap free recipe opens,
or unlock the plan for a trial). Decide with real funnel numbers once live — no
engineering blocker, just your call on the tradeoff.

## 🟡 A4 — (QA) Exhaustive light-mode + tablet/orientation sweep

Key screens were verified on-device in **both** dark and light this sprint
(dashboard, coach, nutrition freemium, profile) and the new widgets are
theme-aware. A *full* pre-launch pass across every remaining screen, plus a
tablet form factor and landmark orientations, is standard QA that wants a device
matrix — worth one focused session before public production. The always-dark
Coach + onboarding screens are a deliberate premium choice (like many chat UIs),
not a light-mode bug.

---

*(More items are appended below as the sprint progresses.)*
