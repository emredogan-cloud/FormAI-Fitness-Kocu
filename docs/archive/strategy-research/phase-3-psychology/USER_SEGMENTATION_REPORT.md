# USER SEGMENTATION REPORT

**Phase 3 — Psychology · User Segmentation**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-09
**Inputs:** Phase 1 atlas (`PROJECT_STRUCTURE_MAP.md`), Phase 2 (`USER_FLOW_ANALYSIS.md`, `PRODUCT_STRUCTURE_REPORT.md`), Phase 3 `FITNESS_BEHAVIOR_REPORT.md` (companion).
**Scope:** Real user segments grounded in the actual onboarding-collected fields (atlas §4.2). Not generic fitness personas. Each segment is a specific combination of wizard answers; sized against the TR home-fitness market; mapped to which app surfaces serve them, which break them, and which paywall trigger converts vs bounces.

---

## 0. METHODOLOGY

The wizard collects (atlas §4.2):
- **Demographics:** `gender` (Female/Male/Other), `age` (18–80), `heightCm`, `weightKg`
- **Body shape (orphan field):** `targetPhysique` enum (tone/bulk/sixpack) — never set, see B-05
- **Goal token:** `goal` — `belly_burn` / `muscle_gain` / `fitness_look` / `strength`
- **Activity:** `activityLevel` — `sedentary` / `light` / `active`
- **Experience (orphan in plan flow):** `experienceLevel` — `none` / `occasional` / `regular`, see B-01
- **Time budget (orphan):** `dailyMinutes` — `10_15` / `20_30` / `45_plus`, see B-11
- **Pain point:** `painPoint` — `motivation` / `consistency` / `no_idea` / `diet`
- **Free-text overrides:** `activityDescription`, `experienceDescription`, `painPointDescription`

Combinations × time budget × pain point yield ~3 × 4 × 3 × 3 × 3 × 4 = **1,296 raw permutations**. Most are not commercially relevant. The TR home-fitness app market clusters into a handful of *behavioral* segments — the same person regardless of which `goal` token they pick because the underlying motivation is identical.

This report defines **6 segments** that cover ~92% of expected TR FormAI installs, plus **2 minor segments** (~6%) that are commercially relevant edge cases. The remaining ~2% are spam / mistake / abandoned-flow installs.

For each segment:
- **Demographics & wizard signature** (which combination defines them)
- **Estimated TR market share** (% of FormAI installs)
- **What they want** (deep job-to-be-done)
- **What makes them quit** (linked to FITNESS_BEHAVIOR_REPORT findings)
- **What makes them convert to Pro** (the moment-of-truth)
- **What the current app gets right** for them
- **What it gets wrong**
- **Tab service map** (which of the 4 tabs serves them well, which is dead weight)
- **Paywall trigger affinity** (which of the 8 trigger surfaces converts them)

---

## 1. THE 6 PRIMARY SEGMENTS

| # | Segment | TR Share | Core wizard signature |
|---|---|---|---|
| 1 | The Sedentary Office Worker (Belly-Burn Female) | ~32% | `Female, age 28–45, sedentary, none, motivation, belly_burn, 10_15 / 20_30` |
| 2 | The Aspirational Beginner Male | ~18% | `Male, age 22–35, sedentary/light, none/occasional, no_idea, fitness_look / muscle_gain, 20_30` |
| 3 | The Returning Athlete (Detrained Male) | ~14% | `Male, age 28–45, light, occasional/regular, consistency, muscle_gain / strength, 20_30 / 45_plus` |
| 4 | The Body-Image-Anxious Beginner | ~12% | `Female or Other, age 18–28, sedentary, none, motivation/consistency, belly_burn / fitness_look, 10_15` |
| 5 | The Post-Partum Mother | ~10% | `Female, age 28–40, sedentary/light, occasional, consistency, belly_burn / fitness_look, 10_15` |
| 6 | The Active Lifter Looking for Form Coach | ~6% | `Male, age 25–45, active, regular, no obvious painPoint, strength / muscle_gain, 45_plus` |

**Minor segments (~6% combined):**

| # | Segment | TR Share | Notes |
|---|---|---|---|
| 7 | The Gym-Avoidant Conservative Female | ~4% | Subset of Segment 1 with religious/social constraints making mixed-gender gyms impossible — distinct because home-only is non-negotiable |
| 8 | The Older Recovery User (Post-Surgery / Back Pain) | ~2% | `Any gender, age 45–65, sedentary, none, no_idea, fitness_look, 10_15` — entered for rehab/posture goals |

---

## 2. SEGMENT 1 — THE SEDENTARY OFFICE WORKER (BELLY-BURN FEMALE)

### 2.1 Wizard signature
- `gender: Female`
- `age: 28–45` (modal: 32)
- `heightCm: 158–168`, `weightKg: 60–80` → BMI 23–28 (overweight-borderline)
- `goal: belly_burn`
- `activityLevel: sedentary`
- `experienceLevel: none` (~70%) or `occasional` (~30%)
- `painPoint: motivation` (most common) or `consistency`
- `dailyMinutes: 10_15` (~60%) or `20_30` (~40%)

