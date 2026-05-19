# ML Detection Strategy — Phase 96

**Status:** technical specification for `lib/features/workout/services/analyzer_factory.dart`. Drives the slug → analyzer additions in the same patch as the SQL migration.
**Generated:** 2026-05-09
**Constraint:** **No new analyzer classes shipped in Phase 96.** Every new exercise either reuses one of the 17 existing analyzers or routes to `SilentHoldAnalyzer` (the safe default).

---

## 1. Strategy in One Paragraph

The pose pipeline (Google ML Kit on-device → `PoseAnalyzer.analyze(pose)` → `CrunchResult` per frame) was built around 17 movement archetypes. Adding new exercises that fit those archetypes (pushing, pulling, squatting, hinging, twisting, hip-raising, ankle-alternating) is essentially free — they reuse an existing class with the same thresholds. Movements that **don't** fit (mobility holds, stretching, balance work, complex multi-joint patterns like Olympic lifts) route to `SilentHoldAnalyzer`, which deliberately does **not** count reps or warn on form — only emits a throttled encouragement line every ~18 s. This is the same pattern Phase 30 introduced for `wall_sit`, `superman`, etc., and it's the honest UX answer: the user sees their timer, hears occasional encouragement, and is not lied to about a rep count we can't compute reliably.

---

## 2. Routing Decisions Per New Slug

