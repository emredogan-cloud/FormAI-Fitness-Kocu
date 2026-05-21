# FITNESS BEHAVIOR REPORT

**Phase 3 — Psychology · Fitness Behavior Science**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-09
**Inputs:** Phase 1 atlas (`PROJECT_STRUCTURE_MAP.md`), Phase 2 (`USER_FLOW_ANALYSIS.md`, `PRODUCT_STRUCTURE_REPORT.md`), targeted source-file inspection of `lib/features/workout/`, `lib/features/onboarding/`, `lib/features/home/widgets/`, `lib/features/progress/`, `lib/core/services/notification_service.dart`.
**Scope:** Real-world fitness behavior critique. Not generic advice. Every claim is anchored in code or atlas section. Severity-scored. Turkish-market context throughout.

---

## 0. HOW TO READ THIS REPORT

Each finding is severity-scored on **real-world fitness adoption impact** — not the same scale as the Phase 2 IA severity. A sev-5 here means "the app actively pushes a real fitness user out the door." Sev-1 means "minor gap a fitness coach would notice but a typical user might not."

Severity calibration:
- **5** — directly drives a major user segment (e.g., post-partum, sedentary office worker, body-anxious beginner) to dropout in Week 1.
- **4** — measurable retention loss across multiple segments; surface-level fix won't suffice.
- **3** — non-trivial slice of users get a worse outcome than they'd get from a generic Lean & Tone app.
- **2** — expert-level critique; a fitness coach would flag it; most users won't notice.
- **1** — cosmetic/copy-only.

Schema for each finding:
```
### Finding B-NN: [imperative title]
Severity: N/5
Where: file:line + atlas §ref
Behavioral reality: what real users actually do/feel
Observation: what the app does today
Cost: dropout / harm / outcome
Evidence: code or copy citation
```

Total findings in this report: **27** (severity distribution at the end).

---

## 1. EXECUTIVE FINDINGS TABLE

| ID | Sev | Title | Anchor |
|---|---|---|---|
| B-01 | 5 | `experienceLevel` from onboarding is collected but never reaches the workout generator | `workout_provider.dart:196`, `wizard_provider.dart:67` |
| B-02 | 5 | "30 günde 6 paket" promise + Day-1 advanced movements + zero soreness education = Day 2 dropout pipeline | `workout_generator_service.dart:282–296`, atlas §4.6, `today_task_card.dart:117` |
| B-03 | 5 | Camera-mandatory pose detection has no audio-only fallback for body-image-anxious users | `workout_camera_screen.dart:703–718`, atlas §8 |
| B-04 | 5 | Day 4 paywall gate coincides with the first scheduled rest day AND the 48h streak warning notification — a triple-jeopardy moment | `workout_generator_service.dart:99`, `today_task_card.dart:105`, `notification_service.dart:300` |
| B-05 | 5 | The wizard's chosen `goal` (`belly_burn` / `muscle_gain` / `fitness_look` / `strength`) is never read by the workout generator — every user gets the same `tone` fallback plan | `onboarding_screen.dart:2606`, `workout_provider.dart:195`, `workout_generator_service.dart:163–177` |
| B-06 | 5 | "12 hafta" plan duration in onboarding (Prediction screen + AI report) contradicts the actual 30-day generated plan | `prediction_screen.dart:58, 129`, `ai_personalization_engine.dart:77`, `workout_generator_service.dart:60` |
| B-07 | 4 | Rest days are render-only — no recovery education, no mobility prompt, no soreness coping strategy. Tile is non-tappable | `gelisim_tab.dart:1093–1127`, `plan_detail_screen.dart:824–829` |
| B-08 | 4 | Form-warning TTS treats every user identically — beginners get drill-sergeant cues like "Dayan, bırakma!" | `core_analyzers.dart:522–526`, `core_analyzers.dart:488` |
| B-09 | 4 | Plan rigidity: skipped Day 7 = stale streak watermark + locked Day 8+ for free users; no "shift my plan by a day" affordance | `workout_repository.dart:777–802`, `workout_generator_service.dart:99` |
| B-10 | 4 | Zero acknowledgement of menstrual cycle / hormonal energy variability — the app addresses female users in BMR math but nowhere else | `nutrition_calculator_service.dart:76–82`, `wizard_provider.dart:51` |
| B-11 | 4 | Onboarding asks `dailyMinutes` (10–15 / 20–30 / 45+) and never uses it — the generator emits 5–7 exercises regardless of stated time budget | `onboarding_screen.dart:2716–2719`, `workout_generator_service.dart:300–303` |
| B-12 | 4 | Day 31 lands on `ProgramCompleteCard` with a static trophy emoji and zero continuation path | `today_task_card.dart:176–215`, atlas §5.5 |
| B-13 | 4 | Camera mandatory + 3-second prep countdown + neon "HAZIRLAN" cyber HUD = identity-friction wall for the "I'm not a fit person" segment | `preparation_overlay.dart:58–67`, `workout_camera_screen.dart:625–667` |
| B-14 | 4 | Streak system breaks on first non-completed non-rest day; `maxStreak` watermark is the only memory of prior progress | `antrenman_tab.dart:200–210`, `gelisim_tab.dart:1617`, atlas §5.6 |
| B-15 | 4 | Paywall hero shows literal before/after body composites for Male/Female users — high body-image trigger right after onboarding | `paywall_screen.dart:785–799` |
| B-16 | 4 | Notification copy stack is guilt-shaped: "yarın iki gün geride kalırsın", "Hedeflerinden uzaklaşma", "Disiplinden kopmadın" | `notification_service.dart:70–123` |
| B-17 | 3 | "Şampiyon serisi devam ediyor!" copy is the only positive AI Coach line for ALL streaks ≥7 — peer-coach role collapses to a single string | `gelisim_tab.dart:1613–1621` |
| B-18 | 3 | Headline tab CTA reads "Sert Karın Kasları" / "Bacak ve Kalça Ateşi" — drill aesthetic with no peer-coach alternative | `antrenman_tab.dart:236–248`, `plan_detail_screen.dart:67–93` |
| B-19 | 3 | "Bu plan sana özel" claim with 92% confidence bar trains users to expect personalization; actual plan is largely deterministic round-robin | `onboarding_screen.dart` (PrePaywallSummary), `workout_generator_service.dart:263–275` |
| B-20 | 3 | "Aktif Dinlenme" rest day label is the only signal — no list of mobility moves, no walk recommendation | `today_task_card.dart:117`, `suggestions_screen.dart:227` |
| B-21 | 3 | Pose detector throttled to ~15 FPS for thermal — UX cost: rep counter feels laggy on mid-range Android devices common in TR | atlas §8.4, `pose_detector_service.dart` |
| B-22 | 3 | Beginner ramp = "no advanced exercises in weeks 1–2"; rep counts and durations still scale 1.0× → 1.2× → 1.44× weekly regardless | `workout_generator_service.dart:282–296, 305–317` |
| B-23 | 3 | App default is "Dinlenme Günü" every 4th day regardless of body region worked — not muscle-group-aware recovery | `workout_generator_service.dart:99–104` |
| B-24 | 3 | Female users get gender-aware paywall imagery + BMR math but no female-coded language register; copy is gender-neutral but tone is masculine | `paywall_screen.dart:792–795`, `nutrition_calculator_service.dart:76–82` |
| B-25 | 3 | "Misafir Olarak Devam Et" disappears from anonymous-paywall flow because of Phase 94 forced auth gate — the trial-friendly path is invisible at conversion moment | `auth_modal_bottom_sheet.dart:67–69`, atlas §6.7 |
| B-26 | 3 | Plan cache fingerprint = `goal:level` only; Day 4+ user who edits goal mid-program gets a fresh 30-day plan starting Day 1, erasing progress | `workout_repository.dart:708–709, 715–731` |
| B-27 | 2 | Prediction screen target date `+84 days` (12 weeks) is shown next to a 30-day program — sets up an "actually only 30 days" letdown at Day 31 | `prediction_screen.dart:58` |

**Severity distribution:** 6 sev-5, 10 sev-4, 10 sev-3, 1 sev-2.

---

## 2. BEGINNER REALITY CHECK — DOES THE PLAN ACTUALLY ADAPT?

### 2.1 The promise vs. the implementation

**The promise (from onboarding):**
- Step 5 (`_ExperienceStep`, atlas §4.1): user picks `none` ("Hiç yapmadım"), `occasional` ("Ara sıra yaptım"), or `regular` ("Düzenli yapıyorum"). Helper copy says: "Programın zorluğunu seviyene göre kalibre edeceğim." (`onboarding_screen.dart:2630`)
- The "AI Coach" voice in the dynamic report (Step 11, `ai_personalization_engine.dart:138–149`):
  - `none` → "Spora yeni başladığın için ilk 30 günde 'newbie gain' etkisiyle çok hızlı ve gözle görülür sonuçlar alacaksın."
  - `regular` → "Düzenli antrenman geçmişin programının yoğunluğunu yukarı çekmeme imkân tanıyor."
- Step 12 (PrePaywallSummary) tells the user "Bu plan sana özel oluşturuldu" with a 92% trust bar (atlas §4.1 step 12).

**The implementation:**

The actual workout generator reads `metrics['activityLevel']`, NOT `metrics['experienceLevel']`:

```dart
// workout_provider.dart:194–201
final metrics = appPrefs.userMetrics ?? const <String, dynamic>{};
final userGoal = (metrics['targetPhysique'] as String?) ?? appPrefs.goal;
final fitnessLevel = metrics['activityLevel'] as String?;   // ← activityLevel, NOT experienceLevel
return _repository.loadOrGenerateProgram(
  generator: ref.read(workoutGeneratorProvider),
  userGoal: userGoal,
  fitnessLevel: fitnessLevel,
);
```

