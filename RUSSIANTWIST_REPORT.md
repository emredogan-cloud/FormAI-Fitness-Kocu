# RussianTwist Z-Awareness — Tier B.10 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §3 C4 (camera-orientation invariance), §5 U4 (Russian twist camera-orientation-dependent), §8 Tier-B B-10.

## Problem

The previous `RussianTwistAnalyzer` measured the **x-offset** between the shoulder midpoint and the hip midpoint. This works for users sitting **facing the camera**, but most Russian twists are filmed with the camera **placed to the side** — the natural setup because the user sits on the floor with legs forward and twists left-right. In that configuration:

- The torso rotates around its vertical axis.
- The shoulder midpoint moves **toward and away from the camera** (z-axis).
- The shoulder midpoint barely moves left/right (x-axis).

Result: side-camera Russian twists registered essentially no reps. The analyzer was effectively a no-op for the typical user setup.

## Solution

Compute **both** x-offset and z-offset per frame, and **elect the dominant axis** as the signal:

```dart
final xOffset = shoulderMidX - hipMidX;
final zOffset = shoulderMidZ - hipMidZ;
final useZ = zOffset.abs() > xOffset.abs();
final offset = useZ ? zOffset : xOffset;
```

Then the existing state-machine and threshold logic runs against `offset` unchanged.

### Why dominant per-frame, not "lock at start of set"

A user who shifts their camera mid-set (e.g. propping the phone differently between sets) doesn't need the analyzer to relearn — the dominant axis is re-elected on every frame. The cost is one extra comparison per frame; the benefit is robustness to setup changes.

### Why BlazePose's z works here

BlazePose's z is image-relative depth (approximately on the same scale as x/y). Empirically the z-offset for a Russian twist sweep covers a similar magnitude range to what the x-offset covered for the front-camera case. The same `twistFraction × shoulderWidth` threshold works on both axes — no separate tuning needed.

### Older devices without z support

ML Kit may return z = 0 for all landmarks on older devices that don't fully support BlazePose's depth output. In that case `zOffset` is always 0, `useZ` is always false, and the analyzer collapses to the original x-only behavior. Front-camera users keep working.

## Files changed
- `lib/features/workout/services/core_analyzers.dart` — `RussianTwistAnalyzer.analyze` adds the z-offset computation and dominant-axis pick. ~15 LOC delta.

## Behavior changes
- Side-camera Russian twists now count reps. (Previously they did not.)
- Front-camera Russian twists keep working exactly as before — the per-frame dominant-axis pick lands on x.
- Oblique camera angles get the larger of the two signals on each frame, which gracefully handles intermediate setups.
- `medicine_ball_russian_twist` shares the analyzer and gets the same fix.

## Validation
- **Side camera, full sweep:** rep counter ticks per side-flip. The z-axis swings cleanly past ±0.18 × shoulderWidth in both directions.
- **Front camera, full sweep:** rep counter ticks per side-flip. The x-axis signal dominates; identical to pre-Tier-B.10 behavior.
- **45° camera, partial signal on both axes:** the larger axis per frame drives the analyzer; reps still count.
- **Stationary torso (user pauses to breathe):** neither axis crosses the threshold; no false rep.
- **Older device with z=0 across the board:** falls back to x-only signal; matches the pre-Tier-B.10 behavior.
