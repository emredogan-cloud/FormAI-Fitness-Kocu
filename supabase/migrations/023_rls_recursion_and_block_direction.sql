-- ============================================================
-- 023 · The first LIVE RLS pass, and the two defects it found
--       that no amount of reading the SQL had found.
-- ============================================================
--
-- The roadmap has asked for a live RLS penetration pass since Phase 12
-- and it had never been run — every check on these policies until now
-- read the text. This is what happened the first time real requests
-- were made against production with a real user's JWT.
--
-- ------------------------------------------------------------
-- DEFECT 1 · Five tables answered 500, not a row
-- ------------------------------------------------------------
--
--   GET /rest/v1/challenge_participants   500  42P17
--   GET /rest/v1/squad_members            500  42P17
--   GET /rest/v1/squads                   500  42P17
--   GET /rest/v1/activity_events          500  42P17
--   GET /rest/v1/activity_reactions       500  42P17
--
--   infinite recursion detected in policy for relation "squad_members"
--   infinite recursion detected in policy for relation
--     "challenge_participants"
--
-- **A policy that queries its own table recurses.** Postgres applies row
-- security to the tables a policy expression references — including the
-- table the policy is attached to — so evaluating the policy re-enters
-- the policy. Two policies did exactly that:
--
--   squad_members_select_member          selects from squad_members
--   challenge_participants_select_peers  selects from challenge_participants
--
-- The other three tables were collateral: `squads`, `activity_events`
-- and `activity_reactions` each reference `squad_members` in their own
-- policies, so they inherited its recursion and died with it.
--
-- **This is why joining a challenge did nothing.** The button was never
-- the problem and neither was the client: `joinChallenge` sent a
-- correct upsert, Postgres answered 500, and the whole squad and feed
-- half of community had been answering 500 since `019` was applied on
-- 2026-08-03. Phase 12's device walk predates `019`, so it saw the
-- honest "not switched on yet" state; Phase 13's walk never opened
-- squads or the feed. Nothing was hiding the outage — nobody had asked.
--
-- 022 is not implicated and did not cause this. Its subject was a
-- different defect in the same two policies (`m.squad_id = squad_id`
-- resolving to `m.squad_id = m.squad_id`), and that fix was correct.
-- The self-reference was there from the day each policy was written and
-- survived 022 untouched, because qualifying a column name does not
-- change which table the subquery reads.
--
-- ------------------------------------------------------------
-- DEFECT 2 · Blocking a user did nothing to their view of you
-- ------------------------------------------------------------
--
-- Verified against production with two real accounts:
--
--   A publishes a public profile          B sees it        (correct)
--   A blocks B                            201
--   B reads A's profile again             B STILL SEES IT  (wrong)
--
-- Same cause, one layer along. `blocks` has RLS of its own, and
-- `blocks_select_own` deliberately shows a block row only to the
-- blocker. A policy expression is evaluated **as the querying user**, so
-- when B's read runs
--
--   not exists (select 1 from public.blocks b
--               where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
--                  or (b.blocker_id = user_id and b.blocked_id = auth.uid()))
--
-- the row that would match the second clause is invisible to B. The
-- `not exists` is therefore true, and the block has no effect on the
-- blocked user at all.
--
-- The blocker's half worked, which is what made this survive review: A
-- can read A's own block row, so A stopped seeing B correctly. Only the
-- direction that matters for safety was broken — you block someone so
-- that *they* lose sight of *you*.
--
-- Every policy carrying the both-ways comment had it: 019's
-- `public_profiles_select_published` and `friendships_insert_party`,
-- 020's `leaderboard_stats_select_others` and
-- `league_assignments_select_others`, and 022's
-- `activity_events_select_member` and
-- `challenge_participants_select_peers`. The comments are not wrong
-- about the intent — `019` states the requirement as "fully severs
-- visibility both ways" — they are wrong that the SQL below them
-- achieved it.
--
-- ------------------------------------------------------------
-- THE FIX, and why it is a schema rather than three policies
-- ------------------------------------------------------------
--
-- Both defects are the same sentence: *a policy cannot read a table
-- whose RLS is part of the question it is trying to answer.* The
-- standard answer is a `security definer` function, which runs as its
-- owner and therefore reads the table without row security — breaking
-- the recursion in defect 1 and seeing both block rows in defect 2.
--
-- **They live in a `private` schema, not `public`.** PostgREST exposes
-- functions in the schemas it is configured to serve, and `public` is
-- one of them. `public.is_blocked_with(uuid)` would be a REST endpoint
-- any signed-in user could call for any id — an enumerable "did this
-- person block me?" oracle, which is precisely what `blocks_select_own`
-- refuses to be. `private` is not an exposed schema, so the functions
-- are reachable from a policy and from nowhere else.
--
-- `is_blocked_with` takes one argument and answers only about the
-- CALLER, never about a pair of strangers. That is the difference
-- between restoring the guarantee and publishing the block list.
--
-- What this does not claim: a working block is always inferable from
-- absence, and no policy can prevent that. The property `019` wanted —
-- the blocked user cannot *discover* the block — is weaker after this
-- migration than the comment implies, and was worth less before it,
-- because the block did not work. The alternative, widening
-- `blocks_select_own` to both parties, hands over an enumerable list
-- and is strictly worse.