| New slug | Analyzer | Rationale | Landmarks needed | Notes |
|---|---|---|---|---|
| `decline_crunch` | `CrunchAnalyzer` | Torso angle (shoulder-hip-knee) cycle is the same as a regular crunch. | shoulder, hip, knee, ear (form) | Bench tilt does not change the joint geometry; existing thresholds (down 140°, up 90°) hold. |
| `weighted_sit_up` | `CrunchAnalyzer` | Identical geometry to `situp`. Adding load doesn't change the angle. | shoulder, hip, knee, ear | `repJustCompleted` may fire slightly slower with heavier load — acceptable. |
| `weighted_leg_raise` | `LegRaiseAnalyzer` | Hip angle (shoulder-hip-ankle) cycle preserved. | shoulder, hip, ankle | Ankle weights occlude landmarks rarely; min likelihood 0.4 gate handles it. |
| `dragon_flag` | `LegRaiseAnalyzer` | Hip angle still goes 90 → 180 → 90. | shoulder, hip, ankle | Pose may be partially supported by bench; `_pickHigher` handles single-side occlusion. |
| `medicine_ball_russian_twist` | `RussianTwistAnalyzer` | Shoulder-mid vs hip-mid horizontal offset is unchanged. | shoulders, hips | Ball held at chest doesn't change torso landmarks. |
| `reverse_crunch` | `LegRaiseAnalyzer` | Hips and knees rotate up — hip angle drops below `upThreshold`. | shoulder, hip, ankle | ROM is shorter than a full leg raise; current thresholds (down 150°, up 110°) still bracket it. |
| `toe_touch` | `CrunchAnalyzer` | Torso flexes toward feet, same shoulder-hip-knee angle pattern. | shoulder, hip, knee, ear | Reach-to-toes position satisfies `upThreshold < 90°`. |
| `hollow_hold` | `SilentHoldAnalyzer` | Static isometric — no rep to count. | none | Throttled encouragement every 18 s. |
| `side_plank` | `SilentHoldAnalyzer` | `PlankAnalyzer`'s vertical-line check fails on rotated geometry (would constantly warn). | none | Documented in Phase 30: never route lateral/seated holds to `PlankAnalyzer`. |
| `bird_dog` | `SilentHoldAnalyzer` | Single-side balance + extension; not a rep-count-friendly geometry. | none | The user gets encouragement but no count. |
| `dead_bug` | `FlutterKickAnalyzer` | Alternating limb extension creates the same ankle-y delta side-flip the analyzer counts. | ankles | Counts a rep on each L/R switch — matches the user's experience of "one rep = one side". |
| `decline_bench_press` | `BenchPressAnalyzer` | Elbow flexion against load — identical to flat bench. | shoulder, elbow, wrist | Tighter ROM thresholds (up 155°, down 100°) match heavy DB use. |
| `cable_crossover` | `ChestFlyAnalyzer` | Wrist gap vs shoulder width opens and closes — same rep mechanic. | shoulders, wrists | Cable angle doesn't change the wrist-to-wrist spatial measurement. |
| `dumbbell_pullover` | `SilentHoldAnalyzer` | Overhead arc with arms staying straight isn't covered by any analyzer. | none | Could route to `LegRaiseAnalyzer` if we want hip-y-style detection — too brittle. Leave silent. |
| `incline_chest_fly` | `ChestFlyAnalyzer` | Same wrist-gap mechanic; bench tilt doesn't matter. | shoulders, wrists | |
| `machine_chest_press` | `BenchPressAnalyzer` | Elbow flexion against fixed plane — same as DB press. | shoulder, elbow, wrist | |
| `diamond_push_up` | `PushUpAnalyzer` | Elbow flexion identical to wide push-up. | shoulder, elbow, wrist | Hand placement narrower but joint geometry preserved. |
| `wide_push_up` | `PushUpAnalyzer` | Same. | shoulder, elbow, wrist | |
| `archer_push_up` | `PushUpAnalyzer` | Single-side dominant push-up — `_armAngle()` already picks the bent-side cleanly via per-side `_pickHigher`. | shoulder, elbow, wrist | Counts 1 rep per side flex — acceptable since the user does pairs. |
| `pseudo_planche_push_up` | `PushUpAnalyzer` | Same elbow flexion, hand position shifted. | shoulder, elbow, wrist | |
| `clap_push_up` | `PushUpAnalyzer` | Plyometric push-up — elbow still cycles. | shoulder, elbow, wrist | Mid-air clap frame may occlude both wrists — analyzer skips frame, recovers on landing. |
| `knee_push_up` | `PushUpAnalyzer` | Same elbow geometry, knees on floor. | shoulder, elbow, wrist | |
| `dumbbell_row` | `PullUpAnalyzer` | Loaded elbow flexion — DOWN = arms long, UP = pulled in to hip. | shoulder, elbow, wrist | Single-arm; per-side `_armAngle` picks correctly. |
| `t_bar_row` | `PullUpAnalyzer` | Same. | shoulder, elbow, wrist | |
| `face_pull` | `PullUpAnalyzer` | Elbow flexion to head height. ROM is shorter (up ~100°) but still crosses thresholds. | shoulder, elbow, wrist | |
| `seated_cable_row` | `PullUpAnalyzer` | Same loaded elbow flexion. | shoulder, elbow, wrist | |
| `deadlift` | `SquatAnalyzer` | Conventional deadlift has knee bend at the start; knee angle cycles 100° → 180° → 100°. | hip, knee, ankle | Romanian-style deadlift has minimal knee bend — that's why `romanian_deadlift` was already routed to default (silent). Conventional fits. |
| `hyperextension` | `SilentHoldAnalyzer` | Back extension geometry not modeled. | none | |
| `inverted_row` | `PullUpAnalyzer` | Loaded elbow flexion, body parallel to floor. | shoulder, elbow, wrist | |
| `prone_y_raise` | `SilentHoldAnalyzer` | Small-ROM scapular work, prone face-down. Not a rep counter use case. | none | |
| `prone_t_raise` | `SilentHoldAnalyzer` | Same as Y-raise. | none | |
| `swimmer` | `SilentHoldAnalyzer` | Continuous alternating limb work; complex geometry. | none | Time-based hold. |
| `scapular_pull_up` | `PullUpAnalyzer` | Elbow stays straight but `PullUpAnalyzer` reads elbow angle — scapular reps don't show. **Caveat:** rep counter may stay at 0. | shoulder, elbow, wrist | Acceptable — user sees their `targetReps` and can self-count. Alternatively route to SilentHold; calling judgment is keep `PullUpAnalyzer` so any partial-rep (with elbow bend) does count. |
| `rear_delt_fly` | `LateralRaiseAnalyzer` | Same shoulder-vertex angle as rear-delt is just lateral raise from a hinged position. | shoulder, elbow, hip | |
| `upright_row` | `ShoulderPressAnalyzer` | Wrists travel up vs shoulders — same Y-delta pattern. | shoulders, wrists | UP lockout is shorter (chest height not overhead) — partial-rep warning may fire; acceptable. |
| `cuban_press` | `ShoulderPressAnalyzer` | Final phase is overhead press; that's what the analyzer counts. | shoulders, wrists | The first two rotation phases are pre-press — analyzer ignores, counts only the lockout. |
| `landmine_press` | `ShoulderPressAnalyzer` | Single-arm overhead press — wrist Y-vs-shoulder Y still works. | shoulders, wrists | |
| `machine_shoulder_press` | `ShoulderPressAnalyzer` | Same. | shoulders, wrists | |
| `handstand_hold` | `SilentHoldAnalyzer` | Static inverted hold. | none | |
| `pike_walk` | `SilentHoldAnalyzer` | Multi-step movement. | none | |
| `wall_walk` | `SilentHoldAnalyzer` | Complex inverted progression. | none | |
| `scapular_wall_slide` | `SilentHoldAnalyzer` | Small-ROM scapular work. | none | |
| `handstand_push_up` | `PushUpAnalyzer` | Inverted geometry but elbow flexion cycle preserved. | shoulder, elbow, wrist | Likelihood may drop on inverted face — `_armAngle` returns null on low-likelihood frames; counter just won't increment that frame. |
| `preacher_curl` | `BicepsCurlAnalyzer` | Elbow flexion. | shoulder, elbow, wrist | |
| `incline_dumbbell_curl` | `BicepsCurlAnalyzer` | Same. | shoulder, elbow, wrist | |
| `cable_curl` | `BicepsCurlAnalyzer` | Same. | shoulder, elbow, wrist | |
| `overhead_triceps_extension` | `BicepsCurlAnalyzer` | Elbow flexion behind head — geometry inverted but `AngleCalculator.between(s,e,w)` is direction-agnostic. | shoulder, elbow, wrist | Verified: angle still cycles 50° → 150°. |
| `rope_triceps_pushdown` | `BicepsCurlAnalyzer` | Elbow extension cycle. | shoulder, elbow, wrist | Already used for the older `triceps_pushdown` slug. |
| `dumbbell_kickback` | `BicepsCurlAnalyzer` | Elbow extension/flexion. | shoulder, elbow, wrist | |
| `farmer_carry` | `SilentHoldAnalyzer` | Walking with load — no rep concept. | none | |
| `chin_up_negative` | `PullUpAnalyzer` | The eccentric-only rep still has DOWN→UP cycle (UP = chin above bar at start, DOWN = arms long after slow lower). | shoulder, elbow, wrist | Pull-up state machine treats "small angle" as UP and "large angle" as DOWN — one rep counted on the slow lower. |
| `bench_dip` | `PushUpAnalyzer` | Elbow flexion. | shoulder, elbow, wrist | |
| `tricep_extension_floor` | `BicepsCurlAnalyzer` | Elbow flexion with body in plank — same arm geometry. | shoulder, elbow, wrist | |
| `pike_push_up_close` | `PushUpAnalyzer` | Same elbow flexion as `pike_push_up` (already routed). | shoulder, elbow, wrist | |
| `dead_hang` | `SilentHoldAnalyzer` | Static hang. | none | |
| `front_squat` | `SquatAnalyzer` | Knee flexion identical to back squat. | hip, knee, ankle | |
| `goblet_squat` | `SquatAnalyzer` | Same. | hip, knee, ankle | |
| `hip_thrust` | `SilentHoldAnalyzer` | Hip extension primary; knee stays at ~90° throughout — `SquatAnalyzer` would not detect. | none | Honest call: no rep counting, but the user has the timer + their target rep count to follow. |
| `dumbbell_step_up` | `SquatAnalyzer` | Knee flexion cycle preserved (one leg active). | hip, knee, ankle | `_kneeAngle` picks the bent leg via `_pickHigher`. |
| `walking_lunge_dumbbell` | `SquatAnalyzer` | Same. | hip, knee, ankle | |
| `seated_calf_raise` | `SilentHoldAnalyzer` | Ankle-only motion not modeled. | none | |
| `glute_bridge` | `SilentHoldAnalyzer` | Same hip-extension issue as hip thrust. | none | |
| `single_leg_glute_bridge` | `SilentHoldAnalyzer` | Same. | none | |
| `pistol_squat` | `SquatAnalyzer` | Knee flexion still cycles on the standing leg. | hip, knee, ankle | The free leg is occluded; per-side `_pickHigher` handles it. |
| `sumo_squat` | `SquatAnalyzer` | Same knee-angle cycle. | hip, knee, ankle | Wider stance doesn't change the joint angle. |
| `box_jump` | `SquatAnalyzer` | Squat-down + jump — knee flexion cycle still hits both thresholds. | hip, knee, ankle | Mid-air frame may have low-likelihood landmarks — analyzer skips. Counts on landing in squat. |
| `single_leg_calf_raise` | `SilentHoldAnalyzer` | Ankle-only motion. | none | |
| `single_leg_rdl` | `SilentHoldAnalyzer` | Single-leg balance + hip hinge — too complex. | none | |
| `frog_pump` | `SilentHoldAnalyzer` | Hip extension only. | none | |
| `nordic_curl` | `SilentHoldAnalyzer` | Specialized eccentric, knee hinge atypical. | none | |
| `kettlebell_swing` | `SilentHoldAnalyzer` | Hip hinge + arm swing — pattern not modeled. | none | A future `HipHingeAnalyzer` could handle this; out of scope for Phase 96. |
| `thruster` | `SquatAnalyzer` | The squat phase counts cleanly; the press is incidental to rep count. | hip, knee, ankle | One rep per knee cycle. |
| `dumbbell_clean` | `SilentHoldAnalyzer` | Olympic-style multi-phase. | none | |
| `squat_thrust` | `BurpeeAnalyzer` | STANDING → DOWN → STANDING via shoulder Y is identical to a no-jump-no-pushup burpee. | shoulder | |
| `half_burpee` | `BurpeeAnalyzer` | Same phase machine — burpee with no push-up still cycles standing/down. | shoulder | |
| `plank_jack` | `SilentHoldAnalyzer` | Lateral leg-spread in plank — no analyzer covers this. | none | Time-based holds work fine. |
| `bear_crawl` | `SilentHoldAnalyzer` | Quadrupedal forward locomotion. | none | |
| `lateral_shuffle` | `SilentHoldAnalyzer` | Lateral cardio — no rep concept. | none | |
| `squat_jump_pulse` | `SquatAnalyzer` | Continuous shallow squat-jumps still cycle the knee angle. | hip, knee, ankle | Time-based but analyzer is fine emitting reps that the timer ignores. |
| `shadow_boxing` | `SilentHoldAnalyzer` | No rep mechanic. | none | |
| `tuck_jump` | `SquatAnalyzer` | Squat-down + jump-with-tuck — knee angle cycles. | hip, knee, ankle | |
| `cat_cow` | `SilentHoldAnalyzer` | Mobility flow. | none | |
| `child_pose` | `SilentHoldAnalyzer` | Static stretch. | none | |
| `downward_dog` | `SilentHoldAnalyzer` | Static stretch. | none | |
| `cobra_stretch` | `SilentHoldAnalyzer` | Static stretch. | none | |
| `hip_flexor_stretch` | `SilentHoldAnalyzer` | Static stretch. | none | |
| `standing_hamstring_stretch` | `SilentHoldAnalyzer` | Static stretch. | none | |

