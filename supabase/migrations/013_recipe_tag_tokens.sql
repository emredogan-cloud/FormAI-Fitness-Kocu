-- FormAI — split the recipe tag into a stable token and a localised label
--
-- Roadmap Phase 7 · `PHASE_07_NUTRITION_I18N_PLAN.md` §2.1, §4.1.
--
-- THE PROBLEM THIS SOLVES
--
-- `recipes.tags` is a Turkish `text[]` that is a query key and display
-- copy at the same time. The repository filters with
-- `tags @> ARRAY['Pratik & Ekonomik']` and the same string is painted on
-- the category chip. So the tag cannot be translated — translating it
-- breaks the filter — and cannot stay as it is, because leaving it shows
-- Turkish inside an English app.
--
-- The fix is to stop asking one column to do two jobs. `tag_tokens`
-- carries the identity and is never translated; `recipe_tags` carries
-- the label, once per locale.
--
-- WHERE THE LABEL IS ACTUALLY RENDERED FROM
--
-- The app renders tag labels from ARB, not from this table, and that is
-- deliberate. `docs/i18n/README.md` draws the line at data identity: a
-- token is identity and belongs in the database, a label is copy and
-- belongs in ARB where the coverage gate, the pseudo-locale sweep and
-- the offline-first guarantee all already apply. A chip that renders
-- only after a network round-trip is a worse chip.
--
-- The label columns here are not dead weight. They are the server-side
-- record the translation audit (`tool/recipe_translation_audit.dart`)
-- checks, what the recipe pipeline writes when it proposes a new token,
-- and what any non-Flutter consumer reads. If the closed set of six ever
-- opens, the schema is already right.
--
-- WHY `tags` IS NOT DROPPED HERE
--
-- Dropping it in this migration would break every installed client the
-- moment it applies — the shipped app still filters on `tags`. It gets
-- dropped in `016_drop_legacy_tags.sql`, one release after the client
-- that reads `tag_tokens` is live. Until then both columns are correct
-- and this migration is a no-op for existing clients.

-- ─── the token registry ─────────────────────────────────────────────

create table if not exists public.recipe_tags (
  token       text primary key,
  sort_order  int  not null default 100,
  label_tr    text not null,
  label_en    text,
  label_es    text,
  label_fr    text,
  label_de    text,
  created_at  timestamptz not null default now()
);

comment on table public.recipe_tags is
  'Roadmap Phase 7 · closed set of recipe category tokens. `token` is '
  'data identity and is never translated; the label columns are the '
  'server-side record of the copy the app ships in ARB.';

-- Six tokens. The six singleton values in the legacy `tags` column
-- (Omega 3, Sağlıklı Yağ, Fitness, Dengeli, Kahvaltı, Düşük
-- Karbonhidrat) are data-entry noise on two rows and deliberately get no
-- token: a category one recipe uses is not a category, it is a typo with
-- a filter attached.
--
-- `sort_order` follows catalogue size, so the chip row leads with the
-- bucket most likely to have something in it.
insert into public.recipe_tags (token, sort_order, label_tr, label_en) values
  ('budget_friendly', 10, 'Pratik & Ekonomik', 'Quick & affordable'),
  ('high_protein',    20, 'Yüksek Protein',    'High protein'),
  ('low_calorie',     30, 'Düşük Kalori',      'Low calorie'),
  ('bulking',         40, 'Hacim',             'Bulking'),
  ('toning',          50, 'Sıkılaşma',         'Toning'),
  ('vegan',           60, 'Vegan',             'Vegan')
on conflict (token) do update set
  sort_order = excluded.sort_order,
  label_tr   = excluded.label_tr,
  label_en   = excluded.label_en;

alter table public.recipe_tags enable row level security;

drop policy if exists "recipe_tags_public_read" on public.recipe_tags;
create policy "recipe_tags_public_read"
  on public.recipe_tags for select
  to anon, authenticated
  using (true);

-- Mutation is admin-only, matching `public.recipes` in
-- `supabase/sql/rls_policies.sql`. service_role bypasses RLS, so the
-- pipeline's seed scripts keep working without a JWT.
drop policy if exists "recipe_tags_admin_write" on public.recipe_tags;
create policy "recipe_tags_admin_write"
  on public.recipe_tags for all
  to authenticated
  using      (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin')
  with check (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin');

-- ─── the token column ───────────────────────────────────────────────

alter table public.recipes
  add column if not exists tag_tokens text[] not null default '{}';

comment on column public.recipes.tag_tokens is
  'Roadmap Phase 7 · stable category identities, joined to '
  'public.recipe_tags. Replaces the Turkish `tags` column, which is kept '
  'until migration 016 so shipped clients keep working.';

-- GIN, because every read of this column is a containment test
-- (`tag_tokens @> ARRAY['high_protein']`) and btree cannot serve one.
create index if not exists recipes_tag_tokens_gin
  on public.recipes using gin (tag_tokens);

-- ─── backfill ───────────────────────────────────────────────────────
--
-- Idempotent: recomputed from `tags` every time, so re-running after a
-- content edit is the supported way to resync rather than a hazard.

update public.recipes set tag_tokens = (
  select coalesce(array_agg(distinct t order by t), '{}')
  from unnest(tags) as raw
  cross join lateral (
    select case raw
      when 'Pratik & Ekonomik' then 'budget_friendly'
      when 'Yüksek Protein'    then 'high_protein'
      when 'Düşük Kalori'      then 'low_calorie'
      when 'Hacim'             then 'bulking'
      when 'Sıkılaşma'         then 'toning'
      when 'Vegan'             then 'vegan'
      else null
    end
  ) as m(t)
  where t is not null
);

-- One row in the live catalogue (`Izgara Somon & Tatlı Patates`) carries
-- nothing but singletons and would land here with no token at all — an
-- untagged recipe is invisible to every chip and every category screen.
--
-- Rather than hand-code that row's id, derive from macros using the
-- exact thresholds `recipeTags()` in `recipe_tags.dart` already applies
-- when `tags` is empty. The rule was already in the product; this
-- materialises it instead of inventing a second one that can disagree.
update public.recipes set tag_tokens = (
  select coalesce(array_agg(distinct t order by t), '{}') from (
    select 'high_protein' as t where protein  >= 25
    union all
    select 'low_calorie'       where calories <= 400
    union all
    select 'bulking'           where calories >= 500
  ) as derived
)
where cardinality(tag_tokens) = 0;

-- ─── meal_type = 'main' ─────────────────────────────────────────────
--
-- Four legacy seed rows carry `meal_type = 'main'`, which is not one of
-- the five tokens the app knows. `fetchRecipesByCategory` filters with
-- `meal_type = $token`, so those four recipes are unreachable from every
-- category screen and have been since they were seeded — they only ever
-- surfaced through the unfiltered discovery strip.
--
-- All four are salmon or chicken plates in the 520–600 kcal band. They
-- are dinners. Fixed here rather than left for a later migration because
-- a recipe the user cannot navigate to is a live bug, not a taxonomy
-- preference, and the tag work is already touching this table's
-- classification.
update public.recipes set meal_type = 'dinner' where meal_type = 'main';
