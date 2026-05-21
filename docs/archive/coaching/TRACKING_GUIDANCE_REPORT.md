# Tracking Guidance — Tier A.6 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §8 Tier-A camera-positioning step, §5 U1 follow-up (skeleton fade is honest, but doesn't tell the user *what* to do).

## Problem

Tier S.4 made the skeleton fade with landmark likelihood — the user can now *see* that tracking is uncertain. But uncertainty is silent: there's no audible cue saying "you're partly out of frame" or "step closer." A user struggling with camera placement gets a degraded analysis silently.

## Solution

`CoachVoice.onPoseFrame(Pose? pose)` is called from `_processImage` for every analyzed frame. It computes a mean likelihood over the **rep-relevant subset** of landmarks (shoulders, hips, knees, ankles, wrists, elbows — 12 points) and counts the frame as "low-confidence" when the mean drops below `0.35`. After `30` consecutive low-confidence frames (~2 s at the screen's ~15 FPS effective rate), it emits one Turkish positioning cue at `SpeechPriority.cue`.

### Threshold rationale

| Constant | Value | Why |
|---|---|---|
| `_lowConfidenceThreshold` | 0.35 | Just below the analyzers' per-landmark reject threshold of 0.40. A frame this coach calls "low" is exactly the same frame the rep counter is silently rejecting. |
| `_lowConfidenceFramesThreshold` | 30 frames (~2 s) | A reach off-screen for a dumbbell, a hand passing in front of the chest, or one transient occluded frame doesn't trigger the cue. Only sustained tracking failure does. |
| `_trackingCueCooldown` | 45 s | The user gets ONE coaching cue per 45 s window. Camera placement is a one-time correction — nagging at 5 s intervals is harassment. |
| Tracked subset | 12 landmarks | Full 33-point ML Kit set would dilute the signal with face/foot points the analyzers don't read. The 12-point subset is exactly what every analyzer in this codebase keys off. |

### Rotation pool

Three Turkish lines rotated round-robin so a user who triggers this multiple times in one session hears actionable variety, not the same nag:

1. "Kameraya biraz daha yaklaş, tüm vücudun görünmeli."
2. "Pozisyonunu ayarla, kamera vücudunu net görsün."
3. "Bir adım geri çekil, vücudun çerçeveye sığsın."

### Priority interplay

- **`SpeechPriority.cue` (4)** — outranks ambient mid-set heartbeats (1) and encouragement pacing (2), but yields to `warning`. A form warning means the analyzer IS reading the pose — that's a different problem and the user should hear the form fix, not "step back."
- **Phrase-level cooldown 30 s** — backup defence against the analyzer-side cooldown failing.
- **`_lowConfidenceStreak` reset on emit** — after a cue fires, the streak counter resets so the *next* sustained low-confidence window has to re-cross the 30-frame threshold before another cue fires. Combined with the 45 s wall-clock cooldown, this means the user can correct their position, hear the cue, fail to correct, and be reminded again 45 s later — no faster.

### Idle / preparing / resting

`onPoseFrame` is called from `_processImage`, which is gated by the same `isPreparing` / `isResting` / paused early-returns as the analyzer. So no tracking-guidance cue can fire during the HAZIRLAN! countdown, during rest windows, or while the user has paused — periods where the user may be deliberately off-camera and we'd just be nagging.

## Files changed
- `lib/features/workout/services/coach_voice.dart` — `onPoseFrame` method + state fields + tracking constants + 3-entry rotation pool. ~80 LOC.
- `lib/features/workout/presentation/workout_camera_screen.dart` — 5-line addition in `_processImage` to pipe pose into `_coach.onPoseFrame`.

## Behavior changes
- A user standing too close, too far, or partially out of frame hears one cue after ~2 s of bad tracking.
- Subsequent cues respect a 45 s wall-clock cooldown.
- Cues rotate so the user doesn't hear the same string repeatedly.
- The cue's priority (`cue`) ensures it lands cleanly during a noisy moment (pre-empts ambient/encouragement, defers to warning).
- Brief occlusions (< 2 s) silently restart the streak — no false positives.

## Validation surface
- **User stands too close to camera, knees out of frame:** mean likelihood drops below 0.35 (knees ~0.0). After ~2 s, hears "Bir adım geri çekil, vücudun çerçeveye sığsın."
- **User reaches off-screen for water mid-rest:** no cue (gated by `isResting`).
- **User does a clap-pushup with brief wrist occlusion mid-air:** streak resets on the next clean frame. No cue.
- **User's lighting is so bad ML Kit is unreliable for the whole set:** one cue at ~2 s, second cue 45 s later if condition persists. Maximum 2 cues per 90 s set.
- **User has good lighting but the analyzer-side likelihood gate still fires false negatives:** the tracked subset's mean stays above 0.35 → no tracking cue → user just sees the skeleton fade-in (Tier S.4) on whichever joint is uncertain.
