-- FormAI — identity, friends, squads and a squad-scoped activity feed.
--
-- Roadmap Phase 12 (R6, C22, C24, C47) · "give users an identity worth
-- showing and a small group worth showing up for".
--
-- WHY THIS IS 019 AND NOT 015
--
-- The roadmap calls this file `015_social_profiles.sql`. 015 is taken —
-- it is Phase 7's `recipe_origin_and_diet`, applied to production, as
-- are 013 and 014. 016 is RESERVED for the deliberately unwritten
-- `016_drop_legacy_tags.sql`; 017 is Phase 9's body metrics; 018 is
-- Phase 10's progress-photo metadata. Same reasoning as those two
-- headers: the gap is cheaper than the confusion.
--
-- ============================================================
-- THE ONE RULE THIS FILE EXISTS TO ENFORCE
-- ============================================================
--
-- **Nothing is visible to anybody until the owner makes it so.** Not by
-- default, not on sign-up, not as a side effect of completing a workout.
-- The roadmap states it as a UX principle — "a user who never touches
-- community features must see no change in their experience" — and a UX
-- principle enforced only in the client is not enforced at all, because
-- the client is the part an attacker replaces.
--
-- So every policy below is written from the reader's side and starts
-- from "no". `public_profiles` has no row until a user creates one.
-- A row that exists is still invisible unless `is_public` or a
-- relationship says otherwise. Every table is RLS-enabled with no
-- permissive fallback.
--
-- The roadmap calls RLS "the highest-risk area in the roadmap" and asks
-- for adversarial testing. `test/features/community/rls_policy_test.dart`
-- reads THIS FILE and asserts the properties that can be checked
-- statically — every table RLS-enabled, no `using (true)`, no policy
-- without an `auth.uid()` predicate. It cannot execute SQL, and it says
-- so; it is a second pair of eyes on the shape, not a substitute for the
-- live penetration pass recorded in the phase report.
--
-- ============================================================
-- WHY VISIBILITY IS THREE COLUMNS AND NOT ONE ENUM
-- ============================================================
--
-- `is_public`, `show_badges` and `show_stats` are independent booleans
-- because they answer independent questions, and a single
-- `visibility: 'public' | 'friends' | 'private'` enum forces a user who
-- wants their level shown but their session count hidden to choose
-- between two things they do not want. Field-level control is what the
-- roadmap asks for ("granular field-level visibility control") and it is
-- also what makes the resolution testable — see
-- `ProfileVisibility.resolve` in the Dart domain.
--
-- ============================================================
-- APPLYING THIS IS A SEPARATE, DELIBERATE STEP
-- ============================================================
--
-- APPLIED to production 2026-08-03, on founder approval. Community is
-- opt-in and inert until a user creates a profile, so nothing changed
-- for anybody at the moment it landed.
--
-- ORDERING NOTE, learned the hard way. The first application of this
-- file failed with `relation "public.blocks" does not exist` (42P01):
-- `public_profiles_select_published` filters blocked pairs, and `blocks`
-- was declared fifty lines further down — under a header that already
-- read "declared before anything that references them". The intent was
-- right and the file did not match it.
--
-- The static RLS gate could not have caught this. It reads policy SHAPE
-- from the text — RLS enabled, no `using (true)`, `auth.uid()` present,
-- blocks checked both ways — and every one of those was true of a file
-- that could not execute. **A policy's dependencies must be declared
-- above it, and only a real database will tell you they are not.**

-- ------------------------------------------------------------
-- Blocks — declared before anything that references them
-- ------------------------------------------------------------

create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  -- Blocking yourself is not a state anything downstream handles.
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

-- Deliberately readable ONLY by the blocker. The blocked user must not
-- be able to discover that they were blocked — that is the difference
-- between a safety tool and an escalation.
drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own
  on public.blocks for select
  using (auth.uid() = blocker_id);

drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own
  on public.blocks for insert
  with check (auth.uid() = blocker_id);

drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own
  on public.blocks for delete
  using (auth.uid() = blocker_id);

-- ------------------------------------------------------------
-- Profiles
-- ------------------------------------------------------------