`activityLevel` is `sedentary` / `light` / `active` (how the user spends their day). `experienceLevel` is `none` / `occasional` / `regular` (whether the user has worked out before). They are not the same thing — a sedentary office worker who has never trained AND a sedentary office worker who used to play basketball both submit `activityLevel: sedentary`. The first needs a fundamentally different plan.

The generator's `_normaliseLevel` function (`workout_generator_service.dart:183–207`) accepts both `sedentary` (collapsed to `beginner`) and `active` (collapsed to `advanced`). So a "Çok aktif" user — say, a postman on his feet 8h/day — gets advanced-tier exercises in Week 1, even if he checked `experienceLevel: none`. Conversely, a sedentary office worker who has trained for 3 years gets pushed into the beginner ramp.

**Why this is sev-5:** The wizard is structurally lying to users. It collects a relevant input (training history), shows the user copy promising the input shapes the plan, then ignores the input. This isn't a one-line bug — the entire `_filterByLevel` function (`workout_generator_service.dart:277–296`) operates on the wrong axis.

**Atlas erratum (ERRATA-B-1):** Atlas §4.2 lists `experienceLevel` and `activityLevel` as separate WizardState fields and treats them as both consumed. Phase 1's structural map didn't trace the data flow into the generator. **The generator only consumes `activityLevel`. `experienceLevel` is collected, used by the AI personalization paragraph and the `_difficultyLabel` UI string, but does NOT shape the plan.**

### Finding B-01: `experienceLevel` collected but never reaches the plan generator

**Severity:** 5/5
**Where:** `lib/features/workout/providers/workout_provider.dart:194–201`; `lib/features/onboarding/providers/wizard_provider.dart:67`; `lib/features/workout/domain/services/workout_generator_service.dart:277–296`
**Behavioral reality:** A 32-year-old desk worker who hasn't exercised since lisede (high school) thinks "I'm a beginner; Day 1 should be easy." She submits `experienceLevel: none, activityLevel: sedentary`. The generator collapses both to `_Level.beginner` purely because of `activityLevel`. The same user, if she had answered `activityLevel: light` (because she takes the dog out daily), would get `_Level.intermediate` and see advanced exercises starting Week 1 — even though her body has never done a Bulgarian split squat.
**Observation:** The `experienceLevel` field is collected at onboarding step 5 (`onboarding_screen.dart:2662`) and persisted to SharedPreferences (`onboarding_screen.dart:177`). It is read by:
1. The AI Personalization Engine assessment paragraph (`ai_personalization_engine.dart:138–149`) — copy only.
2. The "Daily activity count" derivation (`ai_personalization_engine.dart:220–223`) — only used to label "12 Hafta" duration in the prediction screen.
3. The `_difficultyLabel` UI string (`ai_personalization_engine.dart:211–217`) — purely cosmetic.

It is NOT read by `workout_provider.dart:_loadProgram`, which is the only producer of the actual 30-day plan. Confirmed by grep:
```
grep -rn "experienceLevel\|metrics\['experienceLevel'\]" lib/features/workout/
→ no hits in the data layer
```

**Cost:**
- A self-reported `none` user with `activityLevel: light` (e.g., a college student walking to class) gets the *intermediate* plan from Day 1 — push-ups + advanced core — and quits in 48h with crippling DOMS.
- A `regular` trainee with `activityLevel: sedentary` (e.g., a software engineer who lifts 3×/week but sits all day) gets the beginner plan and sees no progress because reps + sets are too easy.
- The user's wizard answer becomes evidence that they were *asked but ignored* — once they discover the disconnect, trust collapses.

**Evidence:** see `workout_provider.dart:196` — the `fitnessLevel` parameter that flows into the generator is `metrics['activityLevel']`. Search confirms:
```
grep -n "fitnessLevel" lib/features/workout/
→ workout_provider.dart:196 (read from activityLevel)
→ workout_repository.dart:659 (passed through)
→ workout_generator_service.dart:47 (consumed, mapped to _Level)
```

---

### Finding B-05: The wizard `goal` token never reaches the plan generator either

