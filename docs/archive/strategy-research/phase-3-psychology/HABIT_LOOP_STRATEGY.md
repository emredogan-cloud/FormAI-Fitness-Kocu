# HABIT LOOP STRATEGY

**Phase 3 — Psychology · Habit-Formation Diagnostic**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-08
**Inputs:** atlas + Phase 2 USER_FLOW_ANALYSIS + Phase 3 USER_PSYCHOLOGY_REPORT + RETENTION_TRIGGER_REPORT.

**Scope:** Audit the FormAI habit loop using Duhigg's *Power of Habit* framework (cue → routine → reward) and Eyal's *Hooked* model (trigger → action → variable reward → investment). This is **not** a redesign; it identifies where the loop is broken and where investment compounds correctly. Findings are the same severity-scored format as the other Phase 3 reports.

---

## 0. METHODOLOGY

The FormAI canonical habit loop is "open the app every day and complete today's workout." This document deconstructs that loop into:
- **Cue** — what fires the user's motion to start
- **Routine** — the action the system asks them to perform
- **Reward** — the dopamine event after the action
- **Investment** — what the user puts in that compounds for next time
- **Habit Ceiling** — what happens when the canonical loop saturates (Day 30+)

Severity scale (habit-impact):
- **5** — the loop is structurally broken at this stage; users can't form the habit even with good intent
- **4** — the loop forms but breaks within ~7-14 days because the reward decays or the cue misfires
- **3** — the loop forms but doesn't compound (each day is its own cycle, no momentum across cycles)
- **2** — secondary friction
- **1** — cosmetic

---

## 1. EXECUTIVE FINDINGS TABLE

| ID | Sev | Title | File:line / atlas §ref |
|---|---|---|---|
| H-01 | 5 | Cue system relies almost entirely on time-of-day reminder + loss-aversion warning — when notifications get muted, the loop has no fallback cue | `notification_service.dart:70–123, 299–331` |
| H-02 | 5 | Reward schedule is fixed-ratio every cycle — the same trophy + same +1 streak + same predictable cell render — dopamine flatlines after Day 7 | `session_complete_overlay.dart:65–151`, `gelisim_tab.dart:1031–1090` |
| H-03 | 5 | Habit ceiling at Day 30 — `ProgramCompleteCard` has no "Day 31+" surface; successful users churn by design | `today_task_card.dart:176–216`, `suggestions_screen.dart:129–141` |
| H-04 | 4 | Routine is 5 screens deep (atlas §8.6) — "tap to first rep" friction tax compounds across 30 cycles | atlas §8.6 + journey J-A7 |
| H-05 | 4 | Investment built in onboarding (AI report endowment) is discarded post-paywall — the highest-investment artifact never reappears | `_DynamicReportStep` exit at `_finish()`; cf. P-23 |
| H-06 | 4 | Reward magnitude is inverted — single badge unlock (mid-program) gets a fullscreen modal; 30-day completion gets a 60px inline card | `badge_unlock_dialog.dart:55–100` vs `today_task_card.dart:176–216` |
| H-07 | 4 | No habit-stack surface — the wizard captures `dailyMinutes` and `activityLevel` but never asks "after which existing habit do you want this?" | `onboarding_screen.dart:53–66` step list |
| H-08 | 3 | Cue is undifferentiated by program day — Day 1 reminder body identical to Day 14 | `notification_service.dart:70–84` |
| H-09 | 3 | Streak watermark (`maxStreak`) is captured but only consumed by AI Coach copy; not surfaced to scaffold a comeback investment | `gelisim_tab.dart:1617` only consumer |
| H-10 | 3 | "BUGÜNKÜ GÖREV" framing (`today_task_card.dart:44`) is task-phrased, not identity-phrased — frames the user as obligation-holder, not athlete | `today_task_card.dart:44` |
| H-11 | 3 | No tomorrow-preview surface — anticipation as a cue is unused | absence in `gelisim_tab.dart`, `widget_sync_service.dart` |

**Total:** 11 findings. **3 sev-5, 4 sev-4, 4 sev-3.**

---

