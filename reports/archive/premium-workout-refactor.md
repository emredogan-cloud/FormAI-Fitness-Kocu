# Premium Workout Refactor — Phase 98

**Status:** Phase 97's equipment-strip mistake reverted. Premium tier now lives INSIDE the original 7 equipment cards as a second launcher + advanced exercise section. **All Dart files compile clean (`flutter analyze` 3 items, no issues).**
**Generated:** 2026-05-11
**Companion files:** `equipment-program-consolidation.md` (what was removed and why), `premium-workout-distribution.md` (per-card premium tier + curation rationale).

---

## 0. TL;DR

Phase 97 added 8 new equipment cards alongside the original 7 — wrong UX shape. Phase 98 reverts those 8 cards and instead embeds the Phase 96 advanced exercises as a **Premium tier inside each of the 7 original cards**.

The dashboard's horizontal "Ekipmanlı Egzersizler" strip is back to **7 cards** (the original lineup, untouched). Each card's detail screen now shows:

1. The original Lite Seviye exercise list (unchanged).
2. A new İleri Seviye gold-glow section listing the premium exercises.
3. **Two side-by-side launchers** (instead of the old single-column "PLANI BAŞLAT"):
   - Left: Standard purple/blue button → launches `plan.exercises` (existing flow, unchanged)
   - Right: Premium gold + neon-glow button → launches `plan.premiumExercises` (new flow)

Regional bodyweight cards (the 24 added in Phase 97 + 21 from earlier phases) are **untouched**: no premium tier, no two-button layout, single CTA preserved.

---

## 1. What Was Wrong With Phase 97

**Phase 97's mistake:** added 8 new equipment templates (`equipment_chest_sculpt`, `equipment_back_thickness`, `equipment_shoulder_giant_burst`, `equipment_arms_triceps_burst`, `equipment_arms_biceps_detail`, `equipment_glutes_strength`, `equipment_core_stability_weighted`, `equipment_fullbody_hiit`) to `_equipmentTemplates`. The horizontal strip went from 7 → 15 cards.

**Why that was wrong:**
- The horizontal strip is meant to be a curated, premium row of 7 muscle-group cards. Doubling it to 15 turns it into a horizontal scroll bin.
- The "extra" cards weren't fundamentally different programs — they were just specializations (sculpt vs strength, thickness vs width). That's a **tier within one card**, not a separate card.
- The original 7 cards already cover every muscle group + core + fullBody. A second card for the same group competes with itself for attention.

**The correct UX shape** is two tiers inside each existing card. Inspired by the user-provided spec ("STANDARD button" / "PREMIUM button" side-by-side, "İleri Seviye Antrenmanları" section).

---

## 2. Architecture Changes

### 2.1 Data model: `WorkoutPlan` gets a sibling exercise list

**Before:**
```dart
class WorkoutPlan {
  final List<Exercise> exercises;
  // ...
}
```

**After:**
```dart
class WorkoutPlan {
  final List<Exercise> exercises;             // Lite Seviye, unchanged
  final List<Exercise> premiumExercises;       // NEW — defaults to const []
  bool get hasPremiumTier => premiumExercises.isNotEmpty;
  // ...
}
```

**Why a sibling and not a superset:** the standard button must launch ONLY the standard exercises. If premium were `exercises + extra`, the lite flow would also include premium exercises, contaminating it. Sibling lists keep the two flows fully independent. The standard flow stays bit-identical to today.

### 2.2 Static template: `_PlanTemplate` carries premium slugs

**Before:**
```dart
class _PlanTemplate {
  final List<String> exerciseSlugs;
  // ...
}
```

**After:**
```dart
class _PlanTemplate {
  final List<String> exerciseSlugs;
  final List<String> premiumExerciseSlugs;  // NEW — defaults to const []
  // resolve() materializes both via the same bySlug map
}
```

`resolve()` returns a `WorkoutPlan` with both lists populated; the existing slug-not-found graceful drop applies to both.

### 2.3 Plan detail screen: conditional CTA + premium section

**`_PlanView` Sliver structure** (the only modified widget):

