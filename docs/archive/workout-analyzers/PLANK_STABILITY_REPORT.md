# Plank Confidence Gating — Tier B.5 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §5 U5 (PlankAnalyzer transient false warnings).

## Problem

`PlankAnalyzer` was firing "Kalçanı düz tut, plank pozisyonunu koru!" on a SINGLE-FRAME line-angle violation. The 8 s cooldown prevented spam after one false fire, but the user still heard one wrong warning per ~8 s if the ankle landmark was noisy — common because the ankle is at the edge of the frame and is the least-reliable joint in the line check.

## Solution

Require **5 consecutive frames** with `shoulder-hip-ankle < 155°` before emitting the warning. The streak counter:

- **Increments** on every violating frame.
- **Resets to 0** on every clean frame (above the threshold).
- **Resets to 0** after firing a warning (combined with the existing 8 s cooldown, this prevents re-spamming).
- **Holds** (neither increments nor resets) when a frame produces no usable triple of landmarks — a single dropped frame shouldn't wipe an accumulating real violation.

5 frames at the camera screen's ~15 FPS effective rate = ~0.33 s of sustained sag. Long enough to absorb single-frame ankle jitter; short enough that real sag is still surfaced within a third of a second.

## Files changed
- `lib/features/workout/services/core_analyzers.dart` — `PlankAnalyzer` gains a `_violationStreak` counter + `_violationStreakThreshold` constant. ~20 LOC net.

## Behavior changes
- Single transient frames where the ankle landmark jitters no longer fire false "Kalçanı düz tut" warnings.
- Real sustained sag still warns within ~0.33 s.
- The existing 8 s warning cooldown is preserved, so even pathological cases can't speak more than once per 8 s.

## Validation
- **User in good plank, ankle landmark briefly noisy (1 frame at 140°):** streak = 1, no warning. Next clean frame resets streak to 0.
- **User sags hard for 1 s:** streak hits 5 within ~0.33 s, warning fires, streak resets, cooldown holds for 8 s.
- **User sags slightly for 0.2 s then recovers:** streak peaks at ~3, never crosses 5, no warning. Clean frame resets.
- **Pose detection drops (no shoulder/hip/ankle for one frame) during a real sag:** streak holds rather than resetting; next valid frame continues accumulating.
