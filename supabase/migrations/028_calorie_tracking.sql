-- ============================================================
-- 028 · AI calorie tracking — meals, items, and the scan quota
-- ============================================================
--
-- Backing store for the AI calorie tracker specified in
-- `docs/CALORIE_TRACKING_RESEARCH.md`. Three tables and two functions.
--
-- ------------------------------------------------------------
-- WHY `user_id` IS DENORMALISED ONTO `meal_items`
-- ------------------------------------------------------------
--
-- `meal_items` belongs to `meal_entries`, so the obvious policy is
-- "you may read an item if you own its meal":
--
--   using (exists (select 1 from meal_entries m
--                  where m.id = meal_items.meal_id and m.user_id = auth.uid()))
--
-- That is the shape that took five tables down for a day. Migration 023
-- is the post-mortem: Postgres applies row security to the tables a
-- policy references, so a policy that reaches into another RLS-protected
-- table inherits that table's problems, and a policy that reaches into
-- its OWN table recurses outright (42P17). The blast radius there was
-- not the two broken policies — it was the three innocent tables whose
-- policies merely *referenced* them.
--
-- So every policy below is `auth.uid() = user_id` against a column on
-- the row itself. No subquery, no cross-table reference, nothing to
-- inherit. The cost is one redundant uuid per item and a trigger to keep
-- it honest; the benefit is that no policy here can ever take another
-- table down with it.
--
-- ------------------------------------------------------------
-- WHY THE QUOTA DAY IS SERVER-SIDE
-- ------------------------------------------------------------
--
-- The scan limit is the app's only defence against an unbounded model
-- bill (research doc §5.2 sizes it at ~$480/month at 1000 DAU × 4
-- scans). A limit the client can reset is not a limit: if the client
-- supplied the day, a loop that sends a different date each call has
-- infinite scans.
--
-- The quota day therefore comes from `now()`, never from the request.
-- It is evaluated in `Europe/Istanbul` rather than UTC so the reset
-- lands at local midnight for the home market instead of at 03:00.
--
-- `meal_entries.logged_for` is the opposite case and IS client-supplied:
-- which day a meal counts toward is display data the user owns, and a
-- user backfilling yesterday's lunch is a feature, not an attack.
--
-- ------------------------------------------------------------
-- WHY ENTITLEMENT IS READ FROM `pro_entitlements`
-- ------------------------------------------------------------
--
-- Free users get 2 scans a day and Pro users 20, so the limit depends on
-- entitlement — and entitlement asserted by the client is a request to
-- be trusted, not a fact. `public.pro_entitlements` (migration 003) is
-- already maintained server-side by the `revenuecat-webhook` function
-- from RevenueCat's own events, which makes it the one entitlement
-- signal the device cannot forge. `claim_food_scan` reads it directly.
--
-- Note it checks `expires_at` as well as `is_active`: 003 documents that
-- a CANCELLATION deliberately leaves `is_active` true until the paid-up
-- period ends, so `is_active` alone would keep granting 20 scans to a
-- lapsed subscriber whose webhook never arrived.

-- ------------------------------------------------------------
-- 1 · meal_entries — one logged meal
-- ------------------------------------------------------------

create table if not exists public.meal_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,

  -- The day this meal counts toward, in the USER's local calendar.
  -- Client-supplied on purpose — see the header note.
  logged_for    date not null,

  meal_slot     text not null
                  check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),

  -- How the numbers got here. Kept because an AI estimate and a barcode
  -- read carry very different confidence, and the UI must be able to say
  -- so months later.
  source        text not null
                  check (source in ('ai_scan', 'barcode', 'manual')),

  -- Totals, denormalised from the items for cheap daily aggregation.
  -- Maintained by a trigger so they cannot drift from the item rows.
  kcal          integer not null default 0 check (kcal >= 0),
  protein_g     numeric(7, 1) not null default 0 check (protein_g >= 0),
  carbs_g       numeric(7, 1) not null default 0 check (carbs_g >= 0),
  fat_g         numeric(7, 1) not null default 0 check (fat_g >= 0),

  note          text check (note is null or char_length(note) <= 500),

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- The dashboard's only hot query: "this user's meals for this day".
create index if not exists meal_entries_user_day_idx
  on public.meal_entries (user_id, logged_for desc);

-- ------------------------------------------------------------
-- 2 · meal_items — the foods inside a meal
-- ------------------------------------------------------------

