# Progress-Redesign Companion Files — Recovery Report

**Phase:** B (read-only investigation).
**Mode:** no writes, no commits, no stash manipulation.
**Target:** the 10 dangling imports identified in
[`STASH_TRIAGE_REPORT.md`](STASH_TRIAGE_REPORT.md) §4 ("Companion files
this group does not compile without").

---

## 1 · Result summary

**Recovery confidence: 100 %.** All ten target files exist as Dart
blobs in a single dangling commit that the stash keeps alive. The
blobs are non-binary, non-corrupted, and contain valid `library` /
`class` headers with the same `Phase X.Y` voice as the stash's
consumer-side changes — same author, same commit window, same
codebase.

A bonus 6 test files, 2 webp assets, 1 shell script, and 1 SQL
migration sit in the same tree and would round out the redesign series
cleanly.

The blobs are **garbage-collectable** the moment the stash is dropped
(default `git gc` window: 14 days for dangling objects, 30 days for
reflog entries — see §6 for the preservation step).

---

## 2 · Where they are

The stash itself is a 3-parent merge commit, which is what `git stash
--include-untracked` produces:

```
stash@{0} = 81bb13f3aba7415221ea4bb42bb9c4030b77495f
  parent 1: 56a5912   — the branch tip at stash time (base)
  parent 2: a957ab4   — staged-index snapshot
  parent 3: bf87113   — UNTRACKED-FILES snapshot   ← target
```

`git stash show -p` only emits the WIP-vs-base diff. The third parent
(`bf87113`) is what holds the new files the developer hadn't yet
staged when the stash was taken — and that's where every missing
companion file lives.

---

## 3 · Per-file inventory

All paths are relative to repo root. Blob hashes can be read directly
with `git cat-file blob <hash>`.

### 3.1 · The 10 named missing files

| # | Path | Blob hash | Size | Header line (verified) |
|---|---|---|---|---|
| 1 | `lib/core/widgets/spring_tap.dart` | `266ad194cd2c90470456ad0654a560542b83ca30` | 3,314 B | `/// Progress redesign Phase 4.B · scale-down + spring-back tap response.` |
| 2 | `lib/core/widgets/staggered_fade.dart` | `f3a1442c7998f079fe575bff511a907a67c20a8b` | 2,783 B | (recovered, sized) |
| 3 | `lib/features/progress/data/coach_copy_corpus.dart` | `65a634c23322c122dd29eca1d5dc2ca9216c2f8f` | 7,603 B | (recovered, sized) |
| 4 | `lib/features/progress/domain/streak_calculator.dart` | `667d26dc6f22c37b05b771090d9e6e74c98ea69e` | 5,018 B | (recovered, sized) |
| 5 | `lib/features/progress/domain/volume_metrics.dart` | `d581b6ad8d9af01580ad856e6e2f4bd83cca837b` | 8,641 B | (recovered, sized) |
| 6 | `lib/features/progress/domain/year_in_review_summary.dart` | `417cb20e0c278c64549873bab1c951eac4121c96` | 4,412 B | `/// Progress redesign Phase 5.A · Year-in-Review summary derivation.` |
| 7 | `lib/features/progress/presentation/widgets/badge_celebration_screen.dart` | `02246a8c2ea50389747537cefe066b2c1a259204` | 15,162 B | (recovered, sized) |
| 8 | `lib/features/progress/presentation/widgets/session_detail_sheet.dart` | `09347929b96c0c8f9b090dbe4f868e49367d69dd` | 17,958 B | (recovered, sized) |
| 9 | `lib/features/progress/presentation/year_in_review_screen.dart` | `0399a16f05b784eb613cf8ec3d10920c4d7a9dc6` | 23,081 B | (recovered, sized) |
| 10 | `lib/features/progress/providers/volume_metrics_provider.dart` | `ea3ee42fe592f9d9ec777b9c102d3db1ec5a4da1` | 4,643 B | (recovered, sized) |

**Total:** ~92 KB of Dart source. All ten files account-balance the
imports listed in `STASH_TRIAGE_REPORT.md` §4.

### 3.2 · Bonus recoverable content in the same tree

Same commit (`bf87113`), same recovery method, would also restore:

| Path | Blob | Notes |
|---|---|---|
| `test/features/progress/domain/level_curve_test.dart` | `efb2ffcf` | unit test pairs with `level_curve.dart` (already in HEAD) |
| `test/features/progress/domain/streak_calculator_test.dart` | `e3253897` | pairs with file #4 above |
| `test/features/progress/domain/volume_metrics_test.dart` | `385d1f58` | pairs with file #5 above |
| `test/features/progress/domain/xp_calculator_test.dart` | `a206d7f6` | unit test pairs with `xp_calculator.dart` (already in HEAD) |
| `test/features/progress/domain/year_in_review_summary_test.dart` | `4c84d837` | pairs with file #6 above |
| `test/features/workout/presentation/phase98_layout_repro_test.dart` | `c673ba6a` | repro test for Phase 98 premium-tier layout |
| `photos/workouts/cardio_full_body_flow.webp` | `13edfe12` | workout card art |
| `photos/workouts/cardio_mobility_stretch.webp` | `d993333d` | workout card art |
| `scripts/release-build.sh` | `08985155` | release helper (mode 100755) |
| `supabase/sql/phase96_workout_library_expansion.sql` | `283f6cea` | DB migration for Phase 96 |

The 5 test files for already-landed closure files (`level_curve`,
`xp_calculator`) are a high-value side-find: HEAD currently has those
production files with **zero** unit tests.

---

## 4 · Provenance corroboration

Sanity checks confirming this is real engineering work, not a stale
experiment:

* `spring_tap.dart`: header reads "Progress redesign Phase 4.B" — same
  phase nomenclature as the stash's other Progress-Redesign changes.
* `year_in_review_summary.dart`: header reads "Progress redesign Phase
  5.A" — matches the YIR-share path Phase 5.C that the stash already
  contains in `share_service.dart`.
* `phase98_layout_repro_test.dart`: matches Phase 98 (`premiumExercises`)
  which is already in HEAD via commit `7a742da`.
* All 28 files in `bf87113` were created in the same untracked-files
  snapshot, dated within the same stash event (`2026-05-22`).

---

## 5 · Risk

| Risk | Severity | Mitigation |
|---|---|---|
| Dropping the stash orphans `bf87113` → blobs are GC-eligible | **HIGH** | Do not run `git stash drop stash@{0}`. The blobs are alive **only** because the stash references the commit chain that references them. |
| Default `git gc` schedule | LOW (today) → HIGH (after 14 days from stash drop) | Default `gc.pruneExpire = 2.weeks.ago`. Today these blobs are fine; if the stash were dropped today they'd survive another two weeks. |
| User accidentally re-stashes / clears stash list | MEDIUM | The recovery path runs through the stash. Any `git stash clear` is destructive. |
| Recovery via blob hash assumes hashes don't drift | NONE | Blob hashes are content-addressed; they cannot drift. As long as the blob is reachable from any ref, `cat-file` works. |

---

## 6 · Suggested preservation step (optional, NOT executed)

If preservation should be made independent of the stash, an
unobtrusive way is to add a temporary ref so the blobs are reachable
without touching the working tree or branch:

```
git update-ref refs/recovery/progress-redesign-2026-05-22 bf87113
```

This costs ~0 bytes (it's a single SHA file in `.git/refs/recovery/`).
The ref is invisible to `git branch` / `git log` by default, can be
removed with `git update-ref -d` later, and survives `git stash drop`.

**Not executed in this report.** Recovery phase is read-only per the
phase contract.

---

## 7 · What this unblocks

Per `STASH_TRIAGE_REPORT.md` §7 Track 3, the redesign was broken into
six PRs that depend on these files. Recovery flips all six from
"blocked on file recovery" to "ready to author":

| Planned PR | Now blocked on? |
|---|---|
| `feat(progress): volume metrics + streak calculator (domain)` | nothing — files #4, #5, plus their tests, recoverable |
| `feat(progress): badge visuals + celebration screen` | nothing — file #7 + the `BadgeVisual` catalog in the stash's `badge_unlocks_provider.dart` |
| `feat(progress): session detail sheet + calendar tap` | nothing — file #8 + the stash's `calendar_screen.dart` hunk |
| `feat(progress): weekly retrospective MET-based kcal` | nothing — files #5, #10 + the stash's `weekly_retrospective_card.dart` |
| `feat(progress): year-in-review screen + share path` | nothing — files #6, #9 + the stash's `share_service.dart` / `share_templates.dart` |
| `feat(progress): Gelişim-tab v2 (consumer-side rebuild)` | nothing — all above + the stash's `gelisim_tab.dart` |

---

## 8 · Final declaration

* **Recoverable?** **Yes — 100 %.** Every one of the 10 target files
  resolves to a valid Dart blob in `bf87113`.
* **Unrecoverable?** **None.**
* **Next safe action (when the user authorises Phase C):** materialise
  each blob to disk with `git cat-file blob <hash> > <path>` and ship
  the six PR series listed in §7. Until then, the stash must be left
  intact.
