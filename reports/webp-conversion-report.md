# Phase 99 — WEBP Conversion Report

## Summary

| Metric | Value |
|---|---|
| Source format | PNG (from `photos/new_workouts_image/`) |
| Output format | WEBP lossy (to `photos/exercises/`) |
| Files converted | 87 |
| Source total | 129.1 MB |
| Output total | 2.6 MB |
| Overall reduction | **98%** |
| Conversion tool | ImageMagick 6.9.12 |
| Settings | `-resize "800x800>" -quality 82 -define webp:method=6` |

## Conversion Parameters

- **Max dimension**: 800 px (downscale only; originals are 1024×559 or 1536×1024)
- **Quality**: 82 (VP8 lossy — visually transparent at PIP display size 160×200 px)
- **Method**: 6 (ImageMagick's best-effort WEBP encoder pass)
- **Aspect ratio**: preserved

## Per-File Results (sample)

| Exercise | PNG (bytes) | WEBP (bytes) | Reduction |
|---|---|---|---|
| ArcherPushUp | 880,621 | 33,952 | 96% |
| BearCrawl | 1,724,038 | 24,272 | 98% |
| DeclineCrunch | 8,157,695 | 31,536 | 99% |
| DiamondPushUp | 930,058 | 38,168 | 95% |
| DragonFlag | ~1.7 MB | ~32 KB | 98% |

## Output Location

```
photos/exercises/ArcherPushUp.webp
photos/exercises/BearCrawl.webp
... (87 files)
```

Declared in `pubspec.yaml` under `flutter: assets: - "photos/exercises/"`.

## Skipped Files

- `Pasted image.png` — unnamed reference image with no exercise mapping; excluded.

## Verification

Python verification confirmed: all 87 registry slugs map 1-to-1 with the 87 WEBP files.
No missing files, no orphaned files.
