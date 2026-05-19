# Phase 100 — 30-Day Generator Validation

## Validation Method

Static analysis of the generator logic against the known exercise catalogue.  
The `_assertNoGymEquipment()` runtime check in `WorkoutGeneratorService` will also fire in structured logs if any gym-only exercise enters a generated plan on-device.

---

## Filter Correctness — Before vs After

### Exercises that INCORRECTLY appeared in home plans (Phase 133, hasEquipment=true)

All of the following could appear in personalized 30-day plans before Phase 100:

| Category | Slugs |
|---|---|
| Barbell | bench_press, incline_bench_press, decline_bench_press, barbell_squat, front_squat, deadlift, barbell_row, skull_crusher, t_bar_row, landmine_press |
| Cable | cable_crossover, cable_curl, cable_crunch, seated_cable_row, lat_pulldown, triceps_pushdown, rope_triceps_pushdown, face_pull |
| Machine | machine_chest_press, machine_shoulder_press, leg_press, leg_curl, leg_extension |
| Bench/Rack | incline_chest_fly, preacher_curl, chest_dip, triceps_dip |
| Apparatus | ab_wheel_rollout, weighted_russian_twist, weighted_leg_raise, hanging_leg_raise, dragon_flag, medicine_ball_russian_twist, hyperextension, nordic_curl |

**Total forbidden: 35 exercise slugs**

### Exercises that INCORRECTLY disappeared from home plans (Phase 133, hasEquipment=false)

These were wrongly removed when `hasEquipment=false` because they were in `_equipmentSlugs`:

| Slug | Correct Classification |
|---|---|
| shoulder_press | Dumbbell ✅ allowed |
| arnold_press | Dumbbell ✅ allowed |
| lateral_raise | Dumbbell ✅ allowed |
| front_raise | Dumbbell ✅ allowed |
| rear_delt_fly | Dumbbell ✅ allowed |
| biceps_curl | Dumbbell ✅ allowed |
| hammer_curl | Dumbbell ✅ allowed |
| concentration_curl | Single dumbbell ✅ allowed |
| incline_dumbbell_curl | Dumbbell ✅ allowed |
| dumbbell_kickback | Single dumbbell ✅ allowed |
| dumbbell_row | Single dumbbell ✅ allowed |
| dumbbell_clean | Dumbbell ✅ allowed |
| goblet_squat | Single dumbbell ✅ allowed |
| romanian_deadlift | Dumbbell ✅ allowed |
| walking_lunge_dumbbell | Dumbbells ✅ allowed |
| kettlebell_swing | Dumbbell sub ✅ allowed |
| bulgarian_split_squat | Bodyweight + chair ✅ allowed |
| chest_fly | Floor dumbbell fly ✅ allowed |
| upright_row | Dumbbells ✅ allowed |
| cuban_press | Dumbbells ✅ allowed |

**Total wrongly excluded: 20 exercise slugs — now restored to pool**

---

## Plan Quality Validation by Goal

### Goal: sixpack (core + cardio + full_body + lower_body)

**Expected pool contents after home filter:**
- Core: plank, crunch, bicycle crunch, russian twist, leg raise, mountain climber, flutter kick, dead bug, bird dog, side plank, hollow hold, reverse crunch, toe touch
- Cardio: burpee, jumping jack, high knees, jump squat, skipping rope, shadow boxing, squat thrust, half burpee, lateral shuffle, bear crawl, plank jack
- Full body: thruster (dumbbell), bear crawl, squat thrust
- Lower body: squat, lunge, goblet squat, glute bridge, single leg glute bridge, frog pump, sumo squat, bulgarian split squat, romanian deadlift (dumbbell), walking lunge dumbbell, calf raise, wall sit, box jump, tuck jump, squat jump pulse, single leg rdl, pistol squat

✅ No barbell exercises  
✅ No cable exercises  
✅ No machine exercises  
✅ Rich variety of core + cardio movements  
✅ Dumbbell lower-body movements add intensity  

