-- FormAI — body metrics: weight and tape measurements over time
--
-- Roadmap Phase 9 (C1, C3) · "let users see their body change over time".
--
-- WHY THIS IS 017 AND NOT 013
--
-- The roadmap calls this file `013_body_metrics.sql`. 013, 014 and 015
-- were taken by Phase 7 (tag tokens, ingredients, origin/diet) and are
-- applied to production, and 016 is RESERVED for the deliberately
-- unwritten `016_drop_legacy_tags.sql` — four documents describe it by
-- that exact filename as "not written on purpose". Renumbering it to
-- close the gap would break every one of those references and invite
-- somebody to think it had been done. The gap is cheaper than the
-- confusion.
--
-- ONE ROW PER USER PER DAY
--
-- `recorded_on` is a `date`, not a `timestamptz`, and it is half of the
-- unique key. A body weight is a daily observation: the scale reads
-- differently before and after breakfast by more than a week of real
-- change, so two entries on the same day are not two data points, they
-- are one data point measured twice. Storing both would make the trend
-- line depend on what time of day the user happened to open the app.
-- Re-logging the same day replaces.
--
-- EVERY MEASUREMENT IS NULLABLE, AND THAT IS THE POINT
--
-- A user who only ever weighs themselves must not be forced to invent a
-- thigh circumference, and a user who tracks waist while deliberately
-- not looking at the scale — which is the healthier pattern for a
-- recomposition or an eating-disorder history — must be able to. The
-- only thing a row must have is a date and at least one measurement,
-- which is what the check constraint says.
--
-- UNITS ARE ALWAYS METRIC
--
-- kg and cm, always, exactly as `lib/core/utils/unit_system.dart`
-- promises. Imperial is a rendering choice made at the edge and is
-- never persisted. A column whose unit depends on a preference read at
-- some other time is the bug that file exists to make impossible.

create table if not exists public.body_metrics (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  recorded_on  date not null,

  -- Bounds match `unit_system.dart`'s editor bounds (kMinWeightKg /
  -- kMaxWeightKg) so the client cannot save a value the server rejects
  -- and vice versa. Numeric, not float: a body weight is a decimal
  -- quantity a human reads back, and binary float turns 70.1 into
  -- 70.09999999999999 in a JSON round-trip.
  weight_kg    numeric(5, 2) check (weight_kg is null
                                    or weight_kg between 30 and 250),

  -- Tape measurements. The upper bounds are deliberately generous —
  -- they exist to catch a slipped decimal point or a centimetre value
  -- typed as millimetres, not to tell anybody what size they are
  -- allowed to be.
  waist_cm     numeric(5, 2) check (waist_cm is null
                                    or waist_cm between 30 and 250),
  chest_cm     numeric(5, 2) check (chest_cm is null
                                    or chest_cm between 30 and 250),
  arm_cm       numeric(5, 2) check (arm_cm   is null
                                    or arm_cm   between 10 and 100),
  thigh_cm     numeric(5, 2) check (thigh_cm is null
                                    or thigh_cm between 20 and 150),
  hip_cm       numeric(5, 2) check (hip_cm   is null
                                    or hip_cm   between 30 and 250),

  note         text check (note is null or char_length(note) <= 280),

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  unique (user_id, recorded_on),

  -- An all-null row is not a measurement, it is a date. Rejecting it
  -- here means no reader ever has to decide what an empty entry means
  -- on a chart.
  constraint body_metrics_not_empty check (
    weight_kg is not null
    or waist_cm is not null
    or chest_cm is not null
    or arm_cm   is not null
    or thigh_cm is not null
    or hip_cm   is not null
  )
);

comment on table public.body_metrics is
  'Roadmap Phase 9 · one row per user per calendar day. Always metric '
  '(kg / cm); imperial is a rendering choice made at the edge. Every '
  'measurement is nullable so a user can track only what they want to '
  'track, but a row with none of them is rejected.';

comment on column public.body_metrics.recorded_on is
  'The DAY the measurement describes, not the moment it was typed. A '
  'user logging Monday''s weight on Tuesday evening records Monday.';

-- The one query this table serves: "everything I have logged, oldest
-- first". Descending on the date because the chart, the summary card
-- and the coach all want the most recent window and read backwards.
create index if not exists body_metrics_user_date_idx
  on public.body_metrics (user_id, recorded_on desc);

drop trigger if exists body_metrics_set_updated_at on public.body_metrics;
create trigger body_metrics_set_updated_at
before update on public.body_metrics
for each row execute function public.set_updated_at();

-- ─── Row Level Security ─────────────────────────────────────────────
--
-- Body measurements are the most personal data this app stores. There
-- is no public read here and there never will be — not even the
-- aggregate, not even for the leaderboard work in Phase 13.

alter table public.body_metrics enable row level security;

drop policy if exists "body_metrics_select_own" on public.body_metrics;
create policy "body_metrics_select_own"
  on public.body_metrics
  for select
  using (auth.uid() = user_id);

drop policy if exists "body_metrics_insert_own" on public.body_metrics;
create policy "body_metrics_insert_own"
  on public.body_metrics
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "body_metrics_update_own" on public.body_metrics;
create policy "body_metrics_update_own"
  on public.body_metrics
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "body_metrics_delete_own" on public.body_metrics;
create policy "body_metrics_delete_own"
  on public.body_metrics
  for delete
  using (auth.uid() = user_id);

-- ─── The user's own target weight ───────────────────────────────────
--
-- THE APP DOES NOT PROJECT A GOAL WEIGHT, AND MUST NOT.
--
-- The roadmap asks for "the onboarding goal weight drawn as a target
-- line". There is no such value: `WizardState` captures a CURRENT
-- weight and nothing else, and `ai_personalization_engine.dart` carries
-- an explicit store-compliance rule against emitting quantified outcome
-- promises — Apple 1.4.1 and Play health-misrepresentation both reject
-- guaranteed numeric results, which is why the 12-week projection is
-- qualitative by design.
--
-- So the target is STATED BY THE USER and stored here. The app draws
-- the line the user asked for; it never predicts one. That keeps the
-- compliance rule intact and, more importantly, keeps the number
-- honest: a target the user chose is a commitment, and a target the app
-- invented is a promise it cannot keep.
--
-- On `user_metrics` rather than its own table for the same reason
-- migration 012 put `locale` there: the row already exists per user,
-- is already RLS'd to its owner, and is already upserted on user_id.

alter table public.user_metrics
  add column if not exists target_weight_kg numeric(5, 2);

alter table public.user_metrics
  drop constraint if exists user_metrics_target_weight_range;
alter table public.user_metrics
  add constraint user_metrics_target_weight_range
  check (target_weight_kg is null
         or target_weight_kg between 30 and 250);

comment on column public.user_metrics.target_weight_kg is
  'The weight the USER said they are aiming for, in kg. Null means they '
  'have not set one, which is a valid and permanent state — the trend '
  'chart simply draws no target line. Never computed, never predicted: '
  'the app is not permitted to promise a numeric outcome.';
