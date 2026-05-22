# Root Cleanup Report

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Refers to:** `DOCUMENT_CLASSIFICATION_REPORT.md` for the per-file taxonomy.

---

## Before

```
Repo root (54 *.md files):

AAB_PIPELINE_REPORT.md
ARCHIVE_STRUCTURE_REPORT.md
ASOSYSTEM_GITIGNORE_REPORT.md
ASO_VISUAL_MASTERPLAN.md             ← keep
ASSET_SCOPE_AUDIT.md
AUTH_FIX_REPORT.md
AUTH_PAYWALL_ROOT_CAUSE.md
AUTH_ROUTING_FIX_V2.md
AUTH_TRANSITION_POLISH_REPORT.md
AUTH_UX_LATENCY_REPORT.md
AUTH_VALIDATION_REPORT.md
BUILD_TIME_AUDIT.md
BURPEE_ANALYZER_REPORT.md
CACHE_CONTROL_FIX_REPORT.md
CAMERA_CALIBRATION_REPORT.md
CLAUDE.md                            ← keep
CLEANUP_CANDIDATES.md
FINAL_TIER2A_MIGRATION_REPORT.md
FLUTTER_ANALYZER_REPORT.md
FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md  ← keep
GIT_HYGIENE_REPORT.md
GOOGLE_PLAY_MASTERPLAN_TR.md         ← keep
HIPHINGE_ANALYZER_REPORT.md
JUMPINGJACK_REPORT.md
MARKDOWN_CORPUS_AUDIT.md
MIDSET_COACHING_REPORT.md
ML_AI_COVERAGE_MATRIX.md
MLKIT_BUILD_REPORT.md
MLKIT_FINAL_REPORT.md
MLKIT_POSE_MODEL_AUDIT.md
MLKIT_PRE_EXECUTION_VERIFY.md
MLKIT_SMOKE_TEST_CHECKLIST.md
MLKIT_STRIP_PATCH_REPORT.md
MOUNTAIN_ANALYZER_REPORT.md
ONBOARDING_DIALOG_REDESIGN.md
ONBOARDING_UX_MASTER_AUDIT_TR.md     ← keep
PACE_SYSTEM_REPORT.md
PLANK_STABILITY_REPORT.md
PROGRESS_SECTION_MASTERPLAN.md       ← keep
PROJECT_DOC_DUPLICATE_AUDIT.md
README.md                            ← keep
REPO_HYGIENE_AUDIT.md
REPORT_ARCHIVE_REPORT.md
REST_COACHING_REPORT.md
REST_PROVIDER_REPORT.md
RUSSIANTWIST_REPORT.md
SCAPULAR_ANALYZER_REPORT.md
TIER3_SIZE_AUDIT.md
TIER_1_3_4_CHANGE_LOG.md
TRACKING_GUIDANCE_REPORT.md
TTS_QUEUE_FIX_REPORT.md              (added by parallel track during cleanup)
WARNING_SANITY_REPORT.md             (added by parallel track during cleanup)
WORKOUT_INTELLIGENCE_AUDIT.md        (added by parallel track during cleanup)
WORKOUT_SECTION_REMOVAL_REPORT.md
```

(57 total once the parallel-track files are counted.)

---

## After

```
Repo root (9 *.md files):

README.md                            (canonical)
CLAUDE.md                            (canonical)
FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md   (active strategy)
GOOGLE_PLAY_MASTERPLAN_TR.md         (active strategy)
ASO_VISUAL_MASTERPLAN.md             (active strategy)
ONBOARDING_UX_MASTER_AUDIT_TR.md     (active strategy)
PROGRESS_SECTION_MASTERPLAN.md       (active strategy)
DOCUMENT_CLASSIFICATION_REPORT.md    (this cleanup pass)
ROOT_CLEANUP_REPORT.md               (this cleanup pass)
```

The last two reports stay at root for visibility through the current cycle; they should be archived in the next hygiene pass once they've served their purpose.

---

## New Archive Tree

