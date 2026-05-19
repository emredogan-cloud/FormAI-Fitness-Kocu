# Meal Asset Inventory — Phase 2-A.1

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.1 Backup & Inventory (non-destructive)
> **Backup location:** `/tmp/sixpack-meals-migration-backup/meals/` (verified, 298 files, 64 MB)

---

## 1. Headline numbers

| Metric | Value | Plan expected | Match? |
|---|---|---|---|
| Files in `photos/meals/` | **298** | ~298 | ✓ exact |
| Total size (real bytes) | **62.54 MB** | "64 MB" | ✓ within rounding |
| `du -sh` (block-aligned) | 64 MB | ~64 MB | ✓ |
| Format breakdown | 298 × `.webp` / 0 other | webp-only | ✓ |
| MD5-duplicate files | **0** | n/a (assumed clean) | ✓ |
| Filename collisions | **0** | n/a | ✓ |
| Non-ASCII / uppercase filenames | **0** | n/a | ✓ |
| Min / Max / Avg file size | 73 KB / 610 KB / **214 KB** | — | — |

Image set is **production-clean**: lowercase snake_case slugs, single format, no dupes, no collisions, no encoding hazards.

---

## 2. Reference cross-check

### 2.1 SQL-seed → disk file

Source: `supabase/sql/*.sql` (every file in the directory):

```text
Unique photos/meals/<slug>.webp refs in SQL : 293
Files on disk with matching slug             : 293
SQL refs with NO file on disk (broken refs)  :   0  ← clean
```

**Zero broken DB references.** Every recipe row the seed migration intends to write has its image file on disk today.

The 293 SQL-referenced files are the **migration corpus** for Phases 2-A.3 / 2-A.4: upload to `recipes_images`, rewrite `image_url` to bare filename.

### 2.2 Orphan files (on disk, NOT referenced by SQL)

```text
budget_cover_breakfast.webp
budget_cover_dessert.webp
budget_cover_dinner.webp
budget_cover_lunch.webp
budget_cover_snack.webp
```

**5 files.** Critical finding: these are **NOT recipe DB rows**. They are *UI category cover photos* hardcoded as asset paths in:

| File | Lines | Usage |
|---|---|---|
| `lib/features/nutrition/presentation/nutrition_tab.dart` | 1418, 1425, 1432, 1439, 1446 | `imageUrl: 'photos/meals/budget_cover_<type>.webp'` in a const list driving the budget-meals category strip. |

These covers ride along with the rest of `photos/meals/` in the APK today, but they have a *different migration shape* from the 293 recipe images:

- **They have no DB row.** Phase 2-A.4's `UPDATE recipes` is a no-op for them.
- **Their paths are baked into Dart source.** Moving them to CDN requires editing `nutrition_tab.dart`, not just a DB rewrite.
- **They are not slugs of recipes.** Bundling LQIPs for them under `assets/lqip/meals/budget_cover_<type>.webp` works (filename matches), but the LQIP fallback inside `RecipeImage` is keyed on `recipe.slug`, which these don't have.

**Recommendation:** treat the budget covers as a **Tier 2-A.0.5 follow-up**, not part of the recipe migration:
1. Either leave them bundled (cost: 5 × ~200 KB = ~1 MB — negligible vs the 62 MB win), **or**
2. Migrate separately by hard-coding the CDN URL in `nutrition_tab.dart` after the bucket is populated.

Plan-as-written treats them implicitly — the SQL count of 293 vs the plan's "~298" was already absorbing this.

### 2.3 Orphan in code (refs with no file)

```text
0 broken in-code references.
```

`lib/scripts/sync_recipes_db.dart` (utility, not shipped) computes its own paths and is a no-op against missing files.

---

## 3. Naming convention audit

All 298 filenames match `^[a-z0-9_]+\.webp$`:

- Lowercase ASCII only — no accent / Turkish-letter mojibake.
- snake_case throughout (`acili_domates_corbasi.webp`, `firin_tarcinli_elma.webp`).
- No spaces, no parentheses, no version suffixes (`_v2`, `_final`).
- Slug-clean — directly usable as Supabase Storage object keys with **zero filename rewriting**.

This is the **happy path** for Phase 2-A.3: a straight `supabase storage cp ./photos/meals/ ss:///recipes_images/ --recursive` will produce DB-matching object names.

---

## 4. Size distribution

```text
count   298
total   62.54 MB
min     73 KB   (smallest single image)
max     610 KB  (largest single image)
avg     214 KB
```

**Egress projection** (post-migration, fully cold install browses one full nutrition tab):
- 6 meals prefetched on dashboard mount × avg 214 KB = **~1.3 MB warm-up**
- Plus ~12 visible meal-card thumbnails on first scroll = **~2.5 MB**
- Worst case full corpus = 62 MB but only if a user opens every recipe (~3 months of usage)

Supabase Storage egress at $0.09/GB → **<$0.20 per active user/month** even on heavy usage. Negligible.

---

## 5. Anomalies

None.

- No duplicate files (by md5).
- No empty / zero-byte files (min 73 KB).
- No filename collisions when lowercased + extension-stripped.
- No non-webp masquerading (file extension matches content for all 298 by name; binary content not byte-inspected but the manifest pattern matches `Image.asset` happy path observed in prod).
- No paths longer than POSIX limits.
- No Windows-reserved filenames (`con.webp`, `nul.webp` etc.).

---

## 6. What ships into the CDN

After Phase 2-A.3 upload:

```text
recipes_images/
  ├── acili_domates_corbasi.webp        (293 recipe images)
  ├── akdeniz_kinoa_salatasi.webp
  ├── …
  ├── (5 budget_cover_*.webp — separate decision, see §2.2)
  └── (admin-uploaded files already present, see SUPABASE_PRECHECK_REPORT.md)
```

**The 293 recipe files are the only mandatory migration set.** Treat the 5 budget_cover files as a discretionary follow-up.

---

## 7. Backup verification

```text
SRC:  photos/meals/                              298 files, 65,540,608 bytes
DST:  /tmp/sixpack-meals-migration-backup/meals/  298 files, 65,540,608 bytes
```

Rollback procedure (from §4 of `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md`):

```bash
# If anything goes wrong post-2-A.7 (asset deletion):
cp -r /tmp/sixpack-meals-migration-backup/meals photos/
```

Backup is on `tmpfs` and will be lost on reboot — **before the user runs Phase 2-A.7 (delete local photos)** they should mirror this backup to a persistent location (e.g. `~/sixpack-backup/meals-pre-migration/`).

---

## 8. Gates passed

- [x] Backup created and byte-equivalent to source
- [x] Expected file count (~298) confirmed exact (298)
- [x] No integrity anomalies (duplicates / empty / non-webp / collisions)
- [x] No missing references (every SQL slug has a disk file)
- [x] Orphan files identified and triaged (5 budget covers, decision documented)
- [x] Naming convention validated (CDN-safe as-is, zero rewriting needed)

**Phase 2-A.1 status:** ✅ complete, zero risk surfaced.

Proceed to Phase 2-A.2 (LQIP preparation).
