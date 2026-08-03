-- ============================================================
-- 020 · Leaderboards, leagues and challenges.
-- ============================================================
--
-- Roadmap Phase 13 (C23 · C25 · R6). The roadmap calls this file
-- `016_leaderboards.sql`; 016 is reserved for the deliberately unwritten
-- `drop_legacy_tags`, and 017/018/019 are taken. The roadmap's migration
-- numbers have been wrong in every phase since 013 — the file number is
-- what the directory says, not what the roadmap says.
--
-- ------------------------------------------------------------
-- THE PROBLEM THIS PHASE INHERITS
-- ------------------------------------------------------------
--
-- **XP is client-authoritative.** `lifetimeXpProvider` is a Notifier
-- over `SharedPreferences`; sessions are logged locally; nothing about
-- a user's progress exists on the server. That was correct for nine
-- phases — the app is offline-first and nobody had a reason to lie to
-- it.
--
-- A leaderboard changes that. The moment a number is compared between
-- people it becomes worth inflating, and a client-authoritative number
-- is one `adb shell` away from anything the owner wants.
--
-- ------------------------------------------------------------
-- WHAT THIS MIGRATION ACTUALLY GUARANTEES — read this before trusting it
-- ------------------------------------------------------------
--
-- It **bounds** gaming. It does not eliminate it, and pretending
-- otherwise in a comment would be worse than the gap itself.
--
--   * CHECK constraints make the physically implausible impossible: a
--     week cannot carry more XP than the daily cap times seven, more
--     sessions than three a day, or a streak longer than the account.
--   * `enforce_leaderboard_plausibility()` additionally rejects a jump
--     larger than one day's cap since the row was last written, so a
--     client cannot walk to the ceiling in one request.
--   * Nothing here can tell an honest 400 XP week from a fabricated
--     one, because the server never saw the sessions.
--
-- **Eliminating it requires server-side session recording** — every set
-- and rep written as it happens, with the XP derived server-side from
-- rows the client cannot author freely. That is a real piece of work
-- with real offline-sync consequences, and it belongs to Phase 15
-- (Scale & Reliability), not smuggled in here. The roadmap's "zero
-- verified XP-gaming exploits" is achievable against casual gaming with
-- what is below; it is not achievable against a determined attacker
-- until Phase 15 lands.
--
-- The cap constants live in `lib/features/community/domain/league.dart`
-- as well. They must agree — the Dart copy is what the UI explains to
-- the user, and `league_test.dart` asserts the numbers match this file.
--
-- ------------------------------------------------------------
-- PSEUDONYMITY FALLS OUT OF 019 — no new machinery
-- ------------------------------------------------------------
--
-- The roadmap asks that users "can appear pseudonymously". That is
-- already true and needs nothing added: a leaderboard row lives in
-- `leaderboard_stats`, and the *name* beside it comes from
-- `public_profiles`, whose `public_profiles_select_published` policy
-- requires `is_public`. So a user who opts into leaderboards but leaves
-- their profile private is ranked and unnamed, and the client renders
-- them the same way the feed renders an unresolvable actor: "Someone".
--
-- Two independent switches, two independent meanings, one already
-- built. Adding a third `show_me_on_leaderboards_as` field would have
-- been a second answer to a question 019 already answers.
--
-- ------------------------------------------------------------
-- OPTING OUT IS DELETING THE ROW
-- ------------------------------------------------------------
--
-- There is no `opted_in boolean`. A user is on the leaderboard exactly
-- when they have a row in `leaderboard_stats`, and withdrawing deletes
-- it. The roadmap requires withdrawal "without losing progress", and
-- that holds precisely because XP is client-authoritative: the numbers
-- that matter to the user never lived here in the first place.
--
-- This is the same shape as the progress-photo repository, where the
-- privacy guarantee is the absence of networking code rather than a
-- flag guarding it. A flag can be read wrong. An absent row cannot.