create table if not exists public.public_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,

  -- Not unique-by-accident: two people may legitimately be called
  -- "Emre". `handle` below is the unique one, because a handle is an
  -- address and a display name is a name.
  display_name text not null check (char_length(display_name) between 2 and 32),

  -- Lowercase, url-safe, unique. This is what a friend invite link
  -- carries and what a search resolves.
  handle text not null unique
    check (handle ~ '^[a-z0-9_]{3,20}$'),

  -- A Storage object reference, never bytes. Null means the default
  -- avatar set, which is deliberately the common case.
  avatar_ref text,

  -- See the header for why these are three booleans. All default FALSE:
  -- creating a profile is not publishing one.
  is_public boolean not null default false,
  show_badges boolean not null default false,
  show_stats boolean not null default false,

  -- Set by the moderation hook before a display name or avatar becomes
  -- visible to anyone else. A profile pending review is visible to its
  -- owner and to nobody else, which is why every read policy below
  -- checks it.
  moderation_state text not null default 'approved'
    check (moderation_state in ('approved', 'pending', 'rejected')),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists public_profiles_handle_idx
  on public.public_profiles (handle);

alter table public.public_profiles enable row level security;

drop policy if exists public_profiles_select_own on public.public_profiles;
create policy public_profiles_select_own
  on public.public_profiles for select
  using (auth.uid() = user_id);

-- A profile is readable by others only when its owner published it AND
-- moderation cleared it AND neither party has blocked the other.
--
-- The block check is written in BOTH directions on purpose. Blocking is
-- not a mute: the roadmap requires that a block "fully severs visibility
-- both ways", so the blocker disappears from the blocked user's view as
-- well. A one-directional policy would let somebody keep watching a
-- profile that had blocked them.
drop policy if exists public_profiles_select_published on public.public_profiles;
create policy public_profiles_select_published
  on public.public_profiles for select
  using (
    is_public
    and moderation_state = 'approved'
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
  );

drop policy if exists public_profiles_insert_own on public.public_profiles;
create policy public_profiles_insert_own
  on public.public_profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists public_profiles_update_own on public.public_profiles;
create policy public_profiles_update_own
  on public.public_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists public_profiles_delete_own on public.public_profiles;
create policy public_profiles_delete_own
  on public.public_profiles for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Friendships
-- ------------------------------------------------------------
--
-- ONE ROW PER PAIR, not two.
--
-- The obvious schema is two mirrored rows so every query is "where
-- user_id = me". It is also how a friendship ends up half-deleted: two
-- rows are two writes, and the second one can fail. One row with an
-- ordered pair means the relationship is atomic by construction, and the
-- `least`/`greatest` constraint means the same pair cannot be inserted
-- twice in the other order.

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),

  -- Ordered so a pair has exactly one representation. `requester_id` is
  -- who asked, which the ordering does NOT encode — hence the separate
  -- column, because "accept" is only offered to the other party.
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,

  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),

  created_at timestamptz not null default now(),
  responded_at timestamptz,

  check (user_a < user_b),
  unique (user_a, user_b)
);

create index if not exists friendships_user_a_idx
  on public.friendships (user_a, status);
create index if not exists friendships_user_b_idx
  on public.friendships (user_b, status);

alter table public.friendships enable row level security;

drop policy if exists friendships_select_party on public.friendships;
create policy friendships_select_party
  on public.friendships for select
  using (auth.uid() = user_a or auth.uid() = user_b);

-- The requester must be the caller, and must be one of the two parties.
-- Without the second half, anybody could manufacture a friendship
-- between two strangers by naming themselves the requester of neither.
drop policy if exists friendships_insert_party on public.friendships;
create policy friendships_insert_party
  on public.friendships for insert
  with check (
    auth.uid() = requester_id
    and (auth.uid() = user_a or auth.uid() = user_b)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = user_a and b.blocked_id = user_b)
         or (b.blocker_id = user_b and b.blocked_id = user_a)
    )
  );

-- Only the party who did NOT ask may respond. `using` restricts which
-- rows are updatable; `with check` restricts what they may become, and
-- both are needed — without the second, a party could update a row into
-- a shape the first clause would never have selected.
drop policy if exists friendships_update_recipient on public.friendships;
create policy friendships_update_recipient
  on public.friendships for update
  using (
    (auth.uid() = user_a or auth.uid() = user_b)
    and auth.uid() <> requester_id
  )
  with check (auth.uid() = user_a or auth.uid() = user_b);

-- Either party may unfriend.
drop policy if exists friendships_delete_party on public.friendships;
create policy friendships_delete_party
  on public.friendships for delete
  using (auth.uid() = user_a or auth.uid() = user_b);

-- ------------------------------------------------------------
-- Squads
-- ------------------------------------------------------------