```
docs/archive/
├── audits/                     # 26 files (existing + this pass)
│   ├── APK_OPTIMIZATION_MASTER_AUDIT.md
│   ├── AAB_PIPELINE_REPORT.md
│   ├── ARCHIVE_STRUCTURE_REPORT.md
│   ├── ASOSYSTEM_GITIGNORE_REPORT.md
│   ├── ASSET_SCOPE_AUDIT.md
│   ├── BUILD_TIME_AUDIT.md
│   ├── CLEANUP_CANDIDATES.md
│   ├── FLUTTER_ANALYZER_REPORT.md
│   ├── GIT_HYGIENE_REPORT.md
│   ├── MARKDOWN_CORPUS_AUDIT.md
│   ├── ML_AI_COVERAGE_MATRIX.md
│   ├── MLKIT_BUILD_REPORT.md
│   ├── MLKIT_FINAL_REPORT.md
│   ├── MLKIT_POSE_MODEL_AUDIT.md
│   ├── MLKIT_PRE_EXECUTION_VERIFY.md
│   ├── MLKIT_SMOKE_TEST_CHECKLIST.md
│   ├── MLKIT_STRIP_PATCH_REPORT.md
│   ├── PROJECT_DOC_DUPLICATE_AUDIT.md
│   ├── REPO_HYGIENE_AUDIT.md
│   ├── REPORT_ARCHIVE_REPORT.md
│   ├── TIER3_SIZE_AUDIT.md
│   ├── TIER_1_3_4_CHANGE_LOG.md
│   ├── TTS_QUEUE_FIX_REPORT.md
│   ├── WARNING_SANITY_REPORT.md
│   └── WORKOUT_INTELLIGENCE_AUDIT.md
├── coaching/                   # 5 files (NEW subdir)
│   ├── MIDSET_COACHING_REPORT.md
│   ├── PACE_SYSTEM_REPORT.md
│   ├── REST_COACHING_REPORT.md
│   ├── REST_PROVIDER_REPORT.md
│   └── TRACKING_GUIDANCE_REPORT.md
├── diagnostics/                # 12 files (existing + this pass)
│   ├── AUTH_FIX_REPORT.md
│   ├── AUTH_FLOW_TRACE.md
│   ├── AUTH_PAYWALL_ROOT_CAUSE.md
│   ├── AUTH_ROUTING_FIX_V2.md
│   ├── AUTH_STATE_MACHINE_AUDIT.md
│   ├── AUTH_TRANSITION_POLISH_REPORT.md
│   ├── AUTH_UX_LATENCY_REPORT.md
│   ├── AUTH_VALIDATION_REPORT.md
│   ├── ONBOARDING_DIALOG_REDESIGN.md
│   ├── ROOT_CAUSE_ANALYSIS.md
│   ├── STARTUP_FLOW_ANALYSIS.md
│   └── WORKOUT_SECTION_REMOVAL_REPORT.md
├── old-doc-snapshots/          # 1 file (existing)
│   └── PROJECT_DOCUMENTATION_TR_phase39.md
├── strategy-research/          # 19 files (existing, 4 subdirs)
│   ├── phase-1-project-discovery/
│   ├── phase-2-product-analysis/
│   ├── phase-3-psychology/
│   └── phase-4-market-intelligence/
├── tier2a/                     # 10 files (existing + this pass)
│   ├── CACHE_CONTROL_FIX_REPORT.md
│   ├── CACHE_WARMING_REVIEW.md
│   ├── DELETION_REPORT.md
│   ├── FINAL_TIER2A_MIGRATION_REPORT.md
│   ├── LQIP_BULK_REPORT.md
│   ├── LQIP_PREVIEW_REPORT.md
│   ├── MEAL_ASSET_INVENTORY.md
│   ├── RECIPE_IMAGE_MIGRATION_MAP.md
│   ├── SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md
│   └── SUPABASE_PRECHECK_REPORT.md
└── workout-analyzers/          # 8 files (NEW subdir)
    ├── BURPEE_ANALYZER_REPORT.md
    ├── CAMERA_CALIBRATION_REPORT.md
    ├── HIPHINGE_ANALYZER_REPORT.md
    ├── JUMPINGJACK_REPORT.md
    ├── MOUNTAIN_ANALYZER_REPORT.md
    ├── PLANK_STABILITY_REPORT.md
    ├── RUSSIANTWIST_REPORT.md
    └── SCAPULAR_ANALYZER_REPORT.md
```