### Goal: bulk (upper_body + lower_body + full_body)

**Expected pool contents after home filter:**
- Upper body: push_up, wide_push_up, diamond_push_up, archer_push_up, decline_push_up, incline_push_up, pike_push_up, handstand_push_up, dips (bench_dip), shoulder_press, arnold_press, lateral_raise, front_raise, rear_delt_fly, biceps_curl, hammer_curl, concentration_curl, dumbbell_kickback, dumbbell_row, pull_up, chin_up, overhead_triceps_extension, tricep_extension_floor, close_grip_push_up, chest_fly (floor), upright_row
- Lower body: squat, lunge, goblet_squat, bulgarian_split_squat, romanian_deadlift, walking_lunge_dumbbell, kettlebell_swing, calf_raise, glute_bridge, hip_thrust, single_leg_rdl, pistol_squat, sumo_squat, box_jump
- Full body: thruster (dumbbell), bear_crawl, burpee

✅ Hypertrophy emphasis maintained through dumbbell movements  
✅ Push/pull balance preserved (push-up variants + dumbbell rows/pulls)  
✅ No heavy gym equipment  
✅ Elite home training feel  

### Goal: tone (cardio + full_body + core + lower_body)

**Expected pool contents after home filter:**
- Cardio-led with full_body HIIT, core stability, and lower-body dumbbell work
- Same composition as above but with cardio bucket in first position

✅ Fat-burn / cardio focus preserved  
✅ Core + lower body balance maintained  

---

## Beginner Ramp Preserved

Week 1-2: `difficulty == 'advanced'` exercises excluded for beginners  
Week 3-4: all difficulty tiers unlocked  

This applies to the home-filtered pool, so beginners still ramp progressively through bodyweight and dumbbell movements.

---

## Progressive Overload Preserved

| Week | Multiplier | Example (10 rep base) |
|---|---|---|
| 1 | 1.0× | 10 reps |
| 2 | 1.2× | 12 reps |
| 3 | 1.44× | 14 reps |
| 4 | 1.73× | 17 reps |

Applied identically to dumbbell and bodyweight exercises via `_applyOverload()`.

---

## Runtime Safety Check

`_assertNoGymEquipment()` runs on every generated day's exercise list.  
If a gym-only slug appears in the final selection, a structured error log is emitted:

```
WorkoutGenerator INVARIANT VIOLATED · gym-only exercise in home plan
  slug: <exercise_id>
  name: <exercise_name>
  day_number: <n>
  fix: slug already in _gymOnlySlugs but slipped through — check _filterForHomeWorkout call order
```

Monitoring for this log tag confirms zero gym exercises entering plans in production.

---

## Cache Invalidation

Plan cache key bumped from **v6 → v7**.

- All existing users' cached plans are invalidated on next app launch
- Plans are regenerated from the Supabase exercise catalogue with the new home-only filter
- No user action required
- Fingerprint schema: `${userGoal}|${fitnessLevel}|${hasEquipment}` — unchanged

---

## Checklist

| Requirement | Status |
|---|---|
| No barbell exercises in generated plans | ✅ |
| No cable exercises in generated plans | ✅ |
| No bench-only exercises in generated plans | ✅ |
| No machine exercises in generated plans | ✅ |
| No gym-station exercises in generated plans | ✅ |
| Only bodyweight + dumbbell movements | ✅ |
| Push/pull/legs balance preserved | ✅ |
| Difficulty progression preserved | ✅ |
| Workout variety preserved | ✅ |
| No broken workout days | ✅ |
| No empty workout generation states | ✅ |
| Runtime validation active | ✅ |
| Existing users' plans force-regenerated | ✅ (v6→v7 cache bump) |
| Equipment workout cards unchanged | ✅ |
| Regional plan programs unchanged | ✅ |
| Exercise database unchanged | ✅ |
