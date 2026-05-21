# Archive Structure Report — T2.5

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Create `docs/archive/` hierarchy + relocate 8 Tier 2-A reports + 4 diagnostic reports + 1 audit predecessor + 1 doc snapshot.
> **Status:** APPLIED.

---

## 1. New directory structure

```
docs/archive/
├── audits/                       # 1 file
├── diagnostics/                  # 4 files
├── old-doc-snapshots/            # 1 file
├── strategy-research/            # 4 subdirs / 19 files
└── tier2a/                       # 8 files
```

`reports/archive/` was created in parallel (covered in `REPORT_ARCHIVE_REPORT.md`).

---

## 2. Files moved to `docs/archive/tier2a/` (8 files)

All Tier 2-A intermediate and design artefacts. The migration is **operationally** still pending the cache-control SQL paste, but **engineering** is closed; these are the evidence record.

| Old path | New path | Method |
|---|---|---|
| `MEAL_ASSET_INVENTORY.md` | `docs/archive/tier2a/MEAL_ASSET_INVENTORY.md` | `git mv` (history preserved) |
| `LQIP_PREVIEW_REPORT.md` | `docs/archive/tier2a/LQIP_PREVIEW_REPORT.md` | `git mv` |
| `LQIP_BULK_REPORT.md` | `docs/archive/tier2a/LQIP_BULK_REPORT.md` | `git mv` |
| `SUPABASE_PRECHECK_REPORT.md` | `docs/archive/tier2a/SUPABASE_PRECHECK_REPORT.md` | `git mv` |
| `RECIPE_IMAGE_MIGRATION_MAP.md` | `docs/archive/tier2a/RECIPE_IMAGE_MIGRATION_MAP.md` | `git mv` |
| `CACHE_WARMING_REVIEW.md` | `docs/archive/tier2a/CACHE_WARMING_REVIEW.md` | `git mv` |
| `DELETION_REPORT.md` | `docs/archive/tier2a/DELETION_REPORT.md` | `git mv` |
| `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md` | `docs/archive/tier2a/SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md` | `git mv` |

**NOT moved (intentionally kept at root):**
- `FINAL_TIER2A_MIGRATION_REPORT.md` — pinned reference for the migration operator checklist
- `CACHE_CONTROL_FIX_REPORT.md` — pending operator action

---

## 3. Files moved to `docs/archive/diagnostics/` (4 files)

Companion docs from past auth/paywall/startup investigations. All resolved; the bug fix is in commit `d537b08` (Phase 139).

| Old path | New path | Method |
|---|---|---|
| `AUTH_FLOW_TRACE.md` | `docs/archive/diagnostics/AUTH_FLOW_TRACE.md` | `mv` (was untracked at root) |
| `AUTH_STATE_MACHINE_AUDIT.md` | `docs/archive/diagnostics/AUTH_STATE_MACHINE_AUDIT.md` | `mv` (was untracked) |
| `ROOT_CAUSE_ANALYSIS.md` | `docs/archive/diagnostics/ROOT_CAUSE_ANALYSIS.md` | `mv` (was untracked) |
| `STARTUP_FLOW_ANALYSIS.md` | `docs/archive/diagnostics/STARTUP_FLOW_ANALYSIS.md` | `git mv` (history preserved) |

These were never committed at root for the 3 untracked files; they are now staged for first-time commit at their archive paths. Future readers find them under "diagnostics" instead of being scattered at root.

---

## 4. Files moved to `docs/archive/audits/` (1 file)

| Old path | New path | Method |
|---|---|---|
| `APK_OPTIMIZATION_MASTER_AUDIT.md` | `docs/archive/audits/APK_OPTIMIZATION_MASTER_AUDIT.md` | `mv` (was untracked) |

Phase 139's master audit. Tiers 1, 3, 4 of its plan were executed (per `TIER_1_3_4_CHANGE_LOG.md`); Tier 2-A was executed by the just-finished migration; Tiers 2-B / 5 are still open (see `TIER3_SIZE_AUDIT.md`). The doc is preserved as the canonical historical baseline.

---

## 5. Files moved to `docs/archive/old-doc-snapshots/` (1 file)

| Old path | New path | Method |
|---|---|---|
| `docs/PROJECT_DOCUMENTATION1.md` | `docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md` | `git mv` (history preserved + renamed) |

Renamed from cryptic `…1.md` suffix to explicit Turkish-Phase-39 label. All 9 cross-references in `docs/PROJECT_DOCUMENTATION.md` updated to the new path. See `PROJECT_DOC_DUPLICATE_AUDIT.md` for rationale.

---

## 6. Files moved to `docs/archive/strategy-research/` (4 subdirs / 19 files)

These are strategic/market-research/UX-psychology docs from a separate research exercise (not engineering phases). All untracked previously; moved as whole subdirectory trees.

| Old subdir | New subdir | Files |
|---|---|---|
| `reports/phase-1-project-discovery/` | `docs/archive/strategy-research/phase-1-project-discovery/` | 2 |
| `reports/phase-2-product-analysis/` | `docs/archive/strategy-research/phase-2-product-analysis/` | 6 |
| `reports/phase-3-psychology/` | `docs/archive/strategy-research/phase-3-psychology/` | 7 |
| `reports/phase-4-market-intelligence/` | `docs/archive/strategy-research/phase-4-market-intelligence/` | 4 |