---

## 3. Summary by Analyzer (changes required to `analyzer_factory.dart`)

For each existing analyzer, the new slugs that need to be added to its `case` block. Slugs routed to `SilentHoldAnalyzer` do NOT need entries — they fall through the default branch.

### `CrunchAnalyzer` adds
```dart
case 'decline_crunch':
case 'weighted_sit_up':
case 'toe_touch':
  return CrunchAnalyzer();
```

### `LegRaiseAnalyzer` adds
```dart
case 'weighted_leg_raise':
case 'dragon_flag':
case 'reverse_crunch':
  return LegRaiseAnalyzer();
```

### `RussianTwistAnalyzer` adds
```dart
case 'medicine_ball_russian_twist':
  return RussianTwistAnalyzer();
```

### `FlutterKickAnalyzer` adds
```dart
case 'dead_bug':
  return FlutterKickAnalyzer();
```

### `BenchPressAnalyzer` adds
```dart
case 'decline_bench_press':
case 'machine_chest_press':
  return BenchPressAnalyzer();
```

### `ChestFlyAnalyzer` adds
```dart
case 'cable_crossover':
case 'incline_chest_fly':
  return ChestFlyAnalyzer();
```

### `PushUpAnalyzer` adds
```dart
case 'diamond_push_up':
case 'wide_push_up':
case 'archer_push_up':
case 'pseudo_planche_push_up':
case 'clap_push_up':
case 'knee_push_up':
case 'bench_dip':
case 'pike_push_up_close':
case 'handstand_push_up':
  return PushUpAnalyzer();
```

