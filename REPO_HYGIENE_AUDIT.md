# Tier 3 — Repository Hygiene Audit

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Status:** AUDIT ONLY — no mutations applied.

---

## 0. Working-tree size, decomposed

```
8.2 GB total working tree:
  build/                 6.4 GB    gitignored Flutter build cache
  .dart_tool/            1.1 GB    gitignored Dart tool cache
  .git/                  456 MB    git history (loose objects — see §3)
  asosystem/             245 MB    untracked Vite project (see §1)
  android/                75 MB    Android tooling (most gitignored)
  photos/                 10 MB    asset bundle (clean post-Tier-2A)
  docs/                   10 MB    documentation (most images)
  lib/                   2.7 MB    Dart source
  Beslenme-Photos/       2.3 MB    personal media (gitignored)
  ios/                   2.0 MB    iOS scaffold
  tool/                  1.4 MB    icon source + Flutter version pin
  reports/               1.4 MB    engineering history
  assets/                1.2 MB    LQIPs (Tier 2-A)
  (everything else)    < 500 KB    each
```

`build/` + `.dart_tool/` (7.5 GB combined) **don't ship anywhere**. They are reclaimable with `flutter clean`.

`.git/` is **456 MB of git history**. See §3 for the unpacking opportunity.

The actual "useful working tree" (tracked + untracked sources, no caches) is **~315 MB**.

---

## 1. The `asosystem/` problem (245 MB)

### What it is

A separate Vite + Tailwind + React landing-page project for App Store
Optimization (ASO). Located at the repo root. Verified:

```
asosystem/
├── package.json              # Vite-based web project
├── vite.config.ts
├── tailwind.config.ts
├── postcss.config.js
├── tsconfig.json
├── src/                      328 KB  source
├── public/                   8.2 MB  static (mostly captures/screenshots)
├── prompts/                   20 KB  ASO copy prompts
├── scripts/                   20 KB  helper scripts
├── aso_example_screenshots/  8.4 MB  reference screenshots
├── exports/                   79 MB  ← gitignored by asosystem/.gitignore
└── node_modules/             150 MB  ← gitignored by asosystem/.gitignore
```

### What git sees

```bash
$ git ls-files asosystem/ | wc -l
0
$ git check-ignore -v asosystem/
(empty — NOT gitignored at root level)
```

**`asosystem/` is completely untracked.** No file inside it is in git.
Its internal `.gitignore` correctly excludes `node_modules/` and
`exports/`. But the directory itself is **not in the root `.gitignore`**,
which means:

- It's invisible to git operations (no commits include it).
- It contributes **0 bytes to `.git/`**.
- It contributes **245 MB to working tree `du`**.
- A `git add .` from someone unaware would attempt to add ~700+ files
  (excluding the asosystem-internal-gitignored bits).

### Risk profile

| Concern | Severity |
|---|---|
| Bundled into Flutter APK | 🟢 No — not in pubspec |
| Pushed to GitHub remote | 🟢 No — currently untracked |
| Accidental `git add .` could stage 700+ unrelated files | 🟡 Yes |
| Confuses repo onboarding (looks like part of the Flutter project) | 🟡 Yes |
| Adds 245 MB to fresh-checkout developer machines | n/a — it's not in git, so a fresh clone doesn't get it |

### Options