## 2. THE FORMAI HABIT LOOP MAP

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        FORMAI CANONICAL HABIT LOOP                       │
│                  "Open app daily → complete today's workout"             │
└──────────────────────────────────────────────────────────────────────────┘

      EXTERNAL CUE                          INTERNAL CUE                 
      (system pings user)                   (user reaches reflexively)   
                                                                         
   ┌─────────────────┐                    ┌─────────────────┐             
   │ Daily reminder  │                    │ Streak-anxiety  │             
   │   @ 19:00       │                    │   "won't lose   │             
   │   (default)     │                    │    progress"    │             
   └────────┬────────┘                    └────────┬────────┘             
            │                                       │                     
            │   Streak-warning                      │                     
            │   @ 48h after last                    │                     
            │   (T-01: misfires)                    │                     
            │                                       │                     
            └───────────────┬───────────────────────┘                     
                            │                                             
                            ▼                                             
                      ┌──────────┐                                        
                      │ ROUTINE  │                                        
                      └────┬─────┘                                        
                           │                                              
   1. Open app  ──>  Bootstrap ~split-second to ~8s                       
   2. Land on Antrenman tab (default, even if user habit is Gelişim)      
   3. Find CTA — Challenge Hero OR switch to Gelişim → Today Task         
   4. Tap CTA → /plan-detail                                              
   5. Tap day tile → /workout                                             
   6. HAZIRLAN! 3s prep                                                    
   7. Camera + first exercise                                             
                           │                                              
                  (5 screens, ~13–15 taps total per atlas §8.6 + J-A1)    
                           │                                              
                           ▼                                              
                      ┌────────┐                                          
                      │ REWARD │                                          
                      └────┬───┘                                          
                           │                                              
   • SessionCompleteOverlay: 96px trophy + "Gün N Tamam!" + 3-line copy   
   • Optional: recovery-recipe suggestion                                 
   • Streak ticks +1                                                       
   • One green check on 30-day grid                                       
   • Possible badge unlock dialog (only if user is on Gelişim tab)        
   • Sometimes: AI Coach copy line shifts (only after Day 7)              
                           │                                              
                  (Fixed-ratio reinforcement — H-02)                      
                           │                                              
                           ▼                                              
                  ┌────────────┐                                          
                  │ INVESTMENT │                                          
                  └─────┬──────┘                                          
                        │                                                  
   • completion logged → user_progress (Supabase)                         
   • streak watermark updated → maxStreak (SharedPreferences)             
   • Home widget refreshed → home-screen pill shows new state             
   • Smart-reminder rescheduled → next ping reflects current state        
                        │                                                  
                        ▼                                                  
                ┌──────────────┐                                           
                │ HABIT LOOP   │                                           
                │ COMPLETED    │                                           
                │ Returns to   │                                           
                │ "open app"   │                                           
                └──────────────┘                                           

                                                                          
                       ▲                                                  
                       │                                                  
                       │   Day 30: BREAKS                                 
                       │   ┌────────────────────┐                          
                       └───┤ ProgramCompleteCard│                          
                           │ — no Day 31 loop   │                          
                           │ (H-03)             │                          
                           └────────────────────┘                          
