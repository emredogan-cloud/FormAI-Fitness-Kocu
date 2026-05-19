# RecipeImage Migration Map — Phase 2-A.5

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.5 Flutter Prep (non-destructive — widget created, no call sites swapped yet)
> **Widget created:** `lib/features/nutrition/presentation/widgets/recipe_image.dart`

---

## 1. The replacement contract

`RecipeImage` is a **drop-in for `CachedImage`** for the meal/recipe surface
area. Public API matches `CachedImage` except for an optional `slug:` field
(omit it and the slug is derived from the URL):

```dart
// Old
CachedImage(url: src, fit: BoxFit.cover, memCacheHeight: 300, errorBuilder: …)

// New (drop-in)
RecipeImage(url: src, fit: BoxFit.cover, memCacheHeight: 300, errorBuilder: …)
```

The rename is a **mechanical text replace** at each call site identified
below. No prop reshuffle, no caller refactor, no fallback rewrite — the
`errorBuilder` already passed in stays as-is.

The plan claimed `Recipe.slug` exists. **It does not** (`Recipe.fromJson`
exposes `id, title, mealType, calories, protein, carbs, fat, prepTimeMinutes,
imageUrl, instructions, tags, ingredients` — no slug). `RecipeImage` derives
the slug internally from the URL's last path segment, so the migration does
not need a `Recipe` model change.

---

## 2. Call sites to migrate

All 7 sites are confined to `lib/features/nutrition/presentation/`.

| # | File | Line | Wrapper class | What it renders | Notes |
|---|---|---:|---|---|---|
| 1 | `recipe_detail_screen.dart` | 140 | `_HeroImage` | Recipe-detail full-bleed hero | `memCacheHeight: 800` — the largest of the bunch; LQIP still works (decodes at 64 px) |
| 2 | `nutrition_tab.dart` | 942 | `_Thumb` | Nutrition tab recipe-card thumbnail | Called from line 807; passes `recipe.imageUrl` |
| 3 | `category_recipes_screen.dart` | 313 | `_Thumb` | Category-filtered list thumbnail | Same `_Thumb` shape as nutrition_tab |
| 4 | `favorites_screen.dart` | 310 | `_Thumb` | Favorites list thumbnail | Same `_Thumb` shape |
| 5 | `discover_recipes_screen.dart` | 468 | `_Thumb` | Discover grid thumbnail | Same `_Thumb` shape; passes `recipe.imageUrl` via `_Thumb(imageUrl: recipe.imageUrl)` at line 378 |
| 6 | `widgets/next_best_meal_card.dart` | 324 | `_HeroThumb` | Today's-next-meal hero card | Passes `recipe.imageUrl` directly (line 310); `memCacheHeight: 400` |
| 7 | `widgets/meal_plan_timeline.dart` | 1020 | `_RecipeThumb` | Day-by-day meal-plan timeline thumb | Same shape as the other `_Thumb` widgets |

### Per-site exact diff (for the executor of Phase 2-A.5-do)

Each call site has the same shape:

```dart
//  before
import '../../../core/widgets/cached_image.dart';
…
class _Thumb extends StatelessWidget {            // or _HeroImage / _HeroThumb / _RecipeThumb
  …
  Widget build(BuildContext context) {
    …
    return CachedImage(                            // ← rename this token
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 300,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
```

```dart
//  after
import 'widgets/recipe_image.dart';                // ← path adapts per file's depth
…
return RecipeImage(                                // ← only this token renames
  url: src,
  fit: BoxFit.cover,
  memCacheHeight: 300,
  errorBuilder: (_, __, ___) => fallback,
);
```

Import path adjustments (relative to each file):
- `recipe_detail_screen.dart`: `import 'widgets/recipe_image.dart';`
- `nutrition_tab.dart`: `import 'widgets/recipe_image.dart';`
- `category_recipes_screen.dart`: `import 'widgets/recipe_image.dart';`
- `favorites_screen.dart`: `import 'widgets/recipe_image.dart';`
- `discover_recipes_screen.dart`: `import 'widgets/recipe_image.dart';`
- `widgets/next_best_meal_card.dart`: `import 'recipe_image.dart';`
- `widgets/meal_plan_timeline.dart`: `import 'recipe_image.dart';`

