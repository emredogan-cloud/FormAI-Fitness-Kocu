# Tier 3 — Asset Scope Audit

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — no mutations applied.

---

## 0. Headline

Pubspec asset declarations vs reality after Tier 2-A:

```yaml
flutter:
  assets:
    - .env
    - "photos/"               # 52 webp at root (~3 MB) — all referenced
    - "photos/meals/"         # 5 budget_cover_*.webp (~1 MB) — all referenced
    - "photos/workouts/"      # 33 webp (~3.2 MB) — all referenced
    - "photos/exercises/"     # 87 webp (~2.8 MB) — all referenced
    - "assets/lqip/meals/"    # 298 LQIPs (~200 KB) — Tier 2-A
```

**Every declared directory contains only-used files** (post-Phase-139 + Tier 2-A cleanup). **No orphan asset declarations.** No fonts beyond `MaterialIcons-Regular.otf` (tree-shaken from 1.6 MB → 27 KB).

---

## 1. Bundling reality vs intent

Verified by `unzip -l build/app/outputs/flutter-apk/app-release.apk`:

| Asset path | Bundle count | Bundle bytes | Expected? |
|---|---:|---:|---|
| `assets/flutter_assets/photos/` (root) | 52 files | ~3,072 KB | ✓ matches working tree |
| `assets/flutter_assets/photos/meals/` | 5 files | ~1,038 KB | ✓ (budget covers post-Tier-2A) |
| `assets/flutter_assets/photos/workouts/` | 33 files | ~3,200 KB | ✓ |
| `assets/flutter_assets/photos/exercises/` | 87 files | ~2,800 KB | ✓ |
| `assets/flutter_assets/assets/lqip/meals/` | 298 files | ~205 KB | ✓ (Tier 2-A) |
| `assets/mlkit_pose/*.tflite` | 3 files | ~11,900 KB | bundled by `google_mlkit_pose_detection` plugin (not by us) |
| `assets/flutter_assets/fonts/` | MaterialIcons-Regular.otf | 27 KB | ✓ tree-shaken |
| `assets/flutter_assets/FontManifest.json` | 1 | 82 B | ✓ |
| `assets/flutter_assets/AssetManifest.json` / `.bin` | 2 | small | required for Image.asset lookup |

**Per-bucket orphan scan:**

```bash
# photos/ root — every file's basename was grepped against lib/ *.dart
for f in $(ls photos/*.webp); do
  ! grep -rq "$(basename $f)" lib/ --include="*.dart" && echo "ORPHAN: $f"
done
# Output: (empty — 0 orphans)
```

```bash
# photos/workouts/ — referenced via lib/features/workout/data/workout_repository.dart
# photos/exercises/ — referenced via lib/features/workout/data/exercise_media_registry.dart
# photos/meals/ — 5 budget_covers referenced via lib/features/nutrition/presentation/nutrition_tab.dart
```

All ✓. **No bundled-but-unreferenced asset.**

---

## 2. Non-pubspec assets (NOT bundled, but living in the repo)

These take working-tree space but **do not ship in the APK**:

| Path | Size | Reason for keeping |
|---|---:|---|
| `tool/app_icon.png` | 1.4 MB | flutter_launcher_icons source — read at icon-generation time only. Per Phase 120 comment in pubspec. |
| `docs/screenshots/*.jpg` | 4.9 MB | README + design references |
| `docs/reference-imagery/*.png` | 4.5 MB | Designer / Claude prompts. Phase 127 explicitly moved them here to keep them OUT of the asset bundle. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | 1.3 MB | iOS App Store icon source |
| `Beslenme-Photos/*.jpeg` | 2.3 MB | gitignored; personal reference media (per `.gitignore` Phase 40 comment) |
| `asosystem/` (entire) | 245 MB | Separate Vite landing-page project. Not Flutter. See `REPO_HYGIENE_AUDIT.md §1`. |

None of these inflate the APK; some inflate the working tree. Repo hygiene rather than APK concerns.

---

## 3. Dev-only assets currently in release scope?

**None found.** Phase 139 Tier 3-B removed `assets/ONBOARDING_EXAMPLE_VİDEO.mp4` (3.4 MB) — the only known dev-only asset previously declared. The remaining `assets/lqip/meals/` is genuinely release-critical (LQIP fallback).

---

## 4. Was there ever a way to ship dev assets accidentally?

Yes — and Phase 127 caught it:

> *"Phase 127 · ASSET HYGIENE RULE. This `- "photos/"` declaration is non-recursive (Flutter's asset semantics — every subdirectory needs its own line below) but it DOES bundle every file at the root of `photos/` into the APK. Art-direction reference imagery (Claude conversation visual targets, design comp screenshots, cinematic mood boards) belongs at `docs/reference-imagery/` — NOT at the root of `photos/`. The Phase 127 audit caught 3 large reference PNGs (4.6 MB combined) that had drifted into `photos/` between Phases 124 and 126 and were silently shipping in every APK; they have since been relocated."* — `pubspec.yaml:167-178`

This rule **must remain enforced**: anything at the root of `photos/`
ships in the APK. Stay vigilant when adding new artwork.

---

## 5. Recommendations

| # | Action | Risk | Notes |
|---|---|---|---|
| 1 | **Enforce the Phase 127 asset hygiene rule** — periodically `du -sh photos/*` and any file > 200 KB at the root of `photos/` warrants a sanity check. | 🟢 zero | Documentation rule, not a code change |
| 2 | **Document in `CONTRIBUTING.md` or `docs/CONTENT_OPS.md`** that art-direction references go to `docs/reference-imagery/`, not `photos/` | 🟢 zero | Already exists per pubspec comment, but easier to see if also surfaced in dev docs |
| 3 | Consider whether the 5 `budget_cover_*.webp` deserve their own subdirectory (e.g. `photos/category_covers/`) so the now-confusing `photos/meals/` pubspec entry can eventually be removed | 🟡 needs source edits | Hardcoded paths in `nutrition_tab.dart` lines 1418–1446 would need a rename; not a size win, just clarity. Defer. |
| 4 | iOS app icon: 1.3 MB is normal for a 1024×1024 PNG | 🟢 zero | Apple requires this exact size. No change. |

---

## 6. Cross-references

- `MEAL_ASSET_INVENTORY.md` — full pre-Tier-2A inventory of `photos/meals/`
- `RECIPE_IMAGE_MIGRATION_MAP.md` — confirmed every `CachedImage(recipe.imageUrl)` call site was migrated; the only remaining CachedImage in nutrition uses `entry.imageUrl` for the budget covers (NOT a recipe)
- `LQIP_BULK_REPORT.md` — confirms 298 LQIPs / 201.6 KB total / all bundled
- `TIER3_SIZE_AUDIT.md §1.3` — APK-side measurement of photos/

---

## 7. Risk classification

| Tier | Items |
|---|---|
| **T1 — low risk / high gain** | None — asset scope is already clean post-Phase-139 + Tier 2-A. |
| **T2 — medium complexity** | `photos/category_covers/` rename (clarity, not size). |
| **T3 — architecture-sensitive** | None. |

---

## 8. Bottom line

**The asset surface is in steady state.** Phase 139 cleaned orphans
and re-encoded the 2 PNG-as-WebP outliers. Tier 2-A removed the
single biggest contributor (`photos/meals/` 64 MB). The remaining
asset footprint is the minimum required for the product's offline + onboarding
guarantees.

The only outstanding improvement is **conceptual**, not byte-saving:
the 5 budget covers could move to `photos/category_covers/` so the
`photos/meals/` pubspec entry can be retired entirely — but that's a
clarity refactor, not a size win.
