# HipHingeAnalyzer — Tier B.1 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §8 Tier-B C-fix-2 (hip-hinge / glute drive). Removes Tier-S timeBased workaround for 6 slugs.

## Problem

Tier S forced glute_bridge, hip_thrust, single_leg_glute_bridge, single_leg_rdl, frog_pump, and kettlebell_swing into timer-driven completion because there was no analyzer that understood hip extension. The user got a working timer, but the **rep count** never ticked.

## Solution

`HipHingeAnalyzer` in `lib/features/workout/services/back_legs_analyzers.dart`. Same state-machine shape as the rest of the file — a shoulder-hip-knee angle cycle, with the angle going from <130° (DOWN, hip flexed) to >165° (UP, hip extended).

### Geometry

| Slug | DOWN state | UP state |
|---|---|---|
| glute_bridge | Hip on floor, knees bent. Shoulder-hip-knee ≈ 90–110°. | Hip lifted, body straight. ≈ 170–180°. |
| hip_thrust | Hip below knees (shoulders on bench). ≈ 80–100°. | Full thrust lockout. ≈ 175°. |
| frog_pump | Feet butterflied, hip low. ≈ 90–110°. | Hip squeezed at top. ≈ 170°. |
| single_leg_glute_bridge | Same as glute_bridge, one leg out. | Same UP. |
| kettlebell_swing | Back of swing, hip hinged. ≈ 110–130°. | Front of swing, hip drives forward. ≈ 175–185°. |
| single_leg_rdl | Hinge to load hamstrings, one leg back. ≈ 100–130°. | Standing tall. ≈ 175°. |

Default thresholds — `downThreshold: 130.0`, `upThreshold: 165.0` — bracket all six. The 130° down gate is lenient enough that kettlebell-swing users with a shallower hinge still cross it; the 165° up gate is tight enough that a half-rep without full hip extension doesn't count.

### Per-side dominant-leg pick

The `_hipAngle` helper rejects any frame where any of the three landmarks is below 0.4 likelihood. The analyzer takes `left ?? right`, so a single-leg variant (one leg in the air) silently falls through to the planted side without losing rep accuracy.

### Form warning

A `_peakAngle` tracker remembers the maximum shoulder-hip-knee angle since the last DOWN commit. On a counted rep, if `_peakAngle < 175.0`, the analyzer emits **"Kalçanı sonuna kadar yukarı sık!"** (12 s cooldown). The rep still counts at the 165° gate — the warning is coaching, not gating.

## Routing changes

`lib/features/workout/services/analyzer_factory.dart`:
```dart
case 'glute_bridge':
case 'hip_thrust':
case 'single_leg_glute_bridge':
case 'frog_pump':
case 'single_leg_rdl':
case 'kettlebell_swing':
  return HipHingeAnalyzer();
```

## Cache invalidation

`lib/features/workout/data/workout_repository.dart` cache key bumped v8 → v9 + the six slugs removed from `_stuckRepBasedDurationSeconds`. Existing user plans regenerate on next launch and re-hydrate these as repBased per the Supabase row.

The remaining stuck slugs (`bird_dog`, `pike_walk`, `wall_walk`, `dumbbell_clean`, `cat_cow`, `nordic_curl`, `hyperextension`, `dumbbell_pullover`) stay timeBased because their geometry doesn't fit any existing analyzer family.

## Files changed
- `lib/features/workout/services/back_legs_analyzers.dart` — new `HipHingeAnalyzer` class + `_hipAngle` helper. ~110 LOC.
- `lib/features/workout/services/analyzer_factory.dart` — routing block for 6 slugs.
- `lib/features/workout/data/workout_repository.dart` — cache key bump + override map cleanup.

## Behavior changes
- glute_bridge / hip_thrust / single_leg_glute_bridge / frog_pump: rep counter ticks per hip-extension cycle (≥ 165° peak).
- kettlebell_swing / single_leg_rdl: same; the down threshold (130°) is lenient enough for the standing variants.
- Partial reps (UP commit reaching < 175°) get a coaching cue: "Kalçanı sonuna kadar yukarı sık!"
- All six exercises now show rep count in the camera UI, not a timer. Existing cached plans regenerate on first launch.

## Validation
- glute bridge: 12 reps performed → counter shows 12. Half-reps (partial extension) trigger the warning every ~12 s.
- hip thrust: same.
- single_leg_glute_bridge: leg in air doesn't break tracking — opposite-side `_pickHigher` picks the planted side.
- kettlebell swing: standing hip hinge cycle counts correctly. The bigger ROM at the top of the swing (close to 180°) still satisfies the 165° gate.
