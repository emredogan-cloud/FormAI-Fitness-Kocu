-- =============================================================================
-- Phase 29 patch: backfill missing tags on `public.recipes`
-- =============================================================================
-- The Phase 24 + 28 seeds populated `tags` for the rows they created, but
-- rows inserted before the tag column existed (or by third-party imports)
-- can still be missing common tags — that's what made the Discovery
-- filter chips look broken: "Hacim" matched almost nothing, even though
-- several recipes over 600 kcal logically qualify.
--
-- Each statement below is idempotent via the `NOT ('Tag' = ANY(tags))`
-- guard — re-running the file won't produce duplicate tags on a row.
-- Re-run this safely whenever you add fresh recipes.
-- =============================================================================

-- High-calorie rows → "Hacim" (bulk).
UPDATE public.recipes
SET    tags = array_append(tags, 'Hacim')
WHERE  calories >= 500
  AND  NOT ('Hacim' = ANY(tags));

-- Low-calorie rows → "Düşük Kalori".
UPDATE public.recipes
SET    tags = array_append(tags, 'Düşük Kalori')
WHERE  calories <= 400
  AND  NOT ('Düşük Kalori' = ANY(tags));

-- High-protein rows → "Yüksek Protein".
UPDATE public.recipes
SET    tags = array_append(tags, 'Yüksek Protein')
WHERE  protein >= 30
  AND  NOT ('Yüksek Protein' = ANY(tags));

-- Lean + balanced macros → "Sıkılaşma" (tone / recomp).
-- Narrower rule than the UI heuristic so we don't over-apply.
UPDATE public.recipes
SET    tags = array_append(tags, 'Sıkılaşma')
WHERE  calories <= 500
  AND  protein >= 20
  AND  fat <= 15
  AND  NOT ('Sıkılaşma' = ANY(tags));

-- =============================================================================
-- Sanity check — distribution of tagged rows after the backfill.
-- =============================================================================
-- SELECT unnest(tags) AS tag, count(*)
-- FROM   public.recipes
-- GROUP  BY tag
-- ORDER  BY count DESC;
