# Camera Calibration — Tier B.4 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §3 C4 (camera-orientation invariance), §8 Tier-B C-fix-6 (lightweight calibration).

## Problem

Tier A.6 added sustained-low-confidence tracking guidance (one cue after ~2 s of bad tracking), but the cue only fires AFTER the user has been struggling — by then they've already done a few half-reps. The audit asked for a lightweight check at the *start* of every set: is the user even visible to the camera before they begin?

## Solution

A 20-frame (~1.3 s at the ~15 FPS effective rate) probe that runs in `CoachVoice.onPoseFrame` immediately after `startSet`. The probe accumulates two metrics:

1. **Mean landmark likelihood** over the 12-point tracked subset (shoulders/hips/knees/ankles/wrists/elbows — exact set the analyzers read).
2. **Mean shoulder span / frame width ratio** — how big the user's shoulders are relative to the input frame. A low ratio means the user is far away or mostly out of frame.

At window close (frame 20), the probe fires one of two cues, or nothing:

| Verdict | Phrase | Priority |
|---|---|---|
| `meanLikelihood < 0.55` | "Pozisyonunu ayarla, tüm vücudun görünmeli." | cue |
| `meanShoulderRatio < 0.10` AND likelihood passed | "Kameraya biraz daha yaklaş, vücudun daha net görünsün." | cue |
| Both pass | (silent) | — |

The likelihood check is evaluated first — if the camera can't see the body cleanly, no amount of distance adjustment will help. After emitting a calibration cue, `_lastTrackingCue` is stamped to the current time so the regular Tier-A.6 tracking-guidance scheduler doesn't immediately fire another redundant cue.

## Why a probe, not a wizard

The brief said "No heavy wizard. Light." This implementation:

- Has zero UI surface — no overlay, no countdown, no "Position yourself for analysis." The probe runs invisibly during the first ~1.3 s of the active set.
- Adds one method parameter (`frameWidth`) and four accumulator fields. No new screens.
- Resets cleanly in `startSet` so every new set re-probes.

## Why this complements Tier A.6, not replaces it

- **Tier A.6** = continuous monitoring during the entire set. Fires when sustained low confidence appears mid-rep (user steps out of frame, lights change, etc.).
- **Tier B.4** = one-shot at set start. Fires when the user is poorly positioned BEFORE doing any reps. Different temporal window, different message phrasing ("Pozisyonunu ayarla" vs "Bir adım geri çekil").

The two paths share state — after a calibration cue fires, the tracking-guidance cooldown is bumped to avoid double-firing within seconds.

## Files changed
- `lib/features/workout/services/coach_voice.dart` — new state fields, calibration constants, accumulators inside `onPoseFrame`, `_emitCalibrationVerdict` method. ~80 LOC net.
- `lib/features/workout/presentation/workout_camera_screen.dart` — pass `image.width.toDouble()` to `_coach.onPoseFrame` (one-line change).

## Behavior changes
- Every active-set transition triggers a 20-frame pose-quality probe.
- If the user is poorly tracked or too far away, they hear ONE positioning cue ~1.3 s into the set.
- If both metrics pass, the probe is invisible — user just gets the standard intro speech and starts repping.
- The cue priorities and dedupe (`SpeechPriority.cue` + 25 s cooldown) preserve Tier-A's "no spam" guarantee.

## Validation
- **Good setup, full body visible:** probe runs silently. User hears mid-set heartbeat as usual.
- **Camera too far away, user takes < 8 % of frame width:** at ~1.3 s into the first set, hears "Kameraya biraz daha yaklaş, vücudun daha net görünsün."
- **User off to one side, half-body in frame:** mean likelihood drops below 0.55, hears "Pozisyonunu ayarla, tüm vücudun görünmeli."
- **No pose detected for ~1.3 s (lens covered, lights off):** mean likelihood = 0, fires the position cue. Tracking-guidance scheduler then sleeps for its 45 s cooldown.
- **First set's probe fires a cue, second set begins:** new probe re-runs (state is reset in `startSet`). User who corrected after the first cue won't hear a redundant one on the second set.
