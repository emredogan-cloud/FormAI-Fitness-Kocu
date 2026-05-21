# Pacing System — Tier A.4 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §2 (voice silence during timed holds), §8 Tier-A milestone density.

## Problem

Rep-based exercises already had "Yarıladın!" + "Son iki tekrar!" milestones via `workout_camera_screen.dart`. Time-based exercises (plank, flutter kick, side plank, hollow hold, etc.) emitted **only** "Süre doldu, harika!" when the timer hit zero. A 40-second plank was silent from t=4 (intro ends) until t=40 (timer complete) except for the analyzer's hip-sag warnings.

## Solution

`CoachVoice.onTimerTick(remainingSeconds)` is called from the camera screen's per-second countdown decrement (`_resumeWorkoutTimer`). It fires three single-shot pacing checkpoints derived from the timed set's original duration:

| Checkpoint | Gate | Phrase | Priority |
|---|---|---|---|
| `halfway` | total ≥ 10 s AND remaining == ⌊total/2⌋ | "Yarıladın, sık dişini ve dayan!" | `encouragement` |
| `final-10` | total ≥ 20 s AND remaining == 10 | "Son on saniye, bırakma!" | `encouragement` |
| `final-5` | total ≥ 8 s AND remaining == 5 | "Beş saniye, dayan!" | `encouragement` |

### Gating logic

- Each checkpoint is gated by the minimum total duration that makes the cue read as a real milestone. A 12-second plank skips "Son on saniye" (10 s remaining ≈ first half) but still hits "Beş saniye". A 6-second hold skips everything except the natural "Süre doldu" finale.
- A `Set<String> _firedTimedCheckpoints` tracks which checkpoints have already played for the current set. Cleared in `startSet`/`endSet`. Pause/resume preserves the set — the camera screen's `_resumeWorkoutTimer` doesn't reset `_secondsRemaining`, so the checkpoints can't re-fire across a pause/resume cycle.

### Priority interplay

Pacing checkpoints fire at `encouragement` priority, which outranks ambient mid-set heartbeats (`ambient`) but yields to milestones, cues, and warnings:

- Mid-set ambient ("Karnını sık...") was already speaking when the halfway gate fires → halfway pre-empts → ambient drops off.
- Form warning ("Kalçanı yukarı tut!") was already speaking when the halfway gate fires → halfway queues behind warning → warning finishes, halfway plays.
- Timer-complete milestone ("Süre doldu, harika!") fires after the final-5 cue → milestone outranks encouragement → if final-5 is still mid-utterance it pre-empts; otherwise it just plays next.

### Camera screen wiring

The only change to `_resumeWorkoutTimer` was adding `_coach.onTimerTick(_secondsRemaining)` after the post-decrement `setState`. One line of new code; existing timer mechanics are untouched.

## Rep-based exercises

Rep-milestone announcements (target/2 + target-2) were already present and already correct. This commit doesn't add new rep-side beats. The mid-set heartbeat (Tier A.2) covers the previously-silent gaps between milestones for rep work.

## Files changed
- `lib/features/workout/services/coach_voice.dart` — `onTimerTick` method + `_firedTimedCheckpoints` set + `_fireOnce` helper.
- `lib/features/workout/presentation/workout_camera_screen.dart` — single-line addition inside `_resumeWorkoutTimer`.

## Behavior changes
- Timed sets ≥ 10 s now hear a halfway announcement.
- Timed sets ≥ 20 s hear a "Son on saniye" cue at exactly 10 s remaining.
- Timed sets ≥ 8 s hear a "Beş saniye, dayan!" cue at exactly 5 s remaining.
- Each cue plays at most once per set. Pause/resume does not re-fire.
- Shorter sets (e.g. 6 s) get only the natural completion sound — no false-milestone spam.

## Validation surface
- **Plank 40 s:** intro → ambient @18s → halfway @20s → "Son on saniye" @30s elapsed → "Beş saniye" @35s elapsed → "Süre doldu" @40s.
- **Wall sit 45 s:** intro → ambient @18s → halfway @22s (⌊45/2⌋=22 remaining = 23s elapsed) → "Son on" @35s → "Beş saniye" @40s → "Süre doldu" @45s.
- **Side plank 30 s:** intro → ambient @18s → halfway @15s elapsed → "Son on" @20s → "Beş saniye" @25s → "Süre doldu" @30s.
- **Short hold 8 s:** intro → "Beş saniye" @3s → "Süre doldu" @8s. (No halfway or "Son on" — duration too short.)
- **Pause mid-set:** checkpoints already fired stay fired; remaining ones still fire when their gate is crossed after resume.