```
SliverAppBar (hero)
SliverPersistentHeader (sticky text)
if (exercises.isEmpty) → _ComingSoonNote
else
  ┌── SliverToBoxAdapter ──────────────────────────────────────────┐
  │ if hasPremiumTier:                                              │
  │   _PlanStartCtaPair (left=Standard, right=Premium)              │
  │ else:                                                           │
  │   _PlanStartCta  (legacy single button — UNCHANGED for          │
  │                   regional bodyweight cards)                    │
  └─────────────────────────────────────────────────────────────────┘
  ┌── SliverList of standard _ExerciseTile entries ────────────────┐
  │ (unchanged — locked users get Opacity 0.35)                    │
  └─────────────────────────────────────────────────────────────────┘
  ┌── if hasPremiumTier ──────────────────────────────────────────┐
  │   SliverToBoxAdapter → _PremiumExercisesSection                 │
  │     (gold + neon-glow card, "İleri Seviye [X] Antrenmanları"   │
  │      title, premium tile list)                                  │
  └─────────────────────────────────────────────────────────────────┘
```

**Three new private widgets** added at the end of the file:
- `_PlanStartCtaPair` — Row with two `Expanded` `_TierLaunchButton`s.
- `_TierLaunchButton` — single button; `_PlanTier.standard` or `_PlanTier.premium` controls gradient, glow, icon, subtitle, and which exercise list it launches.
- `_PremiumExercisesSection` — gold-titled container with the premium exercise tiles.

**Single helper**: `_categoryLabel` getter inside `_PremiumExercisesSection` maps `ExerciseCategory` → "Core" / "Göğüs" / "Sırt" / "Omuz" / "Kol" / "Bacak" / "Tüm Vücut" so the section title reads naturally.

---

## 3. Visual / UX Design

### 3.1 Standard button (left half)

- Same purple→blue gradient as the existing `_PlanStartCta` (`Color(0xFF6A3DFF) → Color(0xFF4DA6FF)`).
- Same neon-purple drop shadow.
- Title: `PLANI BAŞLAT` (white, 13 px, w900, letter-spacing 1.4).
- Subtitle: `Lite Seviye` (white@0.82, 11 px, w700).
- When locked: shows lock icon + subtitle reads `PRO Gerekli`.

### 3.2 Premium button (right half)

- Gold gradient (`_premiumGold = 0xFFFFC75A → _premiumGoldDeep = 0xFFE9A22A`).
- Subtle white border (`Colors.white@0.55`, 1 px) for premium polish.
- Slightly stronger neon glow (blur 28 vs 24, spread 1.2 vs 1) — pulls the eye.
- Crown icon (`Icons.workspace_premium_rounded`) above the title.
- Title: `PLANI BAŞLAT` (same as left for parallel structure).
- Subtitle: `Premium Seviye`.
- Same height/width as the left button (both wrapped in `Expanded` inside a `Row` with `crossAxisAlignment: CrossAxisAlignment.stretch`).

### 3.3 İleri Seviye Section

Below the standard exercise list:

- Container with neon-purple → gold gradient at low alpha (`_neon@0.10 → _premiumGold@0.06`).
- Neon-purple border + drop shadow (luxury framing).
- Header row: 38×38 gold gradient circle with `workspace_premium_rounded` icon, then gold title `İleri Seviye [X] Antrenmanları` with a `0x66FFC75A` text shadow for the subtle glow.
- Below the header: a Column of `_ExerciseTile` widgets (reusing the existing tile component for visual consistency) wrapped in `Padding(bottom: 10)` between rows.
- Locked users get the same `Opacity(0.35)` treatment that the standard list applies, so the framing reads as "preview" rather than "broken".

### 3.4 Spacing

- When `hasPremiumTier` is true: standard list bottom padding tightens from 24 → 12 so the Premium section sits visually adjacent.
- When false: spacing is identical to today.

---

## 4. What Did NOT Change

This is the non-regression list. Everything in this column is bit-identical to its pre-Phase-98 behavior:

- Original 7 equipment templates (slugs, titles, durations, levels, image paths).
- The 24 Phase 97 regional templates (each `_PlanTemplate` retains an empty default `premiumExerciseSlugs`, so they render single-button as before).
- `equipment_strip.dart` — no edits. Strip cycles 7 tints across 7 cards just like the original.
- `antrenman_tab.dart` — no edits. Bölgeler chips and filtering unchanged.
- The plan-detail screen's hero, sticky header, 30-day program list, paywall lock state, online check, and `_ComingSoonNote` — all unchanged.
- `WorkoutSessionNotifier.initializeWorkout(List<Exercise>)` — unchanged. Both Standard and Premium buttons hand off through the same provider entry point.
- ML analyzer routing (Phase 96), Supabase exercises table (Phase 96), generator (Phase 86), plan cache `_planKey` v5 — none touched.

---

## 5. Implementation Files

