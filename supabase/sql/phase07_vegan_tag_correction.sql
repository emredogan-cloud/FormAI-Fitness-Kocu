-- Roadmap Phase 7 · a recipe tagged Vegan that contains honey.
--
-- WHAT THE CROSS-CHECK FOUND
--
-- The catalogue was hand-tagged by a dietitian in Phase 24. Phase 7's
-- classifier derived `diet_flags` independently, from the structured
-- ingredient rows migration 014 created. Comparing the two is free once
-- both exist, and it disagreed on one row:
--
--     Fırın Tarçınlı Elma
--       2 orta boy elma
--       1 tatlı kaşığı tarçın
--       10 g bal          ← honey
--       15 g çiğ ceviz
--       1 tutam muskat
--
-- Hand-tagged `Vegan`. Honey is an animal product, so it is not. The tag
-- has been shipping to users who filter on it since Phase 24.
--
-- WHY THE TAG MOVES AND THE RECIPE DOES NOT
--
-- Swapping the honey for maple syrup would make the tag true and would
-- also change the recipe, its macros and the author's intent. That is a
-- content decision. Removing a claim the ingredients do not support is a
-- correction, and it is the one that can be made from here.
--
-- The recipe keeps `vegetarian`, `gluten_free` and `dairy_free`, which
-- the classifier derived and which are all true. It stays in the
-- catalogue, keeps `low_calorie`, and simply stops appearing under a
-- filter it never qualified for.
--
-- Matched on the honey rather than on the id alone, so re-running after
-- someone fixes the recipe correctly is a no-op instead of an undo.

update public.recipes r
set tag_tokens = array_remove(tag_tokens, 'vegan'),
    tags       = array_remove(tags, 'Vegan')
where r.title = 'Fırın Tarçınlı Elma'
  and r.tag_tokens @> ARRAY['vegan']
  and exists (
    select 1 from public.recipe_ingredients i
    where i.recipe_id = r.id and i.name_tr = 'bal'
  );