create table if not exists public.squads (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 32),
  owner_id uuid not null references auth.users(id) on delete cascade,

  -- What a join link carries. Rotatable without destroying the squad,
  -- which is the whole point of it not being the id.
  invite_code text not null unique
    check (invite_code ~ '^[A-Z0-9]{6,10}$'),

  created_at timestamptz not null default now()
);

alter table public.squads enable row level security;

create table if not exists public.squad_members (
  squad_id uuid not null references public.squads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (squad_id, user_id)
);

create index if not exists squad_members_user_idx
  on public.squad_members (user_id);

alter table public.squad_members enable row level security;

-- A squad is readable by its members and by nobody else. Joining is via
-- an invite code, which the client resolves through the SECURITY DEFINER
-- function below rather than by selecting on `invite_code` — otherwise
-- the select policy would have to expose every squad to every user,
-- which is exactly the leak this table is trying to avoid.
drop policy if exists squads_select_member on public.squads;
create policy squads_select_member
  on public.squads for select
  using (
    exists (
      select 1 from public.squad_members m
      where m.squad_id = id and m.user_id = auth.uid()
    )
  );

drop policy if exists squads_insert_owner on public.squads;
create policy squads_insert_owner
  on public.squads for insert
  with check (auth.uid() = owner_id);

drop policy if exists squads_update_owner on public.squads;
create policy squads_update_owner
  on public.squads for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists squads_delete_owner on public.squads;
create policy squads_delete_owner
  on public.squads for delete
  using (auth.uid() = owner_id);

-- Membership is readable by fellow members: the squad screen has to be
-- able to list who is in it.
drop policy if exists squad_members_select_member on public.squad_members;
create policy squad_members_select_member
  on public.squad_members for select
  using (
    exists (
      select 1 from public.squad_members m
      where m.squad_id = squad_id and m.user_id = auth.uid()
    )
  );

-- A user adds only themselves. Joining is `join_squad()` below, which
-- enforces the size cap inside a single statement; this policy is the
-- floor under it.
drop policy if exists squad_members_insert_self on public.squad_members;
create policy squad_members_insert_self
  on public.squad_members for insert
  with check (auth.uid() = user_id);

-- Leave yourself, or be removed by the owner.
drop policy if exists squad_members_delete_self_or_owner on public.squad_members;
create policy squad_members_delete_self_or_owner
  on public.squad_members for delete
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.squads s
      where s.id = squad_id and s.owner_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- Activity feed
-- ------------------------------------------------------------
--
-- Squad-scoped by construction: an event carries the squad it was
-- written for. A single global feed filtered at read time is one missing
-- predicate away from being a global feed.
--
-- `kind` is a token, never a sentence. The copy lives in ARB, the same
-- rule the recipe tags learned in Phase 7 — a label in a database cannot
-- be translated without breaking the query that reads it.

create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.squads(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,

  kind text not null check (kind in (
    'workout_completed', 'badge_earned', 'level_up', 'streak_milestone'
  )),

  -- The one number the copy needs — a day number, a streak length, a
  -- level. Never a name: names come from `public_profiles` at read time
  -- so a rename is not retroactively wrong.
  value integer,

  -- Stable badge id when `kind = 'badge_earned'`. Same reasoning as
  -- Phase 10's timeline: ids are persisted, labels are not.
  token text,

  created_at timestamptz not null default now()
);

create index if not exists activity_events_squad_created_idx
  on public.activity_events (squad_id, created_at desc);

alter table public.activity_events enable row level security;

drop policy if exists activity_events_select_member on public.activity_events;
create policy activity_events_select_member
  on public.activity_events for select
  using (
    exists (
      select 1 from public.squad_members m
      where m.squad_id = squad_id and m.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = actor_id)
         or (b.blocker_id = actor_id and b.blocked_id = auth.uid())
    )
  );

-- Write only your own events, and only into a squad you are in.
drop policy if exists activity_events_insert_own on public.activity_events;
create policy activity_events_insert_own
  on public.activity_events for insert
  with check (
    auth.uid() = actor_id
    and exists (
      select 1 from public.squad_members m
      where m.squad_id = squad_id and m.user_id = auth.uid()
    )
  );

drop policy if exists activity_events_delete_own on public.activity_events;
create policy activity_events_delete_own
  on public.activity_events for delete
  using (auth.uid() = actor_id);

-- ------------------------------------------------------------
-- Reactions
-- ------------------------------------------------------------
--
-- Reactions only, no free-text comments, and that is a Phase 12
-- decision rather than an omission: the roadmap notes it "delivers most
-- of the social reinforcement with a fraction of the moderation risk".
-- There is no text column here to moderate.

