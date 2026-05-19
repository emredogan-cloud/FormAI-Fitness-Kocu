# Tier 3 — Markdown Corpus Audit

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — no .md files deleted, moved, or modified.
> **Total .md count:** 290 across the working tree; **88 belong to the Flutter project**, 202 are vendored inside `asosystem/node_modules/` (untracked npm artifacts).

---

## 0. Classification key

Per the user's brief:

| Tag | Meaning | Action |
|---|---|---|
| **A — Active knowledge** | Still useful, still referenced, may help current work | KEEP at current location |
| **B — Historical** | Valuable context, not active | Move to `docs/archive/` |
| **C — Obsolete** | Outdated, superseded, low-value | Candidate for removal (with content extraction first) |
| **D — Temp / Generated** | AI scratch, one-time logs, migration intermediates | Candidate for cleanup |

---

## 1. Top-level `*.md` (23 files)

### Tier 2-A reports I authored this session (9 files)

These are reference artefacts for the migration just completed. They contain audit data, decision rationale, and rollback procedures. **All A** until Tier 2-A is operationally closed (cache-control SQL applied + smoke tests run); then most become **B** (historical record of the migration).

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `MEAL_ASSET_INVENTORY.md` | 6.6 KB | A→B | Phase 2-A.1 evidence; archive after launch |
| `LQIP_PREVIEW_REPORT.md` | 8.9 KB | A→B | Phase 2-A.2 sample evidence; archive |
| `LQIP_BULK_REPORT.md` | 4.6 KB | A→B | Phase 2-A.2-bulk evidence; archive |
| `SUPABASE_PRECHECK_REPORT.md` | 12.9 KB | A→B | Phase 2-A.3 design + RLS notes; archive |
| `RECIPE_IMAGE_MIGRATION_MAP.md` | 12.0 KB | A→B | Phase 2-A.5 source-of-truth for the 7 call sites; archive |
| `CACHE_WARMING_REVIEW.md` | 16.8 KB | A→B | Phase 2-A.6 design review; archive |
| `DELETION_REPORT.md` | 4.6 KB | A→B | Phase 2-A.7 evidence; archive |
| `CACHE_CONTROL_FIX_REPORT.md` | 5.1 KB | A | **Has pending operator action**; stays A until run |
| `FINAL_TIER2A_MIGRATION_REPORT.md` | 12.5 KB | A | Pinned reference for the operator checklist |

**Recommended action:** after operator confirms cache-control + smoke tests, move 7 of these 9 to `docs/archive/tier-2a/` and keep `FINAL_TIER2A_MIGRATION_REPORT.md` + `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md` at the top level for quick reference.

### Strategic / launch / UX masterplans (5 files)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `FORMAI_LAUNCH_READYNESS_MASTER_PLAN_TR.md` | 69 KB | A | Active launch plan |
| `GOOGLE_PLAY_MASTERPLAN_TR.md` | 64 KB | A | Active Play submission strategy |
| `ASO_VISUAL_MASTERPLAN.md` | 89 KB | A | Active ASO + visual strategy (basis for `asosystem/`) |
| `ONBOARDING_UX_MASTER_AUDIT_TR.md` | 52 KB | A | Active UX retention strategy |
| `PROGRESS_SECTION_MASTERPLAN.md` | 97 KB | A | Active Gelişim-tab redesign roadmap |

**Recommendation:** keep at root for product team visibility. Consider moving to `docs/strategy/` if root becomes cluttered.

### Tier 3 audits I'm authoring now (6 files including this one)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `TIER3_SIZE_AUDIT.md` | (new) | A | This audit cycle |
| `BUILD_TIME_AUDIT.md` | (new) | A | This audit cycle |
| `ASSET_SCOPE_AUDIT.md` | (new) | A | This audit cycle |
| `REPO_HYGIENE_AUDIT.md` | (new) | A | This audit cycle |
| `CLEANUP_CANDIDATES.md` | (new) | A | This audit cycle |
| `MARKDOWN_CORPUS_AUDIT.md` | (this file) | A | This audit cycle |

