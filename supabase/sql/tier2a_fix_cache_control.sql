-- SixPack AI · Tier 2-A · Cache-Control fix for `recipes_images` objects
--
-- BACKGROUND
-- The Phase 2-A.3 upload sent `Cache-Control` as an HTTP request header,
-- which the Supabase Storage REST endpoint ignores (it reads the value
-- from a multipart `cacheControl` form field, not a header). As a
-- result, response headers came back as `cache-control: no-cache` —
-- defeating the migration's edge-cache benefits.
--
-- This is a metadata-only fix; no object re-upload required. Storage
-- reads `metadata->>'cacheControl'` when constructing the response, so
-- updating that one JSONB key flips the Cache-Control header on every
-- subsequent fetch.
--
-- Run this whole block in Supabase Studio → SQL Editor → Run.

begin;

-- 1) Pre-fix sample: how many objects currently have cacheControl set?
select
  count(*)                                                          as total_webps,
  count(*) filter (where metadata ? 'cacheControl')                 as with_cache_control_set,
  count(*) filter (where (metadata->>'cacheControl') = 'public, max-age=2592000, immutable') as already_correct
from storage.objects
where bucket_id = 'recipes_images'
  and name ~ '\.webp$';

-- 2) Set the cacheControl key on every webp in the bucket
update storage.objects
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'cacheControl', 'public, max-age=2592000, immutable'
)
where bucket_id = 'recipes_images'
  and name ~ '\.webp$';

-- 3) Post-fix verification
select
  count(*)                                                          as total_webps,
  count(*) filter (where (metadata->>'cacheControl') = 'public, max-age=2592000, immutable') as fixed_correct,
  count(*) filter (where metadata->>'cacheControl' is null)         as still_unset
from storage.objects
where bucket_id = 'recipes_images'
  and name ~ '\.webp$';

-- 4) Random 3-sample to read back
select name, metadata->>'cacheControl' as cache_control
from storage.objects
where bucket_id = 'recipes_images'
  and name ~ '\.webp$'
order by random()
limit 3;

commit;