### `PullUpAnalyzer` adds
```dart
case 'dumbbell_row':
case 't_bar_row':
case 'face_pull':
case 'seated_cable_row':
case 'inverted_row':
case 'scapular_pull_up':
case 'chin_up_negative':
  return PullUpAnalyzer();
```

### `SquatAnalyzer` adds
```dart
case 'deadlift':
case 'front_squat':
case 'goblet_squat':
case 'dumbbell_step_up':
case 'walking_lunge_dumbbell':
case 'pistol_squat':
case 'sumo_squat':
case 'box_jump':
case 'thruster':
case 'squat_jump_pulse':
case 'tuck_jump':
  return SquatAnalyzer();
```

### `BicepsCurlAnalyzer` adds
```dart
case 'preacher_curl':
case 'incline_dumbbell_curl':
case 'cable_curl':
case 'overhead_triceps_extension':
case 'rope_triceps_pushdown':
case 'dumbbell_kickback':
case 'tricep_extension_floor':
  return BicepsCurlAnalyzer();
```

### `LateralRaiseAnalyzer` adds
```dart
case 'rear_delt_fly':
  return LateralRaiseAnalyzer();
```

### `ShoulderPressAnalyzer` adds
```dart
case 'upright_row':
case 'cuban_press':
case 'landmine_press':
case 'machine_shoulder_press':
  return ShoulderPressAnalyzer();
```

