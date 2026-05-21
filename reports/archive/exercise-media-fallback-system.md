# Phase 99 — Exercise Media Fallback System

## Problem

Phase 96 added 87 new exercises to the catalogue. These exercises have no
Supabase-hosted `.mp4` videos yet. Before Phase 99, the workout camera screen
displayed a "Video yüklenemedi" error tile in the PIP preview for every
Phase 96 exercise — a clearly unpolished experience.

## Solution Architecture

```
_exerciseFromRow(row)
  └─► ExerciseMediaRegistry.localImagePath(slug)
        ├─ slug in registry? → "photos/exercises/<PascalCase>.webp"  (local asset)
        └─ not in registry?  → null → _composeVideoUrl(slug)          (Supabase video)

ExerciseGuidePlayer(assetPath: exercise.videoUrl)
  ├─ assetPath is https://...mp4  → VideoPlayer (unchanged, existing flow)
  ├─ assetPath is photos/...webp  → Image.asset + Ken Burns animation (Phase 99)
  └─ assetPath null/empty/error   → _FallbackTile (existing safety net)
```

## Files Changed

### New files
| File | Purpose |
|---|---|
| `lib/features/workout/data/exercise_media_registry.dart` | Whitelist of 87 Phase 96 slugs + path resolver |
| `photos/exercises/*.webp` (87 files) | Converted WEBP exercise images |
| `reports/exercise-media-fallback-system.md` | This report |
| `reports/video-to-image-mapping.md` | Full slug ↔ asset mapping |
| `reports/webp-conversion-report.md` | Compression statistics |

### Modified files
| File | Change |
|---|---|
| `lib/features/workout/data/workout_repository.dart` | `_exerciseFromRow`: prefer registry image over Supabase URL |
| `lib/features/workout/presentation/widgets/exercise_guide_player.dart` | Ken Burns animation for image branch; `TickerProviderStateMixin` |
| `pubspec.yaml` | Added `photos/exercises/` asset declaration |

## Existing Video Flow — Untouched

`ExerciseGuidePlayer` was already written to handle both video URLs and image
paths via `_isImagePath`. No changes were made to the video loading pipeline,
cache manager logic, or error listener setup.

## Image Display — Ken Burns Animation

For the static-image branch, a subtle `AnimationController` scales the image
from 1.0× to 1.06× over 8 seconds (looped reverse). The animation:
- Uses `TickerProviderStateMixin` (added to `_ExerciseGuidePlayerState`)
- Is disposed on exercise change (`_stopKenBurns` in `_initialize`)
- Falls back gracefully: if `_kenBurnsAnim` is null, `Image.asset` renders
  directly without the `AnimatedBuilder` wrapper

## Failure Hardening

| Failure mode | Result |
|---|---|
| Missing WEBP file | `Image.asset` `errorBuilder` → `_FallbackTile(errorMode: true)` |
| Slug not in registry → Supabase video fails | Existing error tile (unchanged) |
| Both registry miss AND Supabase 404 | `_FallbackTile(errorMode: true)` |
| `AnimationController` not yet ready | Image renders without Ken Burns |

## Performance

- 87 WEBP files, 2.6 MB total (~30 KB average per image)
- `Image.asset` is synchronous — no async load needed, ready immediately
- Ken Burns uses a single `Transform.scale` — GPU-accelerated, no layout
- Animation ticks only when the image branch is active (video exercises
  are unaffected)

## Upgrade Path

When a Phase 96 exercise gets a Supabase video:
1. Remove its slug from `_localImageSlugs` in `ExerciseMediaRegistry`
2. The exercise automatically picks up the Supabase video URL

The WEBP asset can be removed from `photos/exercises/` in the same PR.

## Validation Checklist

- [x] 87 registry slugs match 87 WEBP files exactly (Python verification)
- [x] `flutter analyze` reports no issues on changed files
- [x] Original exercises continue using Supabase video URL (registry returns null)
- [x] `ExerciseGuidePlayer._isImagePath` already handles `.webp` extension
- [x] `MediaUrl.resolve` passthrough for `photos/` prefix already exists
- [x] Ken Burns disposed on `didUpdateWidget` (no animation leak on exercise change)
- [x] `pubspec.yaml` declares `photos/exercises/` subdirectory
