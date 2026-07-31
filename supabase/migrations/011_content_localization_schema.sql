-- 011 · content localisation schema.
--
-- Roadmap Phase 5 (C11 · C12). SCHEMA ONLY — no content lands here.
-- Translated exercise and recipe copy arrives in Phase 7.
--
-- WHY SCHEMA NOW AND CONTENT LATER
--
-- Phase 5 extracts UI strings into ARB. Content strings — exercise
-- names, descriptions, form cues, recipe titles — are a different
-- problem: they live in the database, there are thousands of them, and
-- they change without an app release. Putting them in ARB would tie
-- content edits to the release train, which is exactly backwards.
--
-- So the columns are added now, while the schema is being thought
-- about, and left null. Every read falls back to the existing
-- single-language column until Phase 7 fills them, which means applying
-- this migration changes nothing a user sees — the same property
-- migration 009 was written to have.
--
-- NAMING
--   `<column>_<lang>` rather than a separate translations table. A join
--   table is the textbook answer and the wrong one here: the catalogue
--   is read on every workout screen, the language count will stay small
--   (tr, en, es, fr, de), and a nullable column per language keeps those
--   reads single-table. Revisit if the language count passes ~10.

-- ─── exercises ──────────────────────────────────────────────────────

alter table if exists public.exercises
  add column if not exists name_en          text,
  add column if not exists name_es          text,
  add column if not exists name_fr          text,
  add column if not exists name_de          text,
  add column if not exists description_en   text,
  add column if not exists description_es   text,
  add column if not exists description_fr   text,
  add column if not exists description_de   text,
  add column if not exists short_tip_en     text,
  add column if not exists short_tip_es     text,
  add column if not exists short_tip_fr     text,
  add column if not exists short_tip_de     text;

-- ─── recipes ────────────────────────────────────────────────────────

alter table if exists public.recipes
  add column if not exists title_en         text,
  add column if not exists title_es         text,
  add column if not exists title_fr         text,
  add column if not exists title_de         text,
  add column if not exists instructions_en  text,
  add column if not exists instructions_es  text,
  add column if not exists instructions_fr  text,
  add column if not exists instructions_de  text;

-- ─── translation coverage view ──────────────────────────────────────
--
-- Answers "what is left to translate" without anyone writing the query
-- again. Phase 7 works this list down; a non-zero row here is a user
-- somewhere reading Turkish inside an English app.
--
-- `security_invoker = on` (PG 15+; production runs 17.6) so the view
-- reads with the CALLER's permissions and the underlying RLS still
-- applies. A view left on the default runs as its owner and quietly
-- becomes an RLS bypass — harmless for these two publicly-readable
-- catalogues today, wrong as a habit, and flagged by Supabase's linter
-- as `security_definer_view`.
--
-- Recipes are included alongside exercises: this migration adds locale
-- columns to BOTH, and a coverage view that reports on half of what it
-- localises would read as "done" while a whole table is untranslated.

create or replace view public.content_translation_coverage
with (security_invoker = on) as
select
  'exercises'                                          as table_name,
  'en'                                                 as locale,
  count(*)                                             as total_rows,
  count(*) filter (where name_en is not null)          as translated_rows
from public.exercises
union all
select
  'exercises', 'es', count(*), count(*) filter (where name_es is not null)
from public.exercises
union all
select
  'exercises', 'fr', count(*), count(*) filter (where name_fr is not null)
from public.exercises
union all
select
  'exercises', 'de', count(*), count(*) filter (where name_de is not null)
from public.exercises
union all
select
  'recipes', 'en', count(*), count(*) filter (where title_en is not null)
from public.recipes
union all
select
  'recipes', 'es', count(*), count(*) filter (where title_es is not null)
from public.recipes
union all
select
  'recipes', 'fr', count(*), count(*) filter (where title_fr is not null)
from public.recipes
union all
select
  'recipes', 'de', count(*), count(*) filter (where title_de is not null)
from public.recipes;

comment on view public.content_translation_coverage is
  'Roadmap Phase 5 · per-locale content translation progress. '
  'Populated by Phase 7.';
