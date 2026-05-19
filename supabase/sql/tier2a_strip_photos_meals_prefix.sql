-- SixPack AI · Tier 2-A · phase 2-A.4 — strip `photos/meals/` prefix
--
-- BACKGROUND
-- Until this migration, `public.recipes.image_url` stored a bundled-asset
-- path (`photos/meals/<slug>.webp`) for the 293 meal photos seeded by
-- phases 72, 83, 84. The Tier 2-A migration moves those files to
-- Supabase Storage's `recipes_images` bucket and lets
-- `MediaUrl.resolve()` compose the public URL on the client from a
-- bare filename. This file is the DB-side flip: it strips the
-- `photos/meals/` prefix so each row's `image_url` becomes the bare
-- filename `MediaUrl` expects.
--
-- TARGETED ROWS (and ONLY these):
--   • image_url LIKE 'photos/meals/%' — exactly the 293 meal photos
--
-- EXPLICITLY NOT TOUCHED:
--   • image_url LIKE 'http%'          — Unsplash legacy URLs; the
--                                       client already passes those
--                                       through MediaUrl unchanged
--   • image_url IS NULL or = ''       — no-image rows
--   • Any row whose image_url is already bare-filename (someone could
--     have manually pre-migrated a row in Studio; the WHERE clause
--     excludes those)
--
-- PRE-REQUISITE: phase 2-A.3 has uploaded all 293 files to
-- `recipes_images`. Verify with:
--   SELECT COUNT(*) FROM storage.objects WHERE bucket_id='recipes_images'
--     AND name ~ '^[a-z0-9_]+\.webp$';
-- Should return ≥ 293 BEFORE running this file.
--
-- ROLLBACK: see the inverse transaction at the bottom of this file
-- (commented out). The original `image_url` strings are deterministic
-- — every value mutated by this migration was 'photos/meals/' + the
-- new value, so the rollback is also algorithmic, no CSV restore
-- needed.

begin;

-- =============================================================================
-- 0. Pre-flight counts (informational; do not affect the transaction)
-- =============================================================================
-- Run these manually before COMMIT to verify the deltas look right.
-- Comment out before applying programmatically; psql will print them
-- inline.
-- =============================================================================

\echo '--- pre-flight counts ---'

select
  count(*)                                                 as total_rows,
  count(*) filter (where image_url like 'photos/meals/%')  as will_strip,
  count(*) filter (where image_url like 'http%')           as external_unsplash_etc,
  count(*) filter (where image_url is null or image_url = '') as null_or_empty,
  count(*) filter (
    where image_url is not null
      and image_url not like 'photos/%'
      and image_url not like 'http%'
      and image_url <> ''
  )                                                        as already_bare_filename
from public.recipes;

-- =============================================================================
-- 1. Strip the `photos/meals/` prefix
-- =============================================================================
-- `SUBSTRING(... FROM <pos>)` is 1-indexed in Postgres. The literal
-- 'photos/meals/' is 13 chars, so we want everything from char 14 onwards.
-- Equivalent to `regexp_replace(image_url, '^photos/meals/', '')` but
-- avoids the regex engine for a literal-prefix strip.
-- =============================================================================

update public.recipes
set image_url = substring(image_url from length('photos/meals/') + 1)
where image_url like 'photos/meals/%';

-- =============================================================================
-- 2. Post-flight verification
-- =============================================================================
-- Expected after the UPDATE:
--   stripped_remaining     = 0    (no row still has the old prefix)
--   bare_slug_webps        ≥ 293  (new bare-filename rows, +
--                                  anything that was already bare)
--   external_unsplash_etc  = same as pre-flight (untouched)
--   null_or_empty          = same as pre-flight (untouched)
-- =============================================================================

\echo '--- post-flight counts ---'

select
  count(*)                                                                  as total_rows,
  count(*) filter (where image_url like 'photos/meals/%')                   as stripped_remaining,
  count(*) filter (where image_url ~ '^[a-z0-9_]+\.webp$')                  as bare_slug_webps,
  count(*) filter (where image_url like 'http%')                            as external_unsplash_etc,
  count(*) filter (where image_url is null or image_url = '')               as null_or_empty
from public.recipes;

\echo '--- sample of stripped rows ---'

select id, slug_substring as image_url_now
from (
  select id, image_url as slug_substring,
         row_number() over (order by random()) as rn
  from public.recipes
  where image_url ~ '^[a-z0-9_]+\.webp$'
) sampled
where rn <= 5;

-- =============================================================================
-- 3. Final commit
-- =============================================================================
-- IF the post-flight numbers look wrong (stripped_remaining > 0,
-- or bare_slug_webps < pre-flight will_strip), DO NOT COMMIT — issue
-- ROLLBACK in psql and investigate. The pre/post counts above let you
-- decide before you spend that COMMIT.
-- =============================================================================

commit;

-- =============================================================================
-- ROLLBACK (paste this into psql AFTER the migration if anything regresses)
-- =============================================================================
-- begin;
--
-- update public.recipes
-- set image_url = 'photos/meals/' || image_url
-- where image_url ~ '^[a-z0-9_]+\.webp$';
--
-- -- Verify the inverse:
-- select count(*) filter (where image_url like 'photos/meals/%') as restored
-- from public.recipes;
-- -- Should match the original 'will_strip' count from the pre-flight
-- -- of the forward migration.
--
-- commit;
-- =============================================================================