create table if not exists public.meal_items (
  id             uuid primary key default gen_random_uuid(),
  meal_id        uuid not null references public.meal_entries (id) on delete cascade,

  -- Denormalised from the parent. See the header note — this column is
  -- the reason every policy below is a bare equality test.
  user_id        uuid not null references auth.users (id) on delete cascade,

  name           text not null check (char_length(name) between 1 and 120),

  -- Free text, in the user's language: "1 kase", "200 ml", "2 slices".
  -- Deliberately not a number + unit enum: the model estimates in
  -- household measures, and forcing those into grams at capture time
  -- would invent a precision nobody measured.
  portion_label  text check (portion_label is null or char_length(portion_label) <= 80),

  kcal           integer not null check (kcal >= 0),
  protein_g      numeric(7, 1) not null default 0 check (protein_g >= 0),
  carbs_g        numeric(7, 1) not null default 0 check (carbs_g >= 0),
  fat_g          numeric(7, 1) not null default 0 check (fat_g >= 0),

  -- Per-item, not per-meal. The research doc (§6) is explicit that a
  -- plate is not uniformly knowable: the model may be sure about the
  -- chicken and guessing at the sauce, and the UI has to be able to
  -- show that difference.
  confidence     text not null default 'medium'
                   check (confidence in ('high', 'medium', 'low')),

  -- True once the user has corrected this row. Its value is diagnostic:
  -- a high edit rate on a food is the signal that the prompt or the
  -- nutrition source is wrong about it.
  was_edited     boolean not null default false,

  -- Set when the row came from a barcode rather than the vision model.
  -- Open Food Facts is the MVP provider; the column stores the barcode,
  -- not a provider row id, so swapping providers does not orphan data.
  barcode        text check (barcode is null or char_length(barcode) <= 32),

  sort_order     integer not null default 0,
  created_at     timestamptz not null default now()
);

create index if not exists meal_items_meal_idx
  on public.meal_items (meal_id, sort_order);

-- ------------------------------------------------------------
-- 3 · food_scan_log — the quota counter, and the cost trail
-- ------------------------------------------------------------
--
-- One row per AI scan CLAIM. This is both the rate-limit counter and the
-- only record of what the feature costs, which is why it survives the
-- meal being deleted (no FK to meal_entries) — deleting a meal must not
-- refund a model call that was already paid for.

create table if not exists public.food_scan_log (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,

  -- Server-derived, never client-supplied. See the header note.
  scanned_on   date not null,

  -- 'claimed'   — slot taken, model call in flight
  -- 'succeeded' — model answered
  -- 'failed'    — our fault (timeout, 5xx, malformed). Excluded from the
  --               count, because charging a user for our own outage is
  --               indefensible; the row is kept so the failure rate stays
  --               visible.
  outcome      text not null default 'claimed'
                 check (outcome in ('claimed', 'succeeded', 'failed')),

  created_at   timestamptz not null default now()
);

-- Serves the count inside claim_food_scan, which runs on every scan.
create index if not exists food_scan_log_user_day_idx
  on public.food_scan_log (user_id, scanned_on);

-- ------------------------------------------------------------
-- 4 · Row-level security
-- ------------------------------------------------------------
--
-- Every policy is `auth.uid() = user_id`. No policy references another
-- table. See the header note on 023.

alter table public.meal_entries  enable row level security;
alter table public.meal_items    enable row level security;
alter table public.food_scan_log enable row level security;

drop policy if exists meal_entries_select_own on public.meal_entries;
drop policy if exists meal_entries_insert_own on public.meal_entries;
drop policy if exists meal_entries_update_own on public.meal_entries;
drop policy if exists meal_entries_delete_own on public.meal_entries;

create policy meal_entries_select_own
  on public.meal_entries for select
  using (auth.uid() = user_id);

create policy meal_entries_insert_own
  on public.meal_entries for insert
  with check (auth.uid() = user_id);

create policy meal_entries_update_own
  on public.meal_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy meal_entries_delete_own
  on public.meal_entries for delete
  using (auth.uid() = user_id);

drop policy if exists meal_items_select_own on public.meal_items;
drop policy if exists meal_items_insert_own on public.meal_items;
drop policy if exists meal_items_update_own on public.meal_items;
drop policy if exists meal_items_delete_own on public.meal_items;

create policy meal_items_select_own
  on public.meal_items for select
  using (auth.uid() = user_id);

create policy meal_items_insert_own
  on public.meal_items for insert
  with check (auth.uid() = user_id);

create policy meal_items_update_own
  on public.meal_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy meal_items_delete_own
  on public.meal_items for delete
  using (auth.uid() = user_id);

-- The scan log is READ-ONLY to its owner. Writes happen exclusively
-- through `claim_food_scan`, which is `security definer` — if the client
-- could insert here it could also insert 'failed' rows, which are the
-- ones excluded from the count, and mint itself unlimited scans.
drop policy if exists food_scan_log_select_own on public.food_scan_log;

create policy food_scan_log_select_own
  on public.food_scan_log for select
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 5 · Keep meal_items.user_id honest
-- ------------------------------------------------------------
--
-- The denormalised column is a security boundary, so it must not be
-- settable to someone else's id. The trigger overwrites whatever the
-- client sent with the parent meal's owner. A mismatched insert is not
-- rejected — it is corrected — because the only way to reach this path
-- is a client bug or an attempt, and both want the same safe outcome.

