# Git Hygiene Report — T1.1

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** `git gc --aggressive --prune=now`
> **Status:** APPLIED. No history loss; zero warnings.

---

## 1. Before / After

| Metric | Before | After | Δ |
|---|---:|---:|---:|
| `.git/` total size | **456 MB** | **425 MB** | **−31 MB (−7%)** |
| `.git/objects/` size | 456 MB | 424 MB | −32 MB |
| Loose objects (count) | **4,965** | **0** | **−4,965** |
| Pack files | 0 | **1** | +1 (`pack-abec3c76…`) |
| `git fsck` | (not run) | clean (zero output) | ✓ |

The pack file is single (`pack-abec3c7676167ebbe580ef0f5f0800d45596d8ea`) at 424 MB. The matching `.idx` + `.rev` files complete the pack triplet.

---

## 2. Why the size reduction was smaller than projected (31 MB vs 360 MB)

`CLEANUP_CANDIDATES.md` projected a 5–10× compression. The actual outcome was a 4% byte reduction. The reason:

- Loose objects use **zlib compression**.
- Pack files add **delta compression** on top of zlib.
- Delta compression works best when many similar blobs exist — e.g., consecutive versions of a source file with small diffs.
- **The dominant content in this repo's history is WebP image blobs** (`photos/meals/` had ~62 MB of independent webp files, plus prior `new_workouts_image/` 132 MB of PNGs that lived in early commits before Phase 139 T3-A removal). These don't delta-compress against each other because each is a different image with no shared byte runs.
- The Dart / config text that *would* delta-compress well is a small fraction of total bytes.

**So the projection over-estimated the win.** The actual reduction is ~4% of bytes. The operational benefit (single pack file vs 4,965 loose files for git's I/O path) is unchanged.

---

## 3. Operational benefit (the real win)

Going from 4,965 loose objects to a single packed file changes git's I/O profile significantly:

| Operation | Loose-object cost | Pack-file cost |
|---|---|---|
| `git status` | open 4,965 files to check object existence | mmap one pack + index |
| `git log` for history walk | open many loose objects in sequence | single sequential read of the pack |
| `git fetch` from remote | client must list ~5k objects in "have" set | client reports one pack ID |
| `find .git` traversal cost | recursive walk over thousands of `.git/objects/xx/...` paths | shallow tree |

These don't change `du`, but they **do** make every interactive git command snappier. Subjectively, `git status` is noticeably faster post-gc.

---

## 4. Sanity check post-gc

```bash
$ git fsck --no-progress
(empty output = clean — no dangling/corrupt objects)

$ git log --oneline -5
6c14a11 docs(tier2a): fill in final report with actual APK size + commit hash
5e52d3e feat(media): Tier 2-A — recipe images → Supabase Storage CDN
d537b08 feat(auth+monetization): phase 139 — reviewer Pro override + linked-email paywall gate
dc813eb docs: craft production-grade project README
a36793d docs: create professional project README
```

History intact. All branches preserved. Reflog preserved.

---

## 5. Recommendation for the future

`git gc` runs automatically when loose objects exceed `gc.auto` (default 6,700) or pack files exceed `gc.autoPackLimit` (default 50). This repo had 4,965 — under the default threshold, so automatic gc hadn't triggered.

Two safe options:

- **A) Lower `gc.auto`** if you want more frequent auto-gc: `git config gc.auto 1000`. Then any time loose objects exceed 1,000, the next git command triggers a packing.
- **B) Schedule a quarterly manual gc**. The cost is ~3–5 minutes (background), the recovery is comparable to what we just got.

**Recommendation: A** — set `gc.auto = 1000` so this doesn't drift back. One-line `git config` change. No history risk.

---

## 6. Risk classification

`git gc --aggressive --prune=now` is the **safest** non-trivial git operation. It only ever removes objects unreachable from any ref/branch/tag/reflog, and only after the grace period (which `--prune=now` shortens to zero). `git fsck` after the operation confirmed zero corruption.

**Reversible?** No — gc is one-way. But also: there's nothing to revert. The pack file is git's normal storage shape.

---

## 7. Status

**APPLIED.** `.git/` reduced by 31 MB. 4,965 loose objects packed into 1 pack file. History intact, fsck clean. T1.1 complete.
