# Report Archive — T2.6

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Move 25 historical engineering reports from `reports/` (top level) to `reports/archive/`. Move 4 strategy-research subdirs to `docs/archive/strategy-research/` (covered in `ARCHIVE_STRUCTURE_REPORT.md §6`).
> **Status:** APPLIED.

---

## 1. What stays at `reports/` top level (2 files — active)

These are the 2 `reports/` files classified as **A — Active** in `MARKDOWN_CORPUS_AUDIT.md §3`:

| File | Reason kept active |
|---|---|
| `reports/phase-138-build-perf-final-report.md` | Referenced by `BUILD_TIME_AUDIT.md` as the current build-performance baseline. |
| `reports/render-performance-profile-guide.md` | Actionable measurement guide for when runtime perf is next audited. Phase 122 wrote it specifically for re-use. |

---

## 2. What moved to `reports/archive/` (25 files)

All marked B — Historical in `MARKDOWN_CORPUS_AUDIT.md §3`. Each documents a completed engineering phase, a resolved diagnostic, or a no-longer-active design.

### 2.1 `git mv` (9 files — previously tracked, history preserved)

```
reports/android-build-performance-audit.md       (Phase 117)
reports/exercise-media-fallback-system.md        (Phase 99)
reports/onboarding-emotional-rebuild-analysis.md (n/a)
reports/phase-127-build-iteration-forensic.md    (Phase 127)
reports/reference-video-gap-analysis.md          (Phase 107)
reports/rive-snap-flutter-investigation.md       (n/a)
reports/snap-flutter-migration-guide.md          (n/a)
reports/video-to-image-mapping.md                (Phase 99)
reports/webp-conversion-report.md                (Phase 99)
```

### 2.2 `mv` (16 files — previously untracked, now added at archive path)

```
reports/30day-generator-validation.md            (Phase 100)
reports/dashboard-workout-integration.md         (Phase 97)
reports/equipment-program-consolidation.md       (Phase 98)
reports/exercise-video-prompts.md                (Phase 96)
reports/home-workout-filter-rules.md             (Phase 100)
reports/ml-detection-strategy.md                 (Phase 96)
reports/new-dashboard-programs.md                (Phase 97)
reports/new-exercise-library.md                  (Phase 96)
reports/personalized-generator-equipment-filter.md (Phase 100)
reports/phase98_black_screen_root_cause.md       (Phase 98)
reports/premium-workout-distribution.md          (Phase 98)
reports/premium-workout-refactor.md              (Phase 98)
reports/workout-category-distribution.md         (Phase 97)
reports/workout-integration-summary.md           (Phase 96)
reports/workout-system-analysis.md               (n/a)
reports/workout-system-gap-analysis.md           (n/a)
```

These previously sat untracked on the working tree. The archive commit creates their first git history at the archive location — knowledge that was disk-only is now version-controlled.

---

## 3. Phase-N strategy-research subdirs (covered separately)

Already covered in `ARCHIVE_STRUCTURE_REPORT.md §6`. Briefly:

```
reports/phase-1-project-discovery/   →  docs/archive/strategy-research/phase-1-project-discovery/    (2 files)
reports/phase-2-product-analysis/    →  docs/archive/strategy-research/phase-2-product-analysis/     (6 files)
reports/phase-3-psychology/          →  docs/archive/strategy-research/phase-3-psychology/           (7 files)
reports/phase-4-market-intelligence/ →  docs/archive/strategy-research/phase-4-market-intelligence/  (4 files)
```

**Total 19 files** of business/UX/market research relocated out of `reports/`.

---

## 4. End-state of `reports/`

```
reports/
├── archive/                                # 25 historical engineering reports
├── phase-138-build-perf-final-report.md    # active reference for build audit
└── render-performance-profile-guide.md     # active reference for runtime perf
```

The directory is now clearly bisected: **active references** at top level, **historical record** under `archive/`. A grep / search for "what's the current build perf state" surfaces the 2 active files instantly without competing with 25 phase reports.

---

## 5. Preservation guarantees

| Concern | Mitigation |
|---|---|
| Knowledge loss | None. All files moved, not deleted. Searchable at new paths. |
| Git history loss | `git mv` was used for tracked files. The 16 previously-untracked files gain history by being committed at the archive location. |
| Cross-references | None of the 25 archived files are referenced by code, pubspec, or active docs. (Verified via `grep -rln`.) Active docs may reference the **content** of these reports but not the file paths. |
| Rollback complexity | `git revert <commit>` brings every file back to its original location since `git mv` records the rename. |

---

## 6. Why "archive, not delete"

Per the user's brief:

> Preserve: history / git traceability / rollback value
> No deletion.

And the archive strategy from `MARKDOWN_CORPUS_AUDIT.md §9`:

> Prefer `docs/archive/` for historical-but-valuable files. Avoid knowledge loss.

Each of the 25 archived files documents *why* a specific engineering decision was made — e.g., why the Rive dependency was removed (`rive-snap-flutter-investigation.md`), why Phase 97's equipment-strip layout was reverted (`premium-workout-refactor.md`), why we converted from PNG to WebP (`webp-conversion-report.md`). These reasons are not derivable from the code alone; they live in the prose. **Archival preserves them; deletion destroys them.**

---

## 7. Status

**APPLIED.** 25 historical engineering reports + 19 strategy-research files relocated. `reports/` is now active-only; `reports/archive/` is the historical surface. No file deleted. T2.6 complete.