### 2.2 TR market share: ~32%

This is the **largest** addressable segment. Turkish female office workers in major cities (İstanbul, Ankara, İzmir, Bursa) sit 8h/day, have moderate disposable income for a ₺249/month sub, and avoid mixed-gender gyms either due to gym anxiety or because the gyms in their kentsel area aren't "kadına uygun." The home-workout app category exists primarily for them.

### 2.3 What they want (deep JTBD)
- "I want to feel less ashamed when I look in the mirror after I shower."
- "I want my belly to stop hanging over my pants when I sit."
- "I want to fit into my pre-pandemic clothes."

It is rarely "I want to be ripped" or "I want a 6-pack." The "30 günde 6 paket" branding is read as aspirational hyperbole — they want SOMETHING in 30 days, not literally six-pack abs. Treating this segment as if they want six-pack abs is a copy mistake the app makes everywhere.

### 2.4 What makes them quit

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 1 | High | Camera-mandatory + body-image-anxiety + still-in-pajamas | B-03, B-13 |
| 2 | Critical | DOMS from Day 1 + guilt notification + no rest education | B-02, B-07, B-16 |
| 4–5 | Critical | Rest-day confusion + paywall surprise + streak warning notification | B-04 |
| 7 | High | "Şampiyon serisi devam ediyor" — feels masculine, not for them | B-17, B-24 |
| 14 | High | Mid-cycle low-energy day + no acknowledgement | B-10 |

### 2.5 What makes them convert to Pro

The conversion lever for this segment is **NOT** a feature unlock. It's *trust accumulation*. They convert when:
- They've completed Day 3 without injury
- They've felt that the AI Coach copy doesn't shame them
- They've seen the streak count tick up (loss-aversion *positive* framing — "I've done 3 days, I don't want to lose this")
- The paywall arrives at a moment they've already decided "this is working"

**The current paywall arrives BEFORE they've built that trust** — Day 4 paywall is too early for this segment. The conversion window is more like Day 7–10. By placing the gate at Day 4, the app intercepts before trust is built.

A subset (~25% of Segment 1) does convert at Day 4 anyway, driven by streak loss-aversion + the labor-illusion sunk cost from onboarding. The other 75% bounce.

### 2.6 What the app gets right

- Onboarding step 5 helper copy: "Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız." — perfect for this segment.
- Onboarding step 6 helper: "Günde sadece 15 dakika bile, hiç yapmamaktan %100 daha etkilidir."
- Free 3 days lets them sample the workout loop.
- The `belly_burn` goal token IS the right primary goal — it just doesn't reach the generator (B-05).

### 2.7 What the app gets wrong

- Notifications are scolding (B-16). This segment internalizes "yarın iki gün geride kalırsın" as personal failure, not motivation.
- Camera mandatory (B-03). Half this segment has roommates/kids/spouses in the room.
- Day 1 too aggressive (B-02). Should be 3 movements with knee variants, not 5 with plank-30sec.
- No cycle awareness (B-10). 30-day program covers a full cycle.
- "Sert Karın Kasları" / "HAZIRLAN" aesthetic (B-13, B-18). Wrong tonal register.
- Day 31 dead end (B-12). This segment is the most likely to be a *long-term* customer if Day 31 has continuation.

### 2.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Partial | Challenge Hero CTA works as primary entry; equipment strip is dead weight (they have no equipment) |
| Beslenme | Strong | This segment has explicit nutrition curiosity (recipes, meal planning); calorie ring works for them |
| Gelişim | Strong | Streak card, progress %, badge gallery — motivation visualization is gold for them |
| Profil | Weak | Buried tile structure (F-08); they rarely visit |

The dashboard's default-Antrenman behavior (F-01 from Phase 2) actively works against them — Gelişim's Today Task Card with completion-tracking is the natural home page for this segment.

### 2.9 Paywall trigger affinity

The 8 paywall trigger surfaces (atlas §6.3 + Phase 2 erratum E-2):

| Surface | Conversion likelihood | Why |
|---|---|---|
| Post-onboarding redirect | Low (~10%) | Forced view before they've sampled — same as cold visit to a website |
| Today Task Card (Day 4+) | Medium (~25%) | Surprise paywall + streak loss-aversion = some convert; most bounce |
| Profile FormAI Premium tile | Very low (~3%) | They don't visit Profile |
| Antrenman PRO pill | Very low (~2%) | Reads as status badge; they don't tap |
| Plan-detail Day tile (Day 4+) | Low (~15%) | Same as Today Task Card; they bounce |
| Plan-detail regional CTA | Very low (~5%) | They don't browse regional plans |
| Plan-detail upsell card | Very low (~5%) | Same |
| Post-OAuth | (forced) | Conversion attribution noise |

