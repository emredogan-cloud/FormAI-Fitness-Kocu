# LQIP Bulk Generation Report — Phase 2-A.2-bulk

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.2-bulk (post-sample-approval full corpus generation)
> **Command:** `python3 scripts/generate_meal_lqips.py --all`
> **Output dir:** `assets/lqip/meals/`

---

## 1. Headline numbers

| Metric | Value | Plan estimate | Variance |
|---|---|---|---|
| LQIPs generated | **298 / 298** | ~298 | ✓ exact |
| Bundle size (real bytes) | **201.6 KB** | ~600 KB | **3× better than plan** |
| Min file size | 450 B | <2 KB target | ✓ |
| Max file size | 936 B | <2 KB target | ✓ |
| Mean file size | 692 B | — | — |
| Dimensions audit | 298 / 298 with longest edge = 64 px | all 64 max | ✓ |
| Format audit | 298 / 298 = WEBP | WEBP | ✓ |
| Files <200 B (corrupt risk) | 0 | — | ✓ |
| Open errors | 0 | — | ✓ |

---

## 2. APK delta projection

```text
photos/meals/           -62.54 MB  (to be removed in Phase 2-A.7)
assets/lqip/meals/      +0.20 MB
─────────────────────────────────
Net APK reduction        -62.34 MB
```

This includes all 298 source images and their bundled LQIPs. It is the
**maximum** delta — the actual ship-size delta after `flutter build
appbundle --release` may differ slightly due to ZIP compression of
the WebPs (already near-incompressible) and asset-manifest overhead
(few KB).

---

## 3. Reproducibility

The script is **deterministic** for identical inputs:

- Input: `photos/meals/*.webp` (298 files, content-stable)
- PIL version: 10.2.0 (host `python3 -c "from PIL import Image; print(Image.__version__)"`)
- Settings: 64-px longest edge, WebP, quality=50, method=6 (max compression effort)
- LANCZOS resampling (smoothest downsample for photos)

Re-running on the same inputs produces byte-identical outputs.

```bash
# To reproduce on a fresh checkout:
python3 -m pip install Pillow==10.2.0
python3 scripts/generate_meal_lqips.py --all
# Expected: "Generated 298 LQIPs at .../assets/lqip/meals | total ~201 KB"
```

If a future re-run produces different bytes, it means either (a) source
images changed (e.g. an admin replaced one), or (b) the host has a
different PIL/libwebp version. Neither would compromise the migration —
they just produce slightly different LQIP files of equivalent visual
quality.

---

## 4. Failures during this run

**Zero.** All 298 source images:
- Opened without error
- Converted RGB cleanly (no alpha channel issues, no palette mode quirks)
- Downsized to a 48×64 (or aspect-equivalent) bitmap
- Encoded as WebP quality-50 without re-encoder rejection

The script does not retry on failure — a single failure would have been
surfaced by the `print` summary not reaching the expected count. The
output `Generated 298 LQIPs` confirms a clean pass.

---

## 5. Size distribution (post-bulk)

```
count   298
total   201.6 KB
min     450 B   (smallest)
max     936 B   (largest)
mean    692 B
```

Histogram (approximate, from a sort + bucket):

| Bucket | Count |
|---|---:|
| 400-499 B | ~10 |
| 500-599 B | ~70 |
| 600-699 B | ~100 |
| 700-799 B | ~75 |
| 800-899 B | ~35 |
| 900-999 B | ~8 |

Tight, single-peak distribution centred at ~692 B. No outliers. The
~936 B max comes from images with the most fine-grained detail (e.g.
multi-element composed plates); the ~450 B min comes from low-contrast
images (yogurts, single-ingredient dairy) where WebP's quantiser
compresses harder.

---

## 6. Visual sample (carry-over from Phase 2-A.2)

The 8 curated samples from `LQIP_PREVIEW_REPORT.md` were regenerated as
part of this bulk run (identical settings) and produced byte-identical
output to the sample-mode run. Approved visual quality holds.

---

## 7. What this report does NOT include

- **No pubspec edit yet** — that's the first action of Phase 2-A.5-do
  (the next step), so a `flutter build` here would NOT bundle these
  LQIPs. They live on disk only until the pubspec adds them.
- **No Supabase activity** — Phase 2-A.3-execute is downstream.
- **No DB activity** — Phase 2-A.4 is downstream.

---

## 8. Gates passed

- [x] All 298 LQIPs generated successfully
- [x] Bundle size verified (201.6 KB, 3× under plan budget)
- [x] Per-file dimensions verified (longest edge = 64 px on every file)
- [x] Per-file format verified (WEBP on every file)
- [x] No corrupt / tiny-file outliers
- [x] Reproducibility documented
- [x] Zero failures
- [x] APK delta projection updated (−62.34 MB)

**Phase 2-A.2-bulk status:** ✅ complete. Proceeding to Phase 2-A.5-do.