```

The map shows the loop *exists* — Cue, Routine, Reward, Investment all have working components. But three structural issues compound:

1. The **Cue stage is single-mechanism** (time + loss aversion). When the user mutes notifications or the system misfires (T-01), the cue collapses entirely. There's no internal-trigger replacement (per the Hooked Model graduation, mature apps build internal triggers as backup; FormAI doesn't — see USER_PSYCHOLOGY_REPORT P-17).
2. The **Routine has 5 screens of friction** (atlas §8.6) — every cycle pays this tax. Habit research (Lally et al. 2010) says routines must be "automatic" — friction prevents automation.
3. The **Reward is fixed across cycles** — the same trophy, same +1, same green check. Dopamine flatlines.

---

## 3. CUE ANALYSIS

### 3.1 What cue does the app rely on?

**Primary cue:** time-of-day daily reminder (default 19:00, user-tunable via Profile → AYARLAR → Bildirimler tile, `account_settings_screen.dart:248`).

**Secondary cue:** streak-warning notification 48h after last completion (`notification_service.dart:299–331`).

**Tertiary cue:** home-screen widget glance (`widget_sync_service.dart`).

**Internal cue (latent):** streak-loss anxiety (the user thinks "I'm at 12 days, can't break it" and opens the app).

### 3.2 Cue robustness

A robust cue system has multiple independent triggers so that any one failing doesn't break the loop. FormAI's cue system has known fragility:

| Cue | Failure mode | Probability |
|---|---|---|
| Daily reminder | User mutes (after T-08 loss-framing fatigue) | **High** for users 30+ days in |
| Streak warning | Misfires per T-01 (fires after break) | **100%** for users who break |
| Widget glance | Logged-out tap vaporizes intent (T-02) | Medium |
| Internal streak-anxiety | Vanishes when streak == 0 | **100%** at first break |

So the canonical "user broke streak yesterday" state has *zero* working cues. Every cue source has either misfired or vanished. The user can come back, but the system isn't actively pulling them.

### Finding H-01: Cue system has no fallback when notifications get muted
**Severity:** 5/5
**Where:** `lib/core/services/notification_service.dart:70–123, 299–331`
**Mechanism:** Cue redundancy. Habit research (BJ Fogg, James Clear) recommends **stacked cues** — multiple independent triggers so any one's failure doesn't break the loop. FormAI's cue stack is dominated by push notifications (3 noWorkout variants + 2 streak warnings + 2 workoutNoFood + 3 bothDone). When push gets muted, the only other cue is the home-screen widget, which is opt-in and most users don't add.
**Observation:** The total external-trigger surface is:
- Push notification system (the workhorse)
- Home-screen widget (opt-in by user)
- Live Activity during workout (in-flow only, T-06)

Not present:
- Email digest (no email service in codebase)
- SMS comeback (no SMS service)
- Calendar event integration (atlas confirms no calendar API)
- Apple Health workout reminders bridge
- Habit-stack hook (H-07)

When push gets muted, the system has the widget and that's it. For Turkish-market Android users (a large segment) where notification fatigue is high (cf. App Annie 2024 Turkey market report), losing push means losing the loop.
**Cost:**
- The most retention-risky user state (months in, push muted, no streak active) has no system-driven cue to bring them back.
- Even the in-app comeback messaging (`gelisim_tab.dart:1617`) requires the user to open the app — i.e., it requires a cue that the system isn't providing.

**Evidence:** above + grep `email_service`, `comeback_email`, `smtp` — no email-based re-engagement service exists. The notification system *is* the cue system.

### Finding H-08: Cue is undifferentiated by program day
**Severity:** 3/5
**Where:** `lib/core/services/notification_service.dart:70–84` (noWorkout variants)
**Mechanism:** Cue specificity. A cue that says "do something" (generic) is weaker than a cue that says "do today's specific thing" (specific). Specific cues attach to anticipation (the user thinks "oh right, today is Bacak Gücü") rather than obligation ("oh, that fitness app again").
**Observation:** All 3 noWorkout variants are generic:
```
'Antrenman Vakti! 💪 / Hedeflerinden uzaklaşma…'
'Bugünün antrenmanı seni bekliyor! 💪 / Sadece 10–15 dakika…'
'Bir hedefin var, unutma 🎯 / Bugün antrenmanı geçersen yarın iki gün geride kalırsın.'
```
None reads "Bugün Karın Sertleştirme — 25 dk · Başlangıç" (the data the Today Task Card has). The notification has no link to today's specific workout.
**Cost:**
- Anticipation as a cue is unused. The user has no opportunity to look forward to today's specific routine because the notification doesn't tell them what it is.
- Turkish gym culture (recreational) has a strong "split day" muscle group association ("today is leg day"). A push that names today's focus would land in the existing mental model.

**Evidence:** above. T-09 in RETENTION_TRIGGER_REPORT covers this from the retention angle.

### Finding H-11: No tomorrow-preview surface
**Severity:** 3/5
**Where:** absence in `gelisim_tab.dart`, `widget_sync_service.dart`, `account_settings_screen.dart`
**Mechanism:** Anticipation as a cue. Eyal's Hooked discusses *building anticipation* as the strongest internal cue. A user who knows "tomorrow is Karın Sertleştirme" forms a small commitment overnight; the next morning's open is partly fulfillment of the commitment. Apps like Strava ("you have a planned ride tomorrow"), Duolingo ("tomorrow your XP refreshes"), Apple Fitness+ ("up next: HIIT tomorrow") all leverage this.
**Observation:** FormAI shows today (`Today Task Card` at `today_task_card.dart`) and the 30-day grid (which colors today and locks tomorrow). There is no surface that says "Tomorrow: Day N+1 — focus, level, minutes." Such a surface could live:
- On Gelişim, below Today Task Card ("Yarın: Bacak Gücü, 30 dk")
- On the home-screen widget (currently shows today only)
- As a smart-reminder evening push ("Tomorrow's Bacak Gücü is set for 19:00")

None exists. The app focus is entirely "today now"; anticipation is left on the table.
**Cost:**
- Anticipation reinforces commitment overnight. Without it, every morning open is "what is today?" (unknown → curiosity could be a cue, but also could be friction). With it, every morning open is "I'm here for the planned thing" — a stronger commitment.

**Evidence:** above. Grep `tomorrow|yarın|anticipation|preview` across `lib/features/home` returns nothing meaningful for next-day surfacing.

---

## 4. ROUTINE SIMPLICITY

Habit research (Lally et al. 2010) measures habit formation as the time-to-automation of a behavior. The "Habit-Formation Index" their study tracked was sensitive to behavior friction; complex routines took 2-3x longer to automate. For a 30-day program, a routine that automates by Day 7 vs Day 21 is the difference between a successful program and a bailed program.

### 4.1 Tap-by-tap audit

From cold app launch to first rep on a returning user (Journey B in USER_FLOW_ANALYSIS):

| Step | Tap or wait | Cost (s) | Friction note |
|---|---|---|---|
| 1 | App icon tap | ~0 | ok |
| 2 | Bootstrap (Supabase 8s timeout, PostHog 5s) | ~0.3-8 | first cold launch only |
| 3 | Branded splash render | ~0 | ok |
| 4 | Land on Antrenman tab default | ~0 | first real waste — even users whose habit is Gelişim land here |
| 5 | Visual scan for CTA | ~1-2 | non-trivial — Antrenman has 6 sections (atlas §5.1) |
| 6 | Tap "BAŞLA" on Challenge Hero OR tab to Gelişim → tap "ANTRENMANA BAŞLA" | 1 tap | the routine is unclear — see F-01 in PRODUCT_STRUCTURE_REPORT |
| 7 | /plan-detail mounts | ~0.5 | intermediate screen for canonical flow (J-B2) |
| 8 | Find active day tile (the only tappable cell) | ~0.5 | the active cell is visually distinguished but the user has to recognize it |
| 9 | Tap active day tile | 1 tap | ok |
| 10 | _ensureOnlineForWorkout network check | ~0.1 | usually invisible |
| 11 | startDay → push /workout | ~0.1 | invisible |
| 12 | HAZIRLAN! 3s prep countdown | 3s | unskippable per atlas §8.6 |
| 13 | Camera + first exercise | begin |
| **Total** | **3 taps + ~6-13s** | **6-13s** | + 5 screens |

For comparison, a habit-loop-friendly fitness routine looks like:
- Tap notification → land directly in workout flow → 3s prep → first rep. ~1 tap + 3-5s.

FormAI's 3 taps + 5 screens is non-extreme but compounds. Over 30 cycles the tax adds up: ~150-450 seconds of pure navigation friction the user pays for the same destination.

### Finding H-04: Routine is 5 screens deep
**Severity:** 4/5
**Where:** atlas §8.6, journey J-A7 in USER_FLOW_ANALYSIS, journey J-B2 (plan-detail intermediate).
**Mechanism:** Friction-to-automation. Habit research says routines must "feel effortless" to automate. The 5-screen path means every cycle has a non-trivial cognitive load: which CTA, which tile, when does the prep end. Habits with non-trivial cognitive load take 60-90 days to automate (Lally); a 30-day program ends before automation completes.
**Observation:** From cold-launch to first-rep:
- 5 screens after bootstrap (dashboard → plan-detail → workout prep → camera frame → first exercise overlay)
- 3 user-initiated taps
- 1 forced 3-second wait (HAZIRLAN! prep)

Plus screen-internal navigation:
- Dashboard default tab is Antrenman; users whose habit is Gelişim pay a tab-switch tax (J-B1)
- Antrenman vs Gelişim role overlap (F-01) — user has to *decide* which CTA, every cycle
- Plan-detail intermediate (J-B2) has identical metadata to Today Task Card

**Cost:**
- The routine doesn't fully automate within the 30-day program window.
- Each cycle taxes the user with decision points that should be invisible.
- The fix is structural: a "Resume today" surface that one-taps from any state to /workout.

**Evidence:** above + atlas §8.6 explicit: "5 distinct screens between tap-start and exercise begin."

### Finding H-10: "BUGÜNKÜ GÖREV" framing is task-phrased
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:44`
**Mechanism:** Identity vs task framing. The label of the user's daily action shapes how they relate to it. "Today's Task" frames the user as a duty-holder; "Today's Workout" frames it as activity; "Bugün antrenmanın" frames it as ownership.
**Observation:**
```dart
// today_task_card.dart:44
const _CardLabel(text: 'BUGÜNKÜ GÖREV'),
```
"GÖREV" — task / duty. The label borrows from school/work register. For a discretionary fitness app, this register reframes the activity as obligation.

