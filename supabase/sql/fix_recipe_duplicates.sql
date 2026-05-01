-- =============================================================================
-- Phase 74 · dedupe `public.recipes` and re-arm the title UNIQUE constraint.
-- =============================================================================
-- Background: Phase 72's sync script discovered 25 duplicate-title rows in
-- the live recipes table. The Phase 43 idempotency primer was supposed to
-- have left a UNIQUE constraint on `title`; either it never applied to this
-- DB or it was dropped along the way. Either way, the duplicates now block
-- the constraint from being added back, so we have to dedupe first.
--
-- How to run: paste this entire file into the Supabase SQL Editor (which
-- runs as superuser and bypasses RLS) and execute. The whole script is
-- wrapped in BEGIN/COMMIT so any failure rolls everything back.
--
-- Dedupe rule (per Phase 74 brief):
--   "Keep the row with the lowest ID (or the one with a non-null
--    image_url) and DELETE the duplicates."
--
-- Implemented as: rank rows within each title group by
--   1. image_url IS NOT NULL  (prefer rows that already have a wired-up
--      cover photo — losing one to dedupe would mean re-running the
--      Phase 72 sync), then
--   2. id ASC (lowest UUID as the deterministic tiebreaker)
-- and DELETE everything except rank 1.
-- =============================================================================

BEGIN;

-- 1. Audit: report what we are about to delete. Inspect the result of
--    this SELECT before running the DELETE if you want a sanity check.
--    (Comment-only — does not affect the transaction.)
-- SELECT title, COUNT(*) AS row_count
-- FROM public.recipes
-- GROUP BY title
-- HAVING COUNT(*) > 1
-- ORDER BY row_count DESC, title;

-- 2. Dedupe.
WITH ranked AS (
  SELECT
    id,
    title,
    ROW_NUMBER() OVER (
      PARTITION BY title
      ORDER BY (image_url IS NOT NULL) DESC, id ASC
    ) AS rn
  FROM public.recipes
)
DELETE FROM public.recipes
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- 3. Re-arm the UNIQUE constraint so future duplicate inserts fail
--    fast at the DB layer (admin form, seeding scripts, etc.). Wrapped
--    in a guard so re-running this file is a no-op once installed.
DO $guard$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'recipes_title_unique'
  ) THEN
    ALTER TABLE public.recipes
      ADD CONSTRAINT recipes_title_unique UNIQUE (title);
  END IF;
END
$guard$;

COMMIT;

-- =============================================================================
-- Sanity check (run separately after COMMIT):
-- =============================================================================
-- SELECT title, COUNT(*) FROM public.recipes
-- GROUP BY title HAVING COUNT(*) > 1;     -- should return 0 rows
-- SELECT conname FROM pg_constraint
-- WHERE conname = 'recipes_title_unique'; -- should return 1 row
