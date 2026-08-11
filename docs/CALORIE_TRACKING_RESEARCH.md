# AI Calorie Tracking — Market and Technology Research

**Written:** 2026-08-11 · **Phase 5** of `FORM_AI_NEXT_PRODUCT_ROADMAP.md`
**Status:** research complete, architecture recommended, **not yet implemented**.

This document exists to be argued with before code is written. Every number that
is an estimate is labelled as one; every number with a source has a link.

---

## 1. What the category actually does

The founder brief names Cal AI as the reference product. The category converged
on one flow: photograph the plate → a vision model names the foods and guesses
portions → the app shows an editable calorie and macro breakdown → the user
confirms. The differentiator between products is **not** the model. It is what
happens in the seconds around it: how fast the estimate appears, how easy the
correction is, and how honest the product is about being an estimate.

### 1.1 Accuracy — the number that decides the product's honesty

This is the single most important research finding, and it should shape the UI
before it shapes the backend.

- Independent testing puts Cal AI at **90–95% recognition accuracy on common,
  single-item foods** ([Vora](https://askvora.com/blog/cal-ai-acquisition-photo-food-logging)).
- Studies of AI food-recognition apps report **mean absolute error of roughly
  15–25% on the calorie estimate itself** — a meal shown as 600 kcal is
  plausibly 450–750 ([openhealth](https://openhealth.blog/en/blog/ai-photo-calorie-tracking)).
- A 2026 study found consumer AI calorie trackers off by as much as **345
  calories** on a single meal ([ScienceDaily](https://www.sciencedaily.com/releases/2026/07/260726015237.htm)).
- Every source agrees on the failure mode: **mixed and composite dishes**. A
  stir-fry, a burrito, a curry with rice, anything with hidden oil or sauce.
  This matters disproportionately for FormAI, because Turkish home cooking is
  substantially composite — a plate of *karnıyarık*, *mercimek çorbası* or
  *pilav üstü tavuk* is exactly the shape these models estimate worst.

**Product consequence.** Recognition is good enough to be genuinely useful and
nowhere near good enough to present as fact. The brief already says this (§8:
"Never present uncertain AI results as absolute truth"). The research says it
harder: a single-number answer with no visible uncertainty would be a false
claim about our own accuracy, not merely a UX weakness. Section 6 turns this
into a concrete confidence model.

### 1.2 What the competitors get right that is cheap to copy

- **Speed beats precision.** The workflow wins because snap-confirm-log is
  faster than searching a database, not because the number is better than a
  food scale. Optimise the round trip, not the third significant figure.
- **The correction is the product.** Every review praises editing. A correction
  flow that is one tap from the result screen is worth more than a better model.
- **Barcodes for packaged food.** Vision on a nutrition label is strictly worse
  than reading the barcode. Packaged food should never go through the vision path.

---

## 2. What FormAI already has (and must not duplicate)

Three findings from the repository change the build-versus-buy maths.

| asset | where | why it matters |
| --- | --- | --- |
| **A working server-side Anthropic integration** | `supabase/functions/coach-chat/index.ts` | `ANTHROPIC_API_KEY` is read from the function environment and never reaches the device; `lib/` contains zero AI-provider references. The scanner is the same shape and should be a sibling function, not a new stack. |
| **Macro maths and targets** | `nutrition_calculator_service.dart`, `macro_target.dart` | Daily targets and macro arithmetic already exist. The calorie tracker consumes them; it must not fork a second nutrition model. |
| **A shipped RLS + migration discipline** | `supabase/migrations/001–027` | Table-per-feature with RLS is the established pattern, including the recursion trap documented in migration 023. |

The practical effect: **the risky, expensive part of this feature is already
built and in production.** What remains is a table, a function, and UI.

---

## 3. Architecture options

### A. On-device vision + local nutrition database

Ship a quantised food-classification model (MobileNet/EfficientNet class) plus a
bundled nutrition table.

| | |
| --- | --- |
| accuracy | Poor on composite dishes; a fixed label set cannot cover Turkish home cooking. |
| latency | Excellent — no network. |
| cost | Zero marginal cost. |
| privacy | **Best possible** — the photo genuinely never leaves the device, and we could say so truthfully. |
| scalability | Perfect. |
| maintainability | Poor. Re-training and re-shipping a model to change one food. |
| **verdict** | **Rejected as the primary path.** The app already ships 32.6 MB of photos and a 147 MB APK; adding a model plus a food database makes that worse for a capability that fails on the dishes our market eats most. |

### B. Cloud computer vision API + nutrition database

A dedicated food-recognition API (Clarifai/LogMeal class) returning food labels,
which we then look up.

| | |
| --- | --- |
| accuracy | Good labels, weak portions — portion estimation is the hard half and these APIs mostly don't do it. |
| latency | One extra network hop beyond option C. |
| cost | Per-call pricing on top of a vendor we do not already have. |
| Turkish support | **The weak point.** Label taxonomies are Western-centric. |
| **verdict** | **Rejected.** A second AI vendor, a second billing relationship, and a second set of keys, to do less than the vendor we already have. |

### C. Multimodal AI + structured nutrition database ⭐

One vision-capable LLM call returns foods, estimated portions, and per-item
macros as **structured JSON**; a nutrition database supplies canonical values
for the items it recognises.

| | |
| --- | --- |
| accuracy | Best available for composite dishes — the model reasons about the whole plate rather than classifying it. |
| latency | Single round trip. Estimated 3–8 s on Haiku-tier (see §5). |
| cost | Metered per scan — the real constraint. §5 sizes it. |
| privacy | The image leaves the device. This must be disclosed plainly (§7). |
| Turkish support | **Strong, and the deciding factor.** A multimodal model recognises and names Turkish dishes without a per-locale label taxonomy — the exact place options A and B fall down. |
| maintainability | Excellent — behaviour changes are prompt changes in one edge function. |
| **verdict** | **Recommended.** |

### D. Hybrid

Option C, plus on-device pre-processing and a non-AI fast path.

**This is what is actually recommended**, and it is C with two cheap additions:

1. **On-device barcode scanning** for packaged food (`mobile_scanner` or ML Kit).
   Packaged food is a solved problem with an exact answer; spending a vision
   call on it is waste. Bonus: it works offline.
2. **On-device image preparation** — downscale, re-encode, strip EXIF *before*
   upload. This is a cost control, a latency control and a privacy control in
   one step (§7).

---

## 4. Recommendation

**Architecture D (hybrid): on-device capture and preparation → Supabase edge
function → Claude vision with structured output → editable result → log.**

### 4.1 Why this model, and which one

The existing `coach-chat` function defaults to `claude-haiku-4-5`. Vision food
recognition should start on the **same model**, for reasons beyond consistency:

- It is vision-capable and the cheapest current tier ($1 / $5 per MTok).
- **Structured outputs** (`output_config.format` with a JSON schema) make the
  response a validated object rather than prose we parse — which is what makes
  a confidence field trustworthy rather than something the model might omit.
- The operational pattern — key server-side, locale-aware prompt, error mapping
  — is already written and shipped next door.

Escalating to `claude-sonnet-5` is a one-line change if evaluation shows Haiku
missing Turkish dishes. §5 prices both so that decision can be made on numbers.

### 4.2 Nutrition database — a founder decision

Options, with the Turkish problem stated plainly:

| source | licence | Turkish coverage | note |
| --- | --- | --- | --- |
| [USDA FoodData Central](https://fdc.nal.usda.gov/) | **CC0 / public domain** — no permission needed | Poor for Turkish dishes; good for ingredients | ~380k foods; free API key, 1,000 req/hour/IP; also downloadable in bulk |
| [Open Food Facts](https://world.openfoodfacts.org/) | Open (ODbL) | Good for **packaged** products incl. Turkish retail | Community-contributed; quality varies. Natural pair with barcode scanning |
| TürKomp (Ulusal Gıda Kompozisyon Veritabanı) | **Needs checking** | Authoritative for Turkish foods | Turkey's national food-composition database, lab-analysed. **Licence and API access must be confirmed before it is designed in** — this is a founder action |

**Recommended MVP position:** the model returns per-item macros directly; the
database is used to *correct and canonicalise* recognised items rather than as
the primary source. Bulk-download USDA (CC0, no runtime dependency, no rate
limit) into a Supabase table, pair Open Food Facts with barcode scanning, and
treat TürKomp as a Phase 2 enrichment once its licence is confirmed.

This ordering matters: it means **the feature does not block on a licence
negotiation**, and a database outage cannot break the scanner.

---

## 5. Cost model and controls

All figures below are **estimates** computed from published per-token pricing,
not measured. They must be re-derived against a real prompt before any budget
is committed.

### 5.1 Per-scan cost

Assumptions: one photo at ~1024², a ~800-token system prompt, ~400 tokens of
structured output.

| model | image tokens | in | out | **est. per scan** |
| --- | --- | --- | --- | --- |
| `claude-haiku-4-5` | ~1,400 (older vision tier, ≤1568 px) | 2,200 tok @ $1/MTok | 400 tok @ $5/MTok | **~$0.004** |
| `claude-sonnet-5` | ~4,784 (high-res tier, ≤2576 px) | 5,584 tok @ $3/MTok | 400 tok @ $15/MTok | **~$0.023** |

Roughly a **6× difference**. Haiku is the right default; the gap is the budget
for an accuracy escalation, not a rounding error.

### 5.2 Why this needs a hard limit, not just a soft one

At an estimated $0.004/scan, **1,000 daily active users logging 4 meals a day is
~$16/day — about $480/month**, from a feature with no per-use revenue. On
Sonnet the same load is ~$2,800/month. This is the largest uncontrolled cost
the app would have ever taken on, and it scales with *success*.

Controls, all of which belong in the edge function rather than the client
(a client-side limit is a suggestion):

| control | value | why |
| --- | --- | --- |
| image long edge | **1024 px**, re-encoded JPEG q80 | Above this we pay for tokens the model's vision tier discards |
| request body cap | **~1.5 MB**, rejected server-side | Bounds a hostile or buggy client |
| per-user daily scans | **free 3 / Premium 20** | The actual spend ceiling. Enforced in Postgres, counted server-side |
| timeout | **20 s**, then a typed error | §6 — an AI timeout must never produce an infinite spinner |
| retries | **1**, only on 5xx/timeout | A retry on a refusal or a 400 just doubles the bill |
| caching | none initially | Haiku 4.5's minimum cacheable prefix is 4,096 tokens; our system prompt is far below it, so a `cache_control` marker would pay a write premium for zero reads |

The daily cap is also the **abuse boundary**: without it, one extracted anon key
plus a loop is an unbounded bill.

---

## 6. Confidence handling — the honesty requirement

The brief (§8) forbids fabricated precision. Given §1.1's 15–25% error, this is
not decoration. The structured-output schema should require the model to return
confidence **per item**, and the UI should render three distinct states:

| confidence | UI | behaviour |
| --- | --- | --- |
| high | value shown normally | one-tap confirm |
| medium | value shown with a visible "estimate" qualifier | confirm, edit encouraged |
| low / ambiguous | **a question, not a number** — "Is this rice or bulgur?" | the user disambiguates before anything is logged |

Two rules that follow, and that should be enforced in tests:

1. **A number is never displayed to more precision than it is known to.**
   Calories round to 10 kcal, macros to 1 g. Rendering "347 kcal" claims an
   accuracy no source in §1.1 supports.
2. **Every failure path terminates.** Timeout, network loss, refusal, malformed
   response, permission denial — each maps to a named state with a retry or a
   manual-entry escape. The brief lists "AI timeout creates an infinite spinner"
   and "user can become stuck" as gate failures; this is where that is won.

---

## 7. Privacy model

Food photographs are taken in kitchens, restaurants and homes, and catch faces,
documents and locations at the edges of frame. Treated properly:

- **EXIF is stripped on-device, before upload.** GPS in a food photo is a
  location history nobody asked for. Re-encoding the downscaled JPEG (§5.2) drops
  EXIF as a side effect — the same step that saves money buys the privacy.
- **Images are not retained by default.** The MVP position is: the image is sent,
  analysed, and *not stored* — only the resulting structured nutrition row is
  persisted. This removes an entire class of storage-RLS risk and is the
  strongest privacy claim we can honestly make.
- **The claim we must not make.** The image leaves the device and is processed by
  a third-party model provider. The brief is explicit (§13) that
  *"images never leave the device"* may not be said unless it is true. It is not
  true under this architecture, so the privacy policy must say what actually
  happens, in both languages, before the feature ships.
- **If image retention is added later** (for a correction history or a re-analysis
  feature), it needs its own migration, a Supabase Storage bucket with owner-only
  RLS, a stated retention window, and a user-facing delete. That is a separate
  decision, not an MVP default.

---

## 8. MVP scope, and what is deliberately out

**In:** camera + gallery capture · on-device downscale/EXIF-strip · one
`food-scan` edge function · structured multi-item result with per-item
confidence · full edit before confirm · meal logging against existing macro
targets · daily totals · history · tr/en throughout · server-side rate limit.

**Out of MVP, on purpose:**

- image retention and re-analysis (§7)
- TürKomp integration (licence unconfirmed — founder action)
- multi-photo / video scanning
- restaurant-menu lookup
- weight-based portion input from a connected scale

---

## 9. Rejected alternatives, recorded

| rejected | why |
| --- | --- |
| On-device model (A) | Fails on composite Turkish dishes; grows an already-large APK |
| Dedicated food-vision API (B) | Second vendor, weaker Turkish taxonomy, no portion estimation |
| Client-side AI calls | Would put an API key in a binary that is trivially extractable — the exact thing `coach-chat` was built to avoid |
| Nutrition DB as the primary source | A lookup table cannot answer "how much of it is on this plate", which is the actual question |
| Prompt caching at MVP | Below Haiku 4.5's 4,096-token cacheable minimum — pays a write premium, reads nothing |

---

## 10. Founder actions before Phase 6 can start

1. **Confirm `ANTHROPIC_API_KEY` is set in the Supabase function environment.**
   `coach-chat` already uses it; `food-scan` needs the same secret.
2. **Approve the nutrition-database position** in §4.2 (USDA bulk + Open Food
   Facts now, TürKomp later) — or direct otherwise.
3. **Confirm the per-user daily scan caps** in §5.2. These are the cost ceiling,
   and they are a pricing decision as much as an engineering one.
4. **Approve the privacy position** in §7 — specifically that images are *not*
   retained at MVP, and that the privacy policy will be updated to disclose
   third-party processing before launch.
