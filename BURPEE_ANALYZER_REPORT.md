# Burpee Decay-Window Calibration — Tier B.7 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §5 U8 (BurpeeAnalyzer self-calibration drift).

## Problem

The previous `BurpeeAnalyzer` kept a monotonic running `_yMin`/`_yMax` over the entire set. After the user's first rep established a clean min and max, those values **never decayed**. If a single outlier yMin was recorded (e.g. user briefly hung their head between reps), it polluted the thresholds for the rest of the set. By the late reps:

- `_yMin` was potentially far lower than any actual standing shoulder position → the "STANDING" threshold drifted toward the middle of the range.
- Breathing oscillations or subtle weight-shifts could re-cross the threshold → false reps registered.

## Solution

Replace the running min/max with a **sliding window** of `(timestamp, shoulderY)` samples. Every frame appends a sample; the head is pruned when it ages past `_decayWindow = 8 s`.

Per frame:
```dart
_ySamples.add(_YSample(now, y));
while (_ySamples.first.timestamp older than 8s) _ySamples.removeAt(0);
// derive yMin/yMax from the windowed list
```

Now thresholds are computed from the last 8 s of data only. An outlier from 15 s ago has decayed out — it cannot affect the current burpee's threshold.

Why 8 s: long enough to span a slow burpee cycle (~5 s/rep) so a single rep's range is fully represented; short enough that stale extrema fade before the second-next rep starts.

### Safety cap

`_maxSamples = 256` bounds list growth on degenerate slow-fps devices. 256 samples at the effective 15 FPS rate ≈ 17 s of frames — well above the 8 s window, so this never triggers in normal operation. Pure safety net.

### Pruning algorithm

- Window is timestamp-ascending (always append, never insert mid-list) → head is always the oldest.
- Two while-loops at the top of `analyze`: one prunes by age, one enforces the size cap. Both are O(prune count); typical case is one removal per frame after warm-up.

## Files changed
- `lib/features/workout/services/shoulders_arms_cardio_analyzers.dart` — `BurpeeAnalyzer` rewrite. Removed `_yMin`/`_yMax` fields. Added `_ySamples` list + `_YSample` value class + decay-window pruning. ~30 LOC net delta.

## Behavior changes
- Burpee thresholds now track the recent shoulder-Y range, not the all-time-high range.
- Long sets (20+ reps) no longer drift toward false-positive territory.
- Short sets behave identically — the window is wider than the set duration.
- A user who briefly leans off-screen (outlier yMax) sees the threshold recover within 8 s.

## Validation
- **Standard 10-rep burpee set:** counter ticks correctly. No drift.
- **Long 30-rep burpee set, user occasionally rests with head down between reps:** previous behavior — late reps registered as false doubles from breathing oscillation. New behavior — outlier yMin from a hung-head frame decays out within 8 s; thresholds stay clean for subsequent reps.
- **Slow burpee (5 s/rep) for 60 s:** 12 reps. Window holds ~1.5 reps of data at any time, which is enough to bracket the full vertical range. No threshold collapse.
- **Burpee variant (squat_thrust, half_burpee):** same analyzer, same behavior. The shoulder-Y range is preserved across the variant types.