### `BurpeeAnalyzer` adds
```dart
case 'squat_thrust':
case 'half_burpee':
  return BurpeeAnalyzer();
```

### `SilentHoldAnalyzer` (default — no edits needed)
All remaining new slugs fall through to the default branch. The default branch is already `SilentHoldAnalyzer`. The list (for documentation completeness):
`hollow_hold`, `side_plank`, `bird_dog`, `dumbbell_pullover`, `hyperextension`, `prone_y_raise`, `prone_t_raise`, `swimmer`, `handstand_hold`, `pike_walk`, `wall_walk`, `scapular_wall_slide`, `farmer_carry`, `dead_hang`, `hip_thrust`, `seated_calf_raise`, `glute_bridge`, `single_leg_glute_bridge`, `single_leg_calf_raise`, `single_leg_rdl`, `frog_pump`, `nordic_curl`, `kettlebell_swing`, `dumbbell_clean`, `plank_jack`, `bear_crawl`, `lateral_shuffle`, `shadow_boxing`, `cat_cow`, `child_pose`, `downward_dog`, `cobra_stretch`, `hip_flexor_stretch`, `standing_hamstring_stretch`.

---

## 4. Future Analyzer Backlog (out of scope for Phase 96)

If a future phase wants to upgrade these from silent to fully detected:

| Movement archetype | Proposed analyzer | Effort |
|---|---|---|
| Hip hinge / glute drive (hip thrust, glute bridge, kettlebell swing, RDL) | `HipHingeAnalyzer` — track shoulder-hip-knee angle and hip-y delta over time | ~120 LOC + tuning |
| Lateral plank (side plank) | `SidePlankAnalyzer` — single-side shoulder-hip-ankle line at the rotated angle | ~80 LOC |
| Olympic / dynamic full-body (clean, snatch) | `MultiPhaseAnalyzer` — phase machine over body Y + arm Y | ~200 LOC |
| Mobility / stretching | `StretchHoldAnalyzer` — track angle of one limb and emit "deepen the stretch" cues | ~100 LOC |
| Forearm / grip work (dead hang, farmer carry) | `IsometricLoadAnalyzer` — track grip duration only, no rep counting | ~50 LOC |

These are flagged but not built. Phase 96's promise is **catalogue expansion using the existing detection scaffolding**.

---

## 5. Validation Checklist

After applying the analyzer factory edits + SQL:

- [ ] Compile: `flutter analyze` passes (no new warnings).
- [ ] Smoke test: open the camera screen on a `decline_crunch` exercise, perform a rep, see the rep counter tick.
- [ ] Smoke test: open `hollow_hold`, confirm SilentHold's encouragement line surfaces every ~18 s and no spurious rep counts appear.
- [ ] Smoke test: open `archer_push_up` and confirm the per-side `_armAngle` picks the bent side correctly.
- [ ] Visual inspection: verify the new exercise rows landed in `public.exercises` via `SELECT count(*) FROM public.exercises;` (expect 138).
- [ ] Plan generator: trigger a fresh plan generation (Reset Progress on a test account) and confirm new slugs appear in some days.

---

End of ML detection strategy.
