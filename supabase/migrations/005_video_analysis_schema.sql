-- FormAI · Roadmap B Phase 0 — video form-analysis schema.
--
-- Backs the "record/upload a 30-45s exercise video → AI analyses form →
-- explains mistakes → scores technique → shows correction" feature. The
-- MVP runs inference ON-DEVICE (batch BlazePose, see roadmap §Faz 1/Faz 4),
-- so the Flutter client writes its own analysis rows; a future cloud worker
-- can write the same tables through the service_role bypass without schema
-- change. RLS keeps every row owned by its uploader.
--
-- Three tables:
--   user_video_submissions  — one row per uploaded/recorded clip
--   form_analysis_results   — one row per completed analysis of a submission
--   frame_findings          — per-frame fault rows feeding the timeline UI
--
-- ROLLBACK:
--   drop table if exists public.frame_findings cascade;
--   drop table if exists public.form_analysis_results cascade;
--   drop table if exists public.user_video_submissions cascade;
--   delete from storage.buckets where id = 'user_videos';

create extension if not exists "pgcrypto";

-- Reuse the project-wide updated_at trigger helper (declared in 001/002).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- user_video_submissions
-- ---------------------------------------------------------------------------
create table if not exists public.user_video_submissions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  -- Catalogue slug of the exercise the user declared (squat / push_up /
  -- plank for the MVP). Auto-classification (roadmap Faz 3) may later
  -- overwrite this with a detected slug + confidence.
  exercise_slug   text not null,
  -- Object path inside the private `user_videos` storage bucket:
  -- `${user_id}/${id}.mp4`. RLS on storage.objects (below) enforces that a
  -- user can only read/write under their own `${user_id}/` prefix.
  storage_path    text not null,
  duration_seconds numeric(5,2),
  -- pending → processing → completed | failed
  status          text not null default 'pending'
                  check (status in ('pending','processing','completed','failed')),
  error_detail    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists user_video_submissions_user_idx
  on public.user_video_submissions (user_id, created_at desc);

drop trigger if exists user_video_submissions_set_updated_at
  on public.user_video_submissions;
create trigger user_video_submissions_set_updated_at
  before update on public.user_video_submissions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- form_analysis_results
-- ---------------------------------------------------------------------------
create table if not exists public.form_analysis_results (
  id              uuid primary key default gen_random_uuid(),
  submission_id   uuid not null references public.user_video_submissions (id)
                  on delete cascade,
  -- Denormalised owner column so RLS is a single auth.uid() = user_id check
  -- without a join back to the submission.
  user_id         uuid not null references auth.users (id) on delete cascade,
  exercise_slug   text not null,
  -- 0-100 heuristic technique score (see FormScore in
  -- lib/features/video_analysis/domain/form_score.dart). Heuristic, NOT a
  -- validated accuracy metric — calibration against labelled video is
  -- tracked as DEFERRED (requires real footage).
  form_score      smallint check (form_score between 0 and 100),
  rep_count       smallint,
  -- Short Turkish summary line shown on the history card.
  summary         text,
  -- Engine + model provenance for audit ("rule-v1", later "tflite-vN").
  engine_version  text not null default 'rule-v1',
  analysed_at     timestamptz not null default now(),
  created_at      timestamptz not null default now()
);

create index if not exists form_analysis_results_user_idx
  on public.form_analysis_results (user_id, analysed_at desc);
create index if not exists form_analysis_results_submission_idx
  on public.form_analysis_results (submission_id);

-- ---------------------------------------------------------------------------
-- frame_findings
-- ---------------------------------------------------------------------------
create table if not exists public.frame_findings (
  id              uuid primary key default gen_random_uuid(),
  result_id       uuid not null references public.form_analysis_results (id)
                  on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  frame_index     integer not null,
  timestamp_ms    integer not null,
  -- Joint the fault is anchored to (e.g. 'leftKnee') + a machine code the
  -- UI maps to a localised explanation, plus the raw measured angle.
  joint           text,
  issue_code      text not null,
  severity        text not null default 'info'
                  check (severity in ('info','warn','critical')),
  measured_angle  numeric(5,1),
  message         text,
  created_at      timestamptz not null default now()
);

create index if not exists frame_findings_result_idx
  on public.frame_findings (result_id, frame_index);

-- ---------------------------------------------------------------------------
-- RLS — every row owned by its uploader; no cross-user visibility.
-- The on-device MVP writes its own rows, so unlike pro_entitlements we DO
-- grant insert/select/delete to the owner. A cloud worker (service_role)
-- bypasses RLS entirely and is unaffected by these policies.
-- ---------------------------------------------------------------------------
alter table public.user_video_submissions enable row level security;
alter table public.form_analysis_results  enable row level security;
alter table public.frame_findings         enable row level security;

drop policy if exists "uvs_owner_all" on public.user_video_submissions;
create policy "uvs_owner_all" on public.user_video_submissions
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "far_owner_all" on public.form_analysis_results;
create policy "far_owner_all" on public.form_analysis_results
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "ff_owner_all" on public.frame_findings;
create policy "ff_owner_all" on public.frame_findings
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Storage — private bucket for the raw clips. Files live under
-- `${auth.uid()}/...`; the policies scope every operation to the user's own
-- top-level folder (the first path segment).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('user_videos', 'user_videos', false)
on conflict (id) do nothing;

drop policy if exists "user_videos_owner_rw" on storage.objects;
create policy "user_videos_owner_rw" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'user_videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'user_videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
