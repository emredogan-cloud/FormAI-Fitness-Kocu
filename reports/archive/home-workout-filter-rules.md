# Phase 100 — Home-Workout Filter Rules

## Filter Location

`WorkoutGeneratorService._filterForHomeWorkout()`  
`lib/features/workout/domain/services/workout_generator_service.dart`

Applied **once** to the full exercise pool before any goal or level filtering.

---

## Allowed Exercise Types

| Type | Examples |
|---|---|
| Bodyweight | push-up, squat, lunge, burpee, plank, mountain climber, jumping jack |
| No-equipment | any exercise with `targetMuscle` in `{core, cardio, full_body, lower_body, upper_body}` that has no gym-apparatus dependency |
| Single dumbbell | goblet squat, concentration curl, dumbbell kickback, dumbbell clean, single-arm row |
| Pair of dumbbells | shoulder press, lateral raise, biceps curl, dumbbell row, walking lunge dumbbell, romanian deadlift |
| Pull-up bar (home) | pull_up, chin_up (doorframe bars are common home equipment) |

---

## Forbidden Exercise Types (`_gymOnlySlugs`)

### Barbell Exercises
| Slug | Reason |
|---|---|
| `bench_press` | barbell + rack + bench |
| `incline_bench_press` | barbell + incline bench |
| `decline_bench_press` | barbell + decline bench |
| `barbell_row` | barbell |
| `barbell_squat` | barbell + rack |
| `front_squat` | barbell + rack |
| `deadlift` | barbell (dumbbell Romanian deadlift kept separately) |
| `skull_crusher` | barbell / EZ bar |
| `landmine_press` | barbell + landmine attachment |
| `t_bar_row` | T-bar station |

### Cable Machine Exercises
| Slug | Reason |
|---|---|
| `cable_crossover` | cable crossover station |
| `cable_curl` | cable machine |
| `cable_crunch` | cable machine |
| `seated_cable_row` | cable machine |
| `lat_pulldown` | cable/lat pulldown machine |
| `triceps_pushdown` | cable machine |
| `rope_triceps_pushdown` | cable machine + rope attachment |
| `face_pull` | cable machine |

### Fixed Gym Machines
| Slug | Reason |
|---|---|
| `machine_chest_press` | chest press machine |
| `machine_shoulder_press` | shoulder press machine |
| `leg_press` | leg press machine |
| `leg_curl` | leg curl machine |
| `leg_extension` | leg extension machine |

### Bench / Rack / Dip Station
| Slug | Reason |
|---|---|
| `incline_chest_fly` | requires incline bench |
| `preacher_curl` | preacher bench (gym fixture) |
| `dumbbell_pullover` | requires elevated bench position |
| `chest_dip` | parallel dip bars (gym-grade) |
| `triceps_dip` | parallel dip bars (gym-grade; `bench_dip` with chair is kept) |

### Pull-up Bar Hanging Required
| Slug | Reason |
|---|---|
| `hanging_leg_raise` | hanging from bar required |
| `dead_hang` | hanging from bar |
| `scapular_pull_up` | hanging from bar |

### Specialised Weighted Apparatus
| Slug | Reason |
|---|---|
| `ab_wheel_rollout` | ab wheel (specialized equipment) |
| `weighted_russian_twist` | weight plate |
| `weighted_leg_raise` | ankle weights / plate |
| `weighted_sit_up` | weight plate |
| `dragon_flag` | requires sturdy anchor/bench |
| `medicine_ball_russian_twist` | medicine ball |
| `hyperextension` | hyperextension bench |
| `nordic_curl` | anchoring device / nordic board |

---

## Exercises Explicitly Kept (Common Misclassifications)

These exercises are **NOT** in `_gymOnlySlugs` despite being in the Phase 133 block list:

| Slug | Rationale |
|---|---|
| `dumbbell_row` | Done with single dumbbell; bench optional (can use knee) |
| `romanian_deadlift` | Done with dumbbells at home |
| `goblet_squat` | Done with single dumbbell |
| `kettlebell_swing` | Dumbbell is a common substitute |
| `bulgarian_split_squat` | Bodyweight + household chair |
| `walking_lunge_dumbbell` | Open floor + dumbbells |
| `shoulder_press` | Dumbbells, no rack needed |
| `arnold_press` | Dumbbells only |
| `lateral_raise` | Dumbbells only |
| `biceps_curl` | Dumbbells only |
| `concentration_curl` | Single dumbbell |
| `overhead_triceps_extension` | Single dumbbell |
| `thruster` | Dumbbells (no barbell needed) |
| `hip_thrust` | Bodyweight / dumbbell on lap (no bench required) |
| `chest_fly` | Floor dumbbell fly — bench not required |
| `pull_up` / `chin_up` | Bodyweight; doorframe bars are standard home equipment |

---

## Maintenance

When a new exercise is added to the Supabase catalogue:

1. If it requires **barbell / cable / fixed machine / heavy bench**: add its slug to `_gymOnlySlugs` in `workout_generator_service.dart`
2. If it is **bodyweight or dumbbell**: no action needed — it enters the pool automatically
3. The `_assertNoGymEquipment()` runtime check will log an error if a gym-only exercise appears in a generated day without being in `_gymOnlySlugs`

---

## Filter Implementation (Dart)

```dart
List<Exercise> _filterForHomeWorkout(List<Exercise> pool) {
  return pool.where((e) => !_gymOnlySlugs.contains(e.id)).toList();
}
```

Applied at:  
```
homePool = _filterForHomeWorkout(pool)  // before goal/level filtering
goalFiltered = _filterByGoal(homePool, goal)  // operates on home-only pool
```