create table if not exists public.activity_reactions (
  event_id uuid not null references public.activity_events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('cheer', 'strong', 'fire')),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.activity_reactions enable row level security;

drop policy if exists activity_reactions_select_member on public.activity_reactions;
create policy activity_reactions_select_member
  on public.activity_reactions for select
  using (
    exists (
      select 1
      from public.activity_events e
      join public.squad_members m on m.squad_id = e.squad_id
      where e.id = event_id and m.user_id = auth.uid()
    )
  );

drop policy if exists activity_reactions_write_own on public.activity_reactions;
create policy activity_reactions_write_own
  on public.activity_reactions for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.activity_events e
      join public.squad_members m on m.squad_id = e.squad_id
      where e.id = event_id and m.user_id = auth.uid()
    )
  );

drop policy if exists activity_reactions_delete_own on public.activity_reactions;
create policy activity_reactions_delete_own
  on public.activity_reactions for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Reports
-- ------------------------------------------------------------

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in (
    'harassment', 'impersonation', 'inappropriate_content', 'spam', 'other'
  )),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

create index if not exists user_reports_reported_idx
  on public.user_reports (reported_id, created_at desc);

alter table public.user_reports enable row level security;

-- Write-only from the client's point of view: a reporter may file and
-- may see their own filings, and nobody can read who reported them.
-- Triage happens with the service role, outside RLS.
drop policy if exists user_reports_insert_own on public.user_reports;
create policy user_reports_insert_own
  on public.user_reports for insert
  with check (auth.uid() = reporter_id);

drop policy if exists user_reports_select_own on public.user_reports;
create policy user_reports_select_own
  on public.user_reports for select
  using (auth.uid() = reporter_id);

-- ------------------------------------------------------------
-- join_squad() — the size cap, enforced where it cannot race
-- ------------------------------------------------------------
--
-- A client that counts members and then inserts has a race: two people
-- joining a squad of 11 both read 11 and both insert. `SECURITY DEFINER`
-- with the count and the insert in one statement closes it, and it is
-- also the only way to resolve an invite code without a select policy
-- that would expose every squad to every user.
--
-- Twelve is the roadmap's cap and it is a product decision, not a
-- technical one: small groups outperform global feeds for accountability.

create or replace function public.join_squad(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_squad_id uuid;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id into v_squad_id
  from public.squads
  where invite_code = upper(p_invite_code);

  if v_squad_id is null then
    raise exception 'invalid invite code';
  end if;

  -- Already in? Idempotent: a tapped link twice is not an error.
  if exists (
    select 1 from public.squad_members
    where squad_id = v_squad_id and user_id = auth.uid()
  ) then
    return v_squad_id;
  end if;

  select count(*) into v_count
  from public.squad_members
  where squad_id = v_squad_id;

  if v_count >= 12 then
    raise exception 'squad is full';
  end if;

  insert into public.squad_members (squad_id, user_id, role)
  values (v_squad_id, auth.uid(), 'member');

  return v_squad_id;
end;
$$;

revoke all on function public.join_squad(text) from public;
grant execute on function public.join_squad(text) to authenticated;

comment on function public.join_squad(text) is
  'Resolves an invite code and joins the caller, enforcing the 12-member '
  'cap in one statement so two simultaneous joins cannot both succeed at '
  '11. SECURITY DEFINER because resolving a code by select would require '
  'exposing every squad row to every user.';

-- ------------------------------------------------------------
-- ACCOUNT DELETION
-- ------------------------------------------------------------
--
-- Every table above cascades from `auth.users`, so `delete_user` removes
-- a departing user's profile, friendships, memberships, events,
-- reactions, blocks and reports without `006_delete_user.sql` changing.
--
-- The one case a cascade does NOT cover is a squad whose OWNER leaves:
-- `squads.owner_id` cascades, so the squad and every member's history go
-- with them. That is deliberate for now — a squad is the owner's room —
-- but it is the first thing to revisit if squads outlive their founders.
-- Recorded here rather than discovered later.

comment on table public.public_profiles is
  'Opt-in public identity. Every visibility flag defaults FALSE: creating '
  'a profile is not publishing one.';
comment on table public.blocks is
  'Readable only by the blocker. The blocked user must not be able to '
  'discover the block.';
comment on table public.friendships is
  'One row per pair, ordered by user_a < user_b, so a friendship cannot '
  'be half-written.';
