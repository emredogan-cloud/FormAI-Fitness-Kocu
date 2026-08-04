-- Phase 14 · content-ops templates for `024_content_versioning.sql`.
--
-- Paste-and-edit, like `seed_challenge_example.sql`. The full procedure,
-- including the two traps, is BÖLÜM II of `docs/CONTENT_OPS.md`.
--
-- Run as the service role. There is no client write policy on either
-- table, which is what stops a user authoring a release note.

-- ------------------------------------------------------------
-- 1 · A release note — the What's New screen
-- ------------------------------------------------------------
--
-- `build_number` is the build this note DESCRIBES. A client shows the
-- newest note at or below its own build, so publishing before the build
-- reaches anybody is safe and is the intended workflow. Publishing a
-- note for a build that is still rolling out is also safe: users still
-- on the old one do not see it.
--
-- Three items maximum. A fourth is silently dropped by the client.
-- `en` is effectively required — a note with no usable locale is skipped.

insert into public.content_releases (version, build_number, copy)
values (
  '1.0.0',
  36,
  jsonb_build_object(
    'en', jsonb_build_object(
      'headline', 'FormAI just got better',
      'items', jsonb_build_array(
        jsonb_build_object(
          'title', 'Community',
          'body',  'Friends, squads and a shared activity feed.'),
        jsonb_build_object(
          'title', 'Leaderboards',
          'body',  'Opt in from Community. Consistency counts, not just volume.'),
        jsonb_build_object(
          'title', 'Challenges',
          'body',  'Time-boxed goals you can join in one tap.')
      )
    ),
    'tr', jsonb_build_object(
      'headline', 'FormAI biraz daha iyi oldu',
      'items', jsonb_build_array(
        jsonb_build_object(
          'title', 'Topluluk',
          'body',  'Arkadaşlar, takımlar ve ortak bir aktivite akışı.'),
        jsonb_build_object(
          'title', 'Liderlik tabloları',
          'body',  'Topluluk sekmesinden aç. Sadece hacim değil, tutarlılık sayılır.'),
        jsonb_build_object(
          'title', 'Meydan okumalar',
          'body',  'Tek dokunuşla katılabileceğin süreli hedefler.')
      )
    )
  )
)
on conflict (version) do update set
  build_number = excluded.build_number,
  copy         = excluded.copy;

-- ------------------------------------------------------------
-- 2 · A content drop — the "Yenilikler" card
-- ------------------------------------------------------------
--
-- Targeting: null or empty = everybody. An empty array is what a form
-- submits when nothing was picked, and a drop reaching nobody is the
-- worst failure this table has, so both spellings mean the same thing.
--
-- `expires_at` only for seasonal content. A permanent addition never
-- expires; Ramadan, New Year and summer do.
--
-- Uncomment and edit. Left commented because a drop announcing content
-- that has not landed is worse than no drop.

-- insert into public.content_drops
--   (slug, kind, copy, route, published_at, expires_at,
--    target_goals, target_levels, target_locales, requires_equipment)
-- values (
--   'august-recipes',
--   'recipes',                       -- recipes|workout_plan|challenge|seasonal
--   jsonb_build_object(
--     'en', jsonb_build_object('title', '20 new recipes',
--                              'body',  'Summer cooking.'),
--     'tr', jsonb_build_object('title', '20 yeni tarif',
--                              'body',  'Yaz mutfağı.')
--   ),
--   '/nutrition/discover',
--   now(),
--   null,
--   null, null, null, null
-- )
-- on conflict (slug) do update set
--   copy = excluded.copy, route = excluded.route,
--   published_at = excluded.published_at, expires_at = excluded.expires_at;

-- ------------------------------------------------------------
-- 3 · Post-publish check — 60 seconds, every time
-- ------------------------------------------------------------
--
-- select version, build_number, copy->'tr'->>'headline' as tr,
--        copy->'en'->>'headline' as en
--   from public.content_releases order by build_number desc;
--
-- select slug, kind, published_at, expires_at,
--        copy->'tr'->>'title' as tr, copy->'en'->>'title' as en
--   from public.content_drops order by published_at desc;
--
-- A null in either language column is a row the client will drop.
