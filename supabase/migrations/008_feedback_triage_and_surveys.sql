-- 008 · feedback triage columns + survey_responses table.
--
-- Roadmap Phase 1 (C31 · C8 · R4 · P4).
--
-- Two jobs:
--
--   1. **Feedback triage.** `FeedbackService` (Phase 56 Lite) has been
--      writing to `public.feedback` since before the migration history
--      was formalised, so the table is created defensively here with
--      `if not exists` and then extended. Without a status field the
--      table is a write-only bucket — messages land and nobody is
--      obligated to read them. The Testers Community report treats a
--      feedback mechanism as a loop, not an inbox; these columns are
--      what close it.
--
--   2. **Survey responses.** Backs `SurveyService`
--      (lib/features/feedback/services/survey_service.dart), which the
--      Production Access Questionnaire describes as an operating
--      practice ("feedback collected through surveys and direct
--      communication").
--
-- SECURITY: both tables are user-scoped with RLS. A user may INSERT
-- their own rows and SELECT their own rows; nobody may read anyone
-- else's. Triage columns are deliberately NOT writable by the owner —
-- only the service role (admin tooling) may update them, so a user
-- cannot mark their own ticket resolved.
--
-- `user_id` uses ON DELETE CASCADE so `delete_user()` (migration 006)
-- continues to remove everything a user has ever submitted. Migration
-- 006's comment already names `feedback` as a cascading table; this
-- migration is what makes that true for `survey_responses` too.
--
-- NOTE · must be applied to the production project before release —
-- the client already writes to both tables.

-- ─── 1 · feedback ───────────────────────────────────────────────────

-- This block is a TRANSCRIPTION of the table as it already exists in
-- production, not a fresh design. `feedback` was created ad hoc before
-- the migration history was formalised, so on the production database
-- this `create` is skipped entirely and only the `alter`s below run.
--
-- It therefore has exactly one job: make a database built from scratch
-- (local `db reset`, CI, a future environment) end up with the SAME
-- table production has. A `create if not exists` that describes a
-- different shape is worse than no create at all — it produces a schema
-- that silently depends on whether the table happened to pre-exist.
--
-- Verified against production 2026-07-31: bigserial pk (NOT uuid), and
-- both check constraints below.
create table if not exists public.feedback (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  subject     text not null,
  message     text not null,
  app_version text,
  platform    text,
  os_version  text,
  created_at  timestamptz not null default now(),
  -- The client offers exactly these three categories.
  constraint feedback_subject_check
    check (subject in ('bug', 'suggestion', 'question')),
  -- Long enough to be actionable, short enough not to be an upload.
  constraint feedback_message_check
    check (length(message) >= 4 and length(message) <= 4000)
);

-- Triage columns. Added separately from the create so an existing
-- production `feedback` table (created ad hoc) is upgraded in place
-- rather than skipped by `if not exists`.
alter table public.feedback
  add column if not exists status text not null default 'new',
  add column if not exists tags text[] not null default '{}',
  add column if not exists internal_note text,
  add column if not exists responded_at timestamptz;

-- Terminal + intermediate states. Constrained so a typo in admin
-- tooling can't create a silent fourth state that nothing reports on.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'feedback_status_check'
  ) then
    alter table public.feedback
      add constraint feedback_status_check
      check (status in ('new', 'triaged', 'responded', 'closed'));
  end if;
end
$$;

-- The triage view is "oldest un-actioned first", so index that.
create index if not exists feedback_status_created_idx
  on public.feedback (status, created_at);

alter table public.feedback enable row level security;

-- Production already carries an INSERT policy under the older name
-- `feedback_insert_self`, with a check identical to the one below. Left
-- alone, this migration would add a second permissive INSERT policy
-- saying the same thing — two rules to keep in sync forever, for no
-- gain. Dropping the legacy name and creating the canonical one is
-- behaviour-preserving (same predicate, same role) and leaves exactly
-- one policy per verb.
drop policy if exists "feedback_insert_self" on public.feedback;
drop policy if exists "feedback_self_insert" on public.feedback;
create policy "feedback_self_insert"
  on public.feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "feedback_self_read" on public.feedback;
create policy "feedback_self_read"
  on public.feedback
  for select
  to authenticated
  using (auth.uid() = user_id);

-- ─── 2 · survey_responses ───────────────────────────────────────────

create table if not exists public.survey_responses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  survey_id    text not null,
  score        smallint,
  option_token text,
  app_version  text,
  platform     text,
  created_at   timestamptz not null default now(),
  -- One response per survey per user. The client also guards this
  -- locally via AppPreferences.answeredSurveyIds, but a reinstall
  -- clears local state and we do not want a second NPS row skewing
  -- the average.
  unique (user_id, survey_id),
  -- NPS is 0-10; choice surveys carry a token instead. Exactly one of
  -- the two must be present.
  constraint survey_responses_score_range
    check (score is null or (score >= 0 and score <= 10)),
  constraint survey_responses_answer_present
    check (score is not null or option_token is not null)
);

create index if not exists survey_responses_survey_idx
  on public.survey_responses (survey_id, created_at);

alter table public.survey_responses enable row level security;

drop policy if exists "survey_responses_self_insert" on public.survey_responses;
create policy "survey_responses_self_insert"
  on public.survey_responses
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "survey_responses_self_read" on public.survey_responses;
create policy "survey_responses_self_read"
  on public.survey_responses
  for select
  to authenticated
  using (auth.uid() = user_id);