create or replace function public.meal_items_sync_user_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select m.user_id into new.user_id
  from public.meal_entries m
  where m.id = new.meal_id;

  if new.user_id is null then
    raise exception 'meal_items.meal_id % does not exist', new.meal_id;
  end if;

  return new;
end;
$$;

drop trigger if exists meal_items_sync_user_id_trg on public.meal_items;
create trigger meal_items_sync_user_id_trg
  before insert or update of meal_id on public.meal_items
  for each row execute function public.meal_items_sync_user_id();

-- ------------------------------------------------------------
-- 6 · Keep meal totals in step with the items
-- ------------------------------------------------------------

create or replace function public.meal_entries_recalc_totals()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid := coalesce(new.meal_id, old.meal_id);
begin
  update public.meal_entries m
  set kcal      = coalesce(t.kcal, 0),
      protein_g = coalesce(t.protein_g, 0),
      carbs_g   = coalesce(t.carbs_g, 0),
      fat_g     = coalesce(t.fat_g, 0),
      updated_at = now()
  from (
    select sum(kcal)::integer as kcal,
           sum(protein_g)     as protein_g,
           sum(carbs_g)       as carbs_g,
           sum(fat_g)         as fat_g
    from public.meal_items
    where meal_id = target
  ) t
  where m.id = target;

  return null;
end;
$$;

drop trigger if exists meal_items_recalc_trg on public.meal_items;
create trigger meal_items_recalc_trg
  after insert or update or delete on public.meal_items
  for each row execute function public.meal_entries_recalc_totals();

-- ------------------------------------------------------------
-- 7 · The quota functions
-- ------------------------------------------------------------

-- Daily allowance for a user, from the server's own entitlement record.
create or replace function public.food_scan_daily_limit(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (
      select 1 from public.pro_entitlements e
      where e.user_id = p_user
        and e.is_active
        -- 003: CANCELLATION leaves is_active true until the paid-up
        -- period ends, so the date has to be checked too.
        and (e.expires_at is null or e.expires_at > now())
    ) then 20
    else 2
  end;
$$;

-- Read-only quota view for the UI. Claims nothing.
create or replace function public.food_scan_quota()
returns table (scan_limit integer, used integer, remaining integer)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid   uuid := auth.uid();
  today date := (now() at time zone 'Europe/Istanbul')::date;
  lim   integer;
  cnt   integer;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  lim := public.food_scan_daily_limit(uid);

  select count(*) into cnt
  from public.food_scan_log l
  where l.user_id = uid
    and l.scanned_on = today
    and l.outcome <> 'failed';

  return query select lim, cnt, greatest(lim - cnt, 0);
end;
$$;

-- Take a scan slot, atomically. Returns the claim id when allowed so the
-- caller can settle it to 'succeeded' or 'failed' afterwards.
--
-- The advisory lock is what makes this a limit rather than a suggestion:
-- count-then-insert without it is a race, and two concurrent requests
-- from the same account would both read `used = 1` and both proceed. The
-- lock is transaction-scoped and keyed on the user, so it serialises one
-- account's scans and nobody else's.
create or replace function public.claim_food_scan()
returns table (allowed boolean, claim_id uuid, scan_limit integer, remaining integer)
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid   uuid := auth.uid();
  today date := (now() at time zone 'Europe/Istanbul')::date;
  lim   integer;
  cnt   integer;
  new_id uuid;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));

  lim := public.food_scan_daily_limit(uid);

  select count(*) into cnt
  from public.food_scan_log l
  where l.user_id = uid
    and l.scanned_on = today
    and l.outcome <> 'failed';

  if cnt >= lim then
    return query select false, null::uuid, lim, 0;
    return;
  end if;

  insert into public.food_scan_log (user_id, scanned_on, outcome)
  values (uid, today, 'claimed')
  returning id into new_id;

  return query select true, new_id, lim, greatest(lim - cnt - 1, 0);
end;
$$;

-- Settle a claim. Only the claim's owner can settle it, and only from
-- 'claimed' — so a replayed call cannot flip a charged scan to 'failed'
-- and refund itself.
create or replace function public.settle_food_scan(p_claim uuid, p_ok boolean)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  update public.food_scan_log
  set outcome = case when p_ok then 'succeeded' else 'failed' end
  where id = p_claim
    and user_id = uid
    and outcome = 'claimed';
end;
$$;

revoke all on function public.food_scan_daily_limit(uuid) from public, anon, authenticated;
grant execute on function public.food_scan_quota()               to authenticated;
grant execute on function public.claim_food_scan()               to authenticated;
grant execute on function public.settle_food_scan(uuid, boolean) to authenticated;
