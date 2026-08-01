-- Roadmap Phase 7 · six recipes whose calories do not equal their macros.
--
-- WHAT WAS FOUND
--
-- The pipeline validates every proposed recipe against the Atwater
-- factors — 4 kcal per gram of protein and carbohydrate, 9 per gram of
-- fat, which is how a nutrition label is computed — and rejects anything
-- more than 10 % off. Running the same check over the catalogue that was
-- already there found six rows outside it:
--
--   Tencerede Tavuk Sote              515 stated · 435 from macros · 16 %
--   Hızlı Mercimek Köftesi            405 stated · 459 from macros · 13 %
--   Elma Dilimleri ve Fıstık Ezmesi   240 stated · 268 from macros · 12 %
--   Ev Yapımı Patates Cipsi           220 stated · 246 from macros · 12 %
--   Tavuklu Bulgur Salatası           440 stated · 392 from macros · 11 %
--   Süzme Peynirli Avokado            280 stated · 310 from macros · 11 %
--
-- These are not rounding. A user tracking calories against the daily
-- budget is being told 515 for a plate that is 435.
--
-- WHY THE MACROS ARE TREATED AS AUTHORITATIVE
--
-- One of the two numbers is wrong and the source does not say which. The
-- macros are the more specific claim — four numbers, each checkable
-- against the ingredient list (170 g of chicken breast really is about
-- 40 g of protein) — while `calories` is a one-number summary of exactly
-- those four. Deriving the summary from the parts is what the field
-- means.
--
-- It is also the rule the pipeline already enforces on every new recipe.
-- Applying a different one to the older half would leave the catalogue
-- with two standards and no way to tell which a given row followed.
--
-- The macro rings the app draws are unchanged by this. Only the calorie
-- figure moves, and it moves to the number those rings already implied.
--
-- Rounded to the nearest 5, matching how the authored rows are written.

update public.recipes
set calories = round((protein * 4 + carbs * 4 + fat * 9) / 5.0) * 5
where calories > 0
  and abs((protein * 4 + carbs * 4 + fat * 9) - calories)::numeric / calories
      > 0.10;
