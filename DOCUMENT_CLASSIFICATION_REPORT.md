# Document Classification Report

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Scope:** Classify every `*.md` file at the repository root (and a few near-root locations) by the A / B / C / D taxonomy in the cleanup brief.

---

## Classification Key

| Tag | Meaning | Action |
|---|---|---|
| **A — Active / canonical** | Still referenced or load-bearing | Keep at current location |
| **B — Archive / historical** | Done work, valuable record | `git mv` to `docs/archive/<subdir>/` |
| **C — Obsolete / superseded** | Replaced or no longer load-bearing | Archive (not delete) unless clearly dead |
| **D — Empty / redundant / unused** | Genuinely dead | `git rm` only with high confidence |

---

## Root `.md` Inventory at Start (54 files)

The full classification pass below. Sizes are bytes at scan time. "References" are cross-file mentions found via `grep -rln`.

### A — Active (kept at root, 7 files)

| File | Bytes | Why active |
|---|---:|---|
| `README.md` | 28,053 | Repo entry point; references `docs/*` only |
| `CLAUDE.md` | 2,357 | Behavioral guide loaded into every Claude session |
| `FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md` | 69,076 | Active launch master plan |
| `GOOGLE_PLAY_MASTERPLAN_TR.md` | 64,089 | Active Play submission strategy |
| `ASO_VISUAL_MASTERPLAN.md` | 88,942 | Active ASO + visual strategy (basis for `asosystem/`) |
| `ONBOARDING_UX_MASTER_AUDIT_TR.md` | 51,618 | Active UX retention strategy |
| `PROGRESS_SECTION_MASTERPLAN.md` | 97,334 | Active Gelişim-tab redesign roadmap |

These are product-team strategy docs that should remain immediately visible on `ls` at the root. They are stable references, not phase reports.

### B — Archive (moved, 47 files)

#### B.1 → `docs/archive/audits/` (24 files)

Audit-cycle artifacts, MLKit audit + smoke records, and the workout-intelligence audit triad. All document work that's been applied and is operationally closed.

| File | Bytes | Reason archived |
|---|---:|---|
| `AAB_PIPELINE_REPORT.md` | 5,165 | Tier 3 — AAB pipeline verification (applied) |
| `ARCHIVE_STRUCTURE_REPORT.md` | 8,426 | Tier 3 — T2.5 archive plan (applied) |
| `ASOSYSTEM_GITIGNORE_REPORT.md` | 2,317 | Tier 3 — T1.2 (applied) |
| `ASSET_SCOPE_AUDIT.md` | 6,882 | Tier 3 audit cycle |
| `BUILD_TIME_AUDIT.md` | 8,989 | Tier 3 audit cycle |
| `CLEANUP_CANDIDATES.md` | 11,569 | Tier 3 — ranked recommendation list |
| `GIT_HYGIENE_REPORT.md` | 4,365 | Tier 3 — `git gc` results |
| `MARKDOWN_CORPUS_AUDIT.md` | 15,326 | Tier 3 — predecessor of *this* report |
| `PROJECT_DOC_DUPLICATE_AUDIT.md` | 5,708 | Tier 3 — duplicate-doc audit (applied) |
| `REPO_HYGIENE_AUDIT.md` | 10,049 | Tier 3 audit cycle |
| `REPORT_ARCHIVE_REPORT.md` | 5,731 | Tier 3 — T2.6 archive plan (applied) |
| `TIER3_SIZE_AUDIT.md` | 8,830 | Tier 3 audit cycle |
| `TIER_1_3_4_CHANGE_LOG.md` | 11,814 | Tier 1/3/4 applied-change history (referenced by `scripts/release-build.sh`; reference path updated) |
| `FLUTTER_ANALYZER_REPORT.md` | 2,815 | Tier 3 — analyzer snapshot |
| `ML_AI_COVERAGE_MATRIX.md` | 17,908 | ML/AI coverage status snapshot |
| `MLKIT_BUILD_REPORT.md` | 5,326 | MLKit strip-build verification |
| `MLKIT_FINAL_REPORT.md` | 7,005 | MLKit strip — final report (5.72 MB AAB savings shipped in commit `4c0ea38`) |
| `MLKIT_POSE_MODEL_AUDIT.md` | 7,655 | MLKit pose-model selection audit |
| `MLKIT_PRE_EXECUTION_VERIFY.md` | 7,473 | MLKit pre-strip verification |
| `MLKIT_SMOKE_TEST_CHECKLIST.md` | 8,592 | MLKit smoke-test checklist |
| `MLKIT_STRIP_PATCH_REPORT.md` | 5,406 | MLKit strip patch record |
| `TTS_QUEUE_FIX_REPORT.md` | (~63 lines) | Tier-A closure (TTS interruption race fix) |
| `WARNING_SANITY_REPORT.md` | (~77 lines) | Tier-A closure (warning cooldown / dedupe fix) |
| `WORKOUT_INTELLIGENCE_AUDIT.md` | (~698 lines) | Parent audit doc for the above two closures (was untracked; now committed at archive path) |

