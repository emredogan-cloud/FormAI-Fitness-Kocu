# JumpingJack Hysteresis — Tier B.9 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §3 C3 (demanding thresholds, low fatigue tolerance), §5 U7 (camera-shake false positives).

## Problem

The previous `JumpingJackAnalyzer` used a single-threshold open/close commit:
- `spreadRatio = 1.4` → legs must spread to 1.4× shoulder width.
- `armRatio = 0.6` → wrists must rise 0.6× shoulder width above shoulders.

Two issues compounded:

1. **Tight thresholds for fatigued users.** A user 30 seconds into a 60-second jumping jack hold rarely clears 1.4× spread or 0.6× arm rise. Their jacks were silently uncounted.
2. **No hysteresis.** A user oscillating right at 1.4× spread (some reps just over, some just under) toggled between OPEN and CLOSED on every frame. The 500 ms `minRepInterval` rate-limited the rep counter but did NOT prevent state-flip noise from accumulating misclassifications.

## Solution

Replace the single open/close boundary with **separate open and close thresholds** for each pair (legs, arms), creating a hysteresis gap that absorbs frame-to-frame jitter:

| Gate | Open commit | Close commit | Gap |
|---|---|---|---|
| Leg spread | `> 1.25 × shoulderWidth` | `< 0.95 × shoulderWidth` | 0.30 |
| Arm rise | `> 0.50 × shoulderWidth` | `< 0.20 × shoulderWidth` | 0.30 |

Both pairs must clear their open gate to commit OPEN. Both pairs must clear their close gate to commit CLOSED. Neither condition true → state holds (this is the natural hysteresis).

### Effect on accuracy

- A fatigued user spreading legs to 1.30× and raising arms to 0.55× — previously didn't count (below 1.4 and 0.6). Now both clear their open gates → rep commits.
- A user oscillating around 1.27× spread frame-to-frame — previously flipped OPEN/CLOSED every frame. Now stays OPEN once committed; only crosses back below 0.95× (a real return to the closed position) before re-committing CLOSED.
- A camera shake jiggling the wrist landmark by ~50 px — previously could re-cross the single arm gate. Now needs to drop below 0.20× to commit CLOSED, which a real shake won't do.

### Likelihood gate added

The previous analyzer had no minimum-likelihood gate. A low-confidence frame from a shaky setup could trip the thresholds purely from landmark noise. Added a min(all six landmarks) ≥ 0.4 check at the top of `analyze` — same gate used by every other analyzer in this file.

## Files changed
- `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart` — `JumpingJackAnalyzer` constructor fields restructured (4 thresholds instead of 2), `analyze` body rewritten around the two-gate logic + likelihood gate. ~40 LOC net.

## Behavior changes
- Fatigued / lazy jumping jacks now count (open commit at 1.25× spread, not 1.4×).
- Borderline reps don't oscillate the state machine.
- Camera-shake noise can no longer false-positive a rep — the close gate is far below where shake noise lands.
- The hysteresis gap (0.30 for both pairs) is enough to absorb typical frame jitter while still letting a clean rep complete a full open-close cycle.

## Validation
- **Fast clean jumping jacks** (clearly clearing 1.4 spread, 0.6 arms): count exactly the same as before. The looser open gate doesn't cause double-counting because hysteresis blocks re-entry until the user is fully back to CLOSED.
- **Lazy jumping jacks** (1.30 spread, 0.55 arm rise): previously uncounted, now counted.
- **Borderline jumping jacks oscillating right at the previous threshold**: state stays committed until the user fully closes — no toggle storm.
- **Camera held in shaky hand, user not moving**: no false reps — the close gate is far enough below idle landmark noise.
