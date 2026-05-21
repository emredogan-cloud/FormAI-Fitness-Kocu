# Workout Section Removal Report — "Yeni Egzersizler"

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Scope:** Remove the Phase-134 "Yeni Egzersizler" teaser strip from the Antrenman screen.

---

## What Was Removed

### 1. UI mount + widget tree
`lib/features/home/presentation/widgets/antrenman_tab.dart`

- The mount call `_YeniExercisesStrip(category: _selectedCategory)` at the bottom of the antrenman ListView.
- The 7-line block comment above it (Phase 134 doc-comment).
- The entire section's class tree (≈445 lines):
  - `_YeniExercisesStrip` — the ConsumerWidget that read `exercisesProvider` and rendered the horizontal carousel.
  - `_YeniExerciseCard` — the 138-wide card with gradient backdrop + NEW pill.
  - `_NewPill` — the outlined "NEW" badge in each card.
  - `_showYeniExerciseDetail(...)` — the modal-bottom-sheet trigger.
  - `_YeniExerciseDetailSheet` — the Pro-only detail sheet.
  - `_ExerciseMetaChip` — the meta-info pills inside the detail sheet.

### 2. Now-unused imports (antrenman_tab.dart)
- `monetization/models/locked_feature_type.dart` (only `LockedFeatureType` was used, all in removed section)
- `monetization/providers/monetization_provider.dart` (only `isProProvider`, all in removed section)
- `monetization/services/premium_gate_service.dart` (only `premiumGateProvider`)
- `monetization/widgets/locked_overlay.dart` (only `LockedOverlay`)

### 3. Orphaned enum case + scene config
`lib/features/monetization/models/locked_feature_type.dart`
- Removed `LockedFeatureType.regionNewExercise` enum value.
- Removed its branch in the `analyticsSource` extension's switch.

`lib/features/monetization/services/conversion_moment_service.dart`
- Removed the `LockedFeatureType.regionNewExercise: _ConversionConfig(...)` map entry.

---

## What Was Intentionally Kept

| Symbol | Reason |
|---|---|
| `Exercise.isNew` field | Model-level flag; data layer still owns it. Reusable for future UI without re-tagging. |
| `PremiumExerciseTags.newSlugs` | Same — pure data tagging in `WorkoutRepository._exerciseFromRow`. Removing it would touch every exercise row's hydration. Out of scope. |
| `exercisesProvider` | Still used by other features in the workout module. |
| `_neon`, `_neonAccent` (antrenman_tab.dart) | Still referenced by other widgets in the same file. |

---

## Layout Verification

- The section was the last child of the `_buildContent` ListView. Removing it leaves the previous element (`_RegionalPlansList(plans: filteredPlans)`) as the new bottom child. No spacer/SizedBox surgery needed — the section owned its own internal `SizedBox(height: 28)` and the surrounding ListView already provides bottom padding via `MediaQuery.padding.bottom + 36` (line 162).
- No layout gap.

---

## Validation

- `flutter analyze` on the three touched files: **No issues found! (ran in 5.7s)**
- `grep -rn "regionNewExercise\|_YeniExercisesStrip\|_YeniExerciseCard\|_YeniExerciseDetailSheet\|_NewPill\|_showYeniExerciseDetail\|_ExerciseMetaChip" lib/`: zero matches.

---

## Files Touched

1. `lib/features/home/presentation/widgets/antrenman_tab.dart` — main removal + import cleanup
2. `lib/features/monetization/models/locked_feature_type.dart` — enum case removal
3. `lib/features/monetization/services/conversion_moment_service.dart` — scene config removal

---

## Net Change

- 4 imports removed
- 1 enum case + 1 switch branch removed
- 1 scene config entry removed
- 1 widget mount removed
- ~445 lines of widget tree removed
- 0 layout regressions
- 0 dangling references