#### B.2 → `docs/archive/diagnostics/` (8 files)

The completed auth/onboarding/workout phase (V1 + V2 + V3 — see commits `788f4a2`, `36601ae`, `0e875c9`).

| File | Bytes | Reason archived |
|---|---:|---|
| `AUTH_PAYWALL_ROOT_CAUSE.md` | 6,877 | Auth V1 — popup loop root cause |
| `AUTH_FIX_REPORT.md` | 5,734 | Auth V1 — fix description |
| `AUTH_VALIDATION_REPORT.md` | 9,413 | Auth V1 — validation matrix |
| `AUTH_ROUTING_FIX_V2.md` | 11,593 | Auth V2 — post-auth routing race fix |
| `AUTH_UX_LATENCY_REPORT.md` | 5,303 | Auth V3 — UX latency root cause |
| `AUTH_TRANSITION_POLISH_REPORT.md` | 10,418 | Auth V3 — transition polish |
| `ONBOARDING_DIALOG_REDESIGN.md` | 7,499 | Companion to V1 — Q2 redesign + cascade |
| `WORKOUT_SECTION_REMOVAL_REPORT.md` | (~81 lines) | Companion to V1 — Yeni Egzersizler removal |

Joined the existing `docs/archive/diagnostics/` which already houses `AUTH_FLOW_TRACE.md`, `AUTH_STATE_MACHINE_AUDIT.md`, `ROOT_CAUSE_ANALYSIS.md`, `STARTUP_FLOW_ANALYSIS.md` from earlier auth investigations.

#### B.3 → `docs/archive/tier2a/` (2 files)

Tier 2-A migration closure docs. The migration itself was the May 14 CDN move; these were pinned at root pending operator action, which has now closed.

| File | Bytes | Reason archived |
|---|---:|---|
| `FINAL_TIER2A_MIGRATION_REPORT.md` | 12,467 | Pinned reference, now archived |
| `CACHE_CONTROL_FIX_REPORT.md` | 5,125 | Pending operator action — completed |

#### B.4 → `docs/archive/workout-analyzers/` (8 files, **new subdir**)

Per-exercise analyzer reports authored alongside the Tier-A workout-intelligence work.

| File | Bytes |
|---|---:|
| `BURPEE_ANALYZER_REPORT.md` | 3,260 |
| `HIPHINGE_ANALYZER_REPORT.md` | 4,284 |
| `JUMPINGJACK_REPORT.md` | 3,699 |
| `MOUNTAIN_ANALYZER_REPORT.md` | 3,365 |
| `PLANK_STABILITY_REPORT.md` | 2,252 |
| `RUSSIANTWIST_REPORT.md` | 3,427 |
| `SCAPULAR_ANALYZER_REPORT.md` | 4,028 |
| `CAMERA_CALIBRATION_REPORT.md` | 4,163 |