The existing `import '../../../../core/widgets/cached_image.dart';` line
**stays** — `CachedImage` is still used by every non-recipe surface
(workout plan covers, exercise media, etc.) and is also re-used inside
`RecipeImage` itself.

---

## 3. Call sites to NOT migrate

### 3.1 Budget-meal category covers (non-recipe UI)

| File | Line | Reason |
|---|---:|---|
| `nutrition_tab.dart` | 1505 | Renders `entry.imageUrl` where `entry` is a `_BudgetCategoryEntry` constant from lines 1418-1446 — paths like `'photos/meals/budget_cover_breakfast.webp'`. These are **UI category tiles**, not `Recipe` rows. No DB row, no slug, no LQIP. Plan §1.2 of `MEAL_ASSET_INVENTORY.md` already triaged these for separate handling. **Leave as `CachedImage`.** |

If/when the 5 budget covers are moved to CDN in a separate follow-up,
the call site stays `CachedImage` (the URLs at that point will be full
network URLs, and `CachedImage` already handles those correctly).

### 3.2 CachedImage call sites outside nutrition feature

Out of scope for this migration:

```
lib/core/widgets/cached_image.dart        (the widget itself)
lib/features/workout/                     (workout-plan covers, exercise media)
lib/features/onboarding/                  (onboarding hero images)
lib/features/home/                        (dashboard backgrounds)
… etc.
```

None of these render recipe images. The bare `grep -r "CachedImage.*recipe\." lib/`
returns 0 results, confirming there are no rogue `CachedImage(url: recipe.xxx)`
patterns outside the 7 sites listed in §2.

---

## 4. Migration complexity

| Site | Complexity | Risk | Visual delta |
|---|---|---|---|
| 1. `_HeroImage` (recipe_detail) | Trivial | Low | LQIP shows behind the 800-px hero photo on cold open; visible for ~50–200 ms then full image fades over |
| 2. `_Thumb` (nutrition_tab) | Trivial | Low | Per-card LQIP on first scroll; invisible after warm |
| 3. `_Thumb` (category_recipes) | Trivial | Low | Same as #2 |
| 4. `_Thumb` (favorites) | Trivial | Low | Same as #2 |
| 5. `_Thumb` (discover_recipes) | Trivial | Low | Same as #2 |
| 6. `_HeroThumb` (next_best_meal_card) | Trivial | Low | LQIP shows behind the dashboard's "next meal" hero on cold start |
| 7. `_RecipeThumb` (meal_plan_timeline) | Trivial | Low | Same as #2 |

**All 7 sites are mechanically identical: rename `CachedImage` → `RecipeImage`,
add one import, no behavioural change for callers.**

---

## 5. Regression risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| LQIP-asset-missing fires `errorBuilder` of the bottom layer continuously | None | n/a | The widget's `errorBuilder` for `Image.asset` returns `SizedBox.shrink()`; no exception path |
| Stack layering causes double-decode of the same image | Low | Minor mem overhead (~12 KB per LQIP for the 64-px decode) | `cacheHeight: 64` on the LQIP layer caps decode; full image still uses caller's `memCacheHeight` |
| Existing `errorBuilder` (branded fallback) was relied on when network failed | **Yes — behaviour CHANGES** | LQIP becomes the fallback instead of the icon-on-grey panel | **Intentional**. Document in release notes. PMs may A/B preference for one over the other. |
| Slug derivation drops a recipe whose URL has an unexpected shape (rare external URL) | Low | LQIP layer absent for that recipe; falls back to caller's `errorBuilder` exactly like today | Acceptable — visual is at-worst the existing behaviour |
| `Image.asset` cacheHeight collides with `BoxFit.cover` over a portrait-aspect container | Very low | Minor blur quality | Tested at 64-px decode + 8× upscale; matches Flutter's documented behaviour |
| Pre-Phase-2-A.4 builds use `photos/meals/<slug>.webp` paths, and the LQIP layer also tries to render the same slug's LQIP — but the LQIP file might not yet be in pubspec | **Yes — but only between widget swap and pubspec update** | Bottom layer errors out silently → invisible LQIP → user sees identical-to-today behaviour | **Order of execution matters.** Bulk-generate LQIPs + add `assets/lqip/meals/` to pubspec BEFORE switching call sites. Documented as a sequencing prereq in §7 below. |

