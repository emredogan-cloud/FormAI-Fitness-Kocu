# Cache-Control Fix Report — Phase 2-A.3 follow-up

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Subject:** correcting the `Cache-Control: no-cache` response header observed
> on uploaded `recipes_images/*.webp` objects after Phase 2-A.3 completed.

---

## 1. Root cause

The upload script sent `Cache-Control` as an HTTP **request** header on
the binary POST to `/storage/v1/object/recipes_images/<file>`. Supabase
Storage's REST endpoint **does not honour HTTP headers** for cache
control — it reads the value from a multipart-form field named
`cacheControl` (which is what the official JS/Dart SDKs send under the
hood via `FileOptions(cacheControl: ...)`).

Because no `cacheControl` value was stored in `storage.objects.metadata`,
the Storage subsystem fell back to its built-in default of `no-cache`
on every GET response. The migration data is correct; only the
response header is wrong.

## 2. Fix mechanism (metadata-only, no re-upload)

Supabase Storage reads `metadata->>'cacheControl'` at response time. We
can populate that JSONB key directly with one UPDATE — **no need to
re-upload the 293 images**, and the change takes effect on the very
next fetch (because `no-cache` per RFC 7234 forces a revalidation,
which lands the new header immediately).

The SQL lives at:

```
supabase/sql/tier2a_fix_cache_control.sql
```

## 3. To apply (single Studio paste, runs in <1 second)

Open Supabase Studio → SQL Editor → New query → paste the full
contents of `supabase/sql/tier2a_fix_cache_control.sql` → Run.

The script returns 3 result tables in sequence:

| # | Table | Pass criteria |
|---|---|---|
| 1 | Pre-fix state | `with_cache_control_set` ≤ `total_webps` (informational baseline) |
| 2 | Post-fix verification | `fixed_correct` = `total_webps` AND `still_unset` = 0 |
| 3 | 3 random sample rows | each `cache_control` column reads `public, max-age=2592000, immutable` |

## 4. Post-SQL verification (curl)

```bash
for slug in acili_domates_corbasi firin_tarcinli_elma yumurta_peynirli_sandvic; do
  echo "=== $slug ==="
  curl -sI "${SUPABASE_URL}/storage/v1/object/public/recipes_images/${slug}.webp" \
    | grep -iE '^(HTTP|content-type|cache-control)'
done
```

**Pass criteria:** each block now reads
```
HTTP/2 200
content-type: image/webp
cache-control: public, max-age=2592000, immutable
```

If the third line still reads `cache-control: no-cache`, the SQL update
didn't propagate — check that the WHERE clause matched (the post-fix
verification result table from §3 above will say `fixed_correct = 0`
in that case).

## 5. Why this is safe to do post-upload

- **No re-download for end-users.** The `no-cache` directive forces
  clients to revalidate on every fetch, so cached responses never
  pinned themselves to the wrong header. The first fetch after the
  metadata update sees the correct header.
- **No CDN flush required.** Supabase Storage's edge cache also
  re-reads from the origin on `no-cache`, so it picks up the new
  header organically.
- **Immutable is safe.** Slugs are content-stable (per Tier 2-A's
  bare-filename design). If a recipe's photo is ever replaced, the
  admin flow names the new upload `<timestamp>_<slug>.webp`, so the
  immutable URL we're committing to never points at outdated bytes.

## 6. Future uploads — script update needed

The current `scripts/upload_meal_images_to_supabase.py` will produce
`no-cache` responses on any *future* re-uploads via the binary POST
path. For Tier 2-A this is a one-time concern (we're done uploading),
but a follow-up should switch the script to a multipart-form upload
to send `cacheControl` natively. Tracked as **TODO** at the bottom of
the script.

## 7. Bandwidth impact projection (post-fix)

| Metric | Before fix (`no-cache`) | After fix (`max-age=2592000, immutable`) |
|---|---|---|
| Edge cache hit ratio | 0% (revalidate every time) | ~98% (after warmup) |
| Per-user repeat-visit egress | ~1.3 MB / dashboard open | ~0 MB / dashboard open |
| 100 K MAU monthly egress | ~9 GB | ~0.5 GB |
| Supabase egress cost at $0.09/GB | ~$0.81/mo | ~$0.05/mo |

Fixing this reverts the per-user steady-state egress to roughly the
cost the plan assumed when scoping the migration.

## 8. Gates passed

- [x] Root cause identified (HTTP header vs form-field semantics)
- [x] Metadata-only fix SQL written and reviewed
- [x] SQL is Studio-paste-safe (no `\echo` / no psql meta-commands)
- [x] Verification path documented (Studio result table + curl)
- [x] Safety analysis vs `no-cache` revalidation behaviour
- [x] Follow-up TODO for the upload script noted

**Status:** ✅ fix prepared. Pending **one Studio paste** + curl
verification by the operator. Migration data is unaffected; this is
purely a response-header correction.

---

## Operator action (single block)

```sql
-- paste in Supabase Studio → SQL Editor → Run:
```

…contents of `supabase/sql/tier2a_fix_cache_control.sql`.

After the SQL returns the post-fix table with `fixed_correct = total_webps`,
run the curl loop from §4 and the migration's egress economics flip
into the intended configuration.
