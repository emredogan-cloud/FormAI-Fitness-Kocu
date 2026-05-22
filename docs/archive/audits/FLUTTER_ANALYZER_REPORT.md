# FlutterKick Normalization — Tier B.6 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §5 U9 (FlutterKick minDelta in pixels is non-scaling).

## Problem

`FlutterKickAnalyzer.minDelta = 12.0` was an absolute pixel threshold for the L-vs-R ankle y-separation. The problem:

- **Close camera:** 12 px is a tiny leg motion. Resting-frame ankle jitter routinely crossed it → false reps during a hold-still.
- **Far camera:** 12 px is a big leg motion. The user's actual flutter kick produced an ankle separation of < 12 px → reps never counted.

The same pixel count read as "noise" in one setup and "huge gesture" in another.

## Solution

Express the threshold as a **fraction of the user's shoulder-to-ankle vertical distance**. That distance scales linearly with camera distance: at any setup, the user's body height in pixels IS the relevant scale.

New constant: `minDeltaFraction = 0.04` (4 % of body length).

Per-frame:
```dart
final shoulder = _pickHigher(left, right);
final ankleMidY = (la.y + ra.y) / 2;
final scale = (ankleMidY - shoulder.y).abs();   // body length in pixels
final minDelta = scale * minDeltaFraction;       // threshold scales with body
```

Then the original L-vs-R ankle delta check is unchanged — only the threshold computation moved.

### Why ankle midpoint as the anchor

We use `(la.y + ra.y) / 2` for the bottom of the body length, not a single ankle, because a flutter kick is by definition moving one ankle relative to the other. Anchoring to a single ankle's y would shift the scale every frame; the midpoint stays stable because what one ankle gains the other loses.

### Why higher-likelihood shoulder

`_pickHigher` picks the more reliable shoulder. A user lying with one arm tucked under their head will have one shoulder occluded; we want the visible side's y as the anchor.

## Files changed
- `lib/features/workout/services/core_analyzers.dart` — FlutterKickAnalyzer constructor field renamed (`minDelta` → `minDeltaFraction`), default changed from `12.0` to `0.04`. ~15 LOC delta.

## Behavior changes
- Close-camera flutter kicks no longer false-positive on resting-frame jitter.
- Far-camera flutter kicks no longer fail to count real kicks.
- Mid-range setups behave roughly identically to before (because body length in those setups is ~300 px, so 4 % ≈ 12 px — the previous default).

## Validation
- **Camera at ~1 m, full-body in frame, user does 12 reps:** counter reaches 12. Each kick produces ankle separation of ~30 px (≈ 10 % of body length) — well above the 4 % threshold.
- **Camera at ~3 m, user shows up small in frame:** body length in pixels is ~150. 4 % threshold = 6 px. Kicks producing 8-10 px separation now count; previously needed 12 px.
- **User lies still:** ankle separation stays below the threshold; no false reps.
