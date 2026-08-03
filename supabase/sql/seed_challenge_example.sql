-- Roadmap Phase 13 (C25) · how content ops starts a challenge.
--
-- NOT a migration and deliberately not in `supabase/migrations/`. The
-- whole point of authoring challenges as data is that starting one does
-- not need a release *or* a schema change — so this is a template to run
-- from the SQL editor, not something that gets applied on deploy.
--
-- WHICH CHALLENGE TO RUN IS NOT AN ENGINEERING DECISION.
--
-- `challenges` is empty in production and the app renders "No challenges
-- are running right now", which is honest and correct. Filling it means
-- choosing what to ask users to do and when, and that is a founder /
-- content call. This file exists so making that call costs one paste
-- rather than a conversation about jsonb.
--
-- ------------------------------------------------------------
-- The fields, and what the client does with each
-- ------------------------------------------------------------
--
--   slug        stable id. Used for analytics and never shown.
--   kind        consistency | sessions | streak | xp. A kind the client
--               does not recognise makes it SKIP the challenge — that
--               is intentional, so a newer server never renders a rule
--               an older build cannot track.
--   target      what "done" means, in the unit `kind` implies.
--   copy        {"en": {...}} at minimum. A challenge with no usable
--               locale is dropped rather than shown as its slug, so
--               **`en` is effectively required**.
--   badge_id    must exist in the client's badge catalogue
--               (`kBadgeCatalog`). An unknown id drops the award rather
--               than inventing one. Leave null for no badge.
--   squad_scope true for squad-vs-squad or collective goals.
--
-- Timestamps are timestamptz. Give them a zone; a naive literal is read
-- as the database's, which is not what an author in Istanbul means.

insert into public.challenges
  (slug, kind, target, starts_at, ends_at, copy, badge_id, squad_scope)
values
  (
    'august_consistency_2026',
    'sessions',
    12,
    '2026-08-01T00:00:00+03:00',
    '2026-09-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'August consistency',
        'body',  'Twelve sessions this month. Not the hardest twelve — just twelve.'
      ),
      'tr', jsonb_build_object(
        'title', 'Ağustos istikrarı',
        'body',  'Bu ay on iki antrenman. En zoru değil — sadece on iki.'
      )
    ),
    null,
    false
  )
on conflict (slug) do update
  set copy    = excluded.copy,
      target  = excluded.target,
      ends_at = excluded.ends_at;

-- Ending one early: move `ends_at` into the past rather than deleting
-- the row. `challenge_participants` cascades on delete, so removing a
-- challenge erases the record that people finished it.
--
--   update public.challenges
--      set ends_at = now()
--    where slug = 'august_consistency_2026';
