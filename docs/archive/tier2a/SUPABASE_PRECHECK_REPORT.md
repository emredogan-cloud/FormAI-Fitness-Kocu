# Supabase Precheck Report — Phase 2-A.3

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.3 Supabase Precheck (READ-ONLY, NON-DESTRUCTIVE)
> **Live API access:** none — this is a code/SQL static audit, plus a list of
> read-only queries the user must run themselves to confirm runtime state.

---

## 1. Bucket assumptions vs. on-disk SQL truth

### 1.1 `recipes_images` bucket — already declared

`supabase/migrations/004_admin_storage_rls.sql` (Phase 138 B-6) creates the
bucket idempotently and pins `public = true`:

```sql
-- supabase/migrations/004_admin_storage_rls.sql:104-108
insert into storage.buckets (id, name, public) values
  ('recipes_images', 'recipes_images', true),
  ('exercises_media', 'exercises_media', true),
  ('exercises', 'exercises', true)
on conflict (id) do update set public = true;
```

**Implication:** the plan's Phase 2-A.3 SQL bucket-creation block (lines
106-110 of `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md`) is **redundant on a
live DB that already ran migration 004**. It is still safe to re-run
(both use `ON CONFLICT (id) DO UPDATE`), but the user should know the
bucket is *already provisioned* — Phase 2-A.3 is *upload to existing
bucket*, not *create bucket from scratch*.

### 1.2 RLS policies — admin-only WRITE, public READ

`004_admin_storage_rls.sql` also installs the storage RLS gates:

