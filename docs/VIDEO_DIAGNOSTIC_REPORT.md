# Video Diagnostic Report

**Generated:** 2026-05-03 10:57:52 UTC
**Probe target:** Supabase Storage public endpoint
**Base URL:** `https://xtvqhnjamwvmfcsahzxv.supabase.co/storage/v1/object/public/exercises`
**Slug count:** 51

Probes every `<slug>` against `<base>/<PascalCase(slug)>.mp4` — the
same URL the runtime composes via `WorkoutRepository._composeVideoUrl`.
200 = file present and reachable. 404 = file missing. 403 = bucket
policy blocks anonymous read. `hevc` codec = won't play on stock
Android (ExoPlayer needs H264/AVC for the broadest device support).

## Summary

- ✅ OK:                **50**
- ❌ Missing (404):     **0**
- ❌ Forbidden (403):   **0**
- ⚠️  Codec warnings:   **0**
- ❌ Other failures:    **1**

## Per-slug detail

| # | Slug | URL tail | HTTP | Content-Type | Codec | Verdict |
|---|---|---|---|---|---|---|
| 1 | `crunch` | `Crunch.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 2 | `situp` | `Situp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 3 | `plank` | `Plank.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 4 | `leg_raise` | `LegRaise.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 5 | `hanging_leg_raise` | `HangingLegRaise.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 6 | `russian_twist` | `RussianTwist.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 7 | `mountain_climber` | `MountainClimber.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 8 | `bicycle_crunch` | `BicycleCrunch.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 9 | `flutter_kick` | `FlutterKick.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 10 | `push_up` | `PushUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 11 | `incline_push_up` | `InclinePushUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 12 | `decline_push_up` | `DeclinePushUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 13 | `bench_press` | `BenchPress.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 14 | `chest_fly` | `ChestFly.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 15 | `chest_dip` | `ChestDip.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 16 | `squat` | `Squat.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 17 | `lunge` | `Lunge.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 18 | `bulgarian_split_squat` | `BulgarianSplitSquat.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 19 | `leg_press` | `LegPress.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 20 | `calf_raise` | `CalfRaise.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 21 | `wall_sit` | `WallSit.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 22 | `pull_up` | `PullUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 23 | `chin_up` | `ChinUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 24 | `lat_pulldown` | `LatPulldown.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 25 | `barbell_row` | `BarbellRow.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 26 | `superman` | `Superman.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 27 | `shoulder_press` | `ShoulderPress.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 28 | `arnold_press` | `ArnoldPress.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 29 | `lateral_raise` | `LateralRaise.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 30 | `front_raise` | `FrontRaise.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 31 | `pike_push_up` | `PikePushUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 32 | `biceps_curl` | `BicepsCurl.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 33 | `hammer_curl` | `HammerCurl.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 34 | `triceps_dip` | `TricepsDip.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 35 | `triceps_pushdown` | `TricepsPushdown.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 36 | `close_grip_push_up` | `CloseGripPushUp.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 37 | `burpee` | `Burpee.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 38 | `jumping_jack` | `JumpingJack.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 39 | `jump_squat` | `JumpSquat.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 40 | `high_knees` | `HighKnees.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 41 | `skipping_rope` | `SkippingRope.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 42 | `incline_bench_press` | `InclineBenchPress.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 43 | `concentration_curl` | `ConcentrationCurl.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 44 | `skull_crusher` | `SkullCrusher.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 45 | `barbell_squat` | `BarbellSquat.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 46 | `romanian_deadlift` | `RomanianDeadlift.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 47 | `leg_extension` | `LegExtension.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 48 | `leg_curl` | `LegCurl.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 49 | `cable_crunch` | `CableCrunch.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 50 | `weighted_russian_twist` | `WeightedRussianTwist.mp4` | 200 | video/mp4 | h264 | ✅ OK |
| 51 | `ab_wheel_rollout` | `AbWheelRollout.mp4` | 400 | application/json | — | ❌ HTTP 400 |

## Next steps

- **Other HTTP codes:** 5xx usually means transient Supabase/CDN issues; re-run. 000 means `curl` couldn't reach the host at all (DNS / firewall).
