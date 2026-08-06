-- ============================================================
-- 027 · Reporting AI-generated content
-- ============================================================
--
-- Google Play's AI-Generated Content policy, verbatim:
--
--   "Apps that generate content using AI must contain in-app user
--    reporting or flagging features that allow users to report or flag
--    offensive content to developers without needing to exit the app."
--
-- FormAI ships a Claude-backed coach (`supabase/functions/coach-chat`),
-- so this is not optional and it is not satisfied by the generic
-- "Support & feedback" screen: that screen offers Bug report /
-- Suggestion / Question, is not attached to any message, and requires
-- the user to describe by hand which reply they mean. The requirement is
-- an affordance ON the content.
--
-- The production audit of 2026-08-06 recorded its absence as the single
-- remaining code blocker for production submission.
--
-- ------------------------------------------------------------
-- WHY THE MESSAGE TEXT IS STORED
-- ------------------------------------------------------------
--
-- A report with no content is a report nobody can action. The coach's
-- replies are generated per user from their own profile, so they cannot
-- be looked up later from a prompt id — there is no server-side
-- transcript (see the privacy policy §1.2.1, which says so). If the text
-- does not travel with the report, the report is an anonymous complaint
-- about a sentence that no longer exists anywhere.
--
-- It is capped at 4000 characters, which is above `MAX_TOKENS` for a
-- coach reply and therefore never truncates a real one, and the column
-- takes the reply ONLY. The user's own preceding message is deliberately
-- not carried: it is the AI output that is being reported, the user
-- already knows what they asked, and a prompt is the more sensitive half
-- of the pair.
--
-- ------------------------------------------------------------
-- WHY THE REASONS ARE THESE FOUR
-- ------------------------------------------------------------
--
-- `019`'s `user_reports` uses harassment / impersonation /
-- inappropriate_content / spam / other, which are the failure modes of a
-- *person*. A language model in a fitness app fails differently, and
-- `harmful_advice` is the one that matters most here: this app talks to
-- people about training and eating, and a model that tells somebody to
-- train through chest pain is a materially worse event than one that
-- swears. Giving it its own token means triage can sort on it instead of
-- reading every `other`.
--
-- Tokens, never labels — the same rule `019` set. The `check` constraint
-- is read by a human triaging in a language that is not necessarily the
-- reporter's.
--
-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
--
-- Write-only from the client's point of view, exactly like
-- `user_reports`: a reporter may file, and may read back what they
-- filed. Nothing else. Triage runs with the service role, outside RLS.
--
-- Both policies constrain on `auth.uid()` and neither reads any table —
-- so neither can recurse (`023`) and neither touches `public.blocks`
-- (`023` again). Anonymous Supabase sessions have a real `auth.uid()`,
-- so a guest who never signed in can still file a report; that matters,
-- because guest mode is a first-class path in this app and the policy
-- requirement is not conditional on having an account.

create table if not exists public.ai_content_reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references auth.users (id) on delete cascade,

  -- The reported coach reply, verbatim. See the note above on why this
  -- travels with the report rather than being looked up later.
  message_text  text not null check (
                  char_length(message_text) between 1 and 4000),

  reason        text not null check (reason in (
                  'harmful_advice',
                  'offensive',
                  'inaccurate',
                  'other'
                )),

  -- Which surface produced it. There is one today; the onboarding chat
  -- is the obvious second, and a report that cannot say where it came
  -- from is one a triager has to guess about.
  surface       text not null default 'coach_chat' check (
                  surface in ('coach_chat', 'onboarding_chat')),

  -- The locale the reply was generated in. A model failure is often
  -- language-specific and the persona is authored per locale, so this is
  -- the first thing triage wants to group by.
  locale        text check (locale is null or char_length(locale) <= 16),

  created_at    timestamptz not null default now()
);

create index if not exists ai_content_reports_triage_idx
  on public.ai_content_reports (reason, created_at desc);

alter table public.ai_content_reports enable row level security;

drop policy if exists ai_content_reports_insert_own on public.ai_content_reports;
create policy ai_content_reports_insert_own
  on public.ai_content_reports for insert
  with check (auth.uid() = reporter_id);

drop policy if exists ai_content_reports_select_own on public.ai_content_reports;
create policy ai_content_reports_select_own
  on public.ai_content_reports for select
  using (auth.uid() = reporter_id);