### Prior audit cycle predecessors (3 files)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `APK_OPTIMIZATION_MASTER_AUDIT.md` | 16.3 KB | **B** | Phase 139 audit. Action complete via TIER_1_3_4_CHANGE_LOG. Superseded by `TIER3_SIZE_AUDIT.md`. Keep for the historical reasoning. |
| `TIER_1_3_4_CHANGE_LOG.md` | 11.8 KB | A | Active changelog record. References still useful for rollback. |
| `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md` | 15.9 KB | A | Design doc; executed as `FINAL_TIER2A_MIGRATION_REPORT.md`. Pair them. |

### Diagnostic artifacts from past bug investigations (3 files)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `AUTH_FLOW_TRACE.md` | 17.3 KB | **B** | Investigation 2026-05-17; the bug fix landed in commit `d537b08` (Phase 139). Trace is historical now. |
| `AUTH_STATE_MACHINE_AUDIT.md` | 14.3 KB | **B** | Companion to AUTH_FLOW_TRACE. |
| `ROOT_CAUSE_ANALYSIS.md` | 17.0 KB | **B** | Companion to AUTH_FLOW_TRACE (paywall + auth sync bug). |
| `STARTUP_FLOW_ANALYSIS.md` | 13.6 KB | **B** | "Post-Phase-94 fix" — explains current startup flow; useful future reference but no active action. |

**Recommendation:** move all 4 to `docs/archive/diagnostics/`. Keep linked from `FINAL_TIER2A_MIGRATION_REPORT.md`'s rollback section so engineers can find them.

### Active core (2 files)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `README.md` | 28.1 KB | A | repo readme |
| `CLAUDE.md` | 2.4 KB | A | behavioral guide loaded into every Claude session |

---

## 2. `docs/*.md` (17 files)

### Active dev infrastructure (6 files)

| File | Bytes | Class |
|---|---:|---|
| `docs/AI_CONTEXT_REPORT.md` | 75 KB | A — loaded into AI sessions |
| `docs/api_anahtarlari_kurulum_rehberi.md` | 14 KB | A — dev setup runbook |
| `docs/CONTENT_OPS.md` | 6.6 KB | A — content-team SOP |
| `docs/dev-iteration-workflow.md` | 17.7 KB | A — dev workflow guide |
| `docs/OPERATOR_REVIEWER_ACCESS.md` | 11.0 KB | A — Play/App Store reviewer runbook |
| `docs/PROJECT_DOCUMENTATION.md` | 124 KB | A — current project documentation (English) |

### Active strategy (5 files)

| File | Bytes | Class |
|---|---:|---|
| `docs/MASTER_LAUNCH_ROADMAP.md` | 40.7 KB | A |
| `docs/MONETIZATION_LAUNCH_GUIDE.md` | 33.9 KB | A |
| `docs/ROADMAP.md` | 34.0 KB | A |
| `docs/STORE_LAUNCH_REPORT.md` | 28.8 KB | A |
| `docs/PROJECT_FULL_REPORT.md` | 64.2 KB | A or B (depends on date) |

### Historical / one-shot prompts (5 files)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `docs/IMAGE_PROMPTS.md` | 35.3 KB | **B** | Image-generation prompt library — already used to produce the photos |
| `docs/MEAL_IMAGE_PROMPTS.md` | 108.1 KB | **B** | Phase 66 meal-image prompts — already used |
| `docs/WORKOUT_IMAGE_PROMPTS.md` | 11.9 KB | **B** | Phase 67 workout-image prompts — already used |
| `docs/WORKOUT_DATA_REPORT.md` | 10.5 KB | **B** | Phase 85 workout-data audit; resolved |
| `docs/VIDEO_DIAGNOSTIC_REPORT.md` | 5.0 KB | **B** | Standalone diagnostic; resolved |

### Obsolete duplicate (1 file)

| File | Bytes | Class | Reason |
|---|---:|---|---|
| `docs/PROJECT_DOCUMENTATION1.md` | 27.4 KB | **C** | Older Turkish-language version of `PROJECT_DOCUMENTATION.md`. Diff confirms similar TOC structure, dated 2026-04-24 (Faz 39); current English version is 2026-04-28 (Phase 58). The "1" suffix screams "kept as backup". Either fold any unique Turkish content into a `_TR.md` companion or archive. |

---

## 3. `reports/*.md` (27 files, top-level) — historical engineering phase reports

Every file is a phase-stamped engineering report (Phase 96–138 era), documenting a discrete piece of work that has been completed:

