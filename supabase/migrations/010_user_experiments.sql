-- 010 · user_experiments table.
--
-- Roadmap Phase 4 (C36 · P3). Server-side record of experiment
-- assignment, backing `lib/core/services/experiments.dart`.
--
-- WHY THIS TABLE EXISTS AT ALL
--
-- Assignment is a pure function of (experiment_id, user_id) — the
-- client computes it with sha256 and never asks anyone. So this table
-- is NOT the source of truth, and the client does not read it to decide
-- anything. It exists so that:
--
--   1. Analysis can join behaviour to bucket without depending on an
--      analytics event having been delivered. Client events are lossy;
--      a row is not.
--   2. A bucket can be pinned for a specific user (support escalation,
--      a QA account) by writing the row a human wants.
--   3. The assignment date is recorded, which is what makes it possible
--      to exclude users who joined an experiment mid-flight.
--
-- Because the client derives the same value independently, a missing
-- row costs nothing — which keeps this table optional in exactly the
-- way the flags table is.

create table if not exists public.user_experiments (
  user_id        uuid        not null references auth.users(id) on delete cascade,
  experiment_id  text        not null,
  bucket         text        not null,
  assigned_at    timestamptz not null default now(),
  primary key (user_id, experiment_id)
);

create index if not exists user_experiments_experiment_idx
  on public.user_experiments (experiment_id);

alter table public.user_experiments enable row level security;

-- A user may read and write only their own assignment. Reading someone
-- else's bucket is not sensitive in itself, but user-scoped RLS is this
-- project's default and there is no reason to make an exception.
drop policy if exists "user_experiments_select_own" on public.user_experiments;
create policy "user_experiments_select_own"
  on public.user_experiments
  for select
  using (auth.uid() = user_id);

drop policy if exists "user_experiments_insert_own" on public.user_experiments;
create policy "user_experiments_insert_own"
  on public.user_experiments
  for insert
  with check (auth.uid() = user_id);

-- Deliberately NO update policy.
--
-- Re-bucketing a user mid-experiment silently invalidates their data:
-- their behaviour before the switch belongs to one variant and after it
-- to another, and nothing downstream can tell. Making it impossible
-- through the API is cheaper than detecting it later. A deliberate
-- re-assignment is a service-role operation, which is the right amount
-- of friction for something that corrupts an experiment.
