-- 009 · feature_flags table.
--
-- Roadmap Phase 4 (C7). The remote half of
-- `lib/core/services/feature_flags.dart`.
--
-- The client is built so this table is an OPTIONAL improvement on its
-- compiled-in defaults, never a dependency: every flag has a hardcoded
-- value, the last good payload is cached to disk, and a failed fetch is
-- logged at info level and ignored. Nothing here can break the app, and
-- that is deliberate — a remote-config layer that can brick a client has
-- made reliability worse.
--
-- SECURITY MODEL
--   * Readable by anyone (including anon): flag values are not secrets,
--     and gating reads behind auth would mean a signed-out user gets
--     different behaviour from a signed-in one on the same build, which
--     is a debugging nightmare and a real source of "works for me".
--   * Writable by nobody through the API. Flips happen via the Supabase
--     dashboard or a service-role key. There is no policy granting
--     INSERT/UPDATE/DELETE, so RLS denies them by default.
--
-- OPERATIONAL NOTE
--   A key that no client version knows about is ignored client-side, so
--   it is safe to add a row before the release that reads it. Likewise,
--   deleting a row does not break older clients — they fall back to
--   their compiled default.

create table if not exists public.feature_flags (
  key          text primary key,
  enabled      boolean     not null default false,
  description  text,
  updated_at   timestamptz not null default now()
);

alter table public.feature_flags enable row level security;

-- Read-only for everyone. Idempotent so the migration can be re-run.
drop policy if exists "feature_flags_read_all" on public.feature_flags;
create policy "feature_flags_read_all"
  on public.feature_flags
  for select
  to anon, authenticated
  using (true);

-- Keep `updated_at` honest — it is the only way to tell, from the
-- dashboard, when a flag was last touched.
-- `search_path` is pinned empty: the body resolves nothing by name, so
-- there is nothing to look up, and an unpinned search_path on a function
-- that fires on write is a standing invitation to schema-shadowing
-- (Supabase's own linter flags it as `function_search_path_mutable`).
create or replace function public.touch_feature_flags_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists feature_flags_touch_updated_at on public.feature_flags;
create trigger feature_flags_touch_updated_at
  before update on public.feature_flags
  for each row
  execute function public.touch_feature_flags_updated_at();

-- Seed the current catalogue with values that MATCH the client's
-- compiled defaults.
--
-- Seeding with matching values is the point: applying this migration
-- must be a no-op for behaviour. A migration that silently changes what
-- users see the moment it runs is indistinguishable from an outage.
insert into public.feature_flags (key, enabled, description) values
  ('progressive_disclosure', true,
   'Staged capability unlocks. Off = every capability available immediately.'),
  ('discovery_hub', true,
   'The "Keşfet" capability map entry points.'),
  ('contextual_tips', true,
   'Dashboard contextual tips (C28).'),
  ('unlock_celebrations', true,
   'Coach-delivered unlock moments. Off mutes them without changing unlocks.'),
  ('in_session_tutorial', true,
   'First-workout coach-mark layer over the camera controls.'),
  ('practice_rep', true,
   'Guided practice rep inside the camera setup tutorial.'),
  ('rating_prompts', true,
   'Contextual in-app rating moments.'),
  ('survey_prompts', true,
   'In-app micro-surveys and NPS.'),
  ('camera_free_mode', true,
   'The camera-free workout path (C21).'),
  ('onboarding_length_experiment', false,
   'Onboarding-length A/B. Off until the experiment is deliberately started.')
on conflict (key) do nothing;
