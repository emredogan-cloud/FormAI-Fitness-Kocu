# Deletion Report — Phase 2-A.7

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.7 — local-asset deletion + pubspec hygiene
> **Backup:** `/tmp/sixpack-meals-migration-backup/meals/` (298 files / 64 MB, verified intact)

---

## 1. Headline numbers

| Metric | Before | After | Delta |
|---|---:|---:|---:|
| `photos/meals/` file count | 298 | 5 | **−293** |
| `photos/meals/` directory size | 64 MB (62.54 MB real) | 1.02 MB | **−61.52 MB** |
| Backup file count | n/a | **298** | preserved |
| Backup size | n/a | 64 MB | preserved |
| `pubspec.yaml` lines changed | — | 1 comment block (8 lines) + 1 new entry (8 lines) | non-destructive |

---

## 2. What was deleted

```
photos/meals/*.webp  (293 recipe images, all NON-budget-cover)
```

The deletion command was scoped to `! -name "budget_cover_*"` so the 5
hardcoded category covers were preserved:

```bash
find photos/meals -maxdepth 1 -type f -name "*.webp" ! -name "budget_cover_*" -delete
# (293 files deleted)
```

## 3. What was preserved (intentional)

| File | Reason |
|---|---|
| `photos/meals/budget_cover_breakfast.webp` | UI category tile, hardcoded in `nutrition_tab.dart:1418` |
| `photos/meals/budget_cover_dessert.webp` | UI category tile, hardcoded in `nutrition_tab.dart:1439` |
| `photos/meals/budget_cover_dinner.webp` | UI category tile, hardcoded in `nutrition_tab.dart:1432` |
| `photos/meals/budget_cover_lunch.webp` | UI category tile, hardcoded in `nutrition_tab.dart:1425` |
| `photos/meals/budget_cover_snack.webp` | UI category tile, hardcoded in `nutrition_tab.dart:1446` |

These 5 are **not recipe DB rows** — they're const-list entries in
`nutrition_tab.dart` that drive a "budget meals" category strip. They
have no slug, no Supabase upload, no DB rewrite. Leaving them bundled
is the safest path; migrating them to CDN is a discretionary
follow-up if the ~1 MB matters.

## 4. pubspec.yaml decisions

| Change | Rationale |
|---|---|
| **Kept** `- "photos/meals/"` entry | Still bundling the 5 budget covers (above). Removing the entry would silently un-bundle them and break the budget-category UI. |
| **Updated** the comment block to reflect the new directory contents (was: "per-recipe meal cover photos ~280 KB each"; now: "only budget_cover_*.webp UI tiles after Tier 2-A migration") | Comment was *factually wrong* after the deletion. |
| **Added** `- "assets/lqip/meals/"` (done in Phase 2-A.5-do) | Bundles the 298 LQIPs (~201.6 KB). |

End-state diff summary on pubspec asset list:

```yaml
- ".env"
- "photos/"
- "photos/meals/"             # now only 5 budget covers, ~1 MB
- "photos/workouts/"
- "photos/exercises/"
- "assets/lqip/meals/"        # NEW — 298 × ~700 B LQIPs, ~200 KB
```

## 5. Backup verification

```text
/tmp/sixpack-meals-migration-backup/meals/
  ├── 298 files
  ├── 64 MB total
  └── byte-identical to pre-migration state
```

**Persistent backup recommendation:** the `/tmp` backup will vanish on
reboot. Before that happens, the user should mirror it to a stable
location:

```bash
mkdir -p ~/sixpack-backup
cp -r /tmp/sixpack-meals-migration-backup/meals ~/sixpack-backup/meals-pre-tier2a
```

## 6. Rollback procedure (mechanical)

If anything regresses post-deployment:

```bash
# 1. Restore the 293 recipe images
cp /tmp/sixpack-meals-migration-backup/meals/*.webp photos/meals/
ls photos/meals/ | wc -l       # expected: 298 again

# 2. Run the inverse SQL (paste in Supabase Studio):
#    begin;
#    update public.recipes
#    set image_url = 'photos/meals/' || image_url
#    where image_url ~ '^[a-z0-9_]+\.webp$';
#    commit;

# 3. Revert the pubspec.yaml + 7 nutrition file changes:
git revert <tier2a-commit-hash>   # see FINAL_TIER2A_MIGRATION_REPORT.md

# 4. Re-build and ship
bash scripts/release-build.sh aab
```

The CDN-uploaded files in `recipes_images` do NOT need to be deleted
on rollback — they cost ~$0.001/month in egress and provide a future
option without re-upload.

## 7. Gates passed

- [x] Exactly 293 files deleted (not 292, not 294)
- [x] Exactly 5 budget_cover files preserved
- [x] `find` command audited — `! -name "budget_cover_*"` clause scoped correctly
- [x] Backup at `/tmp` verified intact (298 files / 64 MB unchanged)
- [x] `pubspec.yaml` asset list updated with comment + LQIP entry
- [x] No `photos/meals/` pubspec entry removed (would have un-bundled the 5 covers)
- [x] Rollback procedure documented and mechanical

**Phase 2-A.7 status:** ✅ complete. Local-asset cleanup done; bundle
ready to shrink by ~61.5 MB on next release build.