| Option | Working-tree Δ | Recovery | Notes |
|---|---:|---|---|
| **A.** Add `asosystem/` to root `.gitignore` | 0 (stays on disk) | n/a | Prevents accidental add; keeps the project locally |
| **B.** Move to a separate repo (`formai-aso`) | −245 MB | clone the new repo | The cleanest split; ASO is a separate product surface |
| **C.** Delete locally (since untracked, git won't object) | −245 MB | re-clone from ??? | **NOT RECOMMENDED unless backed up elsewhere** — 8.2 MB of asset_example_screenshots looks unique-to-this-machine |

**Recommendation: A or B.** Option C destroys content with no rollback path.

---

## 2. `Beslenme-Photos/` (2.3 MB)

Already gitignored. 15 personal nutrition reference photos
(`beslenme*.jpeg`, `fitaraöğün*.jpeg`). Per `.gitignore` Phase 40:

> *"untracked personal nutrition reference photography. Kept off-repo because the folder is ~MB of user-owned shots with no production asset binding in pubspec.yaml."*

Phase 139 also flagged this for deletion (T3-E). **Decision belongs to
the user** — these are their personal photos.

| Option | Working-tree Δ | Recommendation |
|---|---:|---|
| Keep | 0 | If still useful as reference / for the meal-photo content team |
| Move to cloud drive | −2.3 MB | If just sitting unused |
| Delete | −2.3 MB | Only with confirmation |

---

## 3. `.git/` — 456 MB of loose objects (NOT packed)

### Current state

```bash
$ find .git/objects -type f -not -path "*/pack/*" -not -path "*/info/*" | wc -l
4965

$ ls .git/objects/pack/
(empty)
```

**4,965 loose objects, 0 pack files.** This is the worst-case storage
shape for `.git`. Loose objects are compressed individually with zlib;
pack files use delta compression across similar objects — typically
**5–10× more efficient** for a repo's history.

### Why it matters

- Every `git status` / `git log` / `git fetch` reads many loose objects → I/O cost.
- `.git/` working-tree size is ~5× larger than it could be.
- Pack-and-prune cleans up unreferenced objects (orphaned blobs from
  prior `git reset` / `git rebase` operations).

### Likely cause of the loose-object accumulation

The 64 MB `photos/meals/` corpus + the 132 MB `new_workouts_image/`
that was removed in Phase 139 T3-A — both lived in commits that the
Phase 139 + Tier 2-A workflow added then later modified. Every modified
blob is a new loose object. Without `git gc`, they accumulate.

### Fix

A single command:

```bash
git gc --aggressive --prune=now
```

Expected outcome:

| Metric | Before | After (projected) |
|---|---:|---:|
| `.git/` size | 456 MB | **~80–100 MB** |
| Loose objects | 4,965 | < 100 |
| Pack files | 0 | 1–2 |
| `git status` time | (current) | ~25–30% faster |

**Risk:** 🟢 zero. `git gc` is by-design idempotent and safe; it never
loses reachable objects. `--prune=now` drops only unreferenced ones
(no branch / tag / reflog points to them). The only side effect is
that the unreferenced-blob-recovery window (`git fsck --lost-found`)
gets shortened — fine in normal operation.

**Reversible?** Pack files are git's normal storage shape; there's
nothing to revert.

---

## 4. Build / tool caches (gitignored, reclaimable)

| Path | Size | Reclaim command |
|---|---:|---|
| `build/` | 6.4 GB | `flutter clean` |
| `.dart_tool/` | 1.1 GB | `flutter clean` |
| `android/.gradle/` | 78 MB | `cd android && ./gradlew --stop && rm -rf .gradle/` (cold next build) |
| **Subtotal** | **~7.6 GB** | reclaimable, but **next build will be cold (~6–8 min)** |

These aren't engineering hygiene issues — they're normal Flutter caches.
The user might want to run `flutter clean` periodically anyway (~quarterly).

---

## 5. `.gitignore` audit — items NOT currently ignored that should be

| Path | Currently | Recommendation |
|---|---|---|
| `asosystem/` | Untracked + not gitignored | Add `asosystem/` to root `.gitignore` (option A from §1) |
| `*.tsbuildinfo` (asosystem has 2) | Untracked | Already handled by `asosystem/.gitignore` if present — verify |
| `/tmp/sixpack-meals-migration-backup/` | (external path) | n/a — outside repo |

The root `.gitignore` is otherwise well-maintained (`.dart_tool/`,
`build/`, IDE caches, OS files, secrets all properly excluded).

---

## 6. Stale-branch / dead-file scan

| Check | Result |
|---|---|
| Branches with no upstream | (run by user) |
| Files marked as tracked but missing on disk | 0 (Tier 2-A's 293 deletions are correctly staged + committed) |
| Symlinks pointing outside the repo | 0 found |
| Pre-existing dirty changes from `main` (carried onto this branch) | ~30 files, unrelated to Tier 2-A — see `FINAL_TIER2A_MIGRATION_REPORT.md §11` |

---

## 7. Markdown corpus overview (full details in `MARKDOWN_CORPUS_AUDIT.md`)

| Location | .md count | Notes |
|---|---:|---|
| Top-level `*.md` | 23 | 9 are recent Tier 2-A reports (mine); rest are historical audits |
| `docs/*.md` | 17 | Established docs + 1 Turkish duplicate (`PROJECT_DOCUMENTATION1.md`) |
| `reports/*.md` | 27 | Phase reports (96–138 era) |
| `reports/phase-N-*/` (4 dirs) | 19 | Strategy / market intelligence / UX research |
| `asosystem/*.md` | 202 | Vendored from asosystem's npm deps; NOT part of Flutter project |
| Other (`README.md`, `CLAUDE.md`, etc.) | 2 | active core |
| **Total** | **290** | |

**Total markdown weight** ≈ 3.6 MB. Trivial in absolute terms; high
in conceptual cost because it represents accumulated knowledge.

---

## 8. Risk classification

| Tier | Items |
|---|---|
| **T1 — low risk / high gain** | (1) Add `asosystem/` to root `.gitignore`. (2) `git gc --aggressive` to pack loose objects (-360 MB `.git/`). (3) Document `flutter clean` cadence (no immediate action). |
| **T2 — medium complexity** | (4) Decide `asosystem/` long-term: own repo vs. monorepo. (5) Decide `Beslenme-Photos/` retention. |
| **T3 — architecture-sensitive** | (6) Move budget-cover photos to a `photos/category_covers/` subdir so the `photos/meals/` pubspec entry can retire. Code-level change, low APK impact. |

---

## 9. Bottom line

The repository is **structurally healthy** with one immediate hygiene opportunity:

1. **`git gc --aggressive`** packs the loose objects — instantly reclaims **~360 MB** in `.git/` and speeds up routine git ops.
2. **Add `asosystem/` to root `.gitignore`** — prevents accidental staging of 245 MB of unrelated files.

Both are zero-risk, one-line operations. Everything else (build caches, photo cleanup, markdown corpus) is steady-state or already optimized.

The **biggest open question** is whether `asosystem/` belongs in this repo at all (option A vs. B in §1). That's a product/process decision the engineering team should make deliberately, not a hygiene fix.
