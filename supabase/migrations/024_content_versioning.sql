-- ============================================================
-- 024 · Content freshness — release notes and content drops
-- ============================================================
--
-- Roadmap Phase 14 (C5, C6, R5, P5, C40, C50). The roadmap calls this
-- `017_content_versioning.sql`; 017 is Phase 9's body metrics, so this
-- is 024. The numbering has diverged from the roadmap since 013 and the
-- resume guide carries the mapping.
--
-- Phase 14's whole premise is that "a 30-day program has a 30-day
-- lifespan". Two of the four answers to that are content rather than
-- code, and content that needs an app release is content that arrives
-- monthly at best. So both tables here are authored by content ops
-- through the service role and read by every client, exactly like
-- `challenges` in `020`.
--
-- WHY THE COPY IS jsonb AND NOT ARB
--
-- The same argument `020` made and `011` made before it: ARB ties a copy
-- edit to the release train, and the point of this phase is shipping
-- content without one. The cost is that the server can be newer than the
-- client, which the client handles by dropping what it cannot render
-- honestly rather than guessing — a missing title drops the row rather
-- than showing a slug.
--
-- ------------------------------------------------------------
-- content_releases — the What's New document
-- ------------------------------------------------------------
--
-- WHY THIS IS KEYED TO A BUILD NUMBER AND NOT A DATE
--
-- A release note is the one piece of content that is NOT free to arrive
-- early. "Here is what's new in 1.1.0" shown to somebody still running
-- 1.0.0 is a description of an app they do not have — and Play rolls a
-- release out over days, so on the day of a release both populations
-- exist at once. The client asks for the newest release whose
-- `build_number` is at or below its own, which makes the staged rollout
-- correct by construction rather than by content ops remembering.
--
-- It also means a note can be authored and published BEFORE the build
-- reaches anybody, which is the workflow content ops actually wants.
--
-- WHY "SEEN" IS NOT A COLUMN HERE
--
-- There is no `content_release_views` table and no `user_id` anywhere in
-- this file. Whether you have read the release notes is answered by
-- `SharedPreferences` on the device, which:
--
--   * keeps this table free of user data, so RLS has nothing to protect
--     and the static gate can prove it (no `user_id`, no `auth.users`);
--   * works offline, which matters because the natural moment to show
--     What's New is first launch after an update, which is exactly when
--     a phone may still be on the store's network and not the user's;
--   * costs a re-read on a new device, which is the correct trade — the
--     failure mode is seeing a changelog twice.
--
-- The same call Phase 10 made about progress photos and Phase 13 made
-- about leaderboard opt-out: the guarantee is that the data is not on
-- the server, not that a flag protects it.

create table if not exists public.content_releases (
  id uuid primary key default gen_random_uuid(),

  -- Marketing version, e.g. '1.1.0'. Unique so a re-publish updates the
  -- note rather than producing two for one release.
  version text not null unique,

  -- The build this note describes. A client shows the newest release at
  -- or below its own build. Unique for the same reason as `version`.
  build_number integer not null unique,

  -- {"en": {"headline": "...", "items": [{"title": "...", "body": "..."}]}}
  --
  -- The roadmap caps What's New at three items, "never a wall of release
  -- notes". That is a UX rule about what a person will read, so the
  -- client takes the first three and this column does not constrain it —
  -- a check constraint here would reject a correct document written for
  -- a locale the constraint did not think to look at.
  copy jsonb not null default '{}'::jsonb,

  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  constraint content_release_build_positive check (build_number > 0)
);

create index if not exists content_releases_build_idx
  on public.content_releases (build_number desc);

alter table public.content_releases enable row level security;

-- Content. Readable by every signed-in user, authored through the
-- service role. No insert/update/delete policy exists, so no client can
-- write one — the same shape as `challenges`.
drop policy if exists content_releases_select_all on public.content_releases;
create policy content_releases_select_all
  on public.content_releases for select
  to authenticated
  using (true); -- rls-gate-ok: published content, no user data on this table

-- ------------------------------------------------------------
-- content_drops — "Yenilikler", and who each drop is for
-- ------------------------------------------------------------
--
-- A drop is an announcement that new content landed: a recipe batch, a
-- workout plan, a challenge, a seasonal program. It is separate from
-- `content_releases` because the two answer different questions —
-- "what changed in the app you just updated" versus "what is new in the
-- app you have been using" — and because a drop needs targeting and a
-- release note does not.
--
-- WHY TARGETING IS COLUMNS AND NOT A RULES ENGINE
--
-- The roadmap asks for "targeting rules (difficulty, goal, equipment)"
-- and per-locale availability. Four array columns and one tri-state
-- boolean cover every drop this product can currently author, and they
-- are readable by a person writing SQL at midnight. A rules engine would
-- be a second query language nobody can debug from the Supabase editor,
-- for a generality no content brief has asked for.
--
-- **Null means everyone, and empty means everyone too.** Both are
-- written out in the client's predicate rather than normalised away,
-- because `target_goals = '{}'` is what a form submits when nobody
-- picked anything, and a drop that silently reaches nobody is the worst
-- failure this table can have.

create table if not exists public.content_drops (
  id uuid primary key default gen_random_uuid(),

  -- Stable identity for analytics and for the client's "already seen"
  -- bookkeeping. Never shown to a user.
  slug text not null unique,

  -- 'recipes' · 'workout_plan' · 'challenge' · 'seasonal'. Text rather
  -- than an enum for the reason `challenges.kind` is: an unknown kind is
  -- a newer server's drop, and the client skips it rather than guessing
  -- which screen it belongs to.
  kind text not null,

  -- {"en": {"title": "...", "body": "..."}, "tr": {...}}
  copy jsonb not null default '{}'::jsonb,

  -- Where tapping it goes, as an in-app route. Null renders the card
  -- without a tap target rather than sending somebody nowhere.
  route text,

  published_at timestamptz not null default now(),

  -- When it stops being new. Null means it never expires, which is right
  -- for a permanent addition like a recipe batch and wrong for a
  -- seasonal program — so seasonal content sets it and the rest does not.
  expires_at timestamptz,

  -- Targeting. Null or empty = everyone.
  target_goals   text[],
  target_levels  text[],
  target_locales text[],

  -- Tri-state on purpose. Null = irrelevant to this drop. True = only
  -- users who told onboarding they have equipment. False = only users
  -- who did not, which is how a bodyweight-only program reaches the
  -- people who need it instead of the people who already have a rack.
  requires_equipment boolean,

  created_at timestamptz not null default now(),

  constraint content_drop_window_ordered
    check (expires_at is null or expires_at > published_at)
);

create index if not exists content_drops_published_idx
  on public.content_drops (published_at desc);

alter table public.content_drops enable row level security;

drop policy if exists content_drops_select_all on public.content_drops;
create policy content_drops_select_all
  on public.content_drops for select
  to authenticated
  using (true); -- rls-gate-ok: published content, no user data on this table