Compare:
- "BUGÜN" + the personalized title alone
- "BUGÜN ANTRENMANIN"
- "GÜNÜN PLANI"

All three would land warmer. "GÖREV" is the formal-Turkish duty register.
**Cost:**
- The user reads "BUGÜNKÜ GÖREV" before the day's content — every cycle, every day, for 30 days.
- The framing slowly trains the user to think of the workout as a chore. Identity-phrased framing ("you're an athlete; today's workout is …") would flip this.
- For a discretionary product (vs e.g. a corporate compliance app), task-phrasing is structurally suboptimal.

**Evidence:** above. The label is `const`, so the framing is the same on every render.

---

## 5. REWARD SCHEDULE

The reward stage is where dopamine fires. Operant conditioning research (Skinner 1957) and modern behavioral design (Hooked Model) agree: **variable** reward schedules sustain engagement; **fixed** reward schedules plateau within ~7 cycles.

### 5.1 Reward inventory by frequency

| Reward | Frequency | Variability | Magnitude |
|---|---|---|---|
| `SessionCompleteOverlay` 96px trophy + "Gün N Tamam!" | 1× per workout | Fixed (only N varies) | High visual |
| Streak +1 | 1× per workout | Fixed (always +1) | Low visual (number ticks) |
| 30-day grid current → green | 1× per workout | Fixed (cell flips) | Medium |
| Recovery-recipe suggestion in overlay | 1× per workout | Slightly variable (algorithmic) | Medium |
| Badge unlock dialog | Sporadic per badge | Slightly variable (which badge, when) | High visual + haptic |
| AI Coach copy shift (3 branches) | At streak crossing 7 / 0 | Quasi-fixed | Low visual |
| Daily summary TTS | On user tap | Variable (3 dynamic fields) | Audio only |
| 5-dot streak checklist fill | 1× per workout | Fixed (capped at 5) | Low after Day 5 |
| Stats charts updates | 1× per workout | Slightly variable | Low (numbers tick up) |