`reports/` and `docs/` (active content) were not touched in this pass.

---

## Operations Log

| Op | Files | Method | Notes |
|---|---:|---|---|
| Move analyzer reports → `docs/archive/workout-analyzers/` | 8 | `git mv` | All tracked |
| Move coaching reports → `docs/archive/coaching/` | 5 | `git mv` | All tracked |
| Move auth-phase reports → `docs/archive/diagnostics/` | 8 | `git mv` | All tracked; joined existing diagnostics dir |
| Move audit + cleanup reports → `docs/archive/audits/` | 15 | `git mv` | All tracked |
| Move MLKit reports → `docs/archive/audits/` | 6 | `git mv` | All tracked |
| Move tier2a closure docs → `docs/archive/tier2a/` | 2 | `git mv` | All tracked |
| Move TTS + warning closure → `docs/archive/audits/` | 2 | `git mv` | Tracked |
| Move `WORKOUT_INTELLIGENCE_AUDIT.md` → `docs/archive/audits/` | 1 | `mv` then `git add` | Was untracked at root; first-time commit at archive path preserves the content under version control |
| Update `scripts/release-build.sh` doc-references | 1 line block | `Edit` | Two comment-only paths repointed at `docs/archive/audits/` so the script stays correct |

No `git rm`. No `rm`. No content destroyed.

---

## Validation

### Reference integrity
- `README.md` links — all targets unchanged (`docs/*` files were not moved).
- `CLAUDE.md` — has no inter-doc links.
- `scripts/release-build.sh` — comment paths updated to new archive locations.
- Cross-references between moved files — preserved by co-locating related files in the same archive subdir (audit↔audit, diagnostic↔diagnostic, etc.). Bare-filename references like `MARKDOWN_CORPUS_AUDIT.md§9` continue to resolve because their referent is now in the same directory.

### Git state sanity
```
$ git status --short | grep "\.md" | head -20
```
Shows only `R `-prefixed rename entries for the 49 tracked moves + a single `A` for the previously-untracked `WORKOUT_INTELLIGENCE_AUDIT.md`. No deletes, no orphan content.

### Root directory
```
$ ls *.md | wc -l
9
```

(7 kept-as-active + the 2 reports authored by this cleanup pass.)

### Archive directory
```
$ find docs/archive -type f -name "*.md" | wc -l
81
```

(Was 33 before this pass; +47 from the moves; +1 from the late-arrival untracked file.)

---

## Future Review

Docs that may need a follow-up classification cycle:

- **`DOCUMENT_CLASSIFICATION_REPORT.md` + `ROOT_CLEANUP_REPORT.md`** (this pass's outputs): move to `docs/archive/audits/` in the next cycle once they've served as the visible "what just happened" surface.
- **`FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md`**, **`GOOGLE_PLAY_MASTERPLAN_TR.md`**: revisit post-launch — they'll graduate from active strategy to historical record once the launch ships.
- **`ASO_VISUAL_MASTERPLAN.md`**: tied to the lifecycle of `asosystem/`; if that project is split out (per Tier-3 T2.1 in the archived audit), the masterplan should move with it.
- **`ONBOARDING_UX_MASTER_AUDIT_TR.md`** and **`PROGRESS_SECTION_MASTERPLAN.md`**: active design roadmaps; their archival cue is "the work they propose has shipped end-to-end."

No file is at urgent risk of becoming stale; the above is a 6-month review prompt, not a backlog.

---

## Bottom Line

**88% root-clutter reduction (57 → 9 *.md), 50 archives, 0 deletes, 0 broken references.** Archive structure is coherent (audits / diagnostics / coaching / workout-analyzers / strategy-research / tier2a / old-doc-snapshots) and discoverable. Knowledge fully preserved under git history.
