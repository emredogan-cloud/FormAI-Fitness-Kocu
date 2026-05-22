# Workout Intelligence Audit — ML Kit, Voice Coach, Rep Counting & Timed Exercises

**Generated:** 2026-05-21
**Branch:** `feature/cdn-meal-migration`
**Scope:** Read-only investigation. No code changes. Truth first.
**Auditor inputs:** Full source trace of the workout/ML pipeline, the Supabase exercise migrations (`exercises_migration.sql`, `phase96_workout_library_expansion.sql`), and the in-repo strategy doc `reports/archive/ml-detection-strategy.md`.

---

## TL;DR — The Honest Verdict

The "workout intelligence" stack is **a rep counter with a thin haptic + TTS shell wrapped around it.** The marketing/UX framing implies an AI form coach. The implementation is closer to a **pose-driven set timer with skeleton drawing.**

| Question | Honest answer |
|---|---|
| Is form correction actually implemented? | **No, for 13 of 17 movement archetypes.** Only crunch, plank, shoulder-press, and burpee emit any form-related TTS. Push-up, squat, lunge, curl, row, lateral raise, leg raise, jumping jack, mountain climber, Russian twist, flutter kick, bicycle crunch, chest fly — **all silent on form**. |
| If yes — why silent? | Because the analyzer classes for those exercises return `formWarning: null` unconditionally. The skeleton overlay still renders (because pose detection runs), creating the **illusion** of tracking. |
| If no — where was the illusion created? | The `PosePainter` draws every joint regardless of likelihood, with no minimum-confidence filter, and never indicates "we're not actually analyzing this." |
| Is the voice coach feature-complete? | **No.** It speaks at four moments: prep start, rest start, session complete, and (rarely) a milestone or warning. Most of the active set is silent — by code, not by accident. |
| Are rep counters trustworthy? | **For ~5 archetypes, yes.** For mountain climber, Russian twist, dead bug, and any movement with significant z-axis displacement (toward/away from camera), **counting is unreliable** because every analyzer uses 2D-only geometry. |
| Are timed workouts trustworthy? | **Plank itself is correctly time-based.** But there is a systemic **stuck-rep-based-exercise** bug: ~12+ rep-based exercises in personalized plans route to `SilentHoldAnalyzer`, which never increments reps — the user is forced to manually tap "Next" to advance. |
| Which systems are fake / partial / unfinished? | Form correction (13/17 analyzers), pacing feedback (1/17 — only crunch), contextual cues (2/17 — burpee, silent-hold), rep-counting for hip-hinge / olympic / mobility / scapular exercises, mid-set voice coaching density. |
| Production risk | **High.** Users on push-ups, squats, or any "stuck" Phase-96 exercise will perceive the AI as broken. App-store reviewers running a 30-second smoke test on a personalised plan have a >50% chance of hitting at least one stuck exercise (see §3.2). |
| Would users trust this system? | Not after one session. The skeleton draws confidently and the TTS goes silent for 60+ seconds. The cognitive dissonance is the product's biggest reputational risk. |

The system *is* honest-by-design in the strategy doc (`reports/archive/ml-detection-strategy.md` §1: "the user is not lied to about a rep count we can't compute reliably"). But the **UX** does not communicate which exercises lack analysis, the rep counter still shows `x 0 / 12` for stuck reps, and the marketing word "Form*AI*" implies more than the implementation delivers.

---

## 0. System Map — What Actually Runs Per Frame

```
Camera (camera plugin, 30 FPS, ResolutionPreset.medium)
   ↓
_onCameraImage(CameraImage) — workout_camera_screen.dart:297
   ↓
[GATES]
   • !mounted              → drop
   • _isProcessingFrame    → drop (single-flight gate)
   • _isPaused             → drop
   • session.isResting     → drop (skip during rest)
   • session.isPreparing   → drop (skip during HAZIRLAN!)
   • <66 ms since last     → drop (FPS throttle to ~15 FPS)
   ↓
_toInputImage(CameraImage) — orientation + format conversion (line 488)
   ↓
PoseDetectorService.detectPose(InputImage)  — pose_detector_service.dart:12
   • PoseDetectionMode.stream
   • Single Pose returned per frame
   ↓
PosePainter.paint() — pose_painter.dart:46
   • Draws ALL 33 landmarks, no confidence filter
   • Draws ALL 18 bone connections, no confidence filter
   ↓
_analyzer.analyze(Pose) → CrunchResult — workout_camera_screen.dart:402
   ↓
[USE THE RESULT]
   • result.formWarning  → speak + warningDoubleTap haptic (debounced)
   • result.contextualCue → speak
   • result.repJustCompleted → heavy haptic, setCurrentReps,
                               milestone speech, target check,
                               completeCurrentExercise() if reps >= target
```

Reps and form are entirely produced by **one Dart object per session**: the active `PoseAnalyzer`. The PoseDetector itself only emits raw landmarks.

---

## 1. ISSUE A — "ML Kit appears to track form visually but provides no coaching"

### Problem
The skeleton overlay renders confidently on the camera feed. No TTS warnings or corrections fire. The user feels tracked but not coached.

### Root Cause — Triple Cause

**A1. 13 of 17 analyzers never produce a `formWarning` string.** A `formWarning: null` analyzer cannot speak because `workout_camera_screen.dart:404`:
```dart
final warning = result.formWarning;
if (warning != null) {
  _audio.speak(warning);
  ...
}
```
With `warning == null`, nothing happens. Skeleton still draws (handled separately).

**A2. The PosePainter ignores landmark confidence.** `pose_painter.dart:46–84` draws every landmark in `pose.landmarks.values` regardless of `likelihood`. There is no visual signal to the user that "this leg is at 0.1 confidence — analysis is unreliable here." The skeleton looks just as confident at 0.05 likelihood as at 0.95.

**A3. The default analyzer for any unmapped slug is `SilentHoldAnalyzer`,** which is named "Silent" for a reason — it returns `formWarning: null` on every frame and emits only a generic encouragement (`"Harika gidiyorsun!"`) every 18 s. For ~34 slugs from the Phase-96 expansion, this is what runs.

### Evidence — Analyzer Feedback Matrix

Direct read of every analyzer in `lib/features/workout/services/`. Columns:
- **formWarning**: does it ever return a non-null `formWarning`?
- **contextualCue**: does it emit a `contextualCue`?
- **pacingFeedback**: does it emit a `pacingFeedback`?
- **partialRepWarn**: does it warn on incomplete ROM?