### The one true regression risk

The branded-fallback panel (a gradient with a meal/dish icon) currently
shows on every meal whose image fails to load. After the swap, it **only**
shows on meals whose LQIP is also missing — which after bulk LQIP
generation is **none of the 293 migrated meals**. Behaviour for the
~5–10% of recipes that are Unsplash-legacy URLs is **unchanged** because
they don't get a matching LQIP either.

This is the intended visual improvement of the migration. PM should
confirm in §7.

---

## 6. Why we do NOT swap call sites yet

This phase is **non-destructive** per the controlled-execution brief:

- The `RecipeImage` widget exists (`lib/features/nutrition/presentation/widgets/recipe_image.dart`) but **nothing imports it yet**.
- All 7 call sites still use `CachedImage`. Today's behaviour is byte-identical to last commit on `main`.
- Removing `photos/meals/` from pubspec is **not done**.
- Adding `assets/lqip/meals/` to pubspec is **not done**.

The widget is therefore unused code on this branch. A `flutter analyze`
run will flag the new file as "unused import target" but not as an error
(it's a class definition, not an unused-import warning). Phase 2-A.5-do
(the actual call-site swap) is the next step after the precheck gates pass.

---

## 7. Required execution order (when Phase 2-A.5-do runs)

```text
1. Bulk-generate LQIPs              ← Phase 2-A.2-bulk: `python3 scripts/generate_meal_lqips.py --all`
2. Add assets/lqip/meals/ to pubspec ← surgical: 1-line addition
3. Switch 7 call sites              ← mechanical token rename + import
4. Upload images to Supabase Storage ← Phase 2-A.3-execute
5. DB rewrite                        ← Phase 2-A.4 (BEGIN/UPDATE/COMMIT)
6. Smoke test                        ← cold-cache install on test device
7. Remove `photos/meals/` from pubspec
8. Delete local `photos/meals/`     ← Phase 2-A.7 (backup retained in /tmp)
```

Steps **1–3** are reversible by git revert. Steps **4–5** are
reversible via the rollback SQL in §4 of the migration plan. Steps
**7–8** are reversible from the `/tmp` backup mirrored to a persistent
location.

---

## 8. Smoke-test plan (for after step 6 above)

| Scenario | Expected | Failure mode if regressed |
|---|---|---|
| Fresh install, open Nutrition tab | All 6 visible cards paint LQIP within 50 ms, real images fade in within 1–2 s on wifi | Grey holes → LQIP missing from pubspec or asset path wrong |
| Cold cache + airplane mode | All cards show LQIPs; no broken-icon fallbacks | Branded fallback visible → LQIP file missing for that slug |
| Slow 3G | LQIP visible for the full 5–15 s loading window | Network-image flicker without LQIP → widget swap missed at that site |
| Restart app (warm cache) | Full images load immediately, LQIP imperceptible (replaced before frame paint) | If LQIP visible: cache-network-image cache key changed unexpectedly |
| Open RecipeDetail | Hero image shows LQIP first, full image fades in within 1 s | Same as nutrition-tab failure modes |

---

## 9. Files written / touched in this phase

```text
NEW    lib/features/nutrition/presentation/widgets/recipe_image.dart   (147 lines)
NEW    RECIPE_IMAGE_MIGRATION_MAP.md                                   (this file)
```

**Zero edits to existing source files.** Zero pubspec changes. Zero
asset changes besides the 8 sample LQIPs created in Phase 2-A.2.

---

## 10. Gates passed

- [x] `RecipeImage` widget exists and is internally well-formed
- [x] Every recipe-image call site enumerated (7 sites)
- [x] Non-recipe call sites identified and explicitly excluded (1 site)
- [x] Per-site diff sketched
- [x] Sequencing prereqs documented (bulk LQIPs + pubspec BEFORE call-site swap)
- [x] Regression risks enumerated with mitigations
- [x] Smoke-test plan written
- [x] No call sites modified yet (per non-destructive brief)

**Phase 2-A.5 status:** ✅ widget ready, migration map complete. Awaiting
sign-off before Phase 2-A.5-do executes the 7 mechanical swaps.
