# ScapularAnalyzer — Tier B.2 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §8 Tier-B C-fix-3 (scapular work). Removes Tier-S timeBased override for 3 slugs.

## Problem

prone_y_raise, prone_t_raise, and scapular_wall_slide were silent-routed in Tier-S because their geometry doesn't fit any of the standard analyzers — small ROM, scapular plane movement, often face-down. Tier-S forced them to timeBased (30 s each) so the user wasn't stuck.

## Solution

`ScapularAnalyzer` in `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart`. Tracks the **vertical position of the wrist midpoint relative to the shoulder midpoint**, normalised by shoulder width so the analyzer self-calibrates to camera distance.

### Signal

```
ratio = (shoulderMidY - wristMidY) / shoulderWidth
```

- `ratio > 0.45` → UP (wrists clearly above shoulder line — arms lifted in prone Y/T, or arms slid up in wall slide)
- `ratio < 0.05` → DOWN (wrists at or below shoulder line — arms resting)
- Between thresholds: hold previous state (natural hysteresis)

One UP-from-DOWN crossing = one rep, gated by `minRepInterval = 900 ms`.

### Why ratios, not angles

LateralRaise uses an angle (shoulder-elbow-hip) because the arms swing through a clean horizontal-to-overhead arc. Scapular movements are too small for angle-based detection — the shoulder-elbow-hip angle barely changes through the full ROM. The wrist-vs-shoulder-Y ratio captures the actual movement: arms moving up, period.

### Why no form warning

These movements are too subtle for any geometric form check that wouldn't false-positive. The analyzer counts reps and emits nothing else. The Tier-A mid-set heartbeat ("Karnını sık, hareketi izole et" for arms category, etc.) is the user-facing coaching layer.

### Likelihood gate

The min of left+right shoulder likelihoods must be ≥ 0.4. Wrists are not separately gated because we average them — a single weak wrist is absorbed into the midpoint. This keeps the analyzer running on prone-position frames where one arm is partially under the body.

## Routing changes

`analyzer_factory.dart`:
```dart
case 'prone_y_raise':
case 'prone_t_raise':
case 'scapular_wall_slide':
  return ScapularAnalyzer();
```

## Cache invalidation

Already handled by Tier B.1's v8→v9 bump. The three slugs are dropped from `_stuckRepBasedDurationSeconds` so they hydrate as repBased per the Supabase row.

## Files changed
- `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart` — new `ScapularAnalyzer` class. ~110 LOC.
- `lib/features/workout/services/analyzer_factory.dart` — routing for 3 slugs.
- `lib/features/workout/data/workout_repository.dart` — drop 3 slugs from override map.

## Behavior changes
- prone_y_raise / prone_t_raise / scapular_wall_slide: rep counter ticks per up-down cycle.
- No more timer for these — the camera UI shows `x N / target` again.
- Existing cached plans regenerate on next launch (Tier B.1 already bumped the cache key).

## Validation
- **prone_y_raise** (lying face-down, arms in Y overhead): lifting wrists off floor pushes wristMidY higher (lower image-y) so the ratio crosses 0.45. Counts a rep.
- **prone_t_raise** (lying face-down, arms out to sides): same — wrists rise relative to shoulder line.
- **scapular_wall_slide** (standing against wall): arms start at shoulder height (ratio ≈ 0), slide overhead (ratio > 0.45). Counts.
- **Edge case — user lies prone with arms below shoulder level (resting palms on floor by hips):** ratio is negative or near-zero → DOWN. Lifting establishes the UP commit. No false reps from breathing or torso shift because shoulder midpoint barely moves.
- **Edge case — camera at extreme angle making shoulder width < 1 pixel:** `_empty()` early-return. Same protective gate as JumpingJack/ChestFly.

## Out of scope
- `bird_dog`: stays timeBased. Quadruped balance + cross-body limb extension doesn't fit this analyzer's wrist-vs-shoulder check (the moving limb is the leg, not the wrist line).