Grouping these under their own subdir makes "what does the analyzer for X currently do?" findable without grepping through unrelated phase reports.

#### B.5 → `docs/archive/coaching/` (5 files, **new subdir**)

Coaching system phase reports (pacing, rest, mid-set, tracking guidance).

| File | Bytes |
|---|---:|
| `MIDSET_COACHING_REPORT.md` | 4,369 |
| `PACE_SYSTEM_REPORT.md` | 4,293 |
| `REST_COACHING_REPORT.md` | 4,639 |
| `REST_PROVIDER_REPORT.md` | 4,316 |
| `TRACKING_GUIDANCE_REPORT.md` | 4,908 |

Mirrors the parallel coaching-track commits visible in `git log` (`a1cb9ef`, `1d4b5fa`, etc.).

### C — Obsolete / superseded

**Zero candidates.** Every root file was either active or a still-valuable historical record. The May 19 audit had already identified the one genuinely-obsolete file (`docs/PROJECT_DOCUMENTATION1.md`) and that move had already been executed (it lives at `docs/archive/old-doc-snapshots/PROJECT_DOCUMENTATION_TR_phase39.md`).

### D — Empty / redundant / unused (deleted)

**Zero candidates.** No empty files, no zero-byte placeholders, no obvious duplicates among root .md content. The `RELEASE_*.md` trio (`RELEASE_BLACK_SCREEN_ROOT_CAUSE_REPORT.md`, `RELEASE_FIXES_APPLIED.md`, `RELEASE_HARDENING_CHECKLIST.md`) was already staged as deleted by a parallel track (visible in `git status -D` rows at the start of this session); those deletions were not authored here and pass through unmodified.

---

## Reference Integrity Check

Verified by `grep -rn "\.md"` across the moved files and the surviving root + `docs/` set:

- **README.md** references `docs/MASTER_LAUNCH_ROADMAP.md`, `docs/PROJECT_DOCUMENTATION.md`, `docs/MONETIZATION_LAUNCH_GUIDE.md`, `docs/OPERATOR_REVIEWER_ACCESS.md`, `docs/AI_CONTEXT_REPORT.md`, `CLAUDE.md`. **All targets unchanged — no broken links.**
- **CLAUDE.md** has no inter-doc links.
- **scripts/release-build.sh** had two comment-only references — `APK_OPTIMIZATION_MASTER_AUDIT.md` (already archived in May 19) and `TIER_1_3_4_CHANGE_LOG.md` (archived in this pass). Both comment paths updated to point at the archive locations.
- **docs/archive/audits/MARKDOWN_CORPUS_AUDIT.md** (this report's predecessor) references its sibling audit files by bare filename only. All siblings are now in the same directory — references remain valid.
- **docs/archive/diagnostics/AUTH_FIX_REPORT.md** and friends cross-reference each other by bare filename. All co-located. No broken links.

---

## Summary Statistics

| Class | Count | Outcome |
|---|---:|---|
| A — Kept at root | 7 | No change |
| B — Archived | 50 | `git mv` (47 tracked) + `mv` (3 untracked, committed at archive path) |
| C — Obsolete | 0 | n/a |
| D — Deleted | 0 | n/a |
| **Total root .md scanned** | **57** | (54 at scan start + 3 added by parallel track during cleanup) |

The 3 additional files that appeared mid-cleanup (`TTS_QUEUE_FIX_REPORT.md`, `WARNING_SANITY_REPORT.md`, `WORKOUT_INTELLIGENCE_AUDIT.md`) were authored by a parallel coaching-system track. They were classified into the same audit / diagnostics taxonomy and moved together with the rest.

---

## Result

**Root went from 57 `.md` files → 7 `.md` files (88% reduction).** Every removed file is preserved in `docs/archive/<subdir>/` under git tracking; no knowledge lost. See `ROOT_CLEANUP_REPORT.md` for the procedural log + new directory tree.