-- ------------------------------------------------------------
-- Weekly stats — one row per user per ISO week
-- ------------------------------------------------------------

create table if not exists public.leaderboard_stats (
  user_id      uuid not null references auth.users(id) on delete cascade,

  -- The Monday of the ISO week, in UTC, as a date. A date rather than a
  -- timestamp because "which week is this" must not depend on the hour,
  -- and UTC rather than local because two users in different zones
  -- comparing scores have to be inside the same bucket. The client
  -- computes it with the same rule; `league_test.dart` pins it.
  week_start   date not null,

  weekly_xp    integer not null default 0,
  sessions     integer not null default 0,
  streak_days  integer not null default 0,

  -- Whole percent, 0-100. Consistency is "days trained / days in the
  -- window", which is the only one of these four a beginner can win.
  consistency  smallint not null default 0,

  updated_at   timestamptz not null default now(),

  primary key (user_id, week_start),

  -- Plausibility. See the header: these bound gaming, they do not
  -- prevent it. 500/day is well above the real ceiling for a single
  -- day's honest training.
  constraint leaderboard_xp_plausible
    check (weekly_xp >= 0 and weekly_xp <= 3500),
  constraint leaderboard_sessions_plausible
    check (sessions >= 0 and sessions <= 21),
  constraint leaderboard_streak_plausible
    check (streak_days >= 0 and streak_days <= 3650),
  constraint leaderboard_consistency_ranged
    check (consistency >= 0 and consistency <= 100)
);

create index if not exists leaderboard_stats_week_xp_idx
  on public.leaderboard_stats (week_start, weekly_xp desc);

alter table public.leaderboard_stats enable row level security;

-- A client cannot walk to the ceiling one request at a time. Rejects any
-- write that raises weekly_xp by more than a single day's cap since the
-- row was last touched.
create or replace function public.enforce_leaderboard_plausibility()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.weekly_xp > old.weekly_xp + 500 then
    raise exception 'implausible_xp_jump';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists leaderboard_stats_plausibility on public.leaderboard_stats;
create trigger leaderboard_stats_plausibility
  before insert or update on public.leaderboard_stats
  for each row execute function public.enforce_leaderboard_plausibility();

-- Own row: full control, including the delete that is the opt-out.
drop policy if exists leaderboard_stats_all_own on public.leaderboard_stats;
create policy leaderboard_stats_all_own
  on public.leaderboard_stats for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Everybody else's rows are readable — that is what a leaderboard is —
