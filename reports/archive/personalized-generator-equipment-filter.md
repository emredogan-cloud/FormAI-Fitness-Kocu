# Phase 100 — Personalized Generator Equipment Filter

## Summary

Refactored the 30-day personalized workout generator to produce **home-only plans** (bodyweight + dumbbell) on every generation, regardless of user equipment settings.

---

## Root Cause of Original Problem

### Phase 133 Design Flaws (pre-Phase-100)

| Issue | Detail |
|---|---|
| `hasEquipment = true` default | Filter was **skipped entirely** for all users who did not explicitly answer the equipment question (legacy installs + default path) |
| Dumbbell exercises in block list | `_equipmentSlugs` lumped dumbbell exercises (lateral raise, curl, dumbbell row, goblet squat…) with barbell/machine exercises — both wrongly removed when `hasEquipment=false` |
| Unfiltered fallback | The coalesce chain's last entry was the raw `pool` — gym exercises could enter via the fallback path even when the filter ran |
| Filter applied after goal-filtering | Even when the filter ran, it operated per-day inside the loop rather than once on the full pool, adding unnecessary complexity |

---

## Changes Made

### `lib/features/workout/domain/services/workout_generator_service.dart`

**Renamed / replaced:**
- `_equipmentSlugs` → `_gymOnlySlugs` (set size reduced from 44 to 35 slugs; dumbbell exercises removed from block list)
- `_filterByEquipment()` → `_filterForHomeWorkout()`

**Logic change — filter applied upfront:**
```
OLD (Phase 133):
  pool → goalFilter → levelFilter → applyEquipment(conditional) → coalesce → pool (fallback)

NEW (Phase 100):
  pool → _filterForHomeWorkout() → homePool
       → goalFilter(homePool) → levelFilter → coalesce → homePool (fallback)
```

The home-workout filter now runs **once** on the entire pool before goal and level filtering, so all downstream steps operate only on valid home exercises.

**Fallback chain fixed:**
- All four coalesce entries now point to home-filtered lists
- `pool` (unfiltered) is the absolute last resort but now triggers a runtime error log if reached

**Runtime validation added:**
- `_assertNoGymEquipment()` inspects each day's final exercises and logs an error for any gym-only slug that slipped through
- A hit means a new equipment exercise was added to Supabase without updating `_gymOnlySlugs`

**`hasEquipment` parameter:**
- Retained in the method signature for cache-fingerprint compatibility
- No longer controls any filtering logic

### `lib/features/workout/data/workout_repository.dart`

**Cache key bumped v6 → v7:**
- `sixpack.user_custom_plan_v6` → `sixpack.user_custom_plan_v7`
- `sixpack.user_custom_plan_fingerprint_v6` → `sixpack.user_custom_plan_fingerprint_v7`
- Forces all existing users to regenerate their plans on next launch, eliminating any cached plans that contain gym exercises

---

## Exercises Removed from Block List (Now Allowed in Home Plans)

These were in `_equipmentSlugs` (Phase 133) but are valid **home/dumbbell** exercises:

| Slug | Equipment | Home-Compatible? |
|---|---|---|
| `shoulder_press` | Dumbbells | ✅ Yes |
| `arnold_press` | Dumbbells | ✅ Yes |
| `lateral_raise` | Dumbbells | ✅ Yes |
| `front_raise` | Dumbbells | ✅ Yes |
| `rear_delt_fly` | Dumbbells | ✅ Yes |
| `upright_row` | Dumbbells | ✅ Yes |
| `cuban_press` | Dumbbells | ✅ Yes |
| `biceps_curl` | Dumbbells | ✅ Yes |
| `hammer_curl` | Dumbbells | ✅ Yes |
| `concentration_curl` | Single dumbbell | ✅ Yes |
| `incline_dumbbell_curl` | Dumbbells | ✅ Yes |
| `dumbbell_kickback` | Single dumbbell | ✅ Yes |
| `dumbbell_row` | Single dumbbell | ✅ Yes |
| `dumbbell_clean` | Dumbbell | ✅ Yes |
| `goblet_squat` | Single dumbbell | ✅ Yes |
| `romanian_deadlift` | Dumbbells | ✅ Yes |
| `walking_lunge_dumbbell` | Dumbbells | ✅ Yes |
| `kettlebell_swing` | Dumbbell substitute | ✅ Yes |
| `bulgarian_split_squat` | Bodyweight + chair | ✅ Yes |
| `chest_fly` | Dumbbells (floor) | ✅ Yes |

---

## Scope Boundaries

| System | Modified? |
|---|---|
| Equipment workout cards (Ekipmanlı strip) | ❌ NOT modified |
| Regional bodyweight programs | ❌ NOT modified |
| Exercise Supabase database | ❌ NOT modified |
| Analyzer/pose detection systems | ❌ NOT modified |
| Premium exercise tags | ❌ NOT modified |
| Onboarding wizard | ❌ NOT modified |
| **Personalized 30-day generator** | ✅ Modified |

---

## Files Changed

```
lib/features/workout/domain/services/workout_generator_service.dart
lib/features/workout/data/workout_repository.dart
```
