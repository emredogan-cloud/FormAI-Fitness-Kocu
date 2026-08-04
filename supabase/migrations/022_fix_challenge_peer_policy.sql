-- ============================================================
-- 022 · Fix two over-permissive reads caused by an alias shadowing
--       the row under test.
-- ============================================================
--
-- Found during the Phase 14 production review, by reading the policy
-- rather than by any gate. `020` shipped this:
--
--   using (
--     exists (
--       select 1 from public.challenge_participants mine
--       where mine.challenge_id = challenge_id      -- <-- the bug
--         and mine.user_id = auth.uid()
--     )
--     and not exists ( ... blocks ... )
--   )
--
-- **`challenge_id` is ambiguous, and Postgres resolves it to the
-- innermost scope — `mine`.** So the intended "is the caller in the same
-- challenge as this row" silently became `mine.challenge_id =
-- mine.challenge_id`, which is always true. The predicate degraded to
-- "does the caller participate in *anything*", and anybody who had ever
-- joined one challenge could read every participation row in the table:
-- which users are in which challenges, and how far along they are.
--
-- The blocks half had the same shape and the same defect.
--
-- **And then the gate written for it found two more, both already live
-- in production**, in `019`:
--
--   squad_members_select_member    `m.squad_id = squad_id` — any member
--                                  of any squad could read every
--                                  `squad_members` row: who is in which
--                                  squad, across the whole product.
--
--   activity_events_select_member  the same expression — so **every
--                                  squad's activity feed was readable by
--                                  anybody who belonged to any squad.**
--
--   activity_events_insert_own     the same expression again, this time
--                                  in a `with check` — so a user in one
--                                  squad could **write** an event into
--                                  any other squad's feed. The only
--                                  read-side leaks above are bad; this
--                                  one lets a stranger post.
--
-- Both have been live since the day community shipped. Neither was
-- reachable through the app's own UI, which only ever asks for one
-- squad's feed — but RLS is the boundary precisely because the UI is
-- not, and a crafted PostgREST query is one `curl` away.
--
-- The blocks halves of those policies are correct, and it is worth
-- saying why: `blocks` has no `actor_id` column, so the bare name there
-- can only mean the outer row. The defect needs the aliased table to
-- *have* a column of the same name, which is what the gate now checks.
--
-- WHY NOTHING CAUGHT IT
--
-- The static RLS gate checks that a policy exists, is not `using
-- (true)`, and mentions `auth.uid()`. All three were true here. A
-- predicate that is *always true for a different reason* looks identical
-- to a correct one from the outside — which is the fourth time in this
-- codebase a gate has been green about something it does not measure,
-- and the clearest argument yet for the live penetration pass the
-- roadmap asks for and that has still never been run.
--
-- THE FIX
--
-- Qualify every outer reference with the table name. Inside a policy the
-- row under test is addressed as `<table>.<column>`, and writing it out
-- is the only thing that makes the two scopes distinguishable to a
-- reader as well as to the planner.
--
-- `rls_policy_test.dart` now fails any policy that leaves a `*_id`
-- column unqualified inside a correlated subquery. That check is what
-- found the squad one, three seconds after it was written.

drop policy if exists challenge_participants_select_peers
  on public.challenge_participants;

create policy challenge_participants_select_peers
  on public.challenge_participants for select
  to authenticated
  using (
    exists (
      select 1 from public.challenge_participants mine
      where mine.challenge_id = challenge_participants.challenge_id
        and mine.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid()
             and b.blocked_id = challenge_participants.user_id)
         or (b.blocker_id = challenge_participants.user_id
             and b.blocked_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- The same defect in 019, live since community shipped
-- ------------------------------------------------------------

drop policy if exists squad_members_select_member on public.squad_members;

create policy squad_members_select_member
  on public.squad_members for select
  using (
    exists (
      select 1 from public.squad_members m
      where m.squad_id = squad_members.squad_id
        and m.user_id = auth.uid()
    )
  );

drop policy if exists activity_events_select_member on public.activity_events;

create policy activity_events_select_member
  on public.activity_events for select
  using (
    exists (
      select 1 from public.squad_members m
      where m.squad_id = activity_events.squad_id
        and m.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid()
             and b.blocked_id = activity_events.actor_id)
         or (b.blocker_id = activity_events.actor_id
             and b.blocked_id = auth.uid())
    )
  );

-- A `with check`, so this one is a write hole rather than a read leak: a
-- member of any squad could insert an event into any other squad's feed.
drop policy if exists activity_events_insert_own on public.activity_events;

create policy activity_events_insert_own
  on public.activity_events for insert
  with check (
    auth.uid() = actor_id
    and exists (
      select 1 from public.squad_members m
      where m.squad_id = activity_events.squad_id
        and m.user_id = auth.uid()
    )
  );