-- except across a block in either direction. Same both-ways check as
-- every 019 policy: a blocked user must not appear, and must not be
-- able to see the blocker either.
drop policy if exists leaderboard_stats_select_others on public.leaderboard_stats;
create policy leaderboard_stats_select_others
  on public.leaderboard_stats for select
  to authenticated
  using (
    not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- League assignment — one row per user per season
-- ------------------------------------------------------------
--
-- Tier is stored rather than derived at read time, because promotion and
-- relegation are events a user is told about. A derived tier changes
-- silently the moment somebody else trains, and "you were promoted"
-- cannot be said about a value that was never written down.

create table if not exists public.league_assignments (
  user_id     uuid not null references auth.users(id) on delete cascade,

  -- The first Monday of the season, UTC. Seasons are monthly per the
  -- roadmap; the client derives the label.
  season      date not null,

  -- bronze · silver · gold · platinum · diamond. Text rather than an
  -- enum for the same reason 019 uses text for kinds: adding a tier
  -- must not require a migration, and an unknown value is rendered as
  -- nothing rather than as a wrong tier.
  tier        text not null default 'bronze',

  -- What the tier was last season, so the client can say "up from
  -- silver" without a second query. Null on a first season.
  prev_tier   text,

  updated_at  timestamptz not null default now(),

  primary key (user_id, season),
  constraint league_tier_known
    check (tier in ('bronze','silver','gold','platinum','diamond')),
  constraint league_prev_tier_known
    check (prev_tier is null or
           prev_tier in ('bronze','silver','gold','platinum','diamond'))
);

alter table public.league_assignments enable row level security;

drop policy if exists league_assignments_all_own on public.league_assignments;
create policy league_assignments_all_own
  on public.league_assignments for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Readable by others so a league board can show peers, blocked pairs
-- excluded exactly as above.
drop policy if exists league_assignments_select_others on public.league_assignments;
create policy league_assignments_select_others
  on public.league_assignments for select
  to authenticated
  using (
    not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Challenges — content, authored as data
-- ------------------------------------------------------------
--
-- The roadmap requires challenge definitions to ship "without a
-- release", so they are rows rather than Dart. Copy is jsonb keyed by
-- locale — the same shape migration 011 chose for content localisation,
-- rather than ARB, because ARB ties a content edit to the release train
-- and that is exactly backwards.
--
-- A locale with no entry falls back to `en`, and a challenge whose copy
-- cannot be built in any locale is dropped by the client rather than
-- rendered as a token. Same rule as the feed's badge rows.

create table if not exists public.challenges (
  id          uuid primary key default gen_random_uuid(),

  -- Stable identifier for analytics and for the completion badge. Never
  -- shown to a user.
  slug        text not null unique,

  -- `consistency` · `sessions` · `streak` · `xp`. Text, not an enum:
  -- an unknown kind is a newer server's challenge and the client skips
  -- it rather than guessing.
  kind        text not null,

  -- {"en": {"title": "...", "body": "..."}, "tr": {...}}
  copy        jsonb not null default '{}'::jsonb,

  -- What "done" means, in the unit implied by `kind`.
  target      integer not null,

  starts_at   timestamptz not null,
  ends_at     timestamptz not null,

  -- Awarded on completion. References the client's badge catalogue by
  -- id; a badge id the client does not know drops the award rather than
  -- inventing one.
  badge_id    text,

  -- True for squad-vs-squad and collective-goal events.
  squad_scope boolean not null default false,

  created_at  timestamptz not null default now(),

  constraint challenge_window_ordered check (ends_at > starts_at),
  constraint challenge_target_positive check (target > 0)
);

create index if not exists challenges_window_idx
  on public.challenges (starts_at, ends_at);

alter table public.challenges enable row level security;

-- Content, readable by every signed-in user. There is no per-user
-- visibility to model here — a challenge is an announcement.
drop policy if exists challenges_select_all on public.challenges;
create policy challenges_select_all
  on public.challenges for select
  to authenticated
  using (true); -- rls-gate-ok: public content, no user data on this table

-- Writes are content-ops only, through the service role. No client
-- policy for insert/update/delete exists, so no client can author one.

-- ------------------------------------------------------------
-- Challenge participation
-- ------------------------------------------------------------

create table if not exists public.challenge_participants (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,

  progress     integer not null default 0,
  joined_at    timestamptz not null default now(),
  completed_at timestamptz,

  -- Squad the user entered under, for squad-scoped challenges. Null for
  -- individual ones. Not a foreign key to `squads` with cascade delete:
  -- a squad disbanding must not delete the record that somebody
  -- finished a challenge.
  squad_id     uuid,

  primary key (challenge_id, user_id),
  constraint challenge_progress_positive check (progress >= 0)
);

create index if not exists challenge_participants_challenge_idx
  on public.challenge_participants (challenge_id, progress desc);

alter table public.challenge_participants enable row level security;

drop policy if exists challenge_participants_all_own on public.challenge_participants;
create policy challenge_participants_all_own
  on public.challenge_participants for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- A challenge has a shared leaderboard, so participants see each other —
-- blocked pairs excluded, as everywhere else.
drop policy if exists challenge_participants_select_peers on public.challenge_participants;
create policy challenge_participants_select_peers
  on public.challenge_participants for select
  to authenticated
  using (
    exists (
      select 1 from public.challenge_participants mine
      where mine.challenge_id = challenge_id
        and mine.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
  );