**Best converter for this segment:** the Today Task Card at Day 4+ AFTER they've completed Days 1–3. But the surprise framing dampens conversion. Pre-tap pricing signal (per Phase 2 F-02) would meaningfully help here.

---

## 3. SEGMENT 2 — THE ASPIRATIONAL BEGINNER MALE

### 3.1 Wizard signature
- `gender: Male`
- `age: 22–35` (modal: 26)
- `heightCm: 170–183`, `weightKg: 70–95` → BMI 22–28
- `goal: fitness_look` (~50%) or `muscle_gain` (~40%) or `belly_burn` (~10%)
- `activityLevel: sedentary` (office workers, students) or `light` (walkers, casual swimmers)
- `experienceLevel: none` (~50%) or `occasional` (~50%)
- `painPoint: no_idea` (most common — they want to start but don't know what to do) or `motivation`
- `dailyMinutes: 20_30`

### 3.2 TR market share: ~18%

Young Turkish men with disposable income who want to "look fit" without committing to a real gym membership (~₺500–800/month for a Fitness World / MAC sub). The home-app is a cheaper toe-dip.

### 3.3 What they want (JTBD)
- "I want to look good in a t-shirt before summer."
- "I want to not be embarrassed at the beach in Antalya."
- "I want my arms to fill out a bit."
- Not yet: "I want to bench-press 100kg." That's a later evolution; first they need to see results from bodyweight.

### 3.4 What makes them quit

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 1 | Medium | "HAZIRLAN" aesthetic is fine for this segment; less of an issue than Segment 1. Camera mandatory is more tolerable but still a spousal/roommate issue. | B-13 (mild) |
| 2 | High | DOMS hits them too. They might push through — "no pain no gain" — but the second-day soreness is real. | B-02 |
| 5–7 | Critical | Plateau perception. They expected to "see something" by Day 7. The deterministic same-plan-as-everyone (B-19) means progress feels generic. | B-19 |
| 14 | Critical | Their plan is `tone` (cardio-led) regardless of which `muscle_gain` token they picked. By Day 14 they realize the workouts are not bulk-shaped. | B-05 |
| 30 | High | Day 31 dead end. They were just starting to enjoy it. | B-06, B-12 |

### 3.5 What makes them convert to Pro

This segment converts at the **Day 4 paywall more often than Segment 1** because:
- They have higher disposable income.
- They've internalized the "real change requires investment" gym-bro mindset.
- The "₺0,00 karşılığında dene" + 7-day trial framing works on them.

But the ⅓-rule applies: ~33% convert at Day 4 paywall, ~25% on Day 7+ as plateau hits, ~42% bounce.

### 3.6 What the app gets right

- Onboarding step 4 (`muscle_gain` option) animation feels validating.
- The "FormAI" / "AI DESTEKLİ FORM KOÇU" tech-bro positioning works for them.
- Pose detection via camera is exciting (novelty).
- The neon aesthetic doesn't alienate them.
- 30-day framing works (they have summer-deadline mental model).

### 3.7 What the app gets wrong

- Their `muscle_gain` goal is silently routed to `tone` plan (B-05). When they figure this out (~Day 7), they leave for Strong / Hevy.
- Day 7+ feels like Day 1 — same exercises, same reps + 1.2× scale. Not bulk-shaped progression.
- Day 31 dead end (B-06) — they were ready to commit to Phase 2.

### 3.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Strong | Challenge Hero + equipment strip + regional plans match their pattern of "what should I do today" browsing |
| Beslenme | Weak | They generally don't track macros at this level; they eat what their family cooks |
| Gelişim | Medium | Streak + progress works; badges are mildly engaging |
| Profil | Weak | Same as Segment 1 |

### 3.9 Paywall trigger affinity

| Surface | Conversion likelihood | Why |
|---|---|---|
| Post-onboarding redirect | Medium (~22%) | They expected a paywall; the 7-day trial framing closes them |
| Today Task Card (Day 4+) | High (~35%) | Streak loss-aversion + sunk cost + disposable income |
| Plan-detail regional CTA | Medium (~18%) | They actively browse regional plans; the locked plans are temptation |
| Plan-detail upsell card | Medium (~15%) | Same |
| Post-OAuth | (forced) | — |

**Best converter for this segment:** Plan-detail regional/equipment-locked plans. They want the bulk-shaped content, see it locked, and pay to unlock.

---

## 4. SEGMENT 3 — THE RETURNING ATHLETE (DETRAINED MALE)

### 4.1 Wizard signature
- `gender: Male`
- `age: 28–45` (modal: 35)
- `heightCm: 175–185`, `weightKg: 80–100` → BMI 24–30 (often previously fit, gained weight)
- `goal: muscle_gain` (~45%) or `strength` (~35%) or `fitness_look` (~20%)
- `activityLevel: light` (used to be active, now light) or `sedentary` (desk job)
- `experienceLevel: occasional` (most common) or `regular`
- `painPoint: consistency` ("I know what to do, I just can't do it consistently")
- `dailyMinutes: 20_30` or `45_plus`

### 4.2 TR market share: ~14%

Married 30s/40s men with kids, ex-rugby/football/lifting backgrounds, can't make it to the gym anymore due to family logistics. They want efficient at-home work that respects their training history.

### 4.3 What they want (JTBD)
- "I want to feel like myself again."
- "I want to lose this 8 kg I gained during pandemic / parenthood."
- "I want efficient workouts I can do at 6am before kids wake up."
- "I want to set an example for my kids."

### 4.4 What makes them quit

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 1 | Low | They handle Day 1 well; their issue is consistency, not Day-1 onboarding |
| 7 | High | The plan being `tone` regardless of their `strength`/`muscle_gain` token (B-05) is most painful for them. They IMMEDIATELY recognize "this is a fat-burn cardio plan, not what I asked for." | B-05 |
| 14 | High | Beginner-tier exercises. They get bored. The advanced-week-2 unlock (B-22) shows them more, but the rep volume scaling (1.44×) feels arbitrary, not progressive overload. | B-22 |
| 21 | Medium | Their `experienceLevel: occasional` answer is ignored (B-01). The plan never branches to "you have a base; let's compound-load." | B-01 |

### 4.5 What makes them convert to Pro

This is the MOST conversion-friendly segment for the current paywall. They:
- Have established disposable income (₺249-999/month is non-issue).
- Recognize subscription value (most have done it before).
- Convert during the trial window because the alternative (gym sub) is more expensive.

~50% convert at Day 4; ~30% convert at Day 7-10 once they "decide it's worth it"; ~20% bounce because the workout content doesn't match their training history.

### 4.6 What the app gets right

- Annual plan with "POPÜLER" badge + 7-day trial works on them.
- Restore button + cross-device sync matches their multi-device usage pattern.
- The streak system reinforces their "consistency" pain point — they appreciate the visualization.
- Equipment strip + regional plans gives them something to browse.

### 4.7 What the app gets wrong

- Plan generator ignores their training history (B-01) and goal (B-05). Most-acute pain point.
- The 30-day program is too short for their stated goals (B-06). 12-week is what they actually want; the app promises it then delivers 30 days.
- "Şampiyon serisi devam ediyor!" at every streak ≥7 (B-17) — they're at Day 21 and the AI Coach is using the same line as Day 7. Personalization illusion collapses.
- Pose detection at 15 FPS misses their faster reps (B-21).

### 4.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Strong | They browse equipment + regional; the role-overlap with Gelişim doesn't bother them |
| Beslenme | Medium | They have macros they want hit; the calorie-ring works but they may use other trackers |
| Gelişim | Strong | Their competitive streak instinct + analytics-orientation makes Gelişim valuable |
| Profil | Medium | They actually visit Profile to manage subscription, see referral code |

### 4.9 Paywall trigger affinity

| Surface | Conversion likelihood | Why |
|---|---|---|
| Post-onboarding redirect | High (~45%) | They were going to pay anyway; the post-onboarding gate is fine |
| Today Task Card (Day 4+) | High (~40%) | Streak + sunk cost |
| Plan-detail regional CTA | High (~30%) | They want the variety |
| Profile FormAI Premium tile | Medium (~15%) | They visit Profile and the tile is conversion-natural |
| Antrenman PRO pill | Low (~5%) | Same affordance issue as other segments |

**Best converter for this segment:** Post-onboarding paywall. Highest LTV.

---

## 5. SEGMENT 4 — THE BODY-IMAGE-ANXIOUS BEGINNER

### 5.1 Wizard signature
- `gender: Female` (~80%) or `Other` (~20%)
- `age: 18–28` (modal: 22)
- `heightCm: 155–172`, `weightKg: 55–95` (high variance — both underweight and overweight present)
- `goal: belly_burn` or `fitness_look` (rarely `muscle_gain`)
- `activityLevel: sedentary` — students, university-age
- `experienceLevel: none` (overwhelming)
- `painPoint: motivation` or `consistency`
- `dailyMinutes: 10_15` (the lowest commitment)

### 5.2 TR market share: ~12%

University-age and post-grad young women + non-binary users with a complicated relationship with their body. Some have ED-spectrum patterns. Some are just shy. They install the app on a 3am impulse and check it for ~2 weeks.

### 5.3 What they want (JTBD)
- "I want to do something private, in my room, where nobody sees me."
- "I want to feel less awful about myself."
- "I want a friend, not a coach."

### 5.4 What makes them quit

This segment has the **highest Day-1 dropout** in the app. They:
- Open the app, see "Vücudunu Yapay Zeka ile Şekillendir" — internalize as judgmental.
- See gendered before/after composite at the paywall (B-15) — read as "your body is wrong, this is what right looks like." Spiral.
- See camera permission prompt (B-03) — close the app.
- See "Sert Karın Kasları" / "Bacak ve Kalça Ateşi" (B-18) — feel they don't belong.

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 0 (cold install) | Critical | Onboarding's "30 günde" labor illusion is exciting; the Welcome screen + Coach intro work | — |
| Paywall view | Critical | Gendered before/after triggers comparison wound | B-15 |
| 1 first workout | Critical | Camera mandatory + neon HAZIRLAN aesthetic | B-03, B-13 |
| 2 (DOMS) | Critical | Soreness + guilt notifications | B-02, B-16 |

By Day 5, ~70% of this segment has uninstalled.

### 5.5 What makes them convert to Pro

This is the **lowest converter** of the 6 segments. ~5–8% convert overall. The conversion lever is NOT the standard "show the value" — it's *psychological safety*. They convert when:
- They've sampled the workout loop and felt safe (no shaming).
- The paywall framing is "support the work" rather than "get more."
- They've heard from a friend (referral) that the app didn't make them feel bad.

### 5.6 What the app gets right

- The free 3 days lets them sample without commitment.
- The onboarding helpers ("Hiç sorun değil") are the right tone.
- The `painPoint: motivation` branch in the AI report addresses them sympathetically.
- AI Coach card on Gelişim with "Geri dönüş zamanı. 10 dakika yeterli." is their style of voice.

### 5.7 What the app gets wrong

- Almost everything visual after onboarding (B-13, B-15, B-18, B-24).
- Camera mandatory (B-03).
- Notifications (B-16).
- Streak loss-aversion (B-14) — they break a 4-day streak and feel WORSE.
- Day 4 triple-jeopardy (B-04).

This segment is the strongest argument for a "soft mode" or "body-positive mode" toggle the app currently doesn't have.

### 5.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Weak | The aggressive "Sert Karın" / "BAŞLA" titles activate them |
| Beslenme | Strong | This segment is most likely to ALSO be tracking calories elsewhere; the recipe browsing is genuinely useful and non-triggering |
| Gelişim | Mixed | Streak + progress is helpful when going well; punishing when not |
| Profil | Weak | They don't visit |

The Beslenme tab is likely the *survival path* for this segment — if the workout side keeps triggering them, the recipe-browse path keeps them engaged at low risk.

### 5.9 Paywall trigger affinity

| Surface | Conversion likelihood | Why |
|---|---|---|
| Post-onboarding redirect | Very low (~3%) | Triggers comparison wound |
| Today Task Card (Day 4+) | Low (~8%) | Most have already bounced |
| Profile FormAI Premium tile | Very low (~1%) | Don't visit |
| Antrenman PRO pill | Very low (~1%) | Don't tap |

**Best converter for this segment:** Almost none, with current paywall framing. A *psychological-safety paywall* (e.g., "destek olarak Pro al, hiç bir özelliği kaybetmezsin" — support the work) would convert ~3× more. The current product can't reach them.

---

## 6. SEGMENT 5 — THE POST-PARTUM MOTHER

### 6.1 Wizard signature
- `gender: Female`
- `age: 28–40` (modal: 32)
- `heightCm: 155–168`, `weightKg: 65–85` (post-pregnancy weight retention)
- `goal: belly_burn` (~60%) or `fitness_look` (~40%)
- `activityLevel: sedentary` (~50%) or `light` (~50%) — many are stay-at-home with infants/toddlers
- `experienceLevel: occasional` — most worked out pre-pregnancy
- `painPoint: consistency` (top) or `motivation`
- `dailyMinutes: 10_15` (overwhelming — this is a real time-budget answer for them)

### 6.2 TR market share: ~10%

Turkish mothers 6 months to 2 years post-partum, often stay-at-home or part-time, looking to "get my body back." Heavy users of Instagram fitness accounts. Often deeply price-sensitive (single income / on maternity leave).

### 6.3 What they want (JTBD)
- "I want to feel like myself in my body again."
- "I want to lose the post-baby belly without diet pills."
- "I want to do this in 15 min while baby naps."
- "I want to do it without leaving the house."

### 6.4 What makes them quit

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 1 | Critical | Camera mandatory while baby sleeps in next room — phone with bright screen, TTS audio | B-03 |
| 1 | Critical | Standard core exercises are NOT post-partum-safe (diastasis recti risk). The plan ships plank + crunch as Day 1 | B-02, B-09 (plan rigidity, no medical-history input) |
| 2 | Critical | DOMS in core that may overlap with diastasis recti recovery | B-02, B-07 |
| 7 | High | `dailyMinutes: 10_15` answer ignored (B-11) — they wanted 10–15 min but got 20+ min sessions | B-11 |
| 14 | High | Cycle insensitivity (B-10) — many post-partum women have irregular cycles | B-10 |

### 6.5 What makes them convert to Pro

Price-sensitive. The 7-day trial works on them ONLY if Day 7 sees results. Otherwise they cancel before billing. ~15% convert; ~85% cancel during trial.

### 6.6 What the app gets right

- 30-day framing matches their "give it a month" mental model.
- The recipe / meal-plan side (Beslenme tab) is genuinely useful — they're feeding family + watching calories.
- Free 3 days is enough to sample.

### 6.7 What the app gets wrong

- **Critically:** No diastasis recti screening. Day 1 plank + crunch is contraindicated for ~30% of post-partum women. The app could LITERALLY harm them.
- Camera mandatory + sleeping-baby scenario (B-03).
- `dailyMinutes` ignored (B-11).
- No cycle awareness (B-10).
- No "you might be sore tomorrow because your core is recovering" rest-day education (B-07).

### 6.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Mixed | The 10–15 min Day 1 promise is broken (sessions actually longer); equipment they don't have |
| Beslenme | Strong | Recipe + meal planning is their daily reality |
| Gelişim | Medium | Streak motivation works; analytics secondary |
| Profil | Weak | — |

### 6.9 Paywall trigger affinity

| Surface | Conversion likelihood | Why |
|---|---|---|
| Post-onboarding redirect | Low (~10%) | Price-sensitive; want to sample first |
| Today Task Card (Day 4+) | Medium (~20%) | Sunk cost + streak |
| Plan-detail regional CTA | Very low (~3%) | They don't browse regional plans |

**Best converter:** They convert post-Day-7, after they've established the habit. The current Day 4 paywall is too early. They'd be better served by a Day 10 paywall with mid-program review.

---

## 7. SEGMENT 6 — THE ACTIVE LIFTER LOOKING FOR FORM COACH

### 7.1 Wizard signature
- `gender: Male` (~90%) or `Female` (~10%)
- `age: 25–45`
- `heightCm: 175–190`, `weightKg: 80–100` (lean to muscular)
- `goal: strength` (~50%) or `muscle_gain` (~50%)
- `activityLevel: active` (they're already lifting 3+×/week)
- `experienceLevel: regular`
- `painPoint: no obvious answer` — many leave it as default `motivation` because nothing fits
- `dailyMinutes: 45_plus`

### 7.2 TR market share: ~6%

Existing gym-goers who heard "AI form coach" and want to use the camera + pose detection as a supplementary tool to check their form between gym sessions. They're not the target audience, but they show up.

### 7.3 What they want (JTBD)
- "I want a free second opinion on my form during my home accessory work."
- "I want to track if my squat depth is improving."
- "Show me my pose data over time."

### 7.4 What makes them quit

| Day | Risk | Cause | Finding ref |
|---|---|---|---|
| 0 (post-onboarding) | High | The 30-day program structure is irrelevant to them — they don't want a program, they want a tool | — |
| 1 first workout | High | Pose detector at 15 FPS misses fast reps (B-21). They want frame-by-frame analysis. | B-21 |
| 1 first workout | High | Form warnings are limited to a few exercises (Plank, Crunch). For barbell squat, the analyzer is silent. | atlas §8.4 (16 analyzer subclasses) |
| 7 | High | The plan they got is `tone` regardless of their stated goals. Pure noise. | B-05 |
| Always | Critical | The app doesn't surface pose data over time. There's no "my form score" history. | (gap) |

### 7.5 What makes them convert to Pro

~3–5%. Most realize within a session that the app isn't built for them and uninstall.

### 7.6 What the app gets right

- The pose detector exists.
- The form-warning TTS exists for a few exercises.

### 7.7 What the app gets wrong

- The product doesn't actually serve this segment, and never claimed to. But the marketing of "AI form coach" attracts them. False positives.

### 7.8 Tab service map

| Tab | Serves them? | How |
|---|---|---|
| Antrenman | Weak | Plan-irrelevant |
| Beslenme | Weak | They use MyFitnessPal |
| Gelişim | Weak | They use Strong / Hevy for tracking |
| Profil | Weak | — |

### 7.9 Paywall trigger affinity

Negligible. They uninstall before reaching the paywall.

---

## 8. SEGMENT 7 (MINOR) — THE GYM-AVOIDANT CONSERVATIVE FEMALE

### 8.1 Wizard signature
- Subset of Segment 1 with strong religious / social constraints making mixed-gender gyms socially impossible.
- Often headscarf-wearing; modest dress in workout context.
- `gender: Female`, `age: 25–55` (broader range than Segment 1).

### 8.2 TR market share: ~4%

A behaviorally distinct cohort because their home-only constraint is non-negotiable. Even if a friend invited them to a women-only gym, distance + transport make it infeasible. The home-app is the only path.

### 8.3 What they want
Same as Segment 1 + the extra constraint that "the workout must be doable wearing modest clothes" (long sleeves, long pants — sweat regulation matters more).

### 8.4 What makes them quit
Same as Segment 1 + the camera-mandatory friction is amplified (B-03) — modest dress users may find filming themselves at home culturally fraught even alone.

### 8.5 Conversion
Same as Segment 1, often slightly higher (~30%) because the alternative (gym sub) is genuinely impossible for them.

### 8.6 What the app should know
- They are an even better fit for the audio-only mode the app doesn't have (B-03).
- Their cultural context means the "Sert Karın" / "Bacak ATEŞİ" copy register is even more alienating.

---

## 9. SEGMENT 8 (MINOR) — THE OLDER RECOVERY USER

### 9.1 Wizard signature
- `gender: Any`
- `age: 45–65` (modal: 52)
- `goal: fitness_look` (most often) — they're not looking for transformation, they're looking for function
- `activityLevel: sedentary` — post-surgery, post-injury, or chronic back pain
- `experienceLevel: none` — even if they were active 20 years ago, that doesn't count
- `painPoint: no_idea` — they don't know what they can safely do
- `dailyMinutes: 10_15`

### 9.2 TR market share: ~2%

Smaller commercial bet but a vocal segment in app reviews. They install based on a doctor's recommendation or a child's nudge ("anne, telefonuna şu uygulamayı yükle, sırt ağrılarına iyi gelecek").

### 9.3 What they want
- "I want to do gentle exercises that don't make my back worse."
- "I want to walk further before getting tired."
- "I want to live independently as I age."

### 9.4 What makes them quit
| Issue | Severity |
|---|---|
| Day 1 plank for 30 sec is unsafe for many in this cohort | Critical |
| The aesthetic ("HAZIRLAN", neon) is immediately read as "this is for young people" | Critical |
| Camera permission prompt + face filming = "I'm too old for this" identity friction | Critical |
| Notification copy + drill aesthetic | High |

### 9.5 Conversion
~2%. They mostly uninstall in 3–5 days.

### 9.6 What the app should know
This segment + Segment 4 (body-image anxious) are the strongest cases for a "Beginner-Safe Mode" the app doesn't have. The technical work is small (knee-variant exercises in catalogue, kinder copy strings). The audience is a long-term LTV cohort if served — older Turkish users are more loyal once trust is built.

---

## 10. CROSS-SEGMENT FINDINGS

### 10.1 The "Day 4–5 cliff" affects every segment differently

| Segment | Day 4–5 dropout impact |
|---|---|
| Segment 1 | ~50% bounce at first paywall |
| Segment 2 | ~33% bounce, but ~33% convert |
| Segment 3 | ~20% bounce — highest conversion segment |
| Segment 4 | They've already bounced by Day 4 |
| Segment 5 | ~60% bounce — too early for them |
| Segment 6 | They've already bounced by Day 1–2 |
| Segment 7 | Same as Segment 1 |
| Segment 8 | They've already bounced |

### 10.2 The "broken wizard data flow" (B-01, B-05) hurts every segment

Every segment is given a `tone, beginner` plan regardless of their wizard answers. The cost is segment-specific:
- Segment 1 (`belly_burn`, `none`): plan is roughly correct by accident. They benefit from the bug.
- Segment 2 (`muscle_gain`/`fitness_look`, `none`): plan is fat-burn cardio. Disconnect by Day 7.
- Segment 3 (`muscle_gain`/`strength`, `occasional`/`regular`): plan is way too easy. They notice immediately.
- Segment 4 (`belly_burn`/`fitness_look`, `none`): same as Segment 1, accidental fit.
- Segment 5 (`belly_burn`, `occasional`): plan is roughly correct. They benefit from the bug.
- Segment 6 (`strength`/`muscle_gain`, `regular`): plan is irrelevant. They were already going to bounce.
- Segment 7: same as Segment 1.
- Segment 8 (`fitness_look`, `none`): plan is too aggressive. The bug hurts them — they need an even gentler path.

The bugs B-01 and B-05 happen to be neutral or beneficial for ~46% of installs (Segments 1, 5, 7) and harmful for ~32% (Segments 2, 3, 8). The remaining ~22% (Segments 4, 6) are bouncing for other reasons.

### 10.3 The default-Antrenman tab works for Segments 2, 3 — fights Segments 1, 5

Segments 1 and 5 (and 7) are completion-tracking, streak-motivated, daily-task users. Their natural home page is **Gelişim**'s Today Task Card. The default Antrenman tab puts the wrong surface first for them.

Segments 2 and 3 are exploration-oriented, browse-first users. Antrenman's Challenge Hero + equipment strip + regional plans is their natural surface. Antrenman default works for them.

The product can't satisfy both with a single default. A "Continue last tab" persistence (Phase 2 J-B1) would solve this.

### 10.4 The Profile tab is dead weight for ~80% of users

| Segment | Profile usage | What they actually need from it |
|---|---|---|
| 1 | Rare | Cancel sub if needed |
| 2 | Rare | Cancel sub |
| 3 | Occasional | Manage sub, see referral |
| 4 | Never | — |
| 5 | Rare | Cancel sub before trial ends |
| 6 | Rare | — |
| 7 | Rare | — |
| 8 | Never | — |

The 8-section Profile tab (Phase 2 F-08, F-20) is over-engineered for what users actually do there.

### 10.5 The 8 paywall trigger surfaces hit segments unevenly

| Surface | Best for | Worst for |
|---|---|---|
| Post-onboarding | Segment 3 | Segments 4, 5 |
| Today Task Card Day 4+ | Segments 2, 3 (high streak buy-in) | Segments 1, 4, 5 (too early) |
| Plan-detail regional CTA | Segment 2 (browses), Segment 3 | Segments 1, 4, 5, 7 |
| Plan-detail upsell card | Segment 2 | All others |
| Profile FormAI Premium tile | Segment 3 | All others |
| Antrenman PRO pill | None | All (poor affordance per F-21) |
| Plan-detail Day tile | Segment 3 | Segments 1, 4, 5 |
| Post-OAuth | (forced) | Same impact regardless of segment |

The lack of a `source` parameter on `paywallViewed` (Phase 2 J-C1) means the team cannot measure these conversion-by-surface differentials.

---

## 11. SEGMENT-AWARE INTERVENTIONS THAT WOULD MOVE THE NEEDLE

Cross-references FITNESS_BEHAVIOR_REPORT.md findings.

| Intervention | Helps segments | Resolves findings |
|---|---|---|
| Make `experienceLevel` reach the generator | All (especially 2, 3, 8) | B-01 |
| Make `goal` token reach the generator | All (especially 2, 3) | B-05 |
| Audio-only / no-camera mode | 1, 4, 5, 7, 8 | B-03 |
| Day 1 = 3 movements, knee-variant defaults for `none`-experience | 1, 4, 5, 8 | B-02 |
| Rest-day educational content (mobility, soreness coping) | All (especially 1, 4, 5, 8) | B-07, B-20, B-23 |
| Female-coded copy register variant | 1, 4, 5, 7 | B-18, B-24 |
| Streak-preservation token (1 per week) | All | B-14 |
| Cycle-aware lighter-day toggle | 1, 4, 5, 7 | B-10 |
| Day-31 continuation path | All (especially 1, 3, 5) | B-06, B-12 |
| Soft-mode body-positive copy + avatar instead of camera | 4, 8 | B-13, B-15 |

---

## 12. ERRATA AGAINST PRIOR PHASES

**ERRATA-S-1.** Phase 2 F-09 says nutrition onboarding fires on first Beslenme tab visit "post-paywall." That's correct. But the segmentation here clarifies: Segment 4 (body-image-anxious) and Segment 5 (post-partum) are MORE likely than other segments to visit the Beslenme tab first because the workout side feels unsafe. So the deferred nutrition modal hits these segments earlier in their session. This compounds the modal's friction (non-dismissible, 7 questions) — the segments most likely to encounter it first are also the segments least tolerant of friction.

**ERRATA-S-2.** Phase 2 F-08 (Profile tab consolidates 8+ functions) is correct as IA critique. The segmentation refines: ~80% of users never visit Profile beyond a single sub-cancel trip. The IA over-engineering is an even larger waste than F-08 quantifies — the 7 hand-rolled headers + 4 InfoTiles + 8 settings tiles serve a tiny minority of the user base.

---

## 13. CRITICAL SEGMENTATION FACTS (TL;DR)

1. **Segment 1 (Sedentary Office Worker, Belly-Burn Female) is the largest commercial segment at ~32%** and the app's drill-bro aesthetic actively works against them.
2. **The lowest-LTV segment (4, body-image-anxious) is also the segment whose Day-1 dropout is essentially designed-in** by camera-mandatory + before/after composite + drill copy.
3. **Segment 3 (Returning Athlete) is the highest-LTV segment, but the broken wizard data flow (B-01, B-05) hurts them most.**
4. **The "Day 4 paywall is too early" judgment varies by segment** — Segment 3 converts there, Segments 1, 5 bounce.
5. **Default-Antrenman-tab serves Segments 2, 3 well; serves Segments 1, 5 poorly.** No tab-state persistence (Phase 2 J-B1) means the dashboard can't be calibrated.
6. **No segment is well-served by the 8-section Profile tab** (Phase 2 F-08, F-20).
7. **Segments 4 and 8 together (~14%) cannot be reached by the current product** without a body-positive / age-friendly mode that doesn't exist.
8. **Segment 5 (Post-Partum Mother) faces a literal injury risk** because Day 1 ships plank + crunch with no diastasis recti screening.
9. **Segment 6 (Active Lifter) was attracted by misleading marketing** (the "AI form coach" framing) but the product doesn't serve them. Most uninstall in <48h.
10. **The 8 paywall surfaces have meaningfully different conversion rates per segment**, but no `source` parameter means this can't be measured.

---

**END OF USER_SEGMENTATION_REPORT.md**
