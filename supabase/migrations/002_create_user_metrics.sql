-- SixPack AI — user_metrics table
--
-- Backs the referral system in `lib/features/referral/services/referral_service.dart`,
-- which reads `referral_code` and upserts `{user_id, referral_code}`. The
-- contract was previously sketched out (commented) in `supabase/sql/rls_policies.sql`
-- Section 4 — this migration is the first applied form. We keep the column
-- list narrow (only what the app currently reads/writes) instead of pre-baking
-- the wizard fields, which still live in SharedPreferences on-device until
-- Phase 43's KVKK-portability sync ships.

create extension if not exists "pgcrypto";

create table if not exists public.user_metrics (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null unique references auth.users (id) on delete cascade,
  referral_code   text unique,
  referral_count  integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists user_metrics_referral_code_idx
  on public.user_metrics (referral_code);

-- Reuse the project-wide `set_updated_at` helper if it already exists
-- (declared in 001_initial_schema.sql). Falling back to a local create
-- keeps this migration applicable on databases where the helper hasn't
-- been declared yet.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_metrics_set_updated_at on public.user_metrics;
create trigger user_metrics_set_updated_at
before update on public.user_metrics
for each row execute function public.set_updated_at();

-- Row Level Security: each authenticated user sees and mutates only
-- their own row. Anonymous callers get nothing.
alter table public.user_metrics enable row level security;

drop policy if exists "user_metrics_select_own" on public.user_metrics;
create policy "user_metrics_select_own"
  on public.user_metrics
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_metrics_insert_own" on public.user_metrics;
create policy "user_metrics_insert_own"
  on public.user_metrics
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_metrics_update_own" on public.user_metrics;
create policy "user_metrics_update_own"
  on public.user_metrics
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_metrics_delete_own" on public.user_metrics;
create policy "user_metrics_delete_own"
  on public.user_metrics
  for delete
  to authenticated
  using (auth.uid() = user_id);