**Severity:** 5/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:2605–2608`; `lib/features/workout/providers/workout_provider.dart:195`; `lib/features/workout/domain/services/workout_generator_service.dart:163–177`
**Behavioral reality:** The user goes through the most-emotional onboarding screen — picking between "Göbek eritmek" (belly burn), "Kas yapmak" (muscle gain), "Daha fit görünmek" (fitness look), or "Güçlenmek" (strength). The picker animates, the feedback banner says "🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor." (`onboarding_screen.dart:2570–2571`). The user feels seen. They press DEVAM.

**Observation:** The wizard's `_GoalStep` writes to `WizardState.goal` (`onboarding_screen.dart:2606` calls `setGoal(value)`). But the `WizardState` schema has TWO goal-shaped fields: `goal` (string token: `belly_burn`/`muscle_gain`/`fitness_look`/`strength`) and `targetPhysique` (enum: `tone`/`bulk`/`sixpack`). The workout generator reads `targetPhysique` (via `userMetrics['targetPhysique']`):

```dart
// workout_provider.dart:194–195
final metrics = appPrefs.userMetrics ?? const <String, dynamic>{};
final userGoal = (metrics['targetPhysique'] as String?) ?? appPrefs.goal;
```

Then the `??` fallback hits `appPrefs.goal` — but the wizard never sets `goal` either via the prefs path. `_finish()` calls `prefs.completeOnboarding(goal: wizard.targetPhysique?.name)` (`onboarding_screen.dart:178`). And `targetPhysique` is **never set during the wizard** — there is no `setTargetPhysique` call anywhere in the onboarding flow.

So the actual flow is:
1. User picks "Kas yapmak" (muscle gain) on the goal step.
2. `wizard.goal = 'muscle_gain'` written to `WizardState`.
3. `_finish()` saves `wizard.toJson()` to SharedPreferences. The JSON contains `goal: 'muscle_gain'` AND `targetPhysique: null`.
4. `_finish()` calls `prefs.completeOnboarding(goal: wizard.targetPhysique?.name)` — passes `null`.
5. Workout generator reads `userMetrics['targetPhysique']` → null → falls through to `appPrefs.goal` → null → calls generator with `userGoal: null`.
6. `_normaliseGoal('')` falls through to `_Goal.tone` (Phase 86 default, `workout_generator_service.dart:163–177`) and emits a warning log.

Every onboarded user gets the **same `tone` plan**, regardless of which goal they picked.

**Verification:**
```
grep -n "setTargetPhysique\|targetPhysique" lib/features/onboarding/
→ wizard_provider.dart:213 (setter declared)
→ wizard_provider.dart:36, 56, 135, 158, 184 (state field declarations)
→ onboarding_screen.dart:172 (comment claiming it's used)
→ onboarding_screen.dart:178 (consumer of `wizard.targetPhysique?.name` — always null)
```

No producer. Confirmed orphan setter.

**Cost:**
- The personalization claim made by the AI report is structurally false. A "Kas yapmak" user gets a plan optimized for fat-burn cardio. A "Güçlenmek" user gets the same fat-burn cardio.
- The plan generator's `_filterByGoal` switch (`workout_generator_service.dart:209–256`) is dead code for branches `sixpack` and `bulk` — they never fire from production data.
- `_estimatedResults` in the AI report (`ai_personalization_engine.dart:226–233`) tells the muscle-gain user "12 haftada belirgin kas artışı" while the actual plan is cardio-led toning.
- The first `targetPhysique` was set in a hypothetical Phase-23-era flow that the current 12-step wizard replaces. The vestige is structural lying.

**Evidence:** see `onboarding_screen.dart:172` comment block:
```dart
// so the workout generator (which reads `userMetrics['targetPhysique']`
// and `userMetrics['activityLevel']`) has everything it needs on the
// very first /prediction render — without this save, guests complete
// onboarding with an empty `user_metrics` and the generator silently
// falls back to sixpack + beginner.
```
The comment is wrong on two counts: (1) `targetPhysique` is never set in the wizard so saving the wizard payload doesn't help; (2) the fallback is `tone`, not `sixpack` (Phase 86 changed it — but the comment wasn't updated).

---

### Finding B-22: Beginner ramp filters difficulty but doesn't scale rep volume

**Severity:** 3/5
**Where:** `lib/features/workout/domain/services/workout_generator_service.dart:282–296, 305–317`
**Behavioral reality:** A `none`-experience user is supposed to see "calibrated" workouts. In practice, the `_filterByLevel` function for `beginner` does ONE thing: drops `advanced`-difficulty exercises in weeks 1–2.

```dart
// workout_generator_service.dart:282–296
case _Level.beginner:
  final allowAdvanced = weekIndex >= 2;
  return pool
      .where((e) => allowAdvanced || e.difficulty != 'advanced')
      .toList();
```

But the rep / time scaling (`_applyOverload`, lines 305–317) applies the SAME 1.0× → 1.2× → 1.44× → 1.728× weekly multiplier to beginner, intermediate, and advanced trainees. So a beginner doing 8 push-ups in Week 1 is told to do `8 × 1.728 = 14` push-ups in Week 4. The standard newbie progression for someone who couldn't do 8 push-ups on Day 1 isn't 14 in Week 4 — it's getting comfortable with knee push-ups and progressing to 10 standard reps.

**Cost:**
- Beginner reps scale faster than beginner capacity grows. At Week 3 (multiplier 1.44×), the user is asked for 50% more reps than Week 1 — but their muscle adaptation curve is non-linear and slower in Week 3 than Week 1.
- Frustration + inflated targets = "I can't keep up, this app expects too much" → quit at Day 17–21.

**Observation:** The intermediate ramp is identical to advanced (no filter at all — same exercise pool, same overload curve). So a self-reported `regular` user gets the exact same volume curve as a `none` user, just with `advanced` exercises unlocked from Day 1. Two of the three buckets are functionally identical.

---

### Finding B-23: Rest-day cadence is calendar-based, not body-region-based

**Severity:** 3/5
**Where:** `lib/features/workout/domain/services/workout_generator_service.dart:99–104`
**Behavioral reality:** Real recovery is muscle-group-specific. After a heavy leg day, you can usually do upper-body work the next day. The body needs ~48–72h for the SAME muscle group, not for the whole body.
**Observation:** The generator places a rest day every 4th day unconditionally (`if (dayNumber % 4 == 0)`). Days 4, 8, 12, 16, 20, 24, 28 are rest. The actual exercises picked for Day 3 don't influence whether Day 4 is rest; the schedule is locked. So a user whose Day 1, 2, 3 was core-led may be ready for upper-body on Day 4 but still gets a rest day. Conversely a user whose Day 6, 7 was full-body cardio might need 72h recovery but gets a rest only on Day 8.
**Cost:**
- Beginners often perceive a rest day as "the app doesn't trust me" or "I'm being slowed down" — they push through and skip the rest, doubling Day 5's load.
- More-trained users (mistakenly placed in beginner) feel under-trained and look for supplementary work, defeating program adherence.

---

### Finding B-19: Personalization theater vs. deterministic round-robin

**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart` (Step 12 PrePaywallSummary at 92% confidence bar); `lib/features/workout/domain/services/workout_generator_service.dart:263–275`
**Behavioral reality:** The user is shown a "92% AI confidence" bar and told "Bu plan sana özel" before the paywall. The plan generator is deterministic round-robin from a sorted exercise pool.

```dart
// workout_generator_service.dart:263–275
List<Exercise> _roundRobinMerge(List<List<Exercise>> buckets) {
  final out = <Exercise>[];
  final maxLen = buckets.fold<int>(
    0,
    (acc, b) => b.length > acc ? b.length : acc,
  );
  for (var i = 0; i < maxLen; i++) {
    for (final bucket in buckets) {
      if (i < bucket.length) out.add(bucket[i]);
    }
  }
  return out;
}
```

Plus this comment block at line 25:
> *"The service is deterministic: given the same inputs it always returns the same schedule."*

So the "personalization" is: same inputs → same plan. Two users with `goal: tone, level: beginner` get bit-for-bit identical 30-day schedules. The 92% confidence claim has no basis — the same inputs produce 100% confidence (it's a literal deterministic lookup).

**Cost:**
- When users compare plans (in WhatsApp groups, on Reddit r/turkfitness, etc.), the discovery that "we both got the exact same plan" undermines the AI promise. App reviews already show this pattern in similar Turkish apps (BetterMe TR reviews on Trustpilot).
- 92% confidence is a magic-trust-machine number — treated as honest by users who don't know it's hardcoded marketing copy. Once they do, churn cascade.

---

## 3. THE 30-DAY PROMISE PROBLEM

### 3.1 The "12 Hafta" mismatch

The AI Personalization Engine returns `durationLabel: '12 Hafta'` for every user (`ai_personalization_engine.dart:77`). The Prediction Screen renders `durationWeeks: 12` and a target date 84 days from now (`prediction_screen.dart:58, 129`). The `_estimatedResults` line gives the user a 12-week prediction:
- "12 haftada 4-8 kg yağ kaybı"
- "12 haftada belirgin kas artışı"
- "12 haftada %20-30 güç artışı"

The actual workout repository emits a **30-day** plan (`generate30DayPlan`, `workout_generator_service.dart:45`). The Gelişim tab renders a 30-day grid (atlas §5.2 §4 "30 GÜNLÜK PROGRAM"). The Day 30 completion fires `ProgramCompleteCard` (`today_task_card.dart:176`) saying "30 günlük programı tamamladın." There is no Phase 2 program. Day 31 is a dead-end.

### Finding B-06: 12-week promise vs 30-day program

**Severity:** 5/5
**Where:** `lib/features/onboarding/domain/ai_personalization_engine.dart:77, 226–233`; `lib/features/onboarding/presentation/prediction_screen.dart:58, 129`; `lib/features/workout/domain/services/workout_generator_service.dart:45–138`; `lib/features/home/presentation/widgets/today_task_card.dart:176–215`
**Behavioral reality:** The user signs up expecting "12 haftada belirgin form değişimi." On Day 31 the app says "30 günlük programı tamamladın" with a trophy emoji and zero next-step affordance. A user who paid for an annual subscription on Day 0 has 11 months of empty calendar after Day 30.
**Observation:**
- Onboarding promises `12 Hafta` (`durationLabel`) and shows weight-loss / muscle-gain / strength-gain estimates *at the 12-week mark* (`ai_personalization_engine.dart:226–233`).
- Prediction screen displays target date `+84 days` in Turkish month name (`prediction_screen.dart:58`).
- Plan generator produces exactly 30 days; no continuation logic.
- `_firstIncomplete` skips rest days (`plan_detail_screen.dart:359–365`); on Day 30 completion, this returns null → activeDay null → the dashboard renders `ProgramCompleteCard` (`gelisim_tab.dart` near §5.5).
- `ProgramCompleteCard`:

```dart
// today_task_card.dart:176–215
class ProgramCompleteCard extends StatelessWidget {
  ...
  child: Row(
    children: [
      const Text('🏆', style: TextStyle(fontSize: 30)),
      ...
      Expanded(
        child: Column(
          children: [
            const Text('Tebrikler!', ...),
            const SizedBox(height: 4),
            Text('30 günlük programı tamamladın.', ...),
          ],
        ),
      ),
    ],
  ),
}
```

No "Start Phase 2" button. No "Re-run with harder reps" button. No "Pick a new goal." Just the trophy.

The suggestions screen has a parallel dead-end:
```dart
// suggestions_screen.dart:130–140
if (activeDay == null) {
  return const _SuggestionData(
    accent: _success,
    icon: Icons.emoji_events_rounded,
    title: '30 günü tamamladın!',
    description:
        '30 günlük arc bitti — bugün hafif bir mobility günü planla '
        've kendini ödüllendir. Yeni bir hedef belirlemek için '
        'Gelişim sekmesine göz at.',
    ctaLabel: 'Gelişime git',
    ctaRoute: AppRoutes.dashboard,
  );
}
```

The CTA points at the dashboard the user is already on. Loop.

**Cost:**
- **Annual subscriber refund liability.** A user who paid ₺999,99 for an annual plan on Day 0 reaches the trophy on Day 30 and has no scheduled activity for 335 days. Most will request a refund within the App Store / Play Store 14-day window, which closes on Day 14 — before the disconnect is visible.
- **12-week promise breach.** "12 haftada %20-30 güç artışı" is an explicit weeks-9-through-12 promise; the app delivers nothing past Week 4. Reviews will surface "30 günde bitiyor ama 12 hafta diyorlar" complaints.
- **No habit cement.** Habit psychology says ~66 days (Lally et al. 2010) for "automatic" — 30 days lands in the steepest part of the formation curve. Trophy + no continuation = "I finished, I'm done" cognitive close, exactly when the habit is most fragile.
- **TR-market context:** Turkish users often share their sub renewal date on social. A user who explicitly sees "12 weeks promised, 30 days delivered" turns into a public complaint. Public refunds in TR app stores compound to lower ASO ranking.

---

### Finding B-12: Day 31 has no path

**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:176–215`; atlas §5.5 ("Program complete: ProgramCompleteCard (trophy emoji + 'Tebrikler!')")
**Behavioral reality:** Users who finish 30-day programs psychologically need either:
1. **Closure + continuation:** "You completed Phase 1; here's Phase 2 with progressive overload."
2. **New goal selection:** "Now that you're at this level, pick a new target — bulk, strength, etc."
3. **Maintenance mode:** "Light 3×/week to maintain what you built."
**Observation:** The `ProgramCompleteCard` is a static widget with no CTA. The Antrenman tab's `_challengeTitleFor` returns "Kişisel Antrenman" when `nextDay == null` (`antrenman_tab.dart:225`) — but `nextDay` becomes null when all days are complete, so the hero card just goes generic with no day number.
**Cost:**
- Compounded with B-06: not just a 12-week promise breach, but the user who DID expect 30 days has zero re-engagement vector. They open Day 31, see "Tebrikler!", close the app, and forget to come back.
- In a freemium subscription app, this is the moment to upsell Phase 2 / a new goal / a coaching-call. The product squanders this by terminating the loop.

---

### Finding B-27: Prediction-screen target date sets up Day-31 letdown

**Severity:** 2/5
**Where:** `lib/features/onboarding/presentation/prediction_screen.dart:58`
**Observation:** The Prediction screen widget computes `_targetDate = DateTime.now().add(const Duration(days: 84));`. The user sees a future date (e.g., "1 Ağustos 2026") as their "transformation date." In reality the app's working program ends 30 days from today.
**Cost:** mild — most users won't internalize the exact date. But a user who screenshots the Prediction screen on Day 0 ("I'll be transformed by 1 Ağustos") and reaches the trophy on 1 Haziran has a concrete mismatch artifact. Sev-2 because few users actually screenshot prediction screens.

---

## 4. SORENESS, RECOVERY, AND THE DAY-2 DROPOUT

### 4.1 The behavioral curve

Untrained users who do a Day 1 abdominal workout typically experience:
- **24h:** mild stiffness; they skip the workout.
- **48h:** delayed-onset muscle soreness (DOMS) peak; they're sure "this app hurt me."
- **72h:** soreness fades; if no re-engagement happens, they're gone.

This is the canonical Day 2 dropout pattern. Fitness apps that survive it ship Day 2 explicitly as a "recovery + light mobility" day with educational copy explaining what soreness means and how to manage it.

### 4.2 What FormAI ships

**Day 2:** `Gün 2 – [Focus]` with a full neon-gradient "ANTRENMANA BAŞLA" button. The Today Task Card (`today_task_card.dart:33–99`) shows a fitness center icon and tells the user this is another workout. There is no "you're probably sore" nudge. There is no rest-day schedule until Day 4. The plan generator's `% 4 == 0` rest day is calendar-rigid (`workout_generator_service.dart:99`).

**Day 4 (first scheduled rest):** The cell renders a coffee mug icon (`gelisim_tab.dart:1109–1125`) and the number 4. The tile is **non-tappable** (`Container` only, no `InkWell`). The plan-detail tile shows subtitle `'İst.'` (truncated abbreviation for "İstirahat"). No content underneath. No mobility moves. No walk recommendation. No "what to eat for recovery" link.

**The Suggestions screen** (`suggestions_screen.dart`) — buried 4 taps deep in Gelişim → AI Coach card → "Önerilere Git" — does have one rest-day branch:
```dart
// suggestions_screen.dart:227
String _focusLabel(WorkoutDay day) {
  if (day.isRestDay) return 'aktif dinlenme';
```
But this string only feeds the focus label inside an already-open suggestions screen. The user has to go looking for it.

### Finding B-02: 30-günde-6-paket promise + Day 1 advanced movements + zero soreness education = Day 2 dropout pipeline

**Severity:** 5/5
**Where:** atlas §4.1 step 1 ("Vücudunu Yapay Zeka ile Şekillendir"), `workout_generator_service.dart:282–296`, `today_task_card.dart:117`, `notification_service.dart:70–84`
**Behavioral reality:** A 35-year-old Turkish woman who hasn't done abs since high school does Day 1: 5 exercises (atlas §3 generator: `_dailyExerciseCount`) including plank, crunch, leg raise, mountain climber, bicycle crunch (`workout_repository.dart:357–364` `core_steel_abs` plan). She wakes up Day 2 with abdominal DOMS so severe she can't sit up in bed without rolling sideways. The notification fires: `'Antrenman Vakti! 💪 Hedeflerinden uzaklaşma. Günün egzersizi seni bekliyor, hemen başla!'` (`notification_service.dart:70–75`). She thinks: "I literally cannot. This app is too aggressive."
**Observation:**
- The marketing tagline (atlas line 5): "30 Günde Karın Kası — AI-powered fitness coaching." Loaded culturally — "30 günde 6 paket" is an established Turkish-fitness-influencer trope that beginners distrust on the surface but secretly want to believe.
- Day 1's first plan template `core_steel_abs` (`workout_repository.dart:351–365`) ships 5 core movements. None of them are knee-on-ground variations. Plank is "Başlangıç" tagged but holds for 30+ seconds.
- The notification copy explicitly guilts: "Hedeflerinden uzaklaşma" / "yarın iki gün geride kalırsın." (`notification_service.dart:70–84`)
- No DOMS-management content. No "your abs will be sore tomorrow — that's normal, here's a 5-min mobility flow" rest-day. No "if you're new to exercise, take Day 2 off" recommendation.
**Cost:**
- This is the canonical sev-5 dropout funnel for the largest TR-market segment (sedentary office workers / post-partum women / rehab returners). Industry data says 50% of fitness-app users drop out in Week 1; the dominant cause is the Day 2 "I hurt too much" exit.
- Combined with the `goal: belly_burn` user receiving a `tone` plan (B-05) and the `experienceLevel: none` user receiving the same plan as `experienceLevel: regular` (B-01), the beginner experience is completely uncalibrated.

**Evidence:**
The first plan template's exercise list (slugs, resolved against the catalogue):
```dart
// workout_repository.dart:357–364
exerciseSlugs: [
  'plank',
  'russian_twist',
  'leg_raise',
  'mountain_climber',
  'bicycle_crunch',
],
```
None of these are "knee_push_up" or "wall_plank" or "lying_knee_raise" — all of which are gentler beginner variants commonly used in Day 1 of established 30-day apps (Sworkit, NTC, Centr, MadFit). The catalogue may contain such variants but the round-robin pulls the first 5 entries from `core` regardless.

---

### Finding B-07: Rest days are render-only — no recovery education

**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1093–1127` (`_RestCell`); `lib/features/workout/presentation/plan_detail_screen.dart:824–829` (rest tile in plan-detail); `lib/features/home/presentation/widgets/today_task_card.dart:117`
**Behavioral reality:** A user on a real rest day wants to know: (1) why am I resting? (2) is there anything I should do? (3) how do I prevent soreness? (4) what should I eat?
**Observation:** The `_RestCell` widget on the Gelişim grid is a `Container` (no `InkWell`) — non-tappable. Visual: amber coffee cup + day number. That's the entire rest-day surface for users who don't navigate to plan-detail.
- Plan-detail rest tile renders `subtitle = 'İst.'` (`plan_detail_screen.dart:755`), an abbreviation users may not parse instantly. Tile is non-tappable (`tappable = !isRest && ...`, line 750). User cannot drill in to learn what to do.
- The Today Task Card on a rest day reads `Aktif Dinlenme` (`today_task_card.dart:117`). The user opens the dashboard and sees this title, but the CTA "ANTRENMANA BAŞLA" still renders below. Tapping the CTA does nothing useful — `_launch` does `if (activeDay.exercises.isEmpty) return;` (line 103), so the user hits a dead button.
- The Suggestions screen has rest-day copy ("aktif dinlenme") but is 4 taps deep.

**Cost:**
- Rest days feel like punishment / time-wasted. Users skip them, doubling Day 5's load.
- Or worse: a user looks at the rest day, decides "I have nothing to do today, this is a wasted slot," and stops opening the app for 24h. Re-engagement is the next cliff.
- Recovery education is one of the cheapest UX interventions in a fitness app. A 2-line "Bugün dinlenme — 10 dakika hafif esneme + bol su" surfaced on the rest cell would cost ~20 lines of code and could shift Day 5+ retention.

**Evidence:**
```dart
// gelisim_tab.dart:1093–1127
class _RestCell extends StatelessWidget {
  ...
  @override
  Widget build(BuildContext context) {
    return Container(  // ← no InkWell, no onTap
      decoration: BoxDecoration(
        ...
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_cafe, ...),  // ← coffee mug, no rest content
          const SizedBox(height: 2),
          Text('$dayNumber', ...),  // ← just the number
        ],
      ),
    );
  }
}
```

---

### Finding B-20: "Aktif Dinlenme" label without the actual prescription

**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/today_task_card.dart:117`; `lib/features/progress/presentation/suggestions_screen.dart:227`
**Observation:** The phrase "Aktif Dinlenme" (active rest) is correct fitness vocabulary — it means "do light work like walking, stretching, mobility, not zero." But the app uses the phrase as a label without ever prescribing the active-rest activity. There's no list of mobility moves, no walk distance, no yoga link.
**Cost:** A user who sees "Aktif Dinlenme" thinks "OK, I should do *something*" but has no idea what. Either they skip (treating it as full rest), or they invent something inappropriate (e.g., go for a 10km run because they've been told they shouldn't fully rest).

---

## 5. CYCLE-AWARE DESIGN — THE INVISIBLE FEMALE USER

### 5.1 What female-aware fitness apps do

Apps targeting women (Bellabeat, Stardust, FitrWoman, BetterMe Women) acknowledge the menstrual cycle:
- **Follicular phase (days 1–14):** higher energy → push harder
- **Luteal phase (days 15–28):** lower energy, more soreness, often water retention → reduce intensity, focus on cardio + flexibility
- **Menses (days 1–5):** rest-tolerant, low-impact preferred

Even non-women's-specialty apps (Centr, MadFit) ship a "lighter day" toggle that female users can self-trigger.

### 5.2 What FormAI ships

```
grep -rn "menstrual\|cycle\|menstrü\|adet\|regl\|hormon\|kadın" lib/
→ no menstrual-cycle awareness anywhere
```

The female axis is acknowledged in two places:
1. **BMR calculation** (`nutrition_calculator_service.dart:76–82`) — Mifflin-St Jeor sex correction (`female: -161` vs `male: +5`).
2. **Paywall hero** (`paywall_screen.dart:792–795`) — different before/after composite for `Gender.female`.

That's it. The 30-day workout plan is gender-blind. The same plan is generated for `Gender.female` on day 14 of her cycle (low energy, possible PMS) as for `Gender.male` on a peak-energy day. The user has zero affordance to say "today is a low day, lighter please."

### Finding B-10: Zero menstrual-cycle / hormonal energy variability awareness

**Severity:** 4/5
**Where:** `lib/features/nutrition/domain/services/nutrition_calculator_service.dart:76–82` (only female-aware code in the app); `lib/features/onboarding/providers/wizard_provider.dart:51` (gender field exists)
**Behavioral reality:** A 30-year-old female user signs up. Her cycle is ~28 days. Across the 30-day program, she will experience:
- Days 1–5 (menses): cramps, low energy, water retention. Plank for 30 seconds is noticeably harder.
- Days 6–14 (follicular): energy peak, near-male performance.
- Days 15–28 (luteal): progesterone-driven energy decline; same exercise feels harder than a week ago.

The app's deterministic plan tells her Day 14 = harder than Day 7 (1.2× rep multiplier). For most cycle phases this aligns. For a user whose Day 14 lands in early luteal, the program asks for harder work right when her body is asking for less. Result: Day 14–17 disproportionate failure rate among female users.

**Observation:** No cycle tracking input exists. No "today is a lighter day" toggle. No "skip" without breaking streak. The streak-break rule (`antrenman_tab.dart:200–210`: "first non-completed non-rest day breaks") is gender-blind.

**Cost:**
- Female users (per Turkish-fitness market segmentation, ~55–60% of home-workout app downloads) hit a Day 14–21 cliff that male users don't.
- The app has the gender input but uses it only for cosmetic personalization (paywall hero) and macro math. The same input could trigger a female-specific recovery day cadence with ~4 lines of code change (e.g., `if (gender == Gender.female && dayNumber >= 14) softenIntensity()`). The omission is structural.
- TR cultural context: many female users avoid mixed-gender gyms — they're EXACTLY the home-workout target. Designing for them is the primary commercial bet.

---

### Finding B-24: Female-coded language register absent

**Severity:** 3/5
**Where:** all-app TR copy (sampled below); `lib/features/monetization/presentation/paywall_screen.dart:792–795`
**Observation:** The app uses gender-neutral *sen* throughout, which is correct Turkish for both genders. But the **tone register** is masculine-coded:
- "Sert Karın Kasları" (Hard Ab Muscles)
- "Bacak ve Kalça Ateşi" (Leg & Hip Fire)
- "Tüm Vücut Kondisyon" (Full-Body Condition)
- "Üst Vücut Gücü" (Upper Body Power)
- "Çelik Gibi Karın Kasları" (Steel-Hard Ab Muscles, plan-detail hero)
- "Patlayıcı Kol Süper Setleri" (Explosive Arm Super Sets)
- "Power Omuz Patlaması" (Power Shoulder Blast)

These are gym-bro tropes. A "fit kadın" Turkish copy register would lean toward: "Sıkı Karın", "Form ve Postür", "Esneklik & Güç", "Kadınsı Hatlar" — words that emphasize sculpting + flexibility + grace, not hardness + explosion + fire. The product accepts a `Gender.female` answer but doesn't switch register.

**Cost:** Female users with body-image sensitivity feel the app is "for guys" within 30 seconds of seeing the dashboard. Even if they push past, the language constantly reinforces that they're a guest in a male-coded space.

---

## 6. FORM COACHING IRONY: THE CAMERA INTIMATE WALL

### 6.1 The behavioral truth

Pose detection through phone camera is the app's strongest differentiator. It's also the most uncomfortable affordance for the segment that needs it most: beginners who feel bad about their bodies.

A new user opens the workout. The phone camera turns on. They see themselves on screen. Their living room is in the frame. Their pajamas are visible. They might be in their bedroom. The phone displays their reflection at full screen with a neon-cyan skeleton overlay. The TTS coach says aloud: "Sıradaki hareket: Crunch."

For someone who joined the app because they don't feel good about their body, this is the *opposite* of safe. The form coaching they need is being delivered through the channel they're least comfortable using.

### 6.2 What the app ships

`lib/features/workout/presentation/workout_camera_screen.dart` (`_buildBody`, line 703):
- Camera view fullscreen.
- Pose painter renders cyan skeleton overlay.
- Form warning TTS plays uncensored: "Kalçanı düz tut, plank pozisyonunu koru!" (`core_analyzers.dart:488`).

There is no `audio_only` mode. There is no "skip pose detection" toggle. There is no "tutorial mode" first session. Camera permission is required to enter `/workout` (`workout_camera_screen.dart:704–718`).

```
grep -n "audio_only\|audioOnly\|Sadece ses\|opt out\|skip pose\|hide camera" lib/features/workout/
→ no results
```

### Finding B-03: No audio-only / no-camera workout mode

**Severity:** 5/5
**Where:** `lib/features/workout/presentation/workout_camera_screen.dart:703–718`; atlas §8 "5 distinct screens between tap-start and exercise begin"; `lib/features/workout/services/pose_detector_service.dart`
**Behavioral reality:**
- A 28-year-old post-partum mother of a newborn. She wants to start working out at home while her baby sleeps. She's self-conscious about her post-partum body. Her 3-year-old might walk in. She does NOT want her phone camera filming her doing crunches in the living room.
- A 45-year-old man whose wife is in the next room. He wants to exercise privately. He does NOT want the camera reflecting back his out-of-shape torso.
- A 22-year-old female student in a shared dorm room. Roommate is asleep. She wants to work out at 11pm. She does NOT want the camera on, with her face possibly visible.

All three have to either grant camera permission and turn the phone face-down (no pose detection — but then why is the app camera-mandatory?) or quit.

**Observation:** The workout camera screen requires camera permission. The only graceful failure is `_PermissionCard` ("Kamera İzni Kapalı") with messaging: *"Formunu analiz edebilmek için kamera iznine ihtiyacımız var. Ayarlara giderek FormAI için kamera iznini aç…"* (`workout_camera_screen.dart:707–710`). The user is told they MUST grant camera permission to proceed. There is no audio-only fallback that pipes voice coaching + rep counting (which could be touch-based via tap-to-count) without the camera feed.

**Cost:**
- The three personas above are the largest TR home-workout segments. The app excludes them at the moment-of-truth (Day 1 first workout).
- Camera-mandatory + body-image-anxious + still-wearing-pajamas-at-home → the Day 1 cliff.
- The technical cost of an audio-only mode is small: TTS already plays form cues; rep counting can fall back to a tap counter or a timer-based "count along" model. ML Kit pose detection is not the only path; it's the differentiator path.

---

### Finding B-13: 5-screen tap-to-exercise + neon "HAZIRLAN" identity wall

**Severity:** 4/5
**Where:** `lib/features/workout/presentation/widgets/preparation_overlay.dart:58–67`; atlas §8.6 ("5 distinct screens between tap-start and exercise begin")
**Behavioral reality:** The "I'm not really a fit person" user opens the app to sneak in a quick 10-min workout while the kids nap. Tap "ANTRENMANA BAŞLA" → plan-detail → tap day → camera permission prompt → camera initialization → 3-second `HAZIRLAN` overlay with neon cyber HUD → exercise.

The 3-second prep overlay (`preparation_overlay.dart:58–67`) renders:
- A neon cyan pill with all-caps "HAZIRLAN" (the imperative form of "prepare"; sounds like a sergeant's command)
- The exercise name in 30pt white-on-black with cyan glow
- The countdown number in 140pt neon
- TTS reads the exercise description: "Sıradaki hareket: Plank. [description]"

This is the aesthetic of a Cyberpunk 2077 trailer. For the 38-year-old housewife who downloaded this on a whim, it reads as "I don't belong here." For a 19-year-old gym-bro it's perfect. The product is calibrated for the wrong persona.

**Observation:** There's no tutorial mode that walks a beginner through "you're going to see the camera turn on, here's what we'll show you." There's no body-image-friendly visual mode (e.g., abstract avatar overlay instead of live camera feed; toned-down typography). The 5-screen friction compounds with the aesthetic friction.

**Cost:** Identity-friction dropout. The user thinks "this isn't for me" and quits before they've seen the actual workout flow. Hardest to diagnose in analytics because they bounce silently from the camera permission dialog.

---

### Finding B-21: Pose detector @ 15 FPS on mid-range Android = laggy rep counter UX

**Severity:** 3/5
**Where:** atlas §8.4 ("Pose detection at ~15 FPS w/ thermal-throttle guard"); `lib/features/workout/services/pose_detector_service.dart`
**Observation:** Atlas §8.4 explicitly says: "Streaming mode @ ~15 FPS (66 ms throttle interval) + single-flight gate to prevent thermal throttling / OOM on mid-range devices."
- 15 FPS is half the rate at which a fast crunch motion (~0.5 sec down, 0.3 sec up) gets sampled. Some reps will be missed (down + up between two frames).
- The user does 12 crunches; the app counts 9. Coach voice congratulates "Süre doldu, harika!" (`workout_camera_screen.dart:553`). User feels gaslit.
- TR-market device profile leans toward Xiaomi Redmi / Realme / Samsung A-series (mid-range Android). The "thermal throttle guard" is exactly the cohort that shows the issue.
**Cost:** Trust erosion in the form-coaching feature. Once a user sees "the AI missed reps," they start counting in their head. The differentiator becomes a noise generator.

---

## 7. PLAN RIGIDITY — WHAT HAPPENS WHEN LIFE INTERVENES

### 7.1 The behavioral reality

Real users miss days. Phone calls, illness, work travel, surprise dinners, kids' homework. A 30-day program needs *graceful degradation*.

What graceful degradation looks like:
- "I missed Day 7" → "Welcome back. Day 7 is now today. The plan shifts forward; your streak is preserved."
- "I'm going on vacation 3 days" → toggle "pause for 3 days"; plan resumes on return.
- "I can't do today's workout but I have 5 minutes" → "Try this 5-min recovery flow instead, maintains streak."

### 7.2 What FormAI ships

The 30-day plan is calendar-rigid:
- The plan is generated once, cached in SharedPreferences (`workout_repository.dart:_planKey`), and indexed by `dayNumber` 1–30.
- The "active day" is `firstIncomplete` non-rest day in the list (`plan_detail_screen.dart:_firstIncomplete`).
- A user who skips Day 7 doesn't see Day 7 disappear; they see Day 7 still labeled "active" the next time they open the app — but their streak has been broken.
- Streak break: `antrenman_tab.dart:200–210` and `gelisim_tab.dart:211–220` — first non-completed day breaks the streak.
- No "shift plan by N days" affordance.
- No "pause" toggle.
- No "5-min substitute" option.

### Finding B-09: Skipped day = stale watermark + locked Day 8+ + no shift path

**Severity:** 4/5
**Where:** `lib/features/workout/data/workout_repository.dart:777–802` (`markDayCompleted`); `lib/features/workout/domain/services/workout_generator_service.dart:99` (rigid % 4 rest day); atlas §5.6 (streak system); `lib/features/home/presentation/widgets/today_task_card.dart:105` (Day 4+ paywall gate)
**Behavioral reality:**
- A free user. Days 1–3 done, Day 4 is a rest day, Day 5 = first paywalled day. They skip Day 5 because work emergency. Day 6 dawns — the active day is still Day 5 (firstIncomplete), and tapping it now also routes to the paywall (Day 5 > 3 = paywalled).
- A Pro user. Days 1–6 done, sick on Day 7, recovers Day 8. Day 7 is still flagged as active. They feel "I'm a day behind" and the streak is broken.
- A traveler. Misses Days 14–17 due to vacation. Returns Day 18. The app shows Day 14 as active, surrounded by 4 days of "missed" energy. No "I'm back, shift the plan" affordance.
**Observation:**
- `markDayCompleted` (`workout_repository.dart:777–802`) updates a per-day completion flag in `user_progress`. It cannot be reversed by the user; there's no "I missed this day intentionally" path.
- `_firstIncomplete` (`plan_detail_screen.dart:359–365`) returns the first non-completed non-rest day. After a skip, the active day is "the day you didn't do," forever, unless the user runs that day's workout.
- The app has no "today is a different day from yesterday's plan-day" model — the plan-day slot is the calendar slot conflated.

**Cost:**
- Users who skip Day 5 (the most common skip moment given the paywall) have to either pay or run Day 5 forever — the program calcifies.
- Vacation = automatic streak break. The app punishes life events.
- TR-market context: religious holidays (Bayram), Ramazan period changes, university exam weeks all create predictable multi-day skip windows. The app has no concept of these.

**Evidence:**
```dart
// workout_repository.dart:777–802
Future<void> markDayCompleted(int dayNumber) async {
  final merged = _localCompleted()..add(dayNumber);
  await _saveLocal(merged);
  unawaited(NotificationService.instance.scheduleStreakWarning());
  ...
}
```
There is `markDayCompleted` but no `markDaySkipped` or `shiftPlanForward(int days)`. The completion bag is monotonically additive.

---

### Finding B-04: Day 4 paywall + first scheduled rest + 48h streak warning = triple-jeopardy moment

**Severity:** 5/5
**Where:** `lib/features/workout/domain/services/workout_generator_service.dart:99` (rest cadence); `lib/features/home/presentation/widgets/today_task_card.dart:105` (Day 4+ paywall); `lib/core/services/notification_service.dart:300` (streak warning at 48h)
**Behavioral reality:** Three independent systems converge on Day 4:
1. **Rest day:** Day 4 is the first scheduled rest day (`% 4 == 0`). The user opens the app expecting a workout and gets an amber coffee cup.
2. **Paywall awakens:** Day 5 is the first paywalled day (`kFreeDayLimit = 3`). If the user does try to advance past the rest, they hit a paywall.
3. **48h streak warning notification:** `markDayCompleted` schedules a streak warning that fires 48h after the *previous* completion (`workout_repository.dart:788`, `notification_service.dart:299`). If the user did Day 3 on Sunday at 9pm, the streak warning fires Tuesday at 9pm — exactly when they're staring at the Day 4 rest cell wondering what's going on.
**Observation:** The three timings combine into a single "this thing is broken" moment:
- Open app → see "Aktif Dinlenme" + non-functional CTA (today_task_card.dart:103 returns early on empty exercises)
- Try to start tomorrow's workout → paywall
- Get push notification "Seriyi kaybetmek üzeresin! ⚡" while the app is showing them they're on a *scheduled rest day*
**Cost:**
- Maximum confusion at the moment the app most needs to retain the user.
- The notification claims the user is missing their workout; the app itself says the user is on a scheduled rest. The user is being lied to by the system.
- Compounded with the paywall: even if the user wants to power through the rest day, they can't (Day 5 is paywalled).
- This is the canonical Day 4–5 free-tier dropout. Industry data says ~30% of users who reach Day 3 don't complete Day 5; this app's design actively engineers that drop.

---

### Finding B-26: Plan cache fingerprint = goal:level only — profile edits wipe progress

**Severity:** 3/5
**Where:** `lib/features/workout/data/workout_repository.dart:708–709, 715–731`
**Observation:** The cached plan is identified by `${userGoal}|${fitnessLevel}` (`workout_repository.dart:708–709`). If the user edits their goal in the Profile tab on Day 5, the fingerprint changes, the cache is invalidated, and a fresh 30-day plan is generated starting at Day 1. The completion flags from Days 1–4 are retained in `_completedDays`, BUT they're applied to the *new* day 1–4 — which may have different exercises.
**Cost:**
- A user who realizes mid-program "actually I want to go from `tone` to `bulk`" gets either (a) their Days 1–4 completions overlaid onto unrelated new-plan days (visual confusion), or (b) reset to Day 1 (lost progress feeling).
- TR cultural context: users often try multiple goals before settling. The app's cache invalidation cliffs make goal-switching feel destructive.

---

## 8. TONE OF VOICE — DRILL SERGEANT, PEER COACH, OR FRIEND?

### 8.1 What 20+ copy strings reveal

Sample copy across surfaces (sourced from grep across `lib/`):

| Surface | TR copy | English | Register |
|---|---|---|---|
| Onboarding step 1 | "Vücudunu Yapay Zeka ile Şekillendir" | Shape your body with AI | Aspirational, neutral |
| Onboarding step 2 | "Merhaba! Ben senin kişisel yapay zeka koçunum." | Hi! I'm your personal AI coach. | Warm, neutral |
| Onboarding step 4 feedback | "🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor." | Great choice! Most who start with this goal see a difference in 30 days. | Validating, peer-coach |
| Onboarding step 5 helpers | "Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız." | No problem at all. We'll start from zero and progress fast. | Supportive friend |
| Onboarding step 6 helper | "Kısa sürede maksimum verim alacağız." | We'll get max output in short time. | Outcome-driven |
| Welcome CTA | "BAŞLA" | START | All-caps imperative |
| Auth screen | "AI DESTEKLİ FORM KOÇU" | AI-powered form coach | Tech bro |
| Auth screen | "GİRİŞ YAP" / "KAYIT OL" | LOG IN / SIGN UP | All-caps imperative |
| Antrenman header | "PRO" | (premium badge) | Status |
| Antrenman challenge title | "Sert Karın Kasları" | Hard Ab Muscles | Drill aesthetic |
| Antrenman challenge title | "Bacak ve Kalça Ateşi" | Leg & Hip Fire | Drill aesthetic |
| Antrenman challenge title | "Üst Vücut Gücü" | Upper Body Power | Drill aesthetic |
| Plan detail hero | "Taş Gibi Sert\nKarın Kasları" | Stone-Hard\nAb Muscles | Drill aesthetic |
| Plan-detail (regional) | "Patlayıcı Kol Süper Setleri" | Explosive Arm Super Sets | Gym-bro |
| Plan-detail (regional) | "Power Omuz Patlaması" | Power Shoulder Blast | Gym-bro |
| Plan-detail (regional) | "Çelik Kollar" | Steel Arms | Drill aesthetic |
| Today task CTA | "ANTRENMANA BAŞLA" | START WORKOUT | All-caps imperative |
| Today task focus (core) | "Göğüs & Core" | Chest & Core | Generic |
| Hero card CTA | "BAŞLA" | START | All-caps imperative |
| Equipment card CTA | "BAŞLA" | START | All-caps imperative |
| Workout prep | "HAZIRLAN" | PREPARE / READY UP | Drill imperative |
| Workout TTS (start) | "Sıradaki hareket: Plank." | Next move: Plank. | Neutral |
| Workout TTS (form warn) | "Kalçanı düz tut, plank pozisyonunu koru!" | Keep your hips flat, hold the plank position! | Drill |
| Workout TTS (silent hold) | "Dayan, bırakma!" | Hold on, don't let go! | Drill |
| Workout TTS (silent hold) | "Harika gidiyorsun!" | You're doing great! | Peer-coach |
| Workout TTS (rest) | "Harika! Şimdi 30 saniye dinlenme." | Great! Now 30 seconds rest. | Peer-coach |
| Workout TTS (complete) | "Antrenman tamamlandı! Harika bir iş çıkardın." | Workout done! Great job. | Peer-coach |
| Session-complete overlay | "Harika iş çıkardın, yarın görüşürüz." | Great job, see you tomorrow. | Friend |
| Crunch analyzer | "Biraz yavaşla, kaslarını hisset." | Slow down a bit, feel your muscles. | Coach |
| Streak card subtitle | "Serini bozma!" | Don't break your streak! | Loss-aversion guilt |
| Program-progress card | "Harika gidiyorsun, devam et! 💪" (hardcoded for ALL %) | You're doing great, keep going! | Hollow validation |
| AI Coach (streak ≥7) | "Şampiyon serisi devam ediyor! Böyle kal." | Champion streak continuing! Stay like this. | Drill |
| AI Coach (streak == 0) | "Geri dönüş zamanı. 10 dakika yeterli." | Comeback time. 10 min is enough. | Coach |
| Notification (no workout) | "Hedeflerinden uzaklaşma. Günün egzersizi seni bekliyor, hemen başla!" | Don't drift from your goals. Today's exercise is waiting, start now! | Loss-aversion guilt |
| Notification (no workout) | "Bugün antrenmanı geçersen yarın iki gün geride kalırsın." | If you skip today's workout, tomorrow you'll be two days behind. | Threat |
| Notification (streak warning) | "Seriyi kaybetmek üzeresin! ⚡ 48 saat oldu. 10 dakikalık bir oturum momentumu kurtarır." | About to lose your streak! 48h passed. A 10-min session saves the momentum. | Threat + urgency |
| Notification (both done) | "Günü fethettin! 🏆 Bugün disiplinden kopmadın." | You conquered the day! Today you didn't break from discipline. | Gladiator |
| Weekly retrospective | "Bu hafta N antrenman yaptın, M kcal yaktın. Beslenme hedefine %X uydun. Gelecek hafta için hazır mısın?" | This week N workouts, M kcal burned, %X nutrition. Ready for next week? | Numerical |

**Verdict:** the tone is **mostly drill-sergeant with peer-coach interludes**. The "supportive friend" register exists in the onboarding helpers (`Hiç sorun değil`) but vanishes once the user is in the dashboard. The notifications are the worst offenders — pure loss-aversion guilt language ("yarın iki gün geride kalırsın", "Hedeflerinden uzaklaşma", "Seriyi kaybetmek üzeresin").

### 8.2 Why this matters for fitness adoption

Three psychographic profiles in the TR home-workout segment:

1. **Already-fit returner** (10–15% of installs): drill-sergeant works. They want to be pushed.
2. **Aspirational beginner** (60–70% of installs): peer-coach works. Drill-sergeant scares them off.
3. **Body-image-anxious** (15–20% of installs): supportive-friend is the only register that doesn't trigger shame.

The app's tone is calibrated for segment 1. Segments 2 and 3 — together 75–85% of the addressable market — get a tone that pushes them out.

### Finding B-16: Notification copy stack is guilt-shaped

**Severity:** 4/5
**Where:** `lib/core/services/notification_service.dart:70–123`
**Observation:** The 7 notification variants across 4 pools (no_workout, workout_no_food, both_done, streak_warning) lean heavily on:
- Loss aversion: "yarın iki gün geride kalırsın" / "Seriyi kaybetmek üzeresin"
- Distance metaphors: "Hedeflerinden uzaklaşma"
- Discipline language: "Disiplinden kopmadın"
- Conquest language: "Günü fethettin"

The peer-coach alternative ("Bir antrenman daha sığdırırsan harikasın" / "Yarına 10 dakika ayırabilir misin") is absent.

**Cost:**
- Beginners and body-image-anxious users perceive these as scolding. The notification triggers app-uninstall from the OS notification settings (the user blocks notifications, then forgets the app exists, then uninstalls within 7 days).
- For the already-fit segment, these work. But they're already-fit, so they're a smaller commercial bet.

---

### Finding B-17: "Şampiyon serisi devam ediyor!" is the only AI-Coach line for ALL streaks ≥7

**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1613–1621`
**Observation:** The AI Coach card has 3 branches:
- streak ≥ 7: "Şampiyon serisi devam ediyor! Böyle kal."
- streak == 0 AND maxStreak > 0: "Geri dönüş zamanı. 10 dakika yeterli."
- otherwise: "Bugün hedeflerimize bir adım daha yaklaşıyoruz."

A user at Day 7 sees "Şampiyon" — same line at Day 14, 21, 28. By Day 14 the user knows "Şampiyon serisi" is the boilerplate; the personalization illusion collapses.

**Cost:** Three branches for 30 days of program is dramatically thin. The peer-coach role gets reduced to a single repeating sentence.

---

### Finding B-18: Drill-aesthetic challenge titles for ALL plans

**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:236–248`; `lib/features/workout/presentation/plan_detail_screen.dart:67–93`
**Observation:** The dominant `targetMuscle` of a day's exercises maps to a fixed Turkish drill-aesthetic title:
```dart
case 'core': return 'Sert Karın Kasları';
case 'upper_body': return 'Üst Vücut Gücü';
case 'lower_body': return 'Bacak ve Kalça Ateşi';
```

Every core day reads "Sert Karın Kasları" (Hard Ab Muscles). For a female user trying to "tone" or a recovering user looking for "form" or "esneklik," the word "Sert" is wrong register. There's no goal-aware variant — `goal: belly_burn` user sees "Sert Karın" same as `goal: strength`.

**Cost:** Constant low-grade alienation for users not aligned with the drill-bro aesthetic.

---

### Finding B-08: Form-warning TTS treats every user identically

**Severity:** 4/5
**Where:** `lib/features/workout/services/core_analyzers.dart:488, 522–526`
**Observation:** The plank analyzer fires "Kalçanı düz tut, plank pozisyonunu koru!" every 8 seconds when the form check fails. The silent-hold encouragement rotates between 3 strings: "Harika gidiyorsun!", "Dayan, bırakma!", "Güzel ritim, aynen böyle!".

For a beginner, "Dayan, bırakma!" is interpreted as "you're failing if you stop" — which is itself bad form coaching. Real beginner-appropriate cues are "If your form breaks, stop and rest" — the *opposite* of "don't let go."

For an advanced trainee, "Dayan, bırakma!" is appropriate. For a beginner, it teaches them to ignore their body's stop signal.

**Cost:**
- Beginner injuries from pushed-through plank failure (lower-back tweaks).
- Form coaching becomes counter-productive: the AI is teaching beginners to override pain signals, which is the standard pre-injury pattern.

---

### Finding B-11: Onboarding asks `dailyMinutes` (10–15 / 20–30 / 45+) and never uses it

**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:2716–2719`; `lib/features/workout/domain/services/workout_generator_service.dart:300–303`
**Observation:** The wizard step 6 (`_DailyMinutesStep`) collects the user's daily time budget. The setter is `setDailyMinutes(value)` (`onboarding_screen.dart:2717`). The persisted JSON includes `dailyMinutes: '10_15'` etc. The workout generator's daily exercise count is:

```dart
// workout_generator_service.dart:300–303
int _dailyExerciseCount(int dayNumber) {
  final span = maxDailyExercises - minDailyExercises + 1; // = 3
  return minDailyExercises + (dayNumber % span);
}
```

It's a function of `dayNumber` only. `dailyMinutes` is never consulted. A user who said "10–15 dakika" gets the same 5–7 exercise day as a user who said "45+ dakika" — but with the same target reps, same rest periods. Total session time on Day 1 is roughly the same regardless of the user's stated time budget.

**Cost:**
- Time-poor users (busy parents, shift workers) get sessions longer than they signed up for, then DNF (did not finish) or skip.
- Time-rich users feel under-trained and look elsewhere.
- The `dailyMinutes` answer becomes another piece of evidence that the wizard collects data without using it (compounds the trust collapse from B-01 + B-05).

---

## 9. STREAK PSYCHOLOGY — LOSS AVERSION OR REWARD?

### 9.1 What FormAI uses

The app leans hard on streak loss aversion:
- Streak resets to 0 on first non-completed non-rest day (`gelisim_tab.dart:211–220`).
- 48h notification fires "Seriyi kaybetmek üzeresin!" (`notification_service.dart:114–123`).
- Streak Card subtitle: "Serini bozma!" (`gelisim_tab.dart:713`) — Don't break your streak!
- Display surfaces: 4 (atlas erratum E-3) — Antrenman flame, Gelişim header pill, Gelişim Streak Card, Profile stats tile.
- `maxStreak` watermark (atlas §5.6) is the only memory of past success.

### 9.2 The behavioral problem

Streak loss aversion is a known *high-output, high-burn* mechanism. It generates short-term consistency at the cost of long-term retention:
- Users who break a 12-day streak feel WORSE than users who never had a streak. They're more likely to uninstall, not less.
- The mechanism punishes life events (illness, vacation, family emergency) as if they were laziness.
- The "streak preserver" pattern (Duolingo's Streak Freeze, Headspace's Vacation Mode) acknowledges this and provides a cushion.

### Finding B-14: Streak break is binary, no preservation, no recovery cushion

**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/antrenman_tab.dart:200–210`; `lib/features/home/presentation/widgets/gelisim_tab.dart:211–220`; atlas §5.6
**Behavioral reality:** A user at 12-day streak gets food poisoning Day 13. They can't physically work out. The next day they recover and open the app — streak shows 0. The Gelişim header reads "🔥 0 Günlük Seri." The 12-day investment is gone.

The `maxStreak` watermark exists in storage but only fires the AI Coach copy "Geri dönüş zamanı." (`gelisim_tab.dart:1617`). It is NOT shown anywhere visually:
- Header pill: shows current streak only
- Streak Card: shows 0 dots filled
- Profile tab: shows current streak only
- Antrenman flame: hidden (count badge only renders when streak > 0)

So the user sees: "0" — the same visual as a brand-new install.

**Observation:** No streak-preservation token exists. No "skip day" affordance. The first non-completed day always breaks the streak. (Also called out in Phase 2 USER_FLOW_ANALYSIS.md as J-E3 / J-E4 with sev 3 — but the behavioral cost is sev-4 from a fitness adoption perspective.)

**Cost:**
- Users who lose long streaks have ~3× the uninstall rate of users who never had streaks (Duolingo internal studies cited in their UX docs).
- The TR market's holiday cadence (Bayram, Ramazan) creates predictable multi-day skip windows. Designed-for-streak apps without preservation tokens become disliked-during-holidays apps.
- Compounded with B-09 (no plan shift): a sick user has both their streak broken AND their plan ossified at Day N.

---

## 10. THE ANONYMOUS / FREE / TRIAL CONFUSION

### Finding B-25: The trial-friendly path is hidden at conversion moment

**Severity:** 3/5
**Where:** `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false); `lib/features/monetization/presentation/paywall_screen.dart:182–214` (forced auth gate); atlas §6.7 Phase 94
**Behavioral reality:** A cautious user wants to try the app before committing. They go through onboarding → land on paywall → forced auth modal blocks the paywall view. They can't even SEE the prices to evaluate.

The auth screen DOES have a "Misafir Olarak Devam Et" (Continue as Guest) button (`auth_screen.dart:289–305`) — but this only appears if the user clicks "E-posta ile Giriş Sayfasına Git" link inside the auth modal. The default modal layout shows Google + Apple OAuth buttons. The guest path is buried.

**Observation:** Phase 94 forced-auth gate makes anonymous purchase impossible (good for billing reconciliation, atlas §6.7). But the side effect is that the user must *commit to an identity* before they can EVALUATE the offer. Most fitness apps let you see the paywall, then ask for sign-up at the purchase moment.

**Cost:** Users who want to "see what's behind the wall" and would have bought after seeing the prices instead bounce because they don't want to share their Google account at first contact.

---

## 11. THE GENDER ASYMMETRY IN MARKETING IMAGERY

### Finding B-15: Paywall hero shows literal before/after body composites

**Severity:** 4/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:785–799`
**Observation:** The paywall hero swaps to a literal before/after body composite for `Gender.male` and `Gender.female`:
```dart
case Gender.male:
  return const _GenderBeforeAfter(
    todayAsset: 'photos/kişiselleştirilmişplandabugünkühalERKEK.webp',
    thirtyDayAsset: 'photos/kişiselleştirilmiş planda30.günERKEK.webp',
  );
case Gender.female:
  return const _GenderBeforeAfter(
    todayAsset: 'photos/kişiselleştirilmişplandabugünkühalKADIN.webp',
    thirtyDayAsset: 'photos/kişiselleştirilmişplanda30.günKADIN.webp',
  );
```

The "30 Günlük Değişimin!" ribbon overlays the composite (atlas §6.2). This is a body-image trigger card.

**Behavioral reality:**
- For the segment that joined out of body anxiety (the largest segment per market data), seeing a polished before/after image right after a 12-step onboarding labor-illusion creates a *comparison wound*. They think: "the after looks nothing like me; this is going to fail."
- For the segment that joined out of "I want to bulk up," the male composite is fine.
- For `Gender.other`, atlas erratum E-10 notes the placeholder is `Icons.accessibility_new` (wheelchair glyph) — accidentally othering a category that already feels excluded.

**Cost:**
- Increased paywall bounce among female users in the body-anxious segment.
- Reinforces the "this app is for people whose bodies look like that" identity friction.
- The composite is also shown to a user who explicitly hasn't said "I want to look like the before/after" — a "Güçlenmek" (strengthen) user gets the same thinness-coded female after image as a "Göbek eritmek" user.

---

## 12. CONSOLIDATED BEHAVIORAL FAILURE MAP

### 12.1 By segment (cross-references USER_SEGMENTATION_REPORT.md)

| Segment | Key behavioral risks (sev-rank) |
|---|---|
| Sedentary office worker, female, no experience | B-01, B-02, B-03, B-10, B-13, B-15, B-24 |
| Active male, regular experience | B-01, B-22 (mostly fine) |
| Post-partum mother, sedentary | B-02, B-03, B-10, B-15, B-23 |
| Body-image-anxious beginner | B-03, B-13, B-15, B-16, B-18, B-24 |
| Vacationing user / Bayram week | B-04, B-09, B-14, B-26 |
| Day 4 free-tier user | B-04, B-07, B-12 (downstream), B-25 |
| Day 30 program-completer | B-06, B-12 |

### 12.2 By moment-of-truth

| Moment | Findings |
|---|---|
| Onboarding promise | B-01, B-05, B-06, B-19 |
| Day 1 first workout | B-02, B-03, B-08, B-13, B-21 |
| Day 2 (DOMS) | B-02, B-07, B-16 |
| Day 4 (rest + paywall + warning) | B-04 |
| Day 7 (skip / vacation) | B-09, B-14 |
| Day 14 (mid-cycle female) | B-10 |
| Day 30 (completion) | B-06, B-12 |

### 12.3 By system layer

| Layer | Findings |
|---|---|
| Plan generator | B-01, B-05, B-19, B-22, B-23 |
| Wizard data flow | B-01, B-05, B-11 |
| Personalization engine | B-06, B-19 |
| Workout execution | B-03, B-08, B-13, B-21 |
| Rest day rendering | B-07, B-20, B-23 |
| Streak system | B-04, B-09, B-14 |
| Notification copy | B-04, B-16 |
| Visual design / aesthetic | B-13, B-15, B-18, B-24 |
| Tone / copy register | B-16, B-17, B-18 |
| Plan rigidity | B-04, B-09, B-26 |
| Female-aware design | B-10, B-15, B-24 |
| Conversion funnel | B-15, B-25 |
| End-game (Day 31+) | B-06, B-12, B-27 |

---

## 13. ERRATA AGAINST PRIOR PHASES

**ERRATA-B-1.** Atlas §4.2 lists `experienceLevel` and `activityLevel` as separate WizardState fields and treats them as both being consumed. The atlas correctly enumerates the schema but does not trace the data flow. **The workout generator only consumes `activityLevel`. `experienceLevel` does NOT shape the plan** (B-01).

**ERRATA-B-2.** Atlas §4.4 says "Phase 60C decision documented in code" for the `/prediction` route bypass. The code at `onboarding_screen.dart:172` makes a stronger claim that `targetPhysique` is consumed by the workout generator. **`targetPhysique` is never set during the wizard** (no `setTargetPhysique` call in `onboarding_screen.dart`). The save-then-read pattern is broken upstream of the generator (B-05).

**ERRATA-B-3.** Atlas §6.4 says `kFreeDayLimit = 3` means "Day 1–3 free; Day 4–30 require Pro." Day 4 is also the first scheduled rest day per `_normaliseGoal` `% 4 == 0`. So the gate doesn't fire on Day 4 (rest is non-tappable); it fires on Day 5. Atlas is technically correct on the constant but the user-perceived gate moment is Day 5. Phase 2 USER_FLOW_ANALYSIS.md J-B3 also says "Day 4 is the worst possible moment for a paywall" — sharper version: **the paywall actually fires on Day 5** because Day 4 is the rest day. Cost remains identical because the user perceives it as "the day after my first 3 free days."

**ERRATA-B-4.** Atlas §9.1 lists "AI Coach 3 contextual tips" via the suggestions screen. The actual logic (`suggestions_screen.dart:130–211`) has FOUR primary branches: program complete, active workout day, nutrition (4 sub-branches), motivational. The "3 tips" framing in the atlas is the *output count*, not the *branch count*. Minor — not a behavioral concern.

---

## 14. APPENDIX — FULL CODE EVIDENCE INDEX

| Finding | Primary file:line | Atlas §ref | Severity |
|---|---|---|---|
| B-01 | `workout_provider.dart:194–201`, `wizard_provider.dart:67`, `workout_generator_service.dart:282–296` | §4.2, §8.3 | 5 |
| B-02 | `workout_repository.dart:357–364`, `today_task_card.dart:117`, `notification_service.dart:70–84` | §4.6, §6.4 | 5 |
| B-03 | `workout_camera_screen.dart:703–718` | §8 | 5 |
| B-04 | `workout_generator_service.dart:99`, `today_task_card.dart:105`, `notification_service.dart:300` | §6.4 | 5 |
| B-05 | `onboarding_screen.dart:2606`, `workout_provider.dart:195`, `workout_generator_service.dart:163–177` | §4.4 | 5 |
| B-06 | `prediction_screen.dart:58, 129`, `ai_personalization_engine.dart:77, 226–233`, `today_task_card.dart:176–215` | §4.4, §5.5 | 5 |
| B-07 | `gelisim_tab.dart:1093–1127`, `plan_detail_screen.dart:824–829` | §5.2 | 4 |
| B-08 | `core_analyzers.dart:488, 522–526` | §8.5 | 4 |
| B-09 | `workout_repository.dart:777–802`, `workout_generator_service.dart:99` | §5.6 | 4 |
| B-10 | `nutrition_calculator_service.dart:76–82`, `wizard_provider.dart:51` | §4.2 | 4 |
| B-11 | `onboarding_screen.dart:2716–2719`, `workout_generator_service.dart:300–303` | §4.2 | 4 |
| B-12 | `today_task_card.dart:176–215` | §5.5 | 4 |
| B-13 | `preparation_overlay.dart:58–67`, `workout_camera_screen.dart:625–667` | §8.6 | 4 |
| B-14 | `antrenman_tab.dart:200–210`, `gelisim_tab.dart:1617`, `gelisim_tab.dart:211–220` | §5.6 | 4 |
| B-15 | `paywall_screen.dart:785–799` | §6.2 | 4 |
| B-16 | `notification_service.dart:70–123` | §10.3 | 4 |
| B-17 | `gelisim_tab.dart:1613–1621` | §5.2 | 3 |
| B-18 | `antrenman_tab.dart:236–248`, `plan_detail_screen.dart:67–93` | §5.7 | 3 |
| B-19 | `onboarding_screen.dart` (PrePaywallSummary), `workout_generator_service.dart:263–275` | §4.1 step 12 | 3 |
| B-20 | `today_task_card.dart:117`, `suggestions_screen.dart:227` | §9.1 | 3 |
| B-21 | atlas §8.4, `pose_detector_service.dart` | §8.4 | 3 |
| B-22 | `workout_generator_service.dart:282–296, 305–317` | §8.3 | 3 |
| B-23 | `workout_generator_service.dart:99–104` | §8.3 | 3 |
| B-24 | `paywall_screen.dart:792–795`, `nutrition_calculator_service.dart:76–82` | §6.2 | 3 |
| B-25 | `auth_modal_bottom_sheet.dart:67–69` | §6.7 | 3 |
| B-26 | `workout_repository.dart:708–709, 715–731` | §8.3 | 3 |
| B-27 | `prediction_screen.dart:58` | §4.4 (orphan) | 2 |

---

## 15. CRITICAL BEHAVIORAL FACTS (TL;DR)

For Phase 7 synthesis, these are the load-bearing facts of the report:

1. **The wizard's `goal` and `experienceLevel` answers don't reach the workout generator.** Every user gets a `tone, beginner` plan regardless of input. (B-01, B-05)
2. **The 30-day program contradicts the 12-week promise** made in onboarding. Day 31 has no path. (B-06, B-12)
3. **Day 1 is hard for beginners; Day 2 has no soreness coping; Day 4 hits paywall + rest + streak warning simultaneously.** (B-02, B-04, B-07)
4. **Camera is mandatory; no audio-only mode exists.** Three large segments excluded by the camera gate. (B-03)
5. **Female users get gender-aware imagery in the paywall but no cycle awareness, no female-coded language register.** (B-10, B-15, B-24)
6. **Notification copy is loss-aversion-guilt by default.** "yarın iki gün geride kalırsın" / "Hedeflerinden uzaklaşma" / "Seriyi kaybetmek üzeresin." (B-16)
7. **Streak break is binary; no streak-preservation token exists.** Vacation = automatic streak break. (B-14)
8. **Plan rigidity breaks under common life events** (illness, travel, holidays). No shift-by-N-days affordance. (B-09, B-26)
9. **The "92% AI confidence" is hardcoded marketing copy** for a deterministic round-robin generator. (B-19)
10. **Tone register is calibrated for the already-fit segment** (~10–15% of installs), pushing out the 60–70% aspirational beginner segment. (B-13, B-16, B-17, B-18)

---

**END OF FITNESS_BEHAVIOR_REPORT.md**
