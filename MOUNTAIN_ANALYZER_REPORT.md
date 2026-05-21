# MountainClimberAnalyzer 3D Upgrade — Tier B.3 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §3 C2 (2D-blind to depth), §8 Tier-B C-fix-4.

## Problem

The previous `MountainClimberAnalyzer` measured 2D pixel distance from knee to same-side shoulder. In the typical front-facing camera setup the user is in plank position facing the camera; the knee drives **toward the camera** (along the z-axis), so its 2D coordinates barely change while its image size grows. The analyzer systematically missed reps.

## Solution

Add a z-axis signal that is the **primary** active-knee detector, with the previous 2D-distance check preserved as a fallback for side-camera setups where z is unreliable. Both signals OR together so a knee triggering either path counts as active.

### Primary z-signal

BlazePose returns a per-landmark `z` that is approximately on the same scale as x/y (image-relative depth, with the hip plane near z ≈ 0). For mountain climbers facing the camera:

- knee back in plank → `knee.z ≈ hip.z` (knee in the same depth plane)
- knee driven forward toward chest → `knee.z < hip.z` (knee closer to camera)

We measure per-side `hip.z - knee.z` (positive when the knee is closer to camera) and compare against `torsoLength × zFraction`. Default `zFraction = 0.25` — a knee that's a quarter of torso length closer to camera than the hip plane counts as "active in z."

### 2D fallback (unchanged)

The original signal is retained verbatim:
```dart
final leftActive2D = _distance(lk, ls) < torsoLength * activeFraction; // 0.55
```

This catches the user who films from the side. From that camera angle, the depth signal is approximately zero (knee moves in the camera plane), so z-fraction never triggers. The 2D distance still shrinks because the knee gets visually closer to the shoulder.

### Combined gate

```dart
final leftActive = leftActiveZ || leftActive2D;
```

A knee that's active in **either** axis is active. No runtime camera-orientation calibration needed — both paths run simultaneously, cheap.

## Rep state machine

Unchanged from the previous implementation: a side is committed when only its knee is active, and a side-flip (L↔R) increments the rep counter. The 350 ms `minRepInterval` floor still applies.

## Files changed
- `lib/features/workout/services/core_analyzers.dart` — `MountainClimberAnalyzer` reworked. New `zFraction` constructor field, default 0.25. ~30 LOC delta net.

## Behavior changes
- Front-camera mountain climbers now count correctly (previous behaviour: systematic undercount).
- Side-camera mountain climbers retain the original behaviour.
- 45° / oblique camera angles get the union of both signals — more permissive, fewer missed reps.

## Validation
- **Front camera, in plank, drive knees alternately to chest:** rep counter ticks per side flip. Each knee that comes forward by ≥ 25 % of torso length lights the z-signal.
- **Side camera, same exercise:** rep counter ticks via the unchanged 2D-distance fallback.
- **Slow / controlled climber (knee comes only partway):** if neither signal crosses the active threshold, no rep counts (correct — half-reps were missed before too, and they should be).
- **Camera with extreme zoom or no z support (older device fallback):** ML Kit returns z = 0 for all landmarks; z-signal never fires; 2D fallback carries the analyzer.
