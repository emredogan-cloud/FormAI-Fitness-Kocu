# FormAI — Growth & Advertising Strategy

**Written:** 2026-08-11 · **Phase 4** of `FORM_AI_NEXT_PRODUCT_ROADMAP.md`

**Scope note, because the wording invites confusion:** this document is about
**how FormAI advertises itself**. It is not about showing ads inside FormAI.
No banner, interstitial, rewarded-video or AdMob integration is proposed here,
and none should be added to `lib/` on the strength of this document. FormAI's
revenue model is the Premium subscription.

**On numbers:** every figure is either cited or explicitly labelled an
*estimate* / *assumption*. Nothing here is a performance promise.

---

## 1. The strategic fact that shapes everything else

FormAI ships Turkish and English, with Turkish as the home market. The economics
of those two markets are close to opposite, and this single asymmetry should
drive channel selection, budget, and sequencing.

| | Turkey (tr) | English-speaking Tier 1 (US/UK/CA/AU) |
| --- | --- | --- |
| install cost | **Tier 2 East — "massive install volume at highly affordable CPI"** ([Mapendo](https://mapendo.co/blog/cost-per-install-2025-the-ultimate-report-to-grow-your-app-worldwide)) | **Health & Fitness CPI ~$4.30–$5.50** ([The Social Outline](https://thesocialoutline.com/blog/mobile-app-cpi-benchmarks-2026)) |
| subscription pricing power | low — **Germany sustains ~4.4× Turkey's price** for the same annual health-and-fitness subscription ([Adapty](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)) | high |
| content advantage | **native, founder-authored copy; 392 localised recipes; Turkish food knowledge** | none — we are one of thousands |
| paid viability | cheap installs, thin revenue per install | expensive installs, real revenue per install |

**What follows from this:**

1. **Turkey is where organic wins.** Cheap attention, a real content moat
   (Turkish-language AI fitness coaching is not crowded), and a price ceiling
   that punishes paid acquisition. Turkey should be won with content, ASO and
   community — not with a media budget.
2. **English is where paid *might* work, and only after retention is proven.**
   A ~$5 CPI is survivable only against subscription LTV — the cited median Year
   1 LTV for subscription apps is **$27.21** ([The Social Outline](https://thesocialoutline.com/blog/mobile-app-cpi-benchmarks-2026)) — and that is a
   *median across apps that already retain*. FormAI does not yet have its own
   retention or LTV data. **Spending on Tier 1 installs before measuring D7/D30
   retention and trial-to-paid conversion is buying a number you cannot read.**
3. **January is not a bargain.** Fitness CPI rises for **6–8 weeks each January**
   as demand spikes and inventory tightens ([The Social Outline](https://thesocialoutline.com/blog/mobile-app-cpi-benchmarks-2026)). The
   New Year surge is worth preparing *organic* assets for; it is the worst
   moment to learn paid.

---

## 2. Paid acquisition

Assessed against FormAI's actual position: pre-scale, no attribution stack yet,
one founder, two markets with opposite economics.

### 2.1 Channel analysis

| channel | realistic minimum | targeting | creative needed | suitability now |
| --- | --- | --- | --- | --- |
| **Google App Campaigns (UAC)** | ~$50–100/day for the algorithm to exit learning *(estimate)* | Largely automated — you feed assets, not audiences | 5+ videos, 5+ images, 5 headlines, 5 descriptions | **Best first paid channel.** Play Store integration is native, install attribution needs no SDK, and it reaches Play users at the moment of intent |
| **Meta (Instagram + Facebook)** | ~$30–50/day *(estimate)* | Strong interest and lookalike targeting; needs SDK/SKAdNetwork for install optimisation | UGC-style vertical video | **Second.** Best creative-testing surface; requires attribution work first |
| **TikTok Ads** | ~$50/day, higher creative burn *(estimate)* | Broad, young, fitness-native | Constant new UGC — creative fatigues fastest here | **Later.** Highest creative production cost per unit of spend |
| **YouTube** | Bundled inside App Campaigns | — | Landscape + vertical | Reachable via UAC without a separate buy |
| **Reddit Ads** | Low minimum | Precise subreddit targeting | Static + short copy | **Niche.** Useful for r/turkey or fitness subs; small volume |
| **Apple Search Ads** | — | — | — | **Not applicable** — FormAI is Android/Play only today |
| **Influencer / UGC creators** | Per-deal; Turkish micro-influencers are the cheapest real reach available *(assumption)* | Audience-inherited | Brief + free Premium codes | **Strong for Turkey.** Founder-led outreach, no ad account needed |
| **Affiliate** | Revenue-share | — | Tracking links | **Later** — needs referral infrastructure |
| **Retargeting** | Low | Installed-but-inactive | Reactivation creative | **Later** — needs event instrumentation first |

### 2.2 The honest recommendation on paid

**Do not start paid acquisition yet.** Not because the channels are wrong, but
because the measurement is not in place: without D1/D7/D30 retention and
trial-to-paid conversion by locale, every campaign is unreadable and every
optimisation is guesswork. §7 lists what to instrument; §8 sequences it.

When paid does start: **one channel (Google App Campaigns), one market
(English/Tier 1), one hypothesis, a fixed test budget, and a pre-committed
stop-loss.**

---

## 3. Free and low-cost acquisition

Ordered by expected return for FormAI specifically, not in general.

### 3.1 ASO — the highest-leverage free channel, and already in motion

The repository already contains an ASO programme (`playstore-new-ASO/`,
`ASO_VISUAL_MASTERPLAN.md`, `PLAY_STORE_ASO_PROMPTS.html`). Store listing work
compounds and costs nothing per install.

- **Effort:** medium · **Cost:** zero · **Scalability:** high · **Do it: now.**
- Turkish keyword coverage is a genuine moat — far less competition than English
  fitness terms.
- **One concrete defect to fix, found during Phase 1 of this roadmap:** the live
  512×512 Play Store icon carries a **1 px light-grey column down its right
  edge** (measured mean 38 vs 8.8 for the interior). It is the same class of
  artifact as the bottom-edge "white stripe" fixed in commit `b216fb9`, which was
  only fixed on that one edge. The in-app icon pipeline now shaves it
  (`tool/gen_app_icons.sh`); **the store listing still has it** and needs a
  re-upload. Founder action.

### 3.2 Turkish organic content — the real moat

Short-form vertical video in Turkish: Reels, Shorts, TikTok.

- **Effort:** high (ongoing) · **Cost:** time · **Scalability:** high
- **Why it works here:** competing in English short-form fitness means competing
  with the entire global fitness internet. Competing in Turkish means competing
  with a fraction of it, and FormAI has the content — 392 localised recipes, an
  exercise library, and a form-analysis feature that is inherently visual.
- **The strongest single asset FormAI has:** the real-time form-analysis
  overlay. A skeleton tracking a squat and flagging depth is *self-demonstrating*
  — it needs no explanation and no claim. Most fitness apps cannot show anything
  as visually specific.

### 3.3 Everything else, briefly

| channel | effort | cost | scalability | when |
| --- | --- | --- | --- | --- |
| Turkish fitness subreddits / forums / Discord | medium | zero | low | Now — participate, don't advertise |
| Facebook groups (Turkish fitness) | medium | zero | medium | Now, carefully — most ban promotion |
| SEO / blog (Turkish nutrition + training) | high | domain cost | high, slow | After launch stabilises; compounds over months |
| Free tools (BMR/TDEE/macro calculators, Turkish) | medium | hosting | high | **High value** — an existing `web/` directory and calculators FormAI already computes internally. Ranks for exactly the queries a future user types |
| Comparison pages ("FormAI vs …") | low | — | medium | Later |
| Product Hunt | low | zero | one-shot | Only with an English landing page ready |
| Referral system | **engineering** | — | high | `lib/features/referral/` already exists — audit before building |
| Email | low | low | medium | Needs list capture first |

---

## 4. The funnel

```
CONTENT / AD  →  PLAY LISTING  →  INSTALL  →  ONBOARDING  →  FIRST WORKOUT/MEAL
                                                                     ↓
   REFERRAL  ←  RETENTION  ←  PREMIUM CONVERSION  ←  AI COACH ACTIVATION
```

| stage | main drop-off cause | what fixes it | measured? |
| --- | --- | --- | --- |
| listing → install | icon, first two screenshots, first line of description | ASO (§3.1) | Play Console |
| install → onboarding done | **length and speed** | Onboarding is 19 steps. Phase 2 of this roadmap cut cold start **4830 ms → ~2784 ms (~42%)**; Phase 3 removed a mandatory language step | ✅ `onboarding_step_completed` with `step_index` already instrumented |
| onboarding → first workout | no obvious next action | first-workout tutorial (shipped, Phase 3 of the previous programme) | partial |
| first workout → AI coach | user never discovers the coach | progressive disclosure (shipped) | partial |
| activation → premium | paywall timing | paywall experiments | RevenueCat |
| retention → referral | no incentive | `lib/features/referral/` | unknown |

**The most valuable instrumented asset already in the app:**
`AnalyticsService.onboardingStepCompleted(stepIndex, stepName)` fires on every
step. That is a complete funnel drop-off map for the highest-drop-off stage,
already collecting. **Read it before optimising anything else** — it will name
the step that loses the most users, and that is worth more than any channel
decision in this document.

---

## 5. Creative strategy

### 5.1 What to make, best first

1. **Form-analysis screen recording.** The skeleton overlay on a real rep. Silent,
   captioned, 8–15 s. Self-evident, unfakeable, and unique to FormAI.
2. **AI coach conversation.** A real question, a real Turkish answer, on screen.
3. **Calorie scan** (once Phase 6–12 ship). Photograph → breakdown. The single
   most screenshot-able interaction in the category.
4. **Turkish recipe content.** 392 localised recipes are a content library, not
   just a feature — each is a potential short.
5. **Problem/solution UGC.** "I didn't know if my form was right" → the overlay.
6. **Educational shorts.** Nutrition and technique, app shown incidentally.

### 5.2 Claims FormAI must never make

Non-negotiable — these are Play Policy risks, ASA/advertising-standards risks,
and simply untrue:

- ❌ guaranteed weight loss, or any specific kg/lb figure as a promise
- ❌ guaranteed muscle gain or body transformation
- ❌ any medical claim — treating, diagnosing, curing, or "safe for [condition]"
- ❌ before/after imagery implying a typical or guaranteed result
- ❌ **a stated AI accuracy percentage** unless we have measured it and can show it
- ❌ **a stated calorie-estimation accuracy** — see `CALORIE_TRACKING_RESEARCH.md`
  §1.1: independent testing puts AI calorie error at **15–25%**, and one 2026
  study found errors up to **345 kcal** on a single meal
  ([ScienceDaily](https://www.sciencedaily.com/releases/2026/07/260726015237.htm)). A precision claim here would be false.
- ❌ "your photos never leave your device" — untrue under the recommended
  architecture (research doc §7)

**Say instead:** what the app *does* ("analyses your form in real time",
"estimates calories from a photo, and lets you correct them"), never what the
user's body *will* do.

---

## 6. Budget scenarios

Allocations are **illustrative**, not forecasts.

### A · $0/month — where FormAI is, and should stay for now

ASO · Turkish short-form · community participation · free calculators on the
existing `web/` · founder outreach to Turkish micro-influencers with Premium
codes.
**KPIs:** organic installs/week, listing conversion rate, D7 retention.
**Scale when:** D7 retention is stable and trial-to-paid is known.

### B · ~$300–500/month — the first real test

~70% Google App Campaigns (English/Tier 1) · ~30% Turkish micro-influencer fees.
**Purpose: learn CPI and D7 for our app, not to grow.**
**Stop-loss:** if CPI > 2× the cited $4.30–5.50 band after 2 weeks with the
learning phase complete, stop and fix creative or targeting.

### C · ~$1,500–3,000/month — scale what B proved

Add Meta once attribution is trustworthy; expand only the geos where measured
LTV > 3× measured CAC.
**Stop-loss:** any channel below 1× LTV:CAC after 30 days is paused.

### D · Aggressive

**Not recommended, and not costed here.** Not on budget grounds — on evidence
grounds. Aggressive spend against unmeasured retention converts cash into
installs that churn. Revisit only with ≥3 months of cohort data.

**Spending more is not automatically better.** The staged path exists because
each stage buys information the next one needs.

---

## 7. Tracking

Use what exists. `AnalyticsService` and RevenueCat already cover most of it.

| need | use | status |
| --- | --- | --- |
| install attribution | Google Play install referrer (native to App Campaigns) | free, no SDK |
| campaign tagging | UTM on every link | founder discipline |
| onboarding funnel | `onboardingStepCompleted` | **already instrumented** |
| activation | first workout / first meal events | audit `AnalyticsService` |
| subscription + trial conversion | RevenueCat | **already integrated** |
| retention cohorts | PostHog | **already integrated** |
| CAC / LTV / ROAS | spend ÷ installs; RevenueCat LTV | manual sheet is sufficient at this scale |

**Do not add an analytics vendor.** Sentry, PostHog and RevenueCat are already
in the binary; a fourth SDK adds startup cost — and Phase 2 of this roadmap just
spent real effort recovering ~2 s of it.

---

## 8. What I would do first — 30 / 60 / 90

### Days 1–30 — measure and fix, spend nothing

| # | action | owner |
| --- | --- | --- |
| 1 | **Read the existing onboarding funnel data.** Find the highest-drop step from `onboardingStepCompleted`. This is the single highest-value hour available | founder |
| 2 | Re-upload the Play Store icon without the 1 px right-edge line (§3.1) | founder |
| 3 | Ship the Phase 1–3 build: correct icon, ~42% faster cold start, no forced language step | engineering ✅ done |
| 4 | Establish the retention baseline — D1/D7/D30 by locale from PostHog | founder |
| 5 | Publish 3 short videos/week in Turkish, form-analysis first | creative |
| 6 | Turkish ASO keyword pass | founder |

### Days 31–60 — build the organic engine

| # | action | owner |
| --- | --- | --- |
| 7 | Fix the worst onboarding drop-off found in (1) | engineering |
| 8 | Ship Turkish BMR/TDEE/macro calculators on `web/` | engineering |
| 9 | Approach 5–10 Turkish micro-influencers with Premium codes | founder |
| 10 | Audit `lib/features/referral/` — decide finish or cut | engineering |
| 11 | Continue 3 videos/week; double down on the best format | creative |

### Days 61–90 — the first paid test, only if the data allows

| # | action | owner |
| --- | --- | --- |
| 12 | **Gate:** is D7 retention known and trial-to-paid measured? If no, stay on §6A | founder |
| 13 | If yes: Scenario B — Google App Campaigns, English/Tier 1, fixed budget, pre-committed stop-loss | founder |
| 14 | Produce the UAC asset pack (5 videos, 5 images, 5 headlines, 5 descriptions) | creative |
| 15 | Weekly CPI / D7 / trial-start review; kill or scale on the numbers | founder |
| 16 | Prepare January assets early — CPI rises 6–8 weeks from 1 Jan | creative |

**Split by type:**
**Free:** 1, 2, 4, 5, 6, 9, 16 · **Paid:** 13 · **Founder:** 1, 2, 4, 6, 9, 12, 13, 15 ·
**Engineering:** 3, 7, 8, 10 · **Creative:** 5, 11, 14, 16

---

## Sources

- [Mobile App CPI Benchmarks 2026 — The Social Outline](https://thesocialoutline.com/blog/mobile-app-cpi-benchmarks-2026)
- [In-app subscription benchmarks for Health & Fitness apps — Adapty](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)
- [Cost per Install 2025 — Mapendo](https://mapendo.co/blog/cost-per-install-2025-the-ultimate-report-to-grow-your-app-worldwide)
- [Cost Per Install Rates — Business of Apps](https://www.businessofapps.com/ads/cpi/research/cost-per-install/)
- [Your AI calorie-tracking app may be off by 345 calories — ScienceDaily](https://www.sciencedaily.com/releases/2026/07/260726015237.htm)