| Policy | Effect | Implication for migration |
|---|---|---|
| `admin_buckets_insert` (line 111) | Only `auth.jwt().app_metadata.role = 'admin'` can `INSERT` into `recipes_images` | **A bulk-upload using `SUPABASE_ANON_KEY` will be REJECTED by RLS.** Must use `SUPABASE_SERVICE_ROLE_KEY` (bypasses RLS) or an admin-role JWT. |
| `admin_buckets_update` | Same gate for UPDATE | n/a (we don't update post-upload) |
| `Public read recipe images` (line 156) | Anon + authenticated SELECT | ✓ Confirms public URLs will resolve for end users |

**Critical credential pre-req:** the bulk upload step needs the
**service-role key**, not the anon key. Document this in the user
brief (§7 below).

---

## 2. Admin upload flow — collision risk analysis

### 2.1 Admin-form file naming

`lib/features/admin/presentation/widgets/admin_recipe_form.dart:411-412`:

```dart
final filename = '${DateTime.now().millisecondsSinceEpoch}_$slug.$extension';
// e.g. '1748234567890_izgara_tavuk.webp'
```

`uploadBinary(..., FileOptions(upsert: false))` (line 418) means new
uploads with a clashing key **fail** rather than overwrite.

### 2.2 Our migration's file naming

`supabase storage cp ./photos/meals/ ss:///recipes_images/ --recursive`
preserves source filenames verbatim:

```
acili_domates_corbasi.webp        (no prefix, no timestamp)
akdeniz_kinoa_salatasi.webp
...
```

### 2.3 Collision matrix

| Existing object (admin-uploaded) | New object (migration) | Collision? |
|---|---|---|
| `1748234567890_izgara_tavuk.webp` | `izgara_tavuk.webp` | **NO** — admin always has `<digits>_` prefix |
| `1700000000000_acili_domates_corbasi.webp` | `acili_domates_corbasi.webp` | **NO** |
| `acili_domates_corbasi.webp` (slug-named in bucket) | `acili_domates_corbasi.webp` | **YES — would be rejected by upsert:false** |

**The risk is exactly one shape:** if a PM ever hand-uploaded a
slug-named file (without the timestamp prefix) to the bucket via the
Supabase Studio UI, our migration would hit `upsert:false`-style
rejection for that one file. Mitigation: use `--upsert` or skip-on-
existing in the upload script (see §7 user actions).

---

## 3. Public URL pattern

`lib/core/utils/media_url.dart:88-92`:

```dart
if (cdn != null) return '$cdn/$bucket/$trimmed';
if (supabase != null) {
  return '$supabase/storage/v1/object/public/$bucket/$trimmed';
}
```

For a recipe with `image_url = 'acili_domates_corbasi.webp'` after Phase
2-A.4 rewrite, the resolved URL depends on `.env`:

| `.env` shape | Resolved URL |
|---|---|
| Both `SUPABASE_URL` + `CDN_BASE_URL` set | `<CDN_BASE_URL>/recipes_images/acili_domates_corbasi.webp` |
| `SUPABASE_URL` only, `CDN_BASE_URL` empty | `<SUPABASE_URL>/storage/v1/object/public/recipes_images/acili_domates_corbasi.webp` |
| Neither set | `null` (caller falls back to empty-state UI) |

Current `.env.example` ships `CDN_BASE_URL=` empty — **default path is
direct Supabase Storage**, which is the migration plan's assumption.

**Verification probe** (no-auth GET): the user can open any of these in
a browser **after upload** to confirm:

```
<SUPABASE_URL>/storage/v1/object/public/recipes_images/firin_tarcinli_elma.webp
```

If it 200s with a webp body → public read is wired correctly.
If it 400s with `{"error":"object not found"}` → upload step failed.
If it 401s → RLS misconfiguration (public select policy missing).

---

## 4. Cache header strategy

### 4.1 What the plan proposes

Plan §2-A.3 lines 110-117:

```sql
UPDATE storage.objects
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
  'cacheControl', 'public, max-age=2592000, immutable'
)
WHERE bucket_id = 'recipes_images' AND name LIKE '%.webp';
```

### 4.2 How Supabase actually reads cache control

Supabase Storage returns the `Cache-Control` response header from
`storage.objects.metadata->>'cacheControl'`. The plan's post-upload
UPDATE works, but the **canonical** way is to set it during upload via
`FileOptions(cacheControl: 'public, max-age=2592000, immutable')`:

```python
# Cleaner — set during upload, no separate UPDATE needed:
supabase.storage.from_('recipes_images').upload(
    path=name,
    file=open(local, 'rb'),
    file_options={
        'content-type': 'image/webp',
        'cache-control': 'public, max-age=2592000, immutable',
    },
)
```

Both approaches end at the same response header. The post-upload SQL
UPDATE is **safer for a re-run scenario** (covers files uploaded
through any path, including admin form which doesn't set
cache-control explicitly today).

### 4.3 `immutable` directive is safe here

The slug → filename mapping is permanent (we never rename), so the
`immutable` directive does not need to be revisited unless a recipe's
visual content is replaced. If that ever happens, the admin form's
`<timestamp>_<slug>` naming guarantees the new URL differs, side-
stepping cache invalidation entirely.

---

## 5. Existing bucket-naming patterns

Patterns observed by reading the codebase:

| Source | Pattern | Example | Migration concern |
|---|---|---|---|
| Admin recipe form | `<ts_ms>_<slug>.<ext>` | `1748234567890_izgara_tavuk.webp` | None — no collision with bare slug |
| Admin exercise form (different bucket) | `<ts_ms>_<slug>.<ext>` | `1748234567890_pushup.mp4` | n/a (different bucket) |
| Plan upload (our migration) | `<slug>.webp` | `izgara_tavuk.webp` | None — clean slot in bucket |
| Legacy Unsplash URLs (some seed rows) | full `https://images.unsplash.com/...` | n/a | `MediaUrl.resolve()` passes through unchanged — these rows are NOT touched by the migration's slug rewrite |

---

## 6. `MediaUrl.resolve()` passthrough confirmation

Reading `lib/core/utils/media_url.dart:62-64`:

```dart
if (trimmed.startsWith('photos/') || trimmed.startsWith('assets/')) {
  return trimmed;
}
```

**Before** Phase 2-A.4 DB rewrite, every `image_url` in `recipes` is
`'photos/meals/<slug>.webp'` → passes through as local asset path →
`CachedImage` routes to `Image.asset`. (Current production behaviour.)

**After** Phase 2-A.4 DB rewrite, every row is `'<slug>.webp'` (no
prefix) → falls through to the bare-filename rule → composes
`<base>/recipes_images/<slug>.webp`. (Target behaviour.)

**Mixed state during the rewrite transaction** (between BEGIN and
COMMIT in §2-A.4): readers using read-committed isolation see either
all-old or all-new (the UPDATE is atomic). No partial state visible to
clients. ✓

---

## 7. What the user MUST verify (read-only, runtime queries)

I cannot reach the live DB. The user should run these themselves and
share the output before Phase 2-A.3 upload kicks off:

### 7.1 Bucket existence + publicness

```sql
SELECT id, name, public, created_at
FROM storage.buckets
WHERE id = 'recipes_images';
-- Expected: 1 row, public = true, created_at predates today.
```

### 7.2 Bucket file count (current state)

```sql
SELECT COUNT(*) AS objects,
       COUNT(*) FILTER (WHERE name LIKE '%.webp') AS webps,
       COUNT(*) FILTER (WHERE name ~ '^[a-z0-9_]+\.webp$') AS bare_slug_webps,
       COUNT(*) FILTER (WHERE name ~ '^[0-9]+_.*\.webp$') AS timestamped_webps
FROM storage.objects
WHERE bucket_id = 'recipes_images';
-- Expected:
--   bare_slug_webps     = 0   ← critical; means no collision risk
--   timestamped_webps   = N   ← admin-uploaded files; do not interfere
--   webps               = objects + (any non-webp files)
```

### 7.3 If `bare_slug_webps > 0` — collision scan

```sql
SELECT name FROM storage.objects
WHERE bucket_id = 'recipes_images'
  AND name ~ '^[a-z0-9_]+\.webp$';
-- Surface any pre-existing slug-named files. Cross-check against
-- photos/meals/ filenames; for each collision, decide whether to
-- skip the upload (use existing) or overwrite (use --upsert).
```

### 7.4 Recipes row count vs. plan expectation

```sql
SELECT COUNT(*) AS rows,
       COUNT(*) FILTER (WHERE image_url LIKE 'photos/meals/%') AS local_asset_rows,
       COUNT(*) FILTER (WHERE image_url LIKE 'http%') AS external_url_rows,
       COUNT(*) FILTER (WHERE image_url IS NULL OR image_url = '') AS null_rows
FROM recipes;
-- Expected:
--   local_asset_rows = 293 (matches SQL-seed cross-check from MEAL_ASSET_INVENTORY.md)
--   external_url_rows = some number (unsplash legacy) — UNTOUCHED by migration
--   null_rows = ideally 0
```

### 7.5 Admin JWT availability

The bulk-upload script needs either:
- `SUPABASE_SERVICE_ROLE_KEY` (from Supabase Studio → Project Settings →
  API → service_role secret), **OR**
- A logged-in admin Supabase Auth session with
  `app_metadata.role = 'admin'`

The service role key is the simpler choice for a one-shot bulk
migration script. **Do not check this key into git.**

---

## 8. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Bulk upload runs with anon key, hits RLS reject 401 | High | Use service-role key; surfaced in §7.5 |
| Pre-existing slug-named admin upload collides with one of our 293 files | Low | §7.3 scan catches it; per-file `--upsert` or skip-on-existing in script |
| Cache-Control not set on objects → no edge caching → high egress | Medium | Use `FileOptions(cacheControl=...)` during upload AND/OR run the metadata UPDATE SQL after upload |
| Unsplash legacy rows mis-detected by `WHERE image_url LIKE '%.webp'` (rare URLs end in .webp?) | Very low | Phase 2-A.4 uses `LIKE 'photos/meals/%'` not the generic suffix match — safe |
| CDN_BASE_URL is set to a URL that doesn't proxy `recipes_images` correctly | Low | Easy rollback: clear `CDN_BASE_URL` → direct Supabase fallback. No DB change |
| Service role key leaks via terminal history when running the upload script | Medium | Pass via env var, not CLI arg: `SUPABASE_SERVICE_ROLE_KEY=… python3 scripts/upload.py` |

---

## 9. Recommended upload mechanism

`supabase storage cp ... --recursive` is the simplest path but the
official CLI's storage subcommand has historically been thin. A small
Python script using `supabase-py` is more controllable:

```python
# scripts/upload_meal_images_to_supabase.py (NOT WRITTEN YET — pending approval)
# Pseudocode:
from supabase import create_client
import os, pathlib

client = create_client(
    os.environ['SUPABASE_URL'],
    os.environ['SUPABASE_SERVICE_ROLE_KEY'],
)
bucket = client.storage.from_('recipes_images')
for p in pathlib.Path('photos/meals').glob('*.webp'):
    with open(p, 'rb') as f:
        bucket.upload(
            path=p.name,
            file=f.read(),
            file_options={
                'content-type': 'image/webp',
                'cache-control': 'public, max-age=2592000, immutable',
                'upsert': 'false',   # change to 'true' only after §7.3 surfaced no collisions
            },
        )
```

This script is **not part of Phase 2-A.3** (precheck-only); it is the
artefact Phase 2-A.3-execute would write. Phase 2-A.3 just validates
that the assumptions hold.

---

## 10. Gates passed

- [x] `recipes_images` bucket SQL declaration found and validated
- [x] Public-read + admin-write RLS policies confirmed in source
- [x] Collision matrix vs. admin-upload naming pattern proven safe
- [x] Public URL pattern matches `MediaUrl.resolve()` bare-filename branch
- [x] Cache-Control mechanism documented (two equivalent paths)
- [x] User read-only verification queries written out (§7)
- [x] Risk register populated
- [x] Recommended upload mechanism scoped (script body sketched, NOT written)

**Phase 2-A.3 status:** ✅ precheck complete. Awaiting user-side read-only
queries (§7) before Phase 2-A.3-execute can run.