| File | Phase | Class |
|---|---|---|
| `30day-generator-validation.md` | 100 | **B** |
| `android-build-performance-audit.md` | 117 | **B** — predecessor to current build audit |
| `dashboard-workout-integration.md` | 97 | **B** |
| `equipment-program-consolidation.md` | 98 | **B** |
| `exercise-media-fallback-system.md` | 99 | **B** |
| `exercise-video-prompts.md` | 96 | **B** — prompts already used |
| `home-workout-filter-rules.md` | 100 | **B** |
| `ml-detection-strategy.md` | 96 | **B** |
| `new-dashboard-programs.md` | 97 | **B** |
| `new-exercise-library.md` | 96 | **B** (70 KB, biggest in this dir) |
| `onboarding-emotional-rebuild-analysis.md` | n/a | **B** |
| `personalized-generator-equipment-filter.md` | 100 | **B** |
| `phase-127-build-iteration-forensic.md` | 127 | **B** |
| `phase-138-build-perf-final-report.md` | 138 | A — referenced by current build audit; keep |
| `phase98_black_screen_root_cause.md` | 98 | **B** — resolved |
| `premium-workout-distribution.md` | 98 | **B** |
| `premium-workout-refactor.md` | 98 | **B** |
| `reference-video-gap-analysis.md` | 107 | **B** |
| `render-performance-profile-guide.md` | 122 | A — actionable guide if perf is ever audited |
| `rive-snap-flutter-investigation.md` | n/a | **B** — Rive removed, Phase 139 era |
| `snap-flutter-migration-guide.md` | n/a | **B** — migration done |
| `video-to-image-mapping.md` | 99 | **B** |
| `webp-conversion-report.md` | 99 | **B** |
| `workout-category-distribution.md` | 97 | **B** |
| `workout-integration-summary.md` | 96 | **B** |
| `workout-system-analysis.md` | n/a | **B** |
| `workout-system-gap-analysis.md` | n/a | **B** |

**Recommendation:** these are valuable engineering history. Move the **B** files to `reports/archive/` after a launch milestone; keep the **A** ones (`phase-138-build-perf-final-report.md`, `render-performance-profile-guide.md`) accessible.

---

## 4. `reports/phase-N-*/` strategic research (19 files in 4 subdirs)

| Subdir | Files | Total | Class |
|---|---:|---:|---|
| `reports/phase-1-project-discovery/` | 2 | 78 KB | **B** — historical executive summary + structure map from May |
| `reports/phase-2-product-analysis/` | 6 | 232 KB | **B** — product/UX/design analysis |
| `reports/phase-3-psychology/` | 7 | 383 KB | **B** — user psychology + retention research |
| `reports/phase-4-market-intelligence/` | 4 | 205 KB | **B** — competitor / market gap analysis |

These are strategic/research artefacts, not engineering. ~900 KB total. **All B.** They feed the masterplans at the top level. Move to `docs/archive/strategy-research/` or leave as-is — they're already cleanly siloed.

---

## 5. Other markdown (3 files)

| File | Class | Notes |
|---|---|---|
| `supabase/functions/revenuecat-webhook/README.md` | A | Function-specific runbook |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | A | Apple-standard scaffolding readme |
| `lib/scripts/sync_recipes_db.dart` — not .md but Dart with markdown-ish docstrings | n/a | Not a real .md |

---

## 6. Vendored `asosystem/*.md` (202 files)

Located inside `asosystem/node_modules/<package>/README.md` etc. These
are dependency-bundled documentation files for the Vite project's npm
deps. They:

- Are **not part of this Flutter repo** in any meaningful sense.
- Are **NOT tracked in git** (the whole `asosystem/` is untracked).
- Should be excluded from any Flutter-side markdown analysis.
- Will disappear if `asosystem/` is gitignored + (optionally) deleted from local.

**No classification needed.** Treat as `D — Temp/Generated` (npm install
output).

---

## 7. Summary statistics

| Class | Top-level | docs/ | reports/ | reports/phase-N/ | Total |
|---|---:|---:|---:|---:|---:|
| **A — Active** | 17 | 11 | 2 | 0 | **30** |
| **B — Historical (archive)** | 5 | 5 | 25 | 19 | **54** |
| **C — Obsolete (remove)** | 0 | 1 | 0 | 0 | **1** |
| **D — Temp/Generated (cleanup)** | 0 | 0 | 0 | 0 | **0** |
| **Flutter project total** | 22 | 17 | 27 | 19 | **85** |