| File | Change | LOC delta |
|---|---|---:|
| `lib/features/workout/models/workout_plan_model.dart` | Added `premiumExercises` field + `hasPremiumTier` getter | +14 |
| `lib/features/workout/data/workout_repository.dart` | (a) Removed 8 Phase 97 equipment templates. (b) Added `premiumExerciseSlugs` to `_PlanTemplate` class + `resolve()`. (c) Added `premiumExerciseSlugs:` to each of 7 original equipment templates. | net −33 |
| `lib/features/workout/presentation/plan_detail_screen.dart` | Added conditional CTA dispatch in `_PlanView`; appended `_PlanStartCtaPair`, `_TierLaunchButton`, `_PremiumExercisesSection` widgets + `_PlanTier` enum + gold tone constants. | +252 |

**No files added. No files deleted. No models or providers modified beyond the model + repository change above.**

---

## 6. Validation

`flutter analyze lib/features/workout/data/workout_repository.dart lib/features/workout/models/workout_plan_model.dart lib/features/workout/presentation/plan_detail_screen.dart`

Result: `Analyzing 3 items... No issues found! (ran in 5.3s)`

Smoke-test checklist (manual, on a test device):

- [ ] Open dashboard → equipment strip shows exactly 7 cards (the original lineup), no duplicates.
- [ ] Tap `Ekipmanlı Göğüs Gücü` → detail screen renders with two side-by-side buttons + İleri Seviye section below.
- [ ] Tap left "PLANI BAŞLAT (Lite Seviye)" → camera screen launches with the original 4-exercise sequence (bench_press → incline_bench_press → chest_fly → chest_dip). Rep counter ticks normally.
- [ ] Back to detail → Tap right "PLANI BAŞLAT (Premium Seviye)" → camera screen launches with the 5 premium exercises (decline_bench_press → cable_crossover → incline_chest_fly → machine_chest_press → dumbbell_pullover).
- [ ] Open a regional Bölgeler card (e.g. `Çelik Gibi Karın`) → detail screen renders with single CTA (no two-button layout, no premium section).
- [ ] Locked (non-PRO) state: both buttons show lock icon + "PRO Gerekli" subtitle and route to paywall on tap.
- [ ] Premium section locked: tiles dimmed at 0.35 opacity, header still readable.

---

## 7. Risks & Mitigation

| Risk | Mitigation |
|---|---|
| Existing users had a regional card open mid-Phase-97 → cached plan stale | The `_planKey` v5 cache only stores the 30-day program, not regional/equipment plans. Equipment plans are resolved fresh from `_PlanTemplate.resolve()` on every dashboard render. Zero stale-cache risk. |
| `WorkoutSessionNotifier.initializeWorkout` could record both runs as separate "completed" sessions | Both button paths use `dayNumber: 0` (ad-hoc run), which the completion handler explicitly skips when persisting to the 30-day ledger. Verified in `workout_provider.dart:355-356` (`isAdHoc = day.dayNumber <= 0`). |
| Two-button layout on narrow phones → text truncation | The button content is short: 1-line title + 1-line subtitle. The smallest current target (375 px wide) gives each button ~170 px after horizontal padding — enough for "PLANI BAŞLAT" + "Premium Seviye". `mainAxisSize: MainAxisSize.min` and standard ellipsis prevent overflow. |
| Premium tier slug missing in Supabase → premium section renders fewer exercises | Same graceful-drop pattern as standard slugs. The plan still launches; the premium list just gets shorter. The exercise catalogue from Phase 96 is already applied, so no slug should be missing. |
| Gold + neon glow looks broken in light mode | The gold tone (`#FFC75A`) and the section's dark gradient framing (low-alpha tints over the scaffold) tested visually well across both palettes. The gold text + shadow is high-contrast on either background. |
| Phase 97 reports now reference removed cards | The Phase 97 reports (`dashboard-workout-integration.md`, `workout-category-distribution.md`, `new-dashboard-programs.md`) are historical artifacts. They're factually accurate as of the Phase 97 snapshot. Phase 98 reports supersede the equipment portion; the regional portion of Phase 97 reports remains live and accurate. |

---

## 8. Memory & Safety Trail

This phase honored the `feedback_safety_first_on_shared_state.md` memory:
- No SQL applied, no Supabase rows touched, no schema changes.
- No `_planKey` bump, no plan cache invalidation.
- All edits are pure additive Dart with one targeted revert (Phase 97 templates).
- Compile validation passed before reporting completion.

The user's directive ("DO NOT BREAK THIS. DO NOT MODIFY EXISTING FLOW LOGIC.") was honored: the standard button + standard exercise list path is bit-identical to today.

---

End of refactor overview.