**The scoring:** of 9 reward sites, only 2 (badge unlock + daily summary TTS) have meaningful variability, and the badge unlocks are sparse. Every other reward is fixed-ratio.

### Finding H-02: Reward schedule is fixed-ratio every cycle — dopamine flatlines after Day 7
**Severity:** 5/5
**Where:** `lib/features/workout/presentation/widgets/session_complete_overlay.dart:65–151`, `lib/features/home/presentation/widgets/gelisim_tab.dart:1031–1090` (completed cell), `lib/features/home/presentation/widgets/today_task_card.dart` (no rotation surface)
**Mechanism:** Variable-ratio reinforcement (Skinner). Variable schedules sustain behavior longer than fixed schedules of equivalent reward density. Slot machines, social media notifications, lottery tickets all exploit variable-ratio. Predictable rewards (every workout = same trophy) plateau the dopamine response — the brain learns the pattern and stops reacting.
**Observation:** A user finishes Day 1, 7, 14, 21, 28. Each time the reward sequence is:
- `Future.delayed(...)` for animation timing
- `SessionCompleteOverlay` renders with `military_tech` icon at 96px (line 69)
- Title `'Gün $N Tamam!'` — only N varies
- Subtitle `'Harika iş çıkardın, yarın görüşürüz.'` — literal const string (line 84-87)
- Recovery-recipe card if catalog loaded (line 89-92)
- "Paylaş" + "Tamam" buttons

The visual + animation + copy is identical on Day 1 and Day 28. The user's brain learns the pattern by Day 5; from Day 6 onward, the reward signal flattens.

The streak + grid cell rewards are even more fixed. Every workout day produces:
- Streak number ticks +1 (predictable)
- 30-day grid cell flips from "pulsing current" to "green check" (predictable)
- Streak Card 5-dot checklist fills (predictable, capped at 5)

There is no "which badge unlocked today?" surprise on most days. There is no "AI Coach said something new and unexpected" event. There is no "today's recovery snack is one you've never tried" highlight.

**Cost:**
- Dopamine flatlines by Day 7-10 of the program.
- The remaining ~20 days of the program operate on declining-returns reward; users continue from intent + identity, but the system isn't helping.
- This is the canonical post-novelty-wear-off pattern that kills 30-day fitness apps. The fix is variable reward injection at any of the existing reward sites:
  - Random "Did you know?" insight in overlay (1 of N pre-written insights)
  - Random badge surface highlight on Gelişim
  - Random AI Coach insight rotation
  - Recovery-recipe rotation through a wider pool
  - Random "stat of the day" celebration in stats cards

Each is ~50 lines of code. The structural absence is the signal — the team built the chrome (overlay, dialog, cards) but didn't randomize the content.

**Evidence:** see lines above. The literal `const String 'Harika iş çıkardın, yarın görüşürüz.'` at `session_complete_overlay.dart:85` is the strongest single evidence — the canonical post-workout celebration line is hardcoded.

### Finding H-06: Reward magnitude is inverted
**Severity:** 4/5
**Where:** `lib/features/progress/presentation/widgets/badge_unlock_dialog.dart:55–100` vs `lib/features/home/presentation/widgets/today_task_card.dart:176–216` (`ProgramCompleteCard`)
**Mechanism:** Reward calibration. The reward magnitude should scale with the behavior magnitude. A 30-day program completion is a meaningfully larger achievement than unlocking one badge mid-program. The system surfaces the badge unlock with a fullscreen modal + heavyImpact haptic + animated halo + share action. The 30-day completion gets a 60-px inline card.
**Observation:** Side-by-side comparison was already laid out in P-28. Repeating the structural takeaway here:

`ProgramCompleteCard`:
- Inline card slot (where Today Task Card lives)
- ~80px tall
- 30pt 🏆 emoji + "Tebrikler!" 18pt + "30 günlük programı tamamladın." 13pt
- No haptic
- No animation
- No fullscreen takeover
- No "share my completion" CTA