Plus 1 each in `supabase/`, `ios/` (both A) → 87. Plus 3 in `lib/`-adjacent README/CLAUDE → 90. The earlier global count of 290 included `asosystem/node_modules/` (~202 npm READMEs, irrelevant).

---

## 8. Files leveraged during this audit cycle

For traceability, the Tier 3 audit specifically read or referenced:

- `APK_OPTIMIZATION_MASTER_AUDIT.md` — APK content decomposition baseline (Phase 139)
- `TIER_1_3_4_CHANGE_LOG.md` — already-applied optimizations to avoid re-recommending
- `FINAL_TIER2A_MIGRATION_REPORT.md` — current state of meals migration
- `MEAL_ASSET_INVENTORY.md` + `LQIP_BULK_REPORT.md` — Tier 2-A asset numbers
- `RECIPE_IMAGE_MIGRATION_MAP.md` — call-site swap confirmation
- `STARTUP_FLOW_ANALYSIS.md` — first 30 lines, contextual
- `AUTH_FLOW_TRACE.md` + `ROOT_CAUSE_ANALYSIS.md` — first 30 lines each, contextual
- `docs/PROJECT_DOCUMENTATION.md` (head) — confirmed it's the current canonical doc
- `docs/PROJECT_DOCUMENTATION1.md` (head + diff) — confirmed Turkish older version
- Headers + first lines of every other .md (batch-extracted)

---

## 9. Recommended archive strategy

Per the user's brief: **prefer `docs/archive/` for historical-but-valuable files. Avoid knowledge loss.**

Proposed directory structure for a future cleanup pass:

```
docs/
├── (active docs stay here)
├── archive/
│   ├── tier-2a/                          # 7 files — Tier 2-A migration artifacts
│   ├── diagnostics/                      # 4 files — AUTH/STARTUP traces
│   ├── prompts/                          # 3 files — IMAGE/MEAL/WORKOUT prompts
│   ├── audits/                           # 2 files — APK_OPT + Phase 117 build audit
│   └── strategy-research/                # 19 files — reports/phase-N-*/ contents
reports/
├── (active engineering refs stay here)
└── archive/                              # 25 files — Phase 96-138 historical reports
```

**Net effect:** ~58 .md files relocated under `docs/archive/` and `reports/archive/`. The top-level root cleans up to ~17 .md files (active strategy + active operations only). Engineering history is preserved, not deleted.

**Single file to actually delete:** `docs/PROJECT_DOCUMENTATION1.md` — superseded Turkish version. Or, if any Turkish content there isn't in the English current version, fold it in first then delete. **0.027 MB.**

---

## 10. Knowledge value leveraged

This audit cycle directly leveraged the markdown corpus to:

1. **Avoid re-recommending Phase 139's already-applied actions** (cleaned 9 orphans, re-encoded 2 PNG-as-WebP, AAB pipeline, dependency hygiene). Without reading `TIER_1_3_4_CHANGE_LOG.md`, the audit would have proposed redundant work.
2. **Identify Phase 139 Tier 2-B / Tier 5 as still-open** (drop one ML model, `--obfuscate + Sentry symbols`).
3. **Confirm Phase 127's asset hygiene rule** is the right anti-regression mechanism for `photos/` root contamination.
4. **Cross-reference Phase 138's build profile** (so I can cite the 153.7 s `assembleRelease` measurement as in-spec, not a regression).
5. **Avoid duplicating the auth/startup diagnostic work** (verified the bug fix landed in commit `d537b08`).

This is the value of the markdown corpus: it prevents engineering deja vu.

---

## 11. Bottom line

The corpus is **structurally healthy** but needs **light reorganization**:

- **30 files are actively valuable** at their current paths.
- **54 files are historical-but-valuable** — they belong in `docs/archive/` / `reports/archive/` for future spelunking, not in the working "what's current?" surface.
- **1 file is genuinely obsolete** (`docs/PROJECT_DOCUMENTATION1.md`) — single delete or fold-in.
- **0 files are pure temp/scratch** that warrant immediate removal.

The `asosystem/` markdown noise (202 npm READMEs) inflates raw counts but isn't an engineering concern — it disappears with the `asosystem/` root-gitignore from `REPO_HYGIENE_AUDIT.md §1`.

**No knowledge loss recommended.** Archive > delete, in every case except the duplicated Turkish doc.