-- ------------------------------------------------------------
-- The helpers
-- ------------------------------------------------------------

create schema if not exists private;

-- No `grant usage ... to public`: only the roles that evaluate policies.
grant usage on schema private to anon, authenticated;

-- Is the caller a member of this squad?
create or replace function private.is_squad_member(p_squad uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.squad_members
    where squad_id = p_squad
      and user_id = auth.uid()
  );
$$;

-- Has the caller joined this challenge?
create or replace function private.is_challenge_participant(p_challenge uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge
      and user_id = auth.uid()
  );
$$;

-- Is there a block between the caller and p_other, in either direction?
--
-- One argument, and it is not the pair — the caller is always one side.
-- Asking about two other people is not a question this answers.
create or replace function private.is_blocked_with(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = p_other)
       or (blocker_id = p_other  and blocked_id = auth.uid())
  );
$$;

grant execute on function private.is_squad_member(uuid) to anon, authenticated;
grant execute on function private.is_challenge_participant(uuid)
  to anon, authenticated;
grant execute on function private.is_blocked_with(uuid) to anon, authenticated;

-- ------------------------------------------------------------
-- Defect 1 · the two self-referencing policies
-- ------------------------------------------------------------
--
-- Only these two are rewritten. `squads`, `activity_events` and
-- `activity_reactions` reference `squad_members` from a DIFFERENT
-- table, which is not recursion — they failed only because the policy
-- they reached was itself recursive, and they recover untouched.

drop policy if exists squad_members_select_member on public.squad_members;

create policy squad_members_select_member
  on public.squad_members for select
  using (private.is_squad_member(squad_members.squad_id));

-- ------------------------------------------------------------
-- Defect 2 · every policy that claims to exclude blocked pairs
-- ------------------------------------------------------------

drop policy if exists public_profiles_select_published on public.public_profiles;

create policy public_profiles_select_published
  on public.public_profiles for select
  using (
    is_public
    and moderation_state = 'approved'
    and not private.is_blocked_with(public_profiles.user_id)
  );

-- The caller is one of the two parties (the clause above requires it),
-- and a block between somebody and themselves cannot exist — `blocks`
-- has a `blocker_id <> blocked_id` check — so testing both names is
-- exactly "is the caller blocked with the other one".
drop policy if exists friendships_insert_party on public.friendships;

create policy friendships_insert_party
  on public.friendships for insert
  with check (
    auth.uid() = requester_id
    and (auth.uid() = user_a or auth.uid() = user_b)
    and not private.is_blocked_with(friendships.user_a)
    and not private.is_blocked_with(friendships.user_b)
  );

drop policy if exists leaderboard_stats_select_others on public.leaderboard_stats;

create policy leaderboard_stats_select_others
  on public.leaderboard_stats for select
  to authenticated
  using (not private.is_blocked_with(leaderboard_stats.user_id));

drop policy if exists league_assignments_select_others on public.league_assignments;

create policy league_assignments_select_others
  on public.league_assignments for select
  to authenticated
  using (not private.is_blocked_with(league_assignments.user_id));

drop policy if exists activity_events_select_member on public.activity_events;

create policy activity_events_select_member
  on public.activity_events for select
  using (
    private.is_squad_member(activity_events.squad_id)
    and not private.is_blocked_with(activity_events.actor_id)
  );

-- Both defects at once: this is the policy that broke Join.
drop policy if exists challenge_participants_select_peers
  on public.challenge_participants;

create policy challenge_participants_select_peers
  on public.challenge_participants for select
  to authenticated
  using (
    private.is_challenge_participant(challenge_participants.challenge_id)
    and not private.is_blocked_with(challenge_participants.user_id)
  );