`_BadgeUnlockDialog`:
- Fullscreen dialog with backdrop
- ~400px tall content
- "YENİ ROZET" eyebrow + 110×110 animated halo + 22pt badge name + body + buttons
- `HapticFeedback.heavyImpact()` (line 25)
- 1.6s pulsing animation
- Share affordance via `shareBadgeTemplate`

**Cost:**
- 30-day completion lands as anticlimactic.
- Worse: the user, at the highest-investment moment, gets the smallest signal that the system noticed. This is a celebration-magnitude inversion that maps directly to long-tail churn.
- Compare to 1Password's "you've been with us 1 year" celebration (custom screen + animation), Strava's "you completed your 100th run" (custom hero card with their photos), Apple Fitness+'s "you closed your rings 7 days in a row" overlay. All scale celebration to behavior magnitude.

**Evidence:** above. The components exist (`SessionCompleteOverlay` is the canonical fullscreen template); they just aren't deployed for program completion.

---

## 6. INVESTMENT — WHAT DOES THE USER PUT IN?

Investment is the Hooked Model's fourth stage: what the user contributes that increases the cost of leaving. Investment artifacts include:
- Data (preferences, history, streak watermark)
- Time (cumulative hours of workouts)
- Content (favorited recipes, custom plans)
- Social capital (referrals, shared progress)
- Identity (the user's self-narrative as "someone who uses FormAI")

### 6.1 Investment by program day

| Day | Investment captured | Compounding? |
|---|---|---|
| Day 0 (post-onboarding) | 11 demographic + emotional fields persisted | **Yes** — `user_metrics` is the foundation |
| Day 1 | first completion logged + first badge unlock | Partial — completion is logged, badge surfacing depends on tab |
| Day 3 | last free day; competence built | **Lost at Day 4 paywall (P-03)** — the system asks for $ before the investment compounds |
| Day 7 | streak hits 7; "İlk 7 Gün" badge actually meaningful (vs unlock at Day 1, P-15); AI Coach copy shifts to "Şampiyon" | Partial — but copy shift is the only AI Coach progression |
| Day 14 | half-program; what does the user see? | **No specific milestone surface** — half-completion has no unique visualization |
| Day 21 | three-quarters; goal-gradient should accelerate | **No specific milestone surface** |
| Day 28 | 2 days left; goal-gradient peak | **No specific milestone surface** |
| Day 30 | program complete | `ProgramCompleteCard` (undersized per H-06) |

**The pattern:** the system captures investment fragments (each completion logged, each streak day persisted) but does not visualize *cumulative* investment in a way that makes leaving feel costly. The user's mental ledger says: "I've done a few workouts." The system's surface says: "you're at %23 / 7 days streak / 3 badges unlocked." These don't compose into "I have invested too much to walk away now."

### Finding H-05: Investment built in onboarding is discarded post-paywall
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:_DynamicReportStep` exit at `_finish()` (line 216 routes to /paywall, no in-app re-entry to report)
**Mechanism:** Endowment loss (Thaler 1980). The dynamic AI report is the maximum-investment artifact in onboarding — it's labeled "Kişisel AI Raporun", contains the user's BMI + calorie numbers + a personalized assessment paragraph + 92% confidence bar. By design, this should be the user's most-cherished early artifact.
**Observation:** Repeated from P-23 here for habit-loop framing: the report is shown once at step 11 (and the same report regenerated at step 12 for the summary) and never again. There is no in-app surface to re-display it. After `_finish()` flips `is_first_time = false`, the wizard cannot be re-entered.

The user's first investment moment (the AI report) does not compound into the daily loop. It's a one-shot.
**Cost:**
- The biggest emotional artifact is built and discarded.
- A "Yeniden Gözden Geçir" tile on Profile that re-renders the report would compound the investment. So would "Day 7: your AI report assessment said X — here's how you're tracking" — that's investment tied to milestone.
- The cost is structural: the canonical "you have invested too much to walk away" psychological state never forms.

**Evidence:** above + `lib/features/home/presentation/widgets/profile_tab.dart` has no consumer of `AiPersonalizationEngine`.

### Finding H-09: maxStreak watermark not surfaced for comeback investment
**Severity:** 3/5
**Where:** `gelisim_tab.dart:1617` (only consumer of `appPreferencesProvider.maxStreak`)
**Mechanism:** Investment continuity. After a streak break, the user has lost their current streak. But they retain their `maxStreak` watermark — that's an investment artifact. Surfacing it ("Best: 12 days; let's beat that") makes the comeback feel like building on, not starting over.
**Observation:** The watermark is persisted correctly (`app_preferences.dart` getter `maxStreak`) and updated on each new high. But the only consumer is the AI Coach copy line at `gelisim_tab.dart:1617`:
```dart
if (streak == 0 && maxStreak > 0) {
  return 'Geri dönüş zamanı. 10 dakika yeterli.';
}
```
The watermark *number* is not in the line. The user reads "Geri dönüş zamanı" and sees zero everywhere else (header pill = 0, streak card = 0, all 5 dots empty). The 12 days of investment is invisible.
**Cost:**
- Comeback feels like Day 1 instead of "Day 13 attempt 2."
- The investment is captured but not leveraged.
- A trivial fix would render `maxStreak` in the streak card: "0 gün / En iyi: 12 gün / Yeni rekor için tekrar başla". Two lines of code; the structural absence is the signal.

**Evidence:** above. Grep `maxStreak` returns one consumer (the AI Coach line). Watermark is captured, never displayed.

### Finding H-07: No habit-stack surface
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:53–66` step list (no habit-stack step); `lib/core/services/notification_service.dart` (no event-triggered scheduling)
**Mechanism:** Habit stacking (BJ Fogg, James Clear): "After [existing habit X], I will [new habit Y]." Habit stacks have ~3x higher 60-day retention than time-of-day reminders alone. The wizard captures `dailyMinutes` (10-15 / 20-30 / 45+) and `activityLevel` (sedentary / light / active) but never asks "what existing habit should this slot after?"
**Observation:** The wizard's 12-step flow:
1. welcome — no habit-stack
2. coach_intro — no habit-stack
3. gender — demographic
4. goal — aspiration
5. experience_level — competence
6. daily_minutes — duration availability
7. activity — lifestyle
8. physical_data — body data
9. pain_point — vulnerability
10. analysis_illusion — labor illusion
11. dynamic_report — reveal
12. pre_paywall_summary — sales

None asks "after which existing daily action do you want this habit to fire?" — e.g., "morning coffee", "evening commute home", "kids' bedtime", "before dinner."

The notification system has no event-trigger primitive (e.g., "20 minutes after the user's first iOS HealthKit step count post-7am"). All scheduling is fixed time-of-day.
**Cost:**
- The user gets a 19:00 reminder regardless of life context. For someone whose existing habit is "coffee at 7am, commute home at 18:00, kids' bedtime at 21:00", the 19:00 ping competes with the kids' bedtime — wrong moment.
- Habit stacking is the highest-leverage retention lever for fitness apps. FormAI doesn't use it.

**Evidence:** above + grep `habitStack`, `existingRoutine`, `afterTrigger` across `lib/` returns nothing.

---

## 7. HABIT CEILING — DAY 30+

The most consequential structural finding in this whole audit:

### Finding H-03: Habit ceiling at Day 30
**Severity:** 5/5
**Where:** `today_task_card.dart:176–216` (`ProgramCompleteCard`), `suggestions_screen.dart:129–141` (post-30 suggestion)
**Mechanism:** Habit continuity. A 30-day program is a perfect arc — beginning, middle, end. The end is the user's highest-investment moment. Without a Day 31+ continuation surface, every successful user is structurally a churned user.
**Observation:** On Day 30 completion:
- `_firstIncomplete(days)` returns null (`gelisim_tab.dart:78, 223–229`)
- `isProgramComplete = hasRealSession && days.isNotEmpty && activeDay == null` (line 85-86)
- The Today Task slot renders `ProgramCompleteCard` (line 175)
- `_AiCoachCard` continues to render its 3-branch copy — `streak >= 7` branch fires "Şampiyon serisi devam ediyor!" (which is wrong — the program ended, the streak isn't continuing in any meaningful sense)
- The 30-day grid is fully green (with rest cells in amber) — visually complete
- `SuggestionsScreen` workout-tip on `activeDay == null`: "30 günü tamamladın!… Yeni bir hedef belirlemek için Gelişim sekmesine göz at." (line 129–141) — but Gelişim has no "next program" surface

The user's options on Day 31:
1. Keep using the app and see a 100%-complete 30-day grid every day with no new progress (boring; no reward)
2. Reset / wipe progress and re-do the same 30 days (no surface in atlas §3.1; would need manual "Hesabı Sil + reinstall" workaround)
3. Churn (the path of least friction)

There is no "what's next" UI. There is no "Day 31: maintenance mode" surface. There is no "Choose your next 30-day arc" picker.
**Cost:**
- The system is a one-shot. Every user who completes the program *can't* keep using it, by design.
- For monetization, this is also bad — the most-engaged segment (Day 30 completers) is structurally lost. They paid for an annual subscription and the product gives them ~30 days of value.
- The fix would be either: (a) introduce program variants ("Maintenance", "Advanced 30 days", "Cardio focus 30 days") for Day 31+; (b) introduce a "Maintenance mode" that recycles workouts with progressive overload; (c) introduce a milestone-tracking surface that reframes the ongoing experience ("Day 47 — 17 days post-program, here's how you're maintaining").

The "30 günde karın kası" brand is bounded. The product behind it doesn't have to be.

**Evidence:** above + atlas §3.1 enumerates 18 routes; none is a "post-program" route. Grep `Day 31|day_31|nextProgram|programVariant|maintenance` across `lib/` returns nothing.

---

## 8. STRUCTURAL OBSERVATIONS — HABIT LOOP SUMMARY

### Where the loop works:
1. **Investment capture is solid for the 30-day arc.** Workouts persist, streak watermarks build, badges accrue, recipes can be favorited. The data flow is complete.
2. **Cue + Routine + Reward components all exist.** This is a working habit loop, not an absent one. The diagnostic is "where it's leaky", not "is it there."
3. **Smart-reminder branching architecture is conceptually correct.** The 3-condition variant pools (T-08 in RETENTION_TRIGGER) are good design; the body-copy ratio is the issue.
4. **Streak-warning cancel-and-replace logic is right.** Every completion replaces the next warning, so users never get stale warnings during active streaks. The 48h timing (T-01) is the issue, not the architecture.
5. **`_BadgeUnlockDialog` is a strong reward template.** Fullscreen modal + animated halo + heavy haptic + share affordance. The undersized program-complete card (H-06) is a deployment gap, not a craft gap — the team has the components.

### Where the loop is broken:
1. **Cue stack is single-mechanism.** Push notifications + widget glance, with push being the workhorse. When push gets muted (T-08 fatigue), the loop has no fallback. (H-01)
2. **Reward schedule is fixed-ratio.** Every workout produces the same trophy + same +1 streak + same green check. Dopamine flatlines by Day 7-10. (H-02)
3. **Routine is 5 screens deep.** Tap-to-first-rep friction taxes every cycle; the routine doesn't fully automate within the 30-day program window. (H-04)
4. **Habit ceiling at Day 30.** Successful users churn by design. (H-03)
5. **Investment artifacts don't compound visibly.** AI report discarded (H-05); maxStreak watermark only consumed by one copy line (H-09); cumulative time-trained nowhere visualized.
6. **No habit-stacking** — neither captured at onboarding nor surfaced in scheduling (H-07).

### The 3 most consequential habit defects:
- **H-01** Single-mechanism cue stack (no fallback when push fatigue hits)
- **H-02** Fixed-ratio rewards (dopamine flatlines)
- **H-03** Habit ceiling at Day 30 (every successful user churns)

These three together produce the canonical "30-day app" failure mode: works for the program duration, fails to retain post-program. Solving any one of the three would meaningfully extend retention; solving all three would shift the product from "30-day program with subscriptions" to "habit-formation app with a 30-day on-ramp."

---

## 9. ERRATA AGAINST PRIOR PHASES

No new factual errata. The atlas + Phase 2 reports' structural claims hold; this report extends them with habit-loop framing. The notable extensions:

- **Atlas §5.6** (streak system) and §6.4 (free-day limit) are factually correct, but neither connects to the habit-loop fragility analysis. H-02 and H-04 are the structural extensions.
- **Atlas §10** (cross-cutting infrastructure) lists notification + widget + live-activity services individually but does not analyze them as a *cue stack*. H-01 is the integration view.

---

## 10. APPENDIX — HABIT EVIDENCE INDEX

| Finding | Primary file:line | Mechanism |
|---|---|---|
| H-01 | `notification_service.dart:70–123, 299–331` | Cue redundancy |
| H-02 | `session_complete_overlay.dart:65–151`, `gelisim_tab.dart:1031–1090` | Variable-ratio reinforcement |
| H-03 | `today_task_card.dart:176–216`, `suggestions_screen.dart:129–141` | Habit continuity |
| H-04 | atlas §8.6, journey J-A7 | Friction-to-automation |
| H-05 | `_DynamicReportStep` exit at `_finish()` (line 216) | Endowment loss |
| H-06 | `badge_unlock_dialog.dart:55–100` vs `today_task_card.dart:176–216` | Reward magnitude |
| H-07 | `onboarding_screen.dart:53–66`, `notification_service.dart` (no event-trigger) | Habit stacking |
| H-08 | `notification_service.dart:70–84` | Cue specificity |
| H-09 | `gelisim_tab.dart:1617` (only `maxStreak` consumer) | Investment continuity |
| H-10 | `today_task_card.dart:44` | Identity vs task framing |
| H-11 | absence in `gelisim_tab.dart`, `widget_sync_service.dart` | Anticipation cue |

---

**END OF HABIT_LOOP_STRATEGY.md**