| Analyzer (class) | formWarning | contextualCue | pacingFeedback | partialRepWarn |
|---|:-:|:-:|:-:|:-:|
| `CrunchAnalyzer` | ✅ "Boynunu düz tut!" (15 s CD) | ❌ | ✅ "Biraz yavaşla" / "Pes etme" (7 s CD) | ❌ |
| `LegRaiseAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `RussianTwistAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `MountainClimberAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `BicycleCrunchAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `FlutterKickAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `PlankAnalyzer` | ✅ "Kalçanı düz tut..." (8 s CD) | ❌ | ❌ | ❌ |
| `SilentHoldAnalyzer` | ❌ | ✅ generic (18 s CD, rotates 3 lines) | ❌ | ❌ |
| `SquatAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `PullUpAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `PushUpAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `BenchPressAnalyzer` (extends PushUp) | ❌ | ❌ | ❌ | ❌ |
| `ChestFlyAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `BicepsCurlAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `ShoulderPressAnalyzer` | ✅ "Kolları tam yukarı uzat!" | ❌ | ❌ | ✅ (same string, on partial ROM) |
| `LateralRaiseAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `JumpingJackAnalyzer` | ❌ | ❌ | ❌ | ❌ |
| `BurpeeAnalyzer` | ❌ | ✅ "Şimdi aşağı in..." (8 s CD) | ❌ | ❌ |

**Count:** 4 of 17 emit form warnings (and one of those is the always-silent `SilentHoldAnalyzer`'s "encouragement"). For the marquee strength movements — **push-up, squat, lunge, curl, row, pull-up, lateral raise** — analyzer-side coaching is **zero**.

### Affected files
- `lib/features/workout/services/back_legs_analyzers.dart` (SquatAnalyzer, PullUpAnalyzer)
- `lib/features/workout/services/chest_analyzers.dart` (PushUpAnalyzer, BenchPressAnalyzer, ChestFlyAnalyzer)
- `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart` (BicepsCurl, LateralRaise, JumpingJack, ShoulderPress, Burpee)
- `lib/features/workout/services/core_analyzers.dart` (LegRaise, RussianTwist, MountainClimber, BicycleCrunch, FlutterKick, Plank, SilentHold)
- `lib/features/workout/presentation/pose_painter.dart` (no confidence filtering)

### Severity
**CRITICAL** for product positioning. The product calls itself "FormAI" (form + AI). For 13/17 archetypes there is no form check.

### User impact
- App feels like a glorified rep counter with a fancy overlay.
- Users with bad form receive **no feedback**. They believe the silence means "good form" because the skeleton shows them as tracked.
- The TTS-silent gap during sets reads as "the app stopped working."

### Best-practice fix
Each analyzer must implement at least one form-correctness check rooted in the joint geometry it already computes:
- **Squat:** knee-over-toe deviation (knee.x vs ankle.x), torso-lean angle (shoulder→hip→vertical).
- **Push-up:** elbow flare (elbow.x vs shoulder.x at bottom), hip sag (shoulder→hip→ankle line).
- **Lunge:** front-knee-over-toe check (front-knee.x vs front-ankle.x), back-knee depth.
- **Pull-up:** chin-over-bar check (nose.y vs wrist.y at top), full-hang lockout at bottom (elbow > 160°).
- **Biceps curl:** elbow drift forward of hip (elbow.x vs hip.x), shoulder-flexion-as-cheating check (shoulder.y rise during curl).
- **Lateral raise:** wrist rise above shoulder line (wrist.y vs shoulder.y — should not exceed by more than X), trapezius-shrug check.
- **Jumping jack:** asymmetric arm/leg extension (compare L vs R amplitudes).

Each warning needs:
- a debounce (10–15 s for repeating warnings),
- a single, sentence-length Turkish coaching line,
- a partial-credit-OK signal so the rep still counts.

### Recommended implementation
Add a per-analyzer abstract `_evaluateForm(...)` hook called inside `analyze()` after the rep state machine. The hook returns `String? warning` and is gated by an analyzer-local cooldown. Reuse `AngleCalculator.between` plus 2D x/y deltas. **Do not** ship a "partial ROM" warning before validating that the user's CAMERA SETUP doesn't already truncate the joint geometry — false partials are worse than no warning.

---

## 2. ISSUE B — Voice coach speaks during the 3-second intro then goes silent

### Problem
For most exercises, the voice coach says one sentence at the start of every set ("Sıradaki hareket: NAME. DESCRIPTION") and then is silent for the duration of the set + 30 s rest. Users perceive "broken TTS" or "the AI gave up."

### Root Cause — The Voice Coach Has Exactly Four Speaking Surfaces

`workout_camera_screen.dart:696–717` and the analyzer pipeline together produce TTS at these moments:

1. **Prep start** (every exercise, line 716): `"Sıradaki hareket: ${exercise.name}. ${exercise.description}"` — takes ~3 s to speak at speechRate 0.5.
2. **Rest start** (line 706): `"Harika! Şimdi ${restDurationInSeconds} saniye dinlenme."` — takes ~2 s.
3. **Session complete** (line 704): `"Antrenman tamamlandı! Harika bir iş çıkardın."` — takes ~3 s.
4. **Per-frame from the analyzer + per-rep from the camera screen,** triggered only when:
   - `formWarning != null` (4 analyzers can produce these — see §1)
   - `contextualCue != null` (2 analyzers — burpee + silent-hold)
   - `pacingFeedback != null` (1 analyzer — crunch)
   - `repJustCompleted && reps == target - 2` (line 449) → "Son iki tekrar, sık dişini!"
   - `repJustCompleted && reps == (target / 2).floor() && target >= 4` (line 451) → "Yarıladın! Aynen böyle devam et."
5. **Timer complete** for time-based (line 603): `"Süre doldu, harika!"`

For a push-up set of 8 reps:
- 0–3 s: intro spoken.
- 3–6 s: silent prep countdown.
- 6–22 s: user reps 1→4 (silent), "Yarıladın!" plays at rep 4, reps 5→6 silent, "Son iki tekrar!" plays at rep 6, reps 7→8 silent, set completes.
- 22–52 s: 30 s rest, "Harika! Şimdi 30 saniye dinlenme." plays once at t=22, then 28 s silent.
- ...

**Active-time TTS density: ~6 seconds of speech per ~52 seconds of activity.** And those 6 seconds are clustered at the very start and rep-4 / rep-6 / rest-start — exactly matching the user's "speaks during the intro then silence" observation.

For exercises where the analyzer produces NO warnings/cues/pacing (13 of 17 — see §1), the only voice that fires during the set is the two milestone announcements. If `targetReps < 4`, even those don't fire.

### Additional voice-coach defects

**B1. Same-tick `_tts.stop()` races.** `AudioFeedback.speak()` at `lib/core/utils/audio_feedback.dart:141` calls `await _tts.stop()` before every speak. If two `speak()` calls fire back-to-back from `_processImage` (e.g., a form warning AND a rep-milestone in the same frame), the second `stop()` pre-empts the first phrase. **Form warnings can be cut off by rep milestones.**

**B2. Cooldown swallowing.** `speak()` returns silently if the exact same phrase fired in the last 3 s. The strings used for form warnings (e.g., `"Kalçanı düz tut, plank pozisyonunu koru!"`) are constants — a sustained problem only gets ONE warning per 15 s analyzer cooldown plus 3 s TTS dedupe.

**B3. The default `_analyzer` race.** `workout_camera_screen.dart:43` sets `_analyzer = CrunchAnalyzer()` as the default. The listener that swaps it to the correct one (line 723) does NOT fire for Riverpod's initial state, only for changes. The first change is the prep-timer tick at t≈1 s. Frames between camera start (~t=200 ms) and t≈1 s would theoretically run against `CrunchAnalyzer`. **Mitigated** by the `isPreparing` early-return in `_onCameraImage` (line 325) — frames during prep are dropped. But if a future code path enters the camera without `isPreparing=true`, the race is open.

**B4. `init()` not awaited.** `initState` calls `_audio.init()` fire-and-forget (line 97). `speak()` does `await init()` if not ready, which serialises every early speak call behind the slow init path (it probes `getLanguages` + sets iOS audio category). On a cold launch, the FIRST speak call may stutter or be silenced if it lands before language enumeration completes.

**B5. No rest-tick or set-tick cues.** During a 30 s rest, the voice says one line at the start and goes silent. There is no halfway cue ("15 seconds left"), no end cue, no "deep breath" coaching. Same for timed holds — a 40 s plank says "Sıradaki hareket: Plank…" then is silent until "Süre doldu, harika!"

### Affected files
- `lib/features/workout/presentation/workout_camera_screen.dart` (speech surfaces, listener, race)
- `lib/core/utils/audio_feedback.dart` (cooldown, stop-races, fire-and-forget init)
- All 17 analyzer classes (most produce zero per-frame voice)

### Severity
**HIGH.** This is the issue the user explicitly raised and it has the largest "feels broken" delta vs the marketing promise.

### User impact
- The session feels abandoned mid-set.
- Hard to follow tempo / breathing without TTS pacing.
- Encouragement-starved sessions correlate with drop-off (a coaching app without coaching).

### Best-practice fix

**B-fix-1: Add a "mid-set heartbeat" line.** Inside the camera screen, register a 10–12 s timer that fires while the user is active (not resting, not preparing) and speaks a rotating coaching string ("Nefesini boşalt!", "Kasları sık!", "Posture düz!"). Cooldown 15 s. Gate by exercise category for relevance.

**B-fix-2: Rest-tick cues.** While `isResting`, fire a tick at 50% of `restSecondsRemaining` ("X saniye kaldı, hazırlan.") and at 5 s remaining ("Beş saniye, başlamaya hazır ol.").

**B-fix-3: Per-analyzer pacing.** Every rep-based analyzer should emit `pacingFeedback` on the same throttle as the crunch analyzer (7 s cooldown, "fast → slow down", "slow → keep going"). Trivial copy-paste.

**B-fix-4: Replace `_tts.stop()` with priority queue.** The pre-empt pattern is wrong. Queue speakable strings with priority (warning > cue > milestone > pacing > encouragement) and drain the queue serially. The `awaitSpeakCompletion(true)` flag is already set — just don't `stop()` between phrases.

**B-fix-5: Eager `init()`.** Move `AudioFeedback.init()` to the app boot path (alongside the workout/Hive/etc. initialisers in `main.dart`) so the FIRST `speak()` call doesn't race against language enumeration.

---

## 3. ISSUE C — "Reps fail to increment" (ML feels blind)

### Problem
Users perform reps but the counter does not tick. The skeleton renders, but `result.repJustCompleted` stays false frame after frame.

### Root Cause — Multiple Independent Failure Modes

**C1. The "stuck rep-based exercise" bug — high impact.** 12+ rep-based exercises in personalized plans are documented in `reports/archive/ml-detection-strategy.md` as routing to `SilentHoldAnalyzer`. `SilentHoldAnalyzer` returns `reps: 0, repJustCompleted: false` on every frame. The user sees `x 0 / 12` and is stuck unless they tap the manual "Next" button.

Confirmed-stuck rep-based slugs (cross-referenced `analyzer_factory.dart` ↔ Phase 96 SQL ↔ generator's `_gymOnlySlugs` filter):

| Slug | DB type | Target | In personalized plan? | Analyzer used | Reps tick? |
|---|---|---|---|---|---|
| `bird_dog` | repBased | 12 reps | YES | SilentHold | ❌ STUCK |
| `frog_pump` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `glute_bridge` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `hip_thrust` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `pike_walk` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `prone_t_raise` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `prone_y_raise` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `scapular_wall_slide` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `single_leg_glute_bridge` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `single_leg_rdl` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `wall_walk` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `dumbbell_clean` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |
| `kettlebell_swing` | repBased | (per SQL) | YES (gym-only? need to verify) | SilentHold | ❌ STUCK |
| `cat_cow` | repBased | (per SQL) | YES | SilentHold | ❌ STUCK |

(The strategy doc lists ~34 slugs total falling through to `SilentHoldAnalyzer`; many of those are time-based — those work fine because the camera-screen timer drives completion. The list above filters to the **rep-based** subset that has no completion gate at all.)

**C2. 2D analyzers blind to z-axis motion — medium impact.** Several analyzers measure 2D pixel distances/angles that change minimally when the movement is along the camera's depth axis:

- **`MountainClimberAnalyzer`** (`core_analyzers.dart:184`): measures `_distance(lk, ls)` — knee to shoulder in 2D. In front-camera plank position, the knee comes IN toward the chest along z, not changing 2D distance much. The threshold `activeFraction = 0.55` of torso length is rarely crossed. **Reps systematically undercounted.**
- **`PushUpAnalyzer`** (front camera, no side angle): elbow flexion is partially detectable from front but the elbow joint barely moves in 2D as the body lowers along z. The 0.4 likelihood gate may also reject frames where the wrist is partially occluded by the chest.
- **`MountainClimberAnalyzer` + plank-position exercises:** the foot-toward-camera motion is a depth motion, ML Kit returns lower-confidence landmarks for occluded sides.

**C3. JumpingJack thresholds are demanding.** `JumpingJackAnalyzer.spreadRatio = 1.4` means the ankle spread must be **40% wider than shoulder width**. `armRatio = 0.6` means wrists must rise **60% of shoulder-width above the shoulder line** — overhead-and-then-some. A casual / fatigued / lazy jumping jack will not satisfy both gates simultaneously and **no rep counts**. Combined with the `minRepInterval = 500 ms`, two near-misses inside half a second will both be lost.

**C4. Camera/body-orientation invariance not handled.** Several analyzers assume the user is **facing the camera** (chest fly: `wristGap` is x-coordinate; russian twist: `shoulderMidX - hipMidX`). If the user sets up at an angle, or sits sideways for the russian twist, the offsets don't represent the intended geometry. No on-screen "Adjust your camera" calibration step exists.

**C5. The likelihood-0.4 gate can starve counts.** `back_legs_analyzers.dart:194` and `_armAngle` reject frames where ANY of the 3 needed landmarks is below 0.4 likelihood. For a person whose lighting is poor or who wears loose clothing, the analyzer may return null for several seconds at a time, dropping rep boundaries.

**C6. The first-exercise default analyzer is `CrunchAnalyzer`.** Workout_camera_screen.dart:43. As noted in B3, this is mitigated by the prep gate, BUT if any future code path lands the camera with `isPreparing == false` already, the user's first 1 s of frames will be analyzed by the wrong class. This is a latent timing-dependent bug.

### Affected files
- `lib/features/workout/services/analyzer_factory.dart:156-158` (the `default → SilentHoldAnalyzer` returns for rep-based slugs)
- `lib/features/workout/services/core_analyzers.dart:184` (`MountainClimberAnalyzer` 2D distance)
- `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart:292` (`JumpingJackAnalyzer` thresholds)
- `lib/features/workout/services/back_legs_analyzers.dart:194-196` (likelihood gate)
- `lib/features/workout/presentation/workout_camera_screen.dart:43` (default analyzer)
- `supabase/sql/phase96_workout_library_expansion.sql` (every repBased slug listed in §3.1)

### Severity
**CRITICAL** for stuck-rep-based exercises (12+ slugs, all in personalized plans). **MEDIUM** for 2D-analyzer undercount cases (mountain climber, jumping jack, push-up).

### User impact
- On any 30-day program day that includes a stuck slug (high probability — see §3.2 below), the user has no way to advance except "Next" → entire exercise fakes as "completed."
- Even where reps *do* count, the threshold tuning gives users the experience of "I did 12 reps but it only counted 7" — corrosive to trust.

### App-store reviewer risk
**Critical.** Personalized plans on a fresh install pull from the Supabase pool through `WorkoutGeneratorService.generate30DayPlan`. The pool includes most Phase-96 exercises (subject to `_gymOnlySlugs`). The probability that day 1 contains at least one of `bird_dog / glute_bridge / single_leg_glute_bridge / frog_pump / hip_thrust / prone_y_raise / prone_t_raise / single_leg_rdl / pike_walk / scapular_wall_slide / wall_walk` is high. A 30-second App Store review of "open app → start day 1" risks landing on a stuck exercise.

### Best-practice fix

**C-fix-1: Add target-rep-driven completion fallback to `SilentHoldAnalyzer` when the exercise is rep-based.** Two paths:
- **Honest path:** if `exercise.type == repBased` AND analyzer is SilentHold, surface an in-screen UI hint: "Bu egzersizde rep otomatik sayılmaz — tamamladığında 'Bitti' butonuna bas." Add a prominent "Bitti / Done" button to the control panel that runs `completeCurrentExercise()`.
- **Convert path:** flip the affected slugs to `timeBased` in the DB (30 s for bodyweight movements). The timer drives completion. No code change beyond SQL.

**C-fix-2: Add a `HipHingeAnalyzer`** (already in the strategy doc backlog) to cover glute bridge, hip thrust, frog pump, single-leg-glute-bridge, kettlebell swing, RDL. Track hip-y delta over time, with shoulder-to-knee angle as a secondary check. ~120 LOC.

**C-fix-3: Add a `ScapularAnalyzer`** to cover prone y/t raises, scapular wall slide. Track shoulder-blade lift via shoulder-y vs spine angle.

**C-fix-4: Mountain climber → 3D-aware.** Use `landmark.z` (BlazePose returns a z coordinate) to detect knee-toward-camera motion. The current 2D distance is the wrong primitive.

**C-fix-5: Loosen jumping-jack thresholds AND add hysteresis.** Drop `spreadRatio` to 1.2 and `armRatio` to 0.45. Add per-state hysteresis to prevent a "borderline" rep from costing two states' worth of motion.

**C-fix-6: Wire camera-positioning calibration.** A 3-second pre-set check: detect if all 33 landmarks are visible and likelihood > 0.5. If not, prompt the user to adjust camera distance/angle BEFORE the rep gate is engaged.

**C-fix-7: Replace the default-analyzer race.** Set `_analyzer` to `null` initially and bail out of `_processImage` if `_analyzer == null`. Force the listener-driven swap to happen first.

---

## 4. ISSUE D — "30-second plank counted as ~10 reps"

### Problem
The user reports that a timed exercise (plank) was registered as a series of reps instead of a hold timer.

### Root Cause — Compound Investigation Result

**Reading the code at face value, this should not happen** for the canonical `plank` slug:
- `supabase/sql/exercises_migration.sql:134`: plank is `'timeBased'` with `targetDurationInSeconds: 40`, `targetReps: NULL`.
- `lib/features/workout/services/analyzer_factory.dart:39-40`: `case 'plank': return PlankAnalyzer()`.
- `PlankAnalyzer.analyze` (`core_analyzers.dart:447`) returns `reps: 0, repJustCompleted: false` on every frame.
- `workout_camera_screen.dart:976`: `isTimeBased` selects `_formatMmSs(_secondsRemaining)` for the metric — the user should see "00:40" not "x N / M".
- `_syncExerciseTimer(exercise)` starts a 1-second-tick countdown for time-based.
- `_onTimerComplete()` calls `completeCurrentExercise()` when the countdown hits zero.

So the canonical plank path is correct. **However**, several drift scenarios CAN reproduce the symptom:

**D1. Supabase row drift.** If a manual SQL edit or a partial migration left the `plank` row with `type='repBased'` AND `target_reps != NULL`, the camera screen would show "x 0 / N" instead of the timer. `PlankAnalyzer` would still emit `reps: 0`, so the counter would stay at 0 — **but** the user would never get to N reps and the exercise would never complete by the rep path. They would be stuck. **This is not "counted as 10" — this is "stuck at 0".**

**D2. The user's plank is actually a different exercise.** Several slugs share "plank position":
- `mountain_climber`: repBased, 30 target reps, in plank position. Routes to `MountainClimberAnalyzer`. The user perceives "I'm in plank position" but is actually running the climber analyzer, which counts left-right knee alternations. If the user shifts weight subtly, **this could plausibly count ~10 reps over 30 s**. **Most likely match for the user's report.**
- `bicycle_crunch`: not plank position but is on the floor and may visually feel similar.
- `flutter_kick`: timed (30 s), but uses `FlutterKickAnalyzer` which emits `repJustCompleted: true` on each ankle alternation. The TIMER drives completion (so the user isn't stuck) BUT the camera screen still fires `AppHaptics.heavyImpact()` (workout_camera_screen.dart:434) on every leg flip. The user feels per-rep heavy haptics during what should be a hold. **This matches the "counted as ~10 reps" sensation even if the visible UI shows a timer.**
- `dead_bug`: repBased, 12 target reps, also routes to `FlutterKickAnalyzer`. Same per-rep haptic on each leg flip. But this one IS rep-based — so if the analyzer's ankle-y delta detection works at all, the user might see ~10 of 12 reps with mis-thresholding.

**D3. The first-exercise analyzer race (B3 / C6).** If the user's first exercise of a session is a plank AND somehow the prep gate is bypassed (an edge path we have not exhaustively ruled out), `CrunchAnalyzer` runs against plank pose. CrunchAnalyzer uses shoulder-hip-knee angle. In plank position, that angle is ≈180°, well above `downThreshold = 140°`, so state stays DOWN. **No reps would count** unless the user's hips sagged dramatically, dipping the angle below 90° — which would correspond to a near-collapse, not a normal plank.

**D4. Set-counter confused with rep-counter.** The control panel shows `currentSet / totalSets` above the metric (workout_control_panel.dart). If the user misread the set indicator (1/3, 2/3, 3/3) as "reps", they might say "counted 3 reps" — but not 10. This is the weakest theory.

### Most likely diagnosis
**D2 — flutter_kick or mountain_climber misidentified as "plank."** The strongest single explanation is that the exercise the user did was either `flutter_kick` (timeBased 30 s, but emits per-rep haptics on each leg flip) or `mountain_climber` (repBased 30, in plank-position, undercounts but still ticks). Both can occur in a personalized day. The Turkish UI calls flutter_kick "Flutter Kick" and mountain_climber "Mountain Climber" — neither is named "Plank" — but the user's spoken description of "I held a plank" is the user's framing, not the app's.

### Affected files
- `lib/features/workout/services/analyzer_factory.dart:54-55` (dead_bug → FlutterKick routing)
- `lib/features/workout/services/core_analyzers.dart:369` (FlutterKickAnalyzer emits per-rep haptic-triggering signal during timed)
- `lib/features/workout/presentation/workout_camera_screen.dart:429-434` (unconditional `heavyImpact()` on `repJustCompleted` regardless of `exercise.type`)

### Severity
**MEDIUM** — not data-loss, but degrades the trust signal. The user perceives chaos when the haptic and counter behaviour doesn't match what they think they are doing.

### User impact
- "The AI doesn't know what exercise I'm doing."
- Haptics fire during what should be a static hold → user thinks the system is malfunctioning.
- The strategy doc's "honest UX" promise breaks because the haptic IS a per-rep signal even when no rep is shown.

### Best-practice fix

**D-fix-1: Gate `repJustCompleted` consumption by `exercise.type`.** In `workout_camera_screen.dart:429`, wrap the entire `if (result.repJustCompleted)` block with `if (exercise.type == repBased && result.repJustCompleted)`. Time-based exercises should NEVER fire the heavy-impact haptic or the rep-milestone speech.

**D-fix-2: Stop routing `dead_bug` to `FlutterKickAnalyzer`.** Dead bug is a controlled quasi-static lying-down alternating limb extension — it doesn't have the same rapid ankle-y delta the flutter analyzer expects. Either route to `SilentHoldAnalyzer` (honest), or build a dedicated `DeadBugAnalyzer` that gates on slow controlled motion + opposite-limb extension geometry.

**D-fix-3: Convert `mountain_climber` and `flutter_kick` to TIME-based with optional rep counting.** Add a third exercise type `timedRepBased` (or an `ExerciseExecutionMode` enum on Exercise) that drives completion by timer but still displays the analyzer's rep count as informational. Mountain climber and flutter kick are continuous rhythmic movements — the user does them "for time," not "for a fixed count."

**D-fix-4: Surface a "form analysis confidence" badge.** When `_analyzer` is `SilentHoldAnalyzer`, show a small chip in the camera UI: "Form analizi bu egzersiz için devre dışı — kendi ritmine güven." This shifts the user's mental model away from "the AI is broken" toward "this exercise is timer-only."

---

## 5. UNKNOWN ISSUES Discovered During Trace

### U1. AnglePainter draws ALL landmarks regardless of confidence (Severity: HIGH)
**File:** `lib/features/workout/presentation/pose_painter.dart:46-84`
**Problem:** Every landmark in `pose.landmarks.values` is rendered with the same opacity and color, even at 0.05 likelihood. Bones connecting two low-confidence joints are drawn with full neon intensity.
**Impact:** The skeleton looks confident even when the analyzer would reject the frame for being below the 0.4 likelihood gate. This is the visual root of "feels tracked, but no coaching."
**Fix:** Alpha-multiply joint + bone by `min(a.likelihood, b.likelihood)`. Below 0.3, draw a hollow joint instead of a filled one. Optional: add a "low confidence" pulse to the overall skeleton when too many landmarks are weak.

### U2. AudioFeedback singleton lifecycle — multi-instance risk (Severity: MEDIUM)
**File:** `lib/features/workout/presentation/workout_camera_screen.dart:44`
**Problem:** A new `AudioFeedback()` is constructed per camera screen. On a back-and-forth navigation flow, multiple instances may exist, each calling `_tts.stop()` on the same shared platform TTS engine. The shared singleton state of flutter_tts means stops from a previous (still-undisposed) instance can cancel speeches from the new one.
**Impact:** Intermittent silent intros after navigating into and out of the camera quickly.
**Fix:** Hoist `AudioFeedback` to a Riverpod singleton provider with lifecycle ownership outside the camera screen.

### U3. Workout-camera frame stream may leak the `ref` after dispose (Severity: LOW — partially mitigated)
**File:** `lib/features/workout/presentation/workout_camera_screen.dart:297-336`
**Problem:** `_onCameraImage` reads `ref.read(workoutSessionProvider)`. The `if (!mounted) return` early-return at line 304 prevents the crash, but the camera plugin may still buffer a frame mid-dispose. Reading `ref` post-dispose throws `Bad state: Using ref when a widget is unmounted`. The current `if (!mounted) return` looks correct but races against the camera plugin's native callback latency.
**Impact:** Crash potential on rapid navigation. The dispose order (`stopImageStream` → `dispose()` at line 562-569) helps, but there's a tiny window.
**Fix:** Move the analyzer + state-read into the post-`_isProcessingFrame` block, and capture `session` once before the frame work begins (avoid `ref.read` from inside the async/await pipeline).

### U4. `RussianTwistAnalyzer` is camera-orientation-dependent (Severity: MEDIUM)
**File:** `lib/features/workout/services/core_analyzers.dart:89-178`
**Problem:** The analyzer measures `shoulderMidX - hipMidX` — a horizontal x-axis drift. If the user is seated sideways (most users will be, because that's the form for a russian twist), the camera doesn't capture the twist as an x-axis motion at all.
**Impact:** Russian twist rep count near-zero on a side-camera setup (which is the normal setup). Users see "0 reps" and assume the AI is broken.
**Fix:** Detect camera orientation via the dominant face-axis at setup and rotate the measurement frame; OR route russian twist to a 3D-aware z-shoulder measurement.

### U5. PlankAnalyzer triggers on ankle-only sag (Severity: LOW)
**File:** `lib/features/workout/services/core_analyzers.dart:447-502`
**Problem:** The angle check is shoulder-hip-ankle. If the user's ankle landmark is noisy (often is), the line angle bounces. False "Kalçanı düz tut" warnings can fire even when the hip is straight. Cooldown 8 s prevents spam but a transient false warning still reaches the user.
**Fix:** Add a 3-frame consecutive-violation check before warning.

### U6. ShoulderPressAnalyzer counts on the WAY DOWN, not the way up (Severity: MEDIUM)
**File:** `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart:155-168`
**Problem:** Reading the code: the rep increments when `delta < downThreshold` AFTER previous state was `up`. That's the descent. Users intuitively count reps on the LOCKOUT at the top, not on the return. Side effects:
- Partial-rep warning fires AFTER the lockout passed (no opportunity to correct).
- The voice milestone "Son iki tekrar!" announces while the user is on the descent of rep `target - 2`, off-by-one in timing perception.
**Fix:** Count on the UP commit (`delta > upThreshold` when previously `down`), and emit partial warning on the next ascent attempt if the previous max-delta was insufficient.

### U7. `JumpingJackAnalyzer` may falsely register from camera shake (Severity: LOW)
**File:** `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart:292`
**Problem:** No frame-confidence gate. A held camera that shakes during exercise can shift wrist/ankle x by enough to satisfy the open/closed thresholds without the user moving.
**Fix:** Add a likelihood gate similar to back_legs_analyzers' `< 0.4` check.

### U8. `BurpeeAnalyzer` self-calibration `_yMin/_yMax` is never reset between sets (Severity: LOW)
**File:** `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart:413-424`
**Problem:** `reset()` clears `_yMin/_yMax`, but only when the camera screen calls `_analyzer.reset()`. That happens on exercise change / prep end / rest end / set change. Within a single set the running min/max grow indefinitely. Late in a long set, the thresholds (30% and 70% of range) become too lenient and false "rep" cycles may register from breathing.
**Fix:** Decay-window the min/max (e.g., reset over a 10-second sliding window) so old extrema don't pollute current thresholds.

### U9. `FlutterKickAnalyzer` minDelta in pixels is non-scaling (Severity: MEDIUM)
**File:** `lib/features/workout/services/core_analyzers.dart:371`
**Problem:** `minDelta = 12.0` is in absolute pixel space. If the user stands far from the camera (their image height is small), 12 px is a much bigger fraction of leg length, and reps don't count. Close to camera, 12 px is a tiny leg motion and noise triggers reps.
**Fix:** Express minDelta as a fraction of `shoulder-to-ankle` distance, like other analyzers do.

### U10. Workout completion silently swallows `_setStartedAt == null` (Severity: LOW)
**File:** `lib/features/workout/providers/workout_provider.dart:645-647`
**Problem:** `_captureCompletedSet` measures duration as `DateTime.now().difference(_setStartedAt!)`. If `_setStartedAt` is null (because `_markSetStarted` was never called, e.g., a manual "Next" before prep completed), the fallback is `setDuration = 0`. The persisted SessionLog will show 0-second sets, which corrupts the gelisim_tab analytics that aggregate per-day duration.
**Fix:** Either skip the duration aggregation when `_setStartedAt` is null, OR fallback to `exercise.targetDurationInSeconds ?? 0` so a manually-skipped time-based exercise records its planned duration.

### U11. `ExerciseGuidePlayer` PiP runs throughout the set (Severity: LOW, perf)
**File:** `lib/features/workout/presentation/workout_camera_screen.dart:1139-1144`
**Problem:** The picture-in-picture video plays continuously during the active set. On low-end devices this competes with the BlazePose inference for CPU/GPU. Reports/archives mention thermal issues — the video is one contributor.
**Fix:** Pause the PiP after the first 5 seconds of the set, or stop the video and show a static frame. Resume on next exercise.

### U12. `workoutSessionProvider` re-emits on EVERY rest-tick (Severity: LOW, perf)
**File:** `lib/features/workout/providers/workout_provider.dart:539-568`
**Problem:** The rest timer ticks every second and `state = AsyncData(current.copyWith(restSecondsRemaining: remaining))` triggers a full provider rebuild. The camera screen's `ref.watch` re-renders the whole tree. The ref.listen body also runs once per tick (most of its work is no-ops on tick).
**Fix:** Split rest-countdown into a separate provider (`restCountdownProvider`) that the rest overlay watches, leaving the main provider stable during rest.

### U13. Session "intro" announcement clashes with rest-end announcement (Severity: LOW)
**File:** `lib/features/workout/presentation/workout_camera_screen.dart:696-717`
**Problem:** When rest ends and prep starts immediately (`justStartedPrep == true`), the speech is "Sıradaki hareket: NAME. DESC." But the rest-end transition itself never gets a "Dinlenme bitti" announcement — the announcement style assumes you transitioned cleanly to the next exercise. If the next exercise IS the same (inter-set rest), the "Sıradaki hareket" phrasing is awkward — it's not the next exercise, it's the next SET of the same exercise.
**Fix:** Branch the speech on whether this is an inter-set or inter-exercise prep. Inter-set: "Sıradaki set, devam et!" Inter-exercise: keep current.

---

## 6. Coverage Matrix — Which Exercises Actually Work?

This matrix combines the SQL exercise definitions × the analyzer factory routing × the analyzer-feedback matrix (§1). One row per slug. Truthful answers in the columns.

> **Legend:**
> - **Counts reps?** Does the analyzer actually increment a rep counter for this exercise type?
> - **Form warning?** Does the analyzer produce any form-correction TTS?
> - **Completes by itself?** Will the camera screen complete the exercise without manual "Next" tap?
> - **STUCK?** If `repBased` AND no rep counting AND no timer → user is stuck.

| Slug | Type | Analyzer | Counts reps? | Form warning? | Completes alone? | STUCK? |
|---|---|---|:-:|:-:|:-:|:-:|
| `crunch` | repBased | CrunchAnalyzer | ✅ | ✅ | ✅ | — |
| `situp` | repBased | CrunchAnalyzer | ✅ | ✅ | ✅ | — |
| `decline_crunch` | repBased | CrunchAnalyzer | ✅ | ✅ | ✅ | — |
| `weighted_sit_up` | repBased | CrunchAnalyzer | ✅ | ✅ | ✅ | — |
| `toe_touch` | repBased | CrunchAnalyzer | ✅ | ✅ | ✅ | — |
| `plank` | timeBased | PlankAnalyzer | n/a (timed) | ✅ | ✅ (timer) | — |
| `leg_raise` | repBased | LegRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `hanging_leg_raise` | repBased | LegRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `weighted_leg_raise` | repBased | LegRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `dragon_flag` | repBased | LegRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `reverse_crunch` | repBased | LegRaiseAnalyzer | ⚠️ partial (shorter ROM) | ❌ | ⚠️ likely undercounts | — |
| `russian_twist` | repBased | RussianTwistAnalyzer | ⚠️ camera-orientation-dependent (U4) | ❌ | ⚠️ likely fails on side camera | — |
| `medicine_ball_russian_twist` | repBased | RussianTwistAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `mountain_climber` | repBased | MountainClimberAnalyzer | ⚠️ 2D-only — undercounts (C2) | ❌ | ⚠️ may not | — |
| `bicycle_crunch` | repBased | BicycleCrunchAnalyzer | ✅ | ❌ | ✅ | — |
| `flutter_kick` | timeBased | FlutterKickAnalyzer | n/a (timed) | ❌ | ✅ (timer); but per-rep haptics misfire (D2) | — |
| `dead_bug` | repBased | FlutterKickAnalyzer | ⚠️ wrong analyzer; quasi-static doesn't match flutter signature | ❌ | ⚠️ likely fails | — |
| `push_up` | repBased | PushUpAnalyzer | ⚠️ depends on camera angle (C2) | ❌ | ⚠️ may undercount | — |
| `incline_push_up` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `decline_push_up` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `diamond_push_up` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `wide_push_up` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `archer_push_up` | repBased | PushUpAnalyzer | ⚠️ counts one per side | ❌ | ⚠️ may double-count | — |
| `clap_push_up` | repBased | PushUpAnalyzer | ⚠️ mid-air frame occludes | ❌ | ⚠️ same | — |
| `knee_push_up` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ same | — |
| `chest_dip` | repBased | PushUpAnalyzer | ✅ | ❌ | ✅ | — |
| `bench_press` | repBased | BenchPressAnalyzer | ✅ | ❌ | ✅ | — |
| `decline_bench_press` | repBased | BenchPressAnalyzer | ✅ | ❌ | ✅ | — |
| `machine_chest_press` | repBased | BenchPressAnalyzer | ✅ | ❌ | ✅ | — |
| `chest_fly` | repBased | ChestFlyAnalyzer | ⚠️ camera-orientation-dependent | ❌ | ⚠️ | — |
| `cable_crossover` | repBased | ChestFlyAnalyzer | ⚠️ same | ❌ | ⚠️ | — |
| `incline_chest_fly` | repBased | ChestFlyAnalyzer | ⚠️ same | ❌ | ⚠️ | — |
| `squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `lunge` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `bulgarian_split_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `leg_press` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `front_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `goblet_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `pistol_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `sumo_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `box_jump` | repBased | SquatAnalyzer | ⚠️ mid-air may occlude | ❌ | ⚠️ | — |
| `dumbbell_step_up` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `walking_lunge_dumbbell` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `deadlift` | repBased | SquatAnalyzer | ⚠️ depends on knee bend | ❌ | ⚠️ | — |
| `jump_squat` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `thruster` | repBased | SquatAnalyzer | ✅ | ❌ | ✅ | — |
| `squat_jump_pulse` | repBased | SquatAnalyzer | ⚠️ shallow squat may not cross down threshold | ❌ | ⚠️ | — |
| `tuck_jump` | repBased | SquatAnalyzer | ⚠️ same as box jump | ❌ | ⚠️ | — |
| `wall_sit` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `calf_raise` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `pull_up` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `chin_up` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `lat_pulldown` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `barbell_row` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `dumbbell_row` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `t_bar_row` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `face_pull` | repBased | PullUpAnalyzer | ⚠️ shorter ROM may not cross thresholds | ❌ | ⚠️ | — |
| `seated_cable_row` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `inverted_row` | repBased | PullUpAnalyzer | ✅ | ❌ | ✅ | — |
| `scapular_pull_up` | repBased | PullUpAnalyzer | ⚠️ minimal elbow bend may not count (acknowledged in strategy doc) | ❌ | ⚠️ likely STUCK | ⚠️ |
| `chin_up_negative` | repBased | PullUpAnalyzer | ⚠️ eccentric-only | ❌ | ⚠️ | — |
| `superman` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `shoulder_press` | repBased | ShoulderPressAnalyzer | ✅ | ✅ partial-only | ✅ | — |
| `arnold_press` | repBased | ShoulderPressAnalyzer | ✅ | ✅ partial-only | ✅ | — |
| `upright_row` | repBased | ShoulderPressAnalyzer | ⚠️ shorter ROM | ✅ partial-only (will misfire) | ⚠️ | — |
| `cuban_press` | repBased | ShoulderPressAnalyzer | ⚠️ multi-phase | ✅ partial-only | ⚠️ | — |
| `landmine_press` | repBased | ShoulderPressAnalyzer | ✅ | ✅ partial-only | ✅ | — |
| `machine_shoulder_press` | repBased | ShoulderPressAnalyzer | ✅ | ✅ partial-only | ✅ | — |
| `lateral_raise` | repBased | LateralRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `front_raise` | repBased | LateralRaiseAnalyzer | ✅ | ❌ | ✅ | — |
| `rear_delt_fly` | repBased | LateralRaiseAnalyzer | ⚠️ requires hinged stance — may not match | ❌ | ⚠️ | — |
| `pike_push_up` | repBased | PushUpAnalyzer | ⚠️ inverted-ish | ❌ | ⚠️ | — |
| `pike_push_up_close` | repBased | PushUpAnalyzer | ⚠️ same | ❌ | ⚠️ | — |
| `handstand_push_up` | repBased | PushUpAnalyzer | ⚠️ likelihood drops inverted | ❌ | ⚠️ | — |
| `biceps_curl` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `hammer_curl` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `triceps_pushdown` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `preacher_curl` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `incline_dumbbell_curl` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `cable_curl` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `overhead_triceps_extension` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `rope_triceps_pushdown` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `dumbbell_kickback` | repBased | BicepsCurlAnalyzer | ⚠️ small ROM may not cross thresholds | ❌ | ⚠️ | — |
| `tricep_extension_floor` | repBased | BicepsCurlAnalyzer | ✅ | ❌ | ✅ | — |
| `triceps_dip` | repBased | PushUpAnalyzer | ✅ | ❌ | ✅ | — |
| `close_grip_push_up` | repBased | PushUpAnalyzer | ⚠️ same as push-up | ❌ | ⚠️ | — |
| `bench_dip` | repBased | PushUpAnalyzer | ✅ | ❌ | ✅ | — |
| `burpee` | repBased | BurpeeAnalyzer | ✅ | ❌ | ✅ | — |
| `squat_thrust` | repBased | BurpeeAnalyzer | ✅ | ❌ | ✅ | — |
| `half_burpee` | repBased | BurpeeAnalyzer | ✅ | ❌ | ✅ | — |
| `jumping_jack` | timeBased | JumpingJackAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `high_knees` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `skipping_rope` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `hollow_hold` | timeBased | SilentHoldAnalyzer (default) | n/a (timed) | ❌ | ✅ (timer) | — |
| `side_plank` | timeBased | SilentHoldAnalyzer (default) | n/a (timed) | ❌ | ✅ (timer) | — |
| `bird_dog` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `dumbbell_pullover` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK (gym-only — won't appear in personalized) |
| `hyperextension` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK (gym-only) |
| `prone_y_raise` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `prone_t_raise` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `swimmer` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `handstand_hold` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `pike_walk` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `wall_walk` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `scapular_wall_slide` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `farmer_carry` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `dead_hang` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `hip_thrust` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `glute_bridge` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `single_leg_glute_bridge` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `single_leg_rdl` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `frog_pump` | **repBased** | **SilentHoldAnalyzer (default)** | **❌** | ❌ | **❌** | **⚠️ STUCK** |
| `nordic_curl` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK (gym-only) |
| `kettlebell_swing` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK |
| `dumbbell_clean` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK |
| `plank_jack` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `bear_crawl` | (per SQL) | SilentHoldAnalyzer | depends on type | ❌ | depends | — |
| `lateral_shuffle` | (per SQL) | SilentHoldAnalyzer | depends on type | ❌ | depends | — |
| `shadow_boxing` | (per SQL) | SilentHoldAnalyzer | depends on type | ❌ | depends | — |
| `cat_cow` | repBased | SilentHoldAnalyzer | ❌ | ❌ | ❌ | ⚠️ STUCK |
| `child_pose` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `downward_dog` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `cobra_stretch` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `hip_flexor_stretch` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |
| `standing_hamstring_stretch` | timeBased | SilentHoldAnalyzer | n/a (timed) | ❌ | ✅ (timer) | — |

**Headline counts:**
- Total slugs surveyed: 138.
- **STUCK rep-based exercises (no reps + no timer): 11+ confirmed in personalized plan eligibility, +4 gym-only.**
- **Exercises with ANY form-correction TTS: 5 archetypes (crunch/situp/etc. via CrunchAnalyzer × 5 slugs; plank; shoulder press × 6 slugs; burpee × 3 slugs). Total ~15 of 138.**
- **Exercises with pacing feedback: 5 (the CrunchAnalyzer family).**
- **Exercises where rep counting is "likely reliable": ~55 of 138 (squat family, push-up family, curl family, press family — all assume good camera setup).**

---

## 7. Critical Questions — Direct Answers

### 1. Is form correction actually implemented?
**Partially.** Form-correction TTS exists for crunch, plank, shoulder press (partial-rep only), and burpee (phase cue). For 13 of 17 analyzer classes, `formWarning` is hard-coded to `null`. The skeleton is rendered for ALL exercises but **the analysis behind the skeleton is rep-counting-only** for the majority.

### 2. If yes — why silent?
The analyzer for the active exercise returns `formWarning: null`. The camera screen at line 405 only speaks when `warning != null`. There's no fallback "generic" coaching voice when an analyzer has nothing to say.

### 3. If no — where was the illusion created?
- **The PosePainter** renders all landmarks at full opacity regardless of likelihood — looks like confident tracking.
- **The marketing string "FormAI"** implies form analysis.
- **The 3-second intro voice line** sets the expectation that an AI coach is "engaged."
- **The HAZIRLAN! countdown overlay** is high-production-value, increasing expectation.

### 4. Is voice coach feature-complete?
**No.** It is functional but minimal. Active speech surfaces: prep start, rest start, session complete, ~3 per-rep / per-form analyzer paths. There are no mid-set heartbeat cues, no rest-tick cues, no breathing cues, no encouragement during exercises that route to non-SilentHold analyzers.

### 5. Are rep counters trustworthy?
**Conditionally.** For the ~5 strength-archetype analyzers (squat, push-up, pull-up, curl, press) on a good camera setup, they're reasonable. For:
- Russian twist, chest fly, jumping jack: camera-orientation-dependent.
- Mountain climber: 2D-blind to depth axis.
- Russian twist, jumping jack: threshold tuning may miss casual reps.
- Anything routed to SilentHoldAnalyzer: **does not count reps at all**.

### 6. Are timed workouts trustworthy?
**Plank itself is correctly time-based.** The timer is independent of the analyzer. But:
- Flutter kick and mountain climber emit per-rep haptics on each ankle flip during a 30 s hold — feels chaotic.
- Several exercises that should be timed are mis-typed as rep-based in the DB (the STUCK list above).

### 7. Which exercises are broken?
See the Coverage Matrix §6. Most acute:
- **Stuck rep-based exercises (all 11+):** bird_dog, glute_bridge, hip_thrust, single_leg_glute_bridge, prone_y_raise, prone_t_raise, single_leg_rdl, frog_pump, wall_walk, pike_walk, scapular_wall_slide, kettlebell_swing, dumbbell_clean, cat_cow, scapular_pull_up.
- **Wrong-analyzer:** dead_bug (uses FlutterKickAnalyzer — quasi-static doesn't match), russian twist (camera-orientation), mountain climber (2D z-blind).

### 8. Which systems are fake / partial / unfinished?
- **Form correction** — partial (4 of 17 archetypes).
- **Pacing feedback** — partial (1 of 17 — crunch only).
- **Contextual cues** — partial (2 of 17 — burpee, silent-hold).
- **Camera positioning calibration** — absent.
- **Confidence visualization** — absent.
- **Mid-set voice coaching** — absent.
- **Rest-tick voice cues** — absent.
- **Timer-mode haptic suppression** — broken (heavy haptics during timed exercises).
- **Hip-hinge / scapular / mobility analyzers** — completely absent (acknowledged in strategy doc backlog).

### 9. What is production risk?
**High to critical.**
- App Store smoke tests have >50% chance of hitting a stuck slug on day 1 of a fresh personalized plan.
- Users complete a session feeling the AI is broken or absent.
- Reviewers rating "form analysis AI" against actual behaviour will downgrade.
- Refund/uninstall risk on the first session is elevated.

### 10. Would users trust this system?
**Not on first session.** The cognitive dissonance between "confident skeleton + AI marketing" and "silent voice + uncounted reps" is the product's single biggest credibility risk.

---

## 8. Recommended Engineering Sequence (severity-ordered, no implementation in this PR)

### TIER S — Pre-launch must-fix (blocks credibility)
1. **Fix the stuck rep-based slugs.** Two paths:
   - SQL-only path: convert the 11+ stuck repBased slugs to `timeBased` with sensible durations (30–45 s for bodyweight movements). No app code change.
   - Hybrid path: add a "Bitti" button to the camera control panel for SilentHoldAnalyzer-routed exercises; surface an in-screen explanation chip "Bu egzersizde rep otomatik sayılmaz".
2. **Gate `repJustCompleted` haptics + speech by `exercise.type == repBased`.** Time-based exercises should never fire `AppHaptics.heavyImpact()` on rep boundaries.
3. **Add at least one form-correction line per major archetype** (squat, push-up, lunge, curl, lateral raise). Even one line per archetype meaningfully improves perception.
4. **Confidence-aware skeleton.** PosePainter should fade joints below 0.3 likelihood. Makes "low-confidence" visible to users.

### TIER A — High-impact polish (closes the silence gap)
5. **Mid-set voice heartbeat.** A 12 s cooldowned rotating coach line during the active set, gated by category.
6. **Rest-tick cues.** Halfway-rest + 5-seconds-left lines.
7. **Add pacing feedback to all rep-based analyzers** (not just crunch). Copy the CrunchAnalyzer mechanism.
8. **Per-exercise prep speech variation.** Don't say "Sıradaki hareket" between sets of the same exercise.
9. **Eager `AudioFeedback.init()`** at app boot, hoist to a Riverpod provider.

### TIER B — Real ML upgrades (multi-day)
10. **Build `HipHingeAnalyzer`** for the hip-thrust / glute-bridge / kettlebell family. ~120 LOC.
11. **Build `ScapularAnalyzer`** for prone Y/T raises, scapular wall slide.
12. **3D-aware MountainClimberAnalyzer** using BlazePose `landmark.z`.
13. **Camera-orientation calibration step** before the active set begins.
14. **Replace `_tts.stop()`-on-every-speak with a priority queue.**

### TIER C — Hardening
15. **Frame-confidence consecutive-violation gating** for plank false-positives.
16. **Pixel-scale normalization** for FlutterKick's `minDelta`.
17. **Camera-image dispose race** — move `ref.read` outside the await pipeline.
18. **Decay-windowed min/max** for BurpeeAnalyzer's self-calibration.
19. **Split `restCountdownProvider`** to reduce per-tick rebuild cost.

---

## 9. What This Audit Did NOT Examine (and why)

- **Native ML Kit version / model variant.** Recent commit `4c0ea38` strips the accurate pose-landmark model, leaving the base model. Whether the base model's accuracy degradation on edge-case poses is acceptable was outside the scope; deserves its own measurement-driven study.
- **Network behaviour for exercise catalogue.** The catalogue fetch's empty-pool fallback to "30 rest days" is documented and looked correct on read. Not stress-tested under flaky network.
- **Workout completion analytics consistency.** The `_pendingExerciseLogs` accumulator was glanced at — looks correct, but a full audit of the analytics fan-out (session_log, analytics_service, gelisim_tab roll-ups) was deferred.
- **Live Activity sync paths.** Read at line 651-694 of workout_camera_screen.dart — no apparent issues but iOS-only and not deeply traced.

---

## 10. Closing — Truth, Not Engineering

The system is not lying — but the UX is wallpapering over what the analyzers can't do. The strategy doc (`reports/archive/ml-detection-strategy.md` §1) admits this explicitly: "the user is not lied to about a rep count we can't compute reliably." That's an internal-developer claim. From the user's perspective:

- The skeleton always draws → the user believes they are being analyzed.
- The TTS goes silent → the user believes the AI gave up.
- The rep counter stays at 0 on bird-dog/glute-bridge/hip-thrust → the user believes the AI is broken.

The fix is partly engineering and partly product copy: either upgrade the analyzers to match the promise, or downgrade the promise to match the analyzers. The current product positioning ("FormAI", "AI form coach", "Cihazında Analiz") is between the two.

This audit is read-only. Engineering fixes are queued in §8 by tier. The first three items in TIER S are necessary before any external review or launch milestone — anything less leaves the largest user-trust gaps unaddressed.

— End of audit —
