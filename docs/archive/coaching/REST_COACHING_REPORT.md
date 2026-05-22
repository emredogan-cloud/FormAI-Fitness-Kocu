# Rest-Phase Coaching — Tier A.3 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §1 B5 (no rest-tick cues), §8 Tier-A B-fix-2.

## Problem

Rest windows ran silently after the initial "Harika! Şimdi 30 saniye dinlenme." Once that one line finished (~2 s), the remaining 28–88 s of rest had no coaching, no recovery cue, no transition prep. The pre-Tier-A audit measured 1 spoken phrase per 30 s rest.

## Solution

`CoachVoice.startRest(int restSeconds)` is called from the camera screen's listener when `justStartedRest` is true and the active exercise is non-null. The coach captures `_restStartedAt` + `_restInitialSeconds`, clears `_firedRestCheckpoints`, and starts a 1 Hz `_restTimer` that decides per-tick what to emit.

### Three emission paths per rest

#### 1. Halfway beat (one-shot)
- **Gate:** total rest ≥ 30 s AND elapsed == ⌊total/2⌋
- **Phrase:** "Nefesini topla, yarısı geçti."
- **Priority:** `ambient`
- **Why gate at 30 s:** shorter rests skip straight to the rotating cue + final 10 s, because "halfway" on a 20 s rest is the wrong waypoint to call out.

#### 2. Final-10-second beat (one-shot)
- **Gate:** total ≥ 20 s AND remaining == 10
- **Phrase:** "On saniye sonra başlıyoruz, hazırlan."
- **Priority:** `encouragement`
- **Why higher priority than halfway:** transition prep — the user is about to begin the next set and this is the last signal they need to refocus.

#### 3. Generic rotating cue (every 18 s, while ≥ 12 s rest remains)
- **Gate:** `elapsed > 0 && elapsed % 18 == 0 && remaining >= 12`
- **Pool (4 entries, rotated round-robin):**
  - "Derin nefes al, kasları gevşet."
  - "Omuzlarını indir, posturanı topla."
  - "Su iç, vücudunu hazırla."
  - "Toparlan, sıradaki set yaklaşıyor."
- **Priority:** `ambient`
- **20 s phrase cooldown** to prevent same-line repeat within one long rest.
- **Why "≥ 12 s remains":** ensures the cue doesn't bump up against the next exercise's HAZIRLAN! countdown.

### Lifecycle integration

| Listener flag | Effect |
|---|---|
| `justStartedRest` | `_coach.endSet()` + `_coach.startRest(exercise.restDurationInSeconds)` |
| `justStartedPrep` | `_coach.endRest()` (prep always succeeds rest) |
| `justFinishedRest` (no prep — e.g. skipRest) | `_coach.endRest()` |
| `sessionJustCompleted` | `_coach.endSet()` + `_coach.endRest()` (defence-in-depth) |
| `dispose` / pop | `_coach.dispose()` → cancels rest timer |

### Density (60 s rest example)

| t (s) | Surface | Played? |
|---|---|---|
| 0 | "Harika! Şimdi 60 saniye dinlenme." (milestone, from camera screen) | YES |
| ~2 | (milestone ends) | — |
| 18 | Ambient: "Derin nefes al, kasları gevşet." | YES |
| 30 | Halfway: "Nefesini topla, yarısı geçti." | YES |
| 36 | Ambient: "Omuzlarını indir, posturanı topla." | YES |
| 48 | (no emit — wraps below the 18s gate; only fires at multiples of 18) | — |
| 50 | Final-10: "On saniye sonra başlıyoruz, hazırlan." | YES |
| 54 | (would be ambient but remaining=6 < 12 — skipped) | — |
| 60 | Rest ends; prep begins; "Sıradaki hareket: ..." | YES |

Total: ~5 spoken phrases across the 60 s rest. Up from 1 pre-Tier-A.

### Short-rest example (20 s rest)

| t (s) | Surface | Played? |
|---|---|---|
| 0 | "Harika! Şimdi 20 saniye dinlenme." | YES |
| 10 | Final-10: "On saniye sonra başlıyoruz, hazırlan." | YES |
| 18 | (ambient would fire here but remaining = 2 < 12 — skipped) | — |
| 20 | Rest ends | — |

The 20 s rest hits the halfway gate's `total >= 30` clause (false → skipped), runs into the final-10 gate (true → fires), and the ambient-rotation 18 s mark hits with only 2 s remaining (blocked by the `>= 12` guard). Clean.

## Files changed
- `lib/features/workout/services/coach_voice.dart` — `startRest` / `endRest` / `_restTick` / `_restRotation` + state fields. `_fireOnce` accepts an optional fired-set parameter so rest checkpoints share the same helper.
- `lib/features/workout/presentation/workout_camera_screen.dart` — 4-line additions inside the existing session listener: start rest on `justStartedRest`, end rest on `justStartedPrep` / `justFinishedRest` / `sessionJustCompleted`.

## Behavior changes
- Rest windows are no longer dead air.
- 30+ s rests get a halfway beat. 20+ s rests get a "10 saniye" cue. Long rests (60–90 s) get rotating ambient encouragement at 18 s intervals.
- All beats respect the queue's priority pre-emption — a form warning from the next exercise's intro flow (e.g. the user is already in plank position before HAZIRLAN! starts) still lands cleanly.
- Skipping rest (`skipRest` button) cancels everything in flight.
