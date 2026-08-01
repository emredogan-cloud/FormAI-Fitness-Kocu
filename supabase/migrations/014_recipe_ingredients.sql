-- FormAI — ingredients become data instead of prose
--
-- Roadmap Phase 7 · `PHASE_07_NUTRITION_I18N_PLAN.md` §2.2, §4.2.
--
-- THE PROBLEM THIS SOLVES
--
-- `recipes.instructions` is one text column shaped
--
--     MALZEMELER:
--     - 3 yumurta
--     - 50g sucuk dilimleri
--
--     HAZIRLANIŞI:
--     1. Sucuk dilimlerini orta ateşte tavada 1 dakika kavurun.
--
-- 291 of the 292 live rows follow it, and three surfaces
-- (`recipe_detail_screen`, `favorites_screen`, `share_service`) each
-- re-parse that blob with their own hand-rolled splitter.
--
-- An ingredient list is structured data pretending to be prose.
-- Translating the blob whole is possible and wrong:
--
--   * Quantities and units must survive translation byte-exact. A model
--     asked to translate "50g sucuk" is a model that can return "2 oz
--     sucuk", and the app has `unit_system.dart` for conversion — doing
--     it in the translation makes it un-round-trippable.
--   * "50g sucuk" needs a substitution note in markets that do not sell
--     sucuk. There is nowhere to attach one to a paragraph.
--   * A shopping list cannot be built by parsing a sentence, and the
--     share sheet and the favourites export are already trying to.
--
-- Splitting it is mechanical, one-time, and only gets more expensive as
-- the catalogue grows.
--
-- WHY `instructions` IS NOT TRIMMED HERE
--
-- The plan says `instructions` keeps only the HAZIRLANIŞI: half after
-- this lands. It does not happen in this migration, for exactly the
-- reason 013 did not drop `tags`: every shipped client still splits the
-- blob on `MALZEMELER:` to render the ingredient block. Removing it the
-- moment this applies would leave every installed app showing a recipe
-- with no ingredients — the most visible regression available.
--
-- The trim moves to `016`, beside the legacy-tag drop, which is already
-- scheduled for one release after the client that reads the new shape is
-- live. Until then both representations are correct and this migration
-- is a no-op for existing clients.

create table if not exists public.recipe_ingredients (
  recipe_id  uuid    not null references public.recipes(id) on delete cascade,
  position   int     not null,

  -- Null for "Tuz" and "Pul biber, tuz, karabiber" — lines that are real
  -- ingredients with no countable amount. Null is the honest answer; a
  -- guessed 1 would show up in a shopping list as a fact nobody stated.
  quantity   numeric,

  -- Null when the quantity is a bare count ("3 yumurta"). Turkish
  -- kitchen units stay Turkish here: this is the authored value, and
  -- `unit_system.dart` is what presents it.
  unit       text,

  name_tr    text not null,
  name_en    text,
  name_es    text,
  name_fr    text,
  name_de    text,

  -- Prep state and substitutions. Two things share this column:
  --
  --   * the parenthetical the parser lifts off the line — "(kuru ölçü)",
  --     "(ince doğranmış)" — which is per row and genuinely differs
  --     between recipes using the same ingredient;
  --   * the substitution gloss a proper noun needs abroad, e.g. sucuk →
  --     "Turkish beef sausage; chorizo or any cured spiced sausage
  --     works."
  --
  -- The second repeats across rows sharing an ingredient. A glossary
  -- table would normalise it and is not worth a join at 1.6k rows; the
  -- translation tool writes it once per distinct name and fans it out.
  note_tr    text,
  note_en    text,

  primary key (recipe_id, position)
);

comment on table public.recipe_ingredients is
  'Roadmap Phase 7 · the MALZEMELER: block, parsed. Quantities and units '
  'are never translated; names and notes are. Ordered by `position`, '
  'which is the line order of the original authored list.';

-- Every read is "the ingredients of this recipe, in order", which the
-- primary key's leading column already serves. No second index.

alter table public.recipe_ingredients enable row level security;

drop policy if exists "recipe_ingredients_public_read"
  on public.recipe_ingredients;
create policy "recipe_ingredients_public_read"
  on public.recipe_ingredients for select
  to anon, authenticated
  using (true);

-- Admin-only mutation, matching `public.recipes` in
-- `supabase/sql/rls_policies.sql`. service_role bypasses RLS, so the
-- seed script this migration is paired with keeps working without a JWT.
drop policy if exists "recipe_ingredients_admin_write"
  on public.recipe_ingredients;
create policy "recipe_ingredients_admin_write"
  on public.recipe_ingredients for all
  to authenticated
  using      (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

-- ─── coverage ───────────────────────────────────────────────────────
--
-- The same question `content_translation_coverage` answers for titles:
-- what is left. A recipe with zero rows here is one the parser could not
-- read, and it will render its ingredients from the legacy blob until
-- someone looks at it.

create or replace view public.recipe_ingredient_coverage
with (security_invoker = on) as
select
  count(*)                                            as total_recipes,
  count(*) filter (where i.n > 0)                     as parsed_recipes,
  coalesce(sum(i.n), 0)                               as total_ingredients,
  coalesce(sum(i.named_en), 0)                        as translated_en
from public.recipes r
left join lateral (
  select count(*)                                       as n,
         count(*) filter (where name_en is not null)    as named_en
  from public.recipe_ingredients ri
  where ri.recipe_id = r.id
) as i on true;

comment on view public.recipe_ingredient_coverage is
  'Roadmap Phase 7 · how much of the catalogue has structured, and '
  'translated, ingredients. A parsed_recipes below total_recipes is a '
  'recipe still rendering from the legacy instructions blob.';
