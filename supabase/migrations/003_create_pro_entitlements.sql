-- SixPack AI · phase 138 B-5 — pro_entitlements table
--
-- Server-side source of truth for the user's RevenueCat "FormAI Pro"
-- entitlement. The Supabase Edge Function `revenuecat-webhook` writes
-- this table whenever RevenueCat fires a subscription event; the
-- Flutter client uses RC's customerInfo as the primary signal but
-- can cross-check this table when it needs an authoritative answer
-- (e.g. before unlocking a server-protected Pro endpoint).
--
-- Why a dedicated table instead of a column on user_metrics:
--   • Pro state changes on a different schedule than wizard answers
--     (monthly renewals vs. one-time wizard completion).
--   • Pro state is written by the service_role through a webhook;
--     user_metrics is written by the user themselves. Keeping them
--     separate lets RLS stay clean — the user can read their own
--     pro_entitlements row but never write to it.
--   • Subscription audit trail. `last_event_type` + `last_event_id`
--     give support enough context to debug "I subscribed but the app
--     says free" complaints without paging through RC logs.
--
-- ROLLBACK: drop table public.pro_entitlements cascade;

create extension if not exists "pgcrypto";

create table if not exists public.pro_entitlements (
  -- One row per Supabase user. The webhook upserts on this PK so a
  -- renewal updates the same row instead of inserting duplicates.
  user_id          uuid primary key references auth.users (id) on delete cascade,

  -- Current entitlement state. Flipped by the webhook based on the
  -- incoming RC event type:
  --   • INITIAL_PURCHASE / RENEWAL / PRODUCT_CHANGE / UNCANCELLATION
  --     / TRANSFER  → true
  --   • EXPIRATION / SUBSCRIPTION_PAUSED                → false
  --   • CANCELLATION                                    → no change
  --     (the user requested cancel but is still active until
  --     expires_at — Play / App Store both keep delivering content
  --     through the paid-up period).
  is_active        boolean not null default false,

  -- Product the user is currently subscribed to (or last had). Maps
  -- to one of `formai_pro_monthly` / `formai_pro_3month` /
  -- `formai_pro_annual`. Plain text — we don't want an enum migration
  -- every time pricing tiers shift.
  product_id       text,

  -- When the entitlement runs out. Populated from RC's
  -- `expiration_at_ms` field. Client code can use this for "your
  -- subscription expires in N days" surfaces.
  expires_at       timestamptz,

  -- Free-trial window (RC `period_type == 'TRIAL'`). Lets the client
  -- show "trial active" badges without consulting RC directly.
  trial_expires_at timestamptz,

  -- Audit / idempotency. The webhook stores the most recent event
  -- type + id so we can replay-protect: if RC retries the same event
  -- (network blip on their side), `last_event_id` matches and we
  -- skip the upsert.
  last_event_type  text,
  last_event_id    text,
  last_event_at    timestamptz,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists pro_entitlements_active_idx
  on public.pro_entitlements (is_active) where is_active = true;

-- Reuse the project-wide `set_updated_at` trigger helper. Declared in
-- 001_initial_schema.sql / 002_create_user_metrics.sql — we use
-- `create or replace` here so applying this migration in isolation
-- (e.g. a hotfix branch) still works.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists pro_entitlements_set_updated_at on public.pro_entitlements;
create trigger pro_entitlements_set_updated_at
before update on public.pro_entitlements
for each row execute function public.set_updated_at();

-- RLS: user reads their own row, nobody else (not even other
-- authenticated users) reads it. Writes are NEVER allowed through
-- the user-facing API — only the service_role bypass (used by the
-- edge function) can mutate this table. That's why there is no
-- INSERT / UPDATE / DELETE policy — without one, the default deny
-- applies and any client request is rejected.
alter table public.pro_entitlements enable row level security;

drop policy if exists "pro_entitlements_select_own" on public.pro_entitlements;
create policy "pro_entitlements_select_own"
  on public.pro_entitlements
  for select
  to authenticated
  using (auth.uid() = user_id);
