# FormAI — Final Founder Actions

Only what is **physically impossible for engineering** to do. Everything else —
including deploying the live Claude coach (done: your `ANTHROPIC_API_KEY` in
`.env.local` made it engineerable) — is complete. The store/launch handbook
remains `FOUNDER_MASTER_GUIDE.md`; this list is only what's newly yours.

---

## 1. Anthropic account guardrails (10 min) — do this week
The coach now spends real money on your Anthropic key.
- console.anthropic.com → **Billing → Spend limits**: set a monthly cap you're
  comfortable with (typical turn is a few hundred tokens on Haiku; even heavy
  use is dollars, not hundreds — but a cap makes runaway impossible).
- Optionally create a **separate key** named `formai-coach-prod`, set it with
  `supabase secrets set ANTHROPIC_API_KEY=…`, and revoke the shared one, so the
  coach has its own revocable credential and usage line.

## 2. Taste the coach yourself (15 min) — before wider testing
Engineering ran the scenario eval (no fabrication, injury safety, honest
timelines, identity, off-topic refusal — all pass). What only you can judge is
**taste**: does Form's tone feel like *your* brand? Talk to it in the app
(motivation, "bugün ne yapmalıyım", food, an injury question). If you want the
voice sharper/softer: the persona is `PERSONA` in
`supabase/functions/coach-chat/index.ts` → edit → `supabase functions deploy
coach-chat`. No app release needed. (Quality lever without code: `supabase
secrets set COACH_MODEL=claude-sonnet-5` — better Turkish, higher cost.)

## 3. Nutrition free/Pro boundary — decide with data (post-launch)
The freemium nutrition flow is live (free: target + recipe library; Pro:
personalised daily plan + tracking). Once real users flow through, read the
funnel (paywall_viewed sources vs conversions) and decide whether the free
taste is too generous or too stingy. The boundary is a small, ready code change
either way.

## 4. Pre-launch device-matrix QA sweep (one session)
Key screens are verified on-device in dark + light. Before public production,
do one full pass on a tablet + an Android 15/16 device (edge-to-edge), every
screen, both themes. (Unchanged from the appendix; still yours because it needs
hardware you have.)

## 5. Everything in `FOUNDER_MASTER_GUIDE.md`
The store path (Play Console, testers, RevenueCat products, iOS via Codemagic,
legal mailbox, secret rotations) is unchanged and remains account/money work
only you can do.

---

*Removed from the founder list because engineering completed them: Edge Function
deploy + secret configuration, live LLM validation pass, long-term memory,
premium chat UX, coach↔workout context.*