**Rationale:** these are business/UX research outputs, not engineering reports. They were misplaced in `reports/` (which is engineering-history-oriented). The new location under `docs/archive/strategy-research/` groups them with their natural sibling — the masterplan `.md` files that build on this research (the 5 top-level masterplans).

---

## 7. Strict no-touch list (verified intact at root)

The user's brief was explicit: **do not move** the following.

| File | Status | Reason |
|---|---|---|
| `FINAL_TIER2A_MIGRATION_REPORT.md` | ✓ at root, untouched | Active operator reference |
| `CACHE_CONTROL_FIX_REPORT.md` | ✓ at root, untouched | Pending operator action |
| `TIER_1_3_4_CHANGE_LOG.md` | ✓ at root, untouched | Active reference for the Phase 139 change history |
| `TIER3_SIZE_AUDIT.md` | ✓ at root, untouched | Current audit cycle |
| `BUILD_TIME_AUDIT.md` | ✓ at root, untouched | Current audit cycle |
| `ASSET_SCOPE_AUDIT.md` | ✓ at root, untouched | Current audit cycle |
| `REPO_HYGIENE_AUDIT.md` | ✓ at root, untouched | Current audit cycle |
| `CLEANUP_CANDIDATES.md` | ✓ at root, untouched | Current audit cycle |
| `MARKDOWN_CORPUS_AUDIT.md` | ✓ at root, untouched | Current audit cycle |
| `FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md` | ✓ at root, untouched | Active launch doc |
| `GOOGLE_PLAY_MASTERPLAN_TR.md` | ✓ at root, untouched | Active launch doc |
| `ASO_VISUAL_MASTERPLAN.md` | ✓ at root, untouched | Active launch doc |
| `ONBOARDING_UX_MASTER_AUDIT_TR.md` | ✓ at root, untouched | Active launch doc |
| `PROGRESS_SECTION_MASTERPLAN.md` | ✓ at root, untouched | Active feature plan |
| `README.md` | ✓ at root, untouched | Repo readme |
| `CLAUDE.md` | ✓ at root, untouched | Behavioural guide |
| `docs/PROJECT_DOCUMENTATION.md` | ✓ at `docs/`, modified for cross-refs only | Active canonical doc |
| `docs/CONTENT_OPS.md` | ✓ untouched | Operator guide |
| `docs/OPERATOR_REVIEWER_ACCESS.md` | ✓ untouched | Operator guide |
| `docs/api_anahtarlari_kurulum_rehberi.md` | ✓ untouched | Dev setup guide |
| `docs/dev-iteration-workflow.md` | ✓ untouched | Active workflow |
| `docs/AI_CONTEXT_REPORT.md` | ✓ untouched | Active AI context |
| `docs/MASTER_LAUNCH_ROADMAP.md` | ✓ untouched | Active launch doc |
| `docs/MONETIZATION_LAUNCH_GUIDE.md` | ✓ untouched | Active launch doc |
| `docs/ROADMAP.md` | ✓ untouched | Active roadmap |
| `docs/STORE_LAUNCH_REPORT.md` | ✓ untouched | Active launch doc |

---

## 8. End-state .md surface at top level (16 files)

After archive:

```
ASO_VISUAL_MASTERPLAN.md
ASSET_SCOPE_AUDIT.md
BUILD_TIME_AUDIT.md
CACHE_CONTROL_FIX_REPORT.md
CLAUDE.md
CLEANUP_CANDIDATES.md
FINAL_TIER2A_MIGRATION_REPORT.md
FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md
GOOGLE_PLAY_MASTERPLAN_TR.md
MARKDOWN_CORPUS_AUDIT.md
ONBOARDING_UX_MASTER_AUDIT_TR.md
PROGRESS_SECTION_MASTERPLAN.md
README.md
REPO_HYGIENE_AUDIT.md
TIER_1_3_4_CHANGE_LOG.md
TIER3_SIZE_AUDIT.md
```

Down from 23 (top-level was cluttered with mid-migration artefacts). The active surface is now **structurally interpretable**:

- 2 core (README, CLAUDE)
- 5 strategic masterplans (launch/ASO/onboarding/progress/launch-readiness)
- 6 current Tier 3 audits
- 3 active reports (Tier 1+3+4 change log + Tier 2-A final + Tier 2-A operator action)

Plus the 7 new T1/T2 reports from this round (`GIT_HYGIENE_REPORT.md`, `ASOSYSTEM_GITIGNORE_REPORT.md`, `AAB_PIPELINE_REPORT.md`, `PROJECT_DOC_DUPLICATE_AUDIT.md`, `MLKIT_POSE_MODEL_AUDIT.md`, `ARCHIVE_STRUCTURE_REPORT.md`, `REPORT_ARCHIVE_REPORT.md`) → final root count 23 .md, same as before but now all are *active* (the 7 historical ones moved out, the 7 new audit ones moved in).

---

## 9. Status

**APPLIED.** All Tier 2-A intermediates, diagnostic traces, and the predecessor Phase 139 audit are archived under `docs/archive/`. Active root surface is clean. T2.5 complete.
