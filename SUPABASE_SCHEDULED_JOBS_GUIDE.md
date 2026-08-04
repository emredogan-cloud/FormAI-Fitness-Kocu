# Scheduled jobs on Supabase — a founder's guide

**Who this is for:** you, deploying and maintaining FormAI's recurring
server work without reading the Dart.

**What it covers:** the four jobs the app needs, which Supabase mechanism
each should use and why, how to deploy them, and what to do when one
misbehaves at 3 a.m.

**Project:** `xtvqhnjamwvmfcsahzxv` (eu-west-1, Postgres 17).

---

## 0. The short version

If you read nothing else:

| job | mechanism | cadence | urgency |
| --- | --- | --- | --- |
| **Weekly league rollover** | pg_cron + SQL function | Mondays 00:05 UTC | needed before leagues can ship |
| **Challenge expiry** | nothing — it is already handled | — | not needed |
| **Challenge activation** | nothing — it is already handled | — | not needed |
| **Scheduled notifications** | **stays on the device** | — | do not build this |

Two of the four turn out not to be jobs at all, and one of those is a
decision rather than an oversight. §4 and §5 explain.

---

## 1. pg_cron vs Edge Functions

Supabase gives you two ways to run something on a schedule. They are not
interchangeable, and picking the wrong one is the most common way this
kind of infrastructure goes bad.

### pg_cron

A Postgres extension. It runs SQL **inside the database**, on the
database's own clock.

* **Use it when the work is data-to-data**: read rows, compute, write
  rows. No HTTP, no third-party API, no secrets.
* Transactional. If the statement fails, nothing partially applied.
* No cold start, no network hop, no egress cost.
* Runs as a superuser-ish role, so RLS does **not** apply. That is
  exactly what a rollover needs (it writes rows for every user) and
  exactly why the function must be written carefully.
* Limited observability: it logs to a table, not to your dashboard.

### Edge Functions

Deno running at the edge, invoked by HTTP. Schedule them with
`pg_cron` + `pg_net`, or an external cron hitting the URL.

* **Use them when the work needs the outside world**: sending a push via
  FCM, calling Anthropic, hitting RevenueCat, writing to storage.
* You get real logs in the Supabase dashboard.
* They can fail halfway. Anything they write needs to be idempotent
  because you will retry them.
* Cold starts, egress, and per-invocation cost.

### The rule for this project

> **If the job never leaves the database, it is pg_cron. The moment it
> needs a network call, it is an Edge Function.**

FormAI's one real job — the league rollover — never leaves the database.
It reads `leaderboard_stats`, applies a ranking rule, and writes
`league_assignments`. That is pg_cron, and using an Edge Function for it
would add a network hop, a cold start and a failure mode in exchange for
nothing.

---

## 2. Enabling pg_cron

Once, per project. Dashboard → Database → Extensions → enable `pg_cron`,
or:

```sql
create extension if not exists pg_cron;
```

It installs into the `cron` schema. Two tables matter:

* `cron.job` — what is scheduled.
* `cron.job_run_details` — every run, with status and duration. **This
  is your log.** See §9.

---

## 3. The weekly league rollover

### 3.1 What it has to do

Phase 13 shipped the *rules* — they are pure Dart in
`lib/features/community/domain/league.dart`, and they are tested. The
job is a transcription of those rules, not a redesign of them:

1. For each league (a tier, within a season), rank its members by the
   ranking metric for the week that just ended.
2. Top **5** are promoted one tier. Bottom **5** are relegated one tier.
   Everyone else holds.
3. Bronze cannot be relegated. Diamond cannot be promoted. A league with
   fewer than 2 members holds — ranking one person is not a competition.
4. Write the new tier into `league_assignments` with `prev_tier` set to
   what they had, so the app can say "up from Silver" without a second
   query.

**The Dart is the specification.** If you change the rule, change it
there first, let its tests fail, then mirror it here. Two sources of
truth that disagree is worse than one that is wrong.

### 3.2 The function

```sql
create or replace function public.run_league_rollover()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_season date := date_trunc('month', now() at time zone 'utc')::date;
  v_week   date := (date_trunc('week', (now() at time zone 'utc') - interval '7 days'))::date;
  v_moved  integer := 0;
begin
  with ranked as (
    select
      la.user_id,
      la.tier,
      row_number() over (
        partition by la.tier
        order by coalesce(ls.consistency, 0) desc,
                 coalesce(ls.weekly_xp, 0) desc,
                 la.user_id                     -- deterministic tiebreak
      ) as rank,
      count(*) over (partition by la.tier) as league_size
    from public.league_assignments la
    left join public.leaderboard_stats ls
      on ls.user_id = la.user_id
     and ls.week_start = v_week
    where la.season = v_season
  ),
  moved as (
    select
      user_id,
      tier as old_tier,
      case
        when league_size < 2 then tier
        when rank <= 5 then
          case tier
            when 'bronze'   then 'silver'
            when 'silver'   then 'gold'
            when 'gold'     then 'platinum'
            when 'platinum' then 'diamond'
            else tier                          -- diamond cannot climb
          end
        when rank > league_size - 5 then
          case tier
            when 'diamond'  then 'platinum'
            when 'platinum' then 'gold'
            when 'gold'     then 'silver'
            when 'silver'   then 'bronze'
            else tier                          -- bronze cannot fall
          end
        else tier
      end as new_tier
    from ranked
  )
  insert into public.league_assignments (user_id, season, tier, prev_tier)
  select
    user_id,
    (date_trunc('month', (now() at time zone 'utc') + interval '1 month'))::date,
    new_tier,
    old_tier
  from moved
  on conflict (user_id, season) do update
    set tier      = excluded.tier,
        prev_tier = excluded.prev_tier,
        updated_at = now();

  get diagnostics v_moved = row_count;
  return v_moved;
end;
$$;
```

**Three things in there are deliberate and should not be "simplified":**

* `security definer` — the job writes rows for every user, and RLS would
  (correctly) stop a normal role from doing that.
* `set search_path = public` — without it, a `security definer` function
  is a privilege-escalation vector. Never omit it. See §12.
* `la.user_id` as the last `order by` term — without a deterministic
  tiebreak, two users on identical numbers can swap places between runs
  and one of them gets promoted for no reason they can see.

### 3.3 Scheduling it

```sql
select cron.schedule(
  'league-rollover',
  '5 0 * * 1',                       -- Mondays, 00:05 UTC
  $$ select public.run_league_rollover(); $$
);
```

**Why 00:05 and not 00:00.** The week boundary in the app is UTC
midnight Monday (`weekStartUtc` in `league.dart`). Running exactly on
the boundary races clients that are still writing the last minute of
Sunday. Five minutes is free and removes the race.

**Why weekly and not daily.** Promotion is meant to be an event. A user
who could be promoted any morning stops reading it as news.

Verify it landed:

```sql
select jobid, jobname, schedule, active from cron.job;
```

### 3.4 Seeding the first season

Nobody has a tier yet, so the first run has nothing to rank. Give every
opted-in user Bronze once:

```sql
insert into public.league_assignments (user_id, season, tier)
select distinct
  ls.user_id,
  date_trunc('month', now() at time zone 'utc')::date,
  'bronze'
from public.leaderboard_stats ls
on conflict (user_id, season) do nothing;
```

Re-runnable. `on conflict do nothing` means a second run is a no-op
rather than a reset.

**Also decide how a *new* user gets their first tier.** Two options:

1. Extend the rollover to insert Bronze for anyone with
   `leaderboard_stats` and no assignment for the current season. Simple,
   but they wait up to a week.
2. Have the client insert Bronze when a user opts in. Immediate, but it
   is one more thing a client can get wrong.

**Recommended: option 1.** A league is a weekly rhythm; joining it
mid-week and being ranked against people who have been in it for six
days is worse than starting Monday.

---

## 4. Challenge expiry — already handled, do not build it

A challenge is over when `ends_at` has passed. Nothing has to happen for
that to be true.

* `CommunityRepository.challenges()` filters `ends_at >= now()`, so an
  ended challenge stops being returned.
* `Challenge.isOpen()` is checked again in the UI *and* in
  `joinChallenge`, because a challenge can close between a frame being
  drawn and a button being pressed.
* `challenge_participants` rows are kept. **They are the record that
  somebody finished**, and a job that deleted them would destroy history
  to save nothing.

A "expire challenges" job would have no work to do. If you ever want to
end one early, move `ends_at` — never delete the row (see
`supabase/sql/seed_challenge_example.sql`).

---

## 5. Challenge activation — also already handled

Same reasoning in the other direction. A challenge becomes live when
`starts_at` passes; the query and `isOpen()` do the rest. Insert it with
a future `starts_at` and it appears on its own.

The only thing a job could add is *announcing* the start, which is a
notification — and see §6.

---

## 6. Scheduled notifications — deliberately NOT a server job

FormAI's notifications are **local**, scheduled on the device by
`notification_service.dart` (the monthly recap is id 1004). This is a
decision, and it should stay one:

* **No push tokens to store**, so no token table to leak, rotate or
  clean up.
* **No FCM/APNs credentials on the server.**
* **They work offline**, which is the app's whole posture.
* **The device knows the user's timezone**, so "Monday morning" means
  their Monday morning without the server modelling zones.

A server-side scheduled push would need: an Edge Function, FCM
credentials in secrets, a device-token table with RLS, token refresh
handling, per-user timezone storage, and a retry policy — to deliver a
reminder the device can already schedule itself.

**Build it only when you need to notify users about something the device
cannot know** — a friend request arriving, a squad-mate finishing a
challenge. That is a genuine reason, and it is a Phase 15+ conversation,
not a scheduling one.

---

## 7. Deployment

pg_cron jobs are **database state, not repository state.** That is worth
sitting with: nothing in `git` will tell you what is scheduled.

**Therefore:** every scheduled job's SQL lives in `supabase/sql/` in this
repository as the source of truth, and is applied by hand. Do not put it
in `supabase/migrations/` — migrations are for schema, and a `cron.schedule`
call in a migration will try to re-run on every fresh environment,
including CI and any local database that has no pg_cron.

Order for a first deploy:

1. `create extension if not exists pg_cron;`
2. Create the function (§3.2).
3. Run it once by hand and read the return value: `select public.run_league_rollover();`
4. Seed the first season (§3.4).
5. Schedule it (§3.3).
6. Check `cron.job` says `active = true`.

---

## 8. Retries

**pg_cron does not retry.** A failed run is skipped and the next one
happens on schedule.

For the rollover that is the correct behaviour, and it is only correct
because the function is **idempotent**: it computes the next season's
tier from the current one and upserts. Running it twice in a week
produces the same rows. Missing a week means one week without movement,
which is a disappointment, not corruption.

**Do not add a retry loop.** If you ever write a job that is *not*
idempotent, fix that instead of retrying it.

For Edge Functions (if you add any), assume they run more than once and
make every write an upsert.

---

## 9. Monitoring and logging

Everything pg_cron does is in one table.

**Did it run, and did it work:**

```sql
select jobid, runid, status, return_message, start_time, end_time
from cron.job_run_details
order by start_time desc
limit 20;
```

**Only the failures:**

```sql
select start_time, return_message
from cron.job_run_details
where status <> 'succeeded'
order by start_time desc
limit 50;
```

**Did anything actually move last week:**

```sql
select tier, count(*)
from public.league_assignments
where season = date_trunc('month', now() at time zone 'utc')::date
group by tier
order by 1;
```

**Housekeeping.** `cron.job_run_details` grows forever. Trim it:

```sql
select cron.schedule(
  'cron-log-prune',
  '0 3 * * 0',
  $$ delete from cron.job_run_details where end_time < now() - interval '90 days'; $$
);
```

**Set one alarm.** In the Supabase dashboard, add a log-based alert on
`cron.job_run_details.status <> 'succeeded'`. A weekly job that silently
stopped is a bug you will otherwise find a month late, when a user asks
why nobody has been promoted since August.

---

## 10. Debugging

**"It is scheduled but nothing happens."** Check `active`:

```sql
select jobname, active, schedule from cron.job;
```

Then check the schedule string is UTC. pg_cron uses the **database's**
timezone, which is UTC on Supabase. `'0 9 * * 1'` is 09:00 UTC, not
09:00 Istanbul.

**"It runs and errors."** `return_message` in `job_run_details` holds
the Postgres error. The two most likely:

* `permission denied for table league_assignments` — the function lost
  `security definer`.
* `relation "..." does not exist` — `search_path` is missing, or you
  created the function in the wrong schema.

**"It runs, succeeds, and changes nothing."** Almost always the week
boundary. The function reads `week_start = v_week`, where `v_week` is
*last* week's Monday. Check a row exists:

```sql
select count(*), week_start
from public.leaderboard_stats
group by week_start
order by week_start desc;
```

If `week_start` values are not Mondays, the client and the job disagree
about what a week is — compare against `weekStartUtc` in `league.dart`.

**Testing a change safely.** Wrap it in a transaction and roll it back:

```sql
begin;
select public.run_league_rollover();
select user_id, tier, prev_tier from public.league_assignments
 where season = (date_trunc('month', now() + interval '1 month'))::date
 limit 20;
rollback;
```

---

## 11. Rollback

**Pause a job** (keeps its definition):

```sql
update cron.job set active = false where jobname = 'league-rollover';
```

**Remove it:**

```sql
select cron.unschedule('league-rollover');
```

**Undo a bad rollover.** `prev_tier` is stored precisely so this is
possible:

```sql
update public.league_assignments
   set tier = prev_tier, prev_tier = null, updated_at = now()
 where season = (date_trunc('month', now() + interval '1 month'))::date
   and prev_tier is not null;
```

Run it inside a transaction and look before you commit. It is only safe
**once** — a second run would swap tiers using a `prev_tier` that has
already been consumed, which is why the statement nulls it out.

**Nothing in the app breaks if leagues stop entirely.** The tier card
simply does not render. Leaderboards, challenges and the rest of
community are unaffected. Pausing this job is a safe first response to
anything odd.

---

## 12. Security

Four rules, in order of how badly it goes if you break them.

1. **Every `security definer` function must set `search_path`.** Without
   it, a caller can put a malicious schema ahead of `public` and your
   elevated function calls their code. This is the single most common
   Postgres privilege-escalation bug.
2. **`security definer` bypasses RLS. Only use it where the job's whole
   purpose is to act across users** — the rollover qualifies; a function
   that reads one user's data does not.
3. **Never put secrets in a `cron.schedule` command string.** It is
   stored in plain text in `cron.job` and readable by anyone with
   database access. Edge Function secrets belong in Supabase secrets.
4. **The service-role key must never reach the client.** Nothing in this
   guide requires it on a device, and if you find yourself wanting it
   there, the design is wrong.

One more, specific to this project: **the rollover reads
`leaderboard_stats`, which is opt-in data.** A user who left the
leaderboard has no row, so they rank as `coalesce(..., 0)` — last. That
is wrong. Before leagues ship, either exclude users with no stats row
from `ranked`, or delete their `league_assignments` when they opt out.
**Recommended: exclude them in the job**, because opting out should not
require the client to succeed at a second write.

---

## 13. Cost

pg_cron is **free**. It is Postgres doing work you are already paying
for, and this job touches a handful of rows per user per week. At 100k
opted-in users the rollover is a single indexed pass — hundreds of
milliseconds.

Edge Functions bill per invocation and per GB-second. Nothing in this
guide needs one. If you later add scheduled push, the cost driver will
be FCM fan-out, not the function.

The one thing that can quietly grow is `cron.job_run_details`. §9 prunes
it.

---

## 14. Recommendations, in order

1. **Do the rollover, and only the rollover.** It is the one piece of
   scheduled infrastructure the app actually needs, and Phase 13 is
   complete without it only in the sense that nothing crashes.
2. **Fix the opt-out ranking hole first** (§12, last paragraph). It is
   three words in a `where` clause and it prevents ranking people who
   asked not to be ranked.
3. **Decide how new users get a first tier** (§3.4). Recommended: the
   job does it, so leagues start on Mondays for everyone.
4. **Set the failure alert** (§9) on the day you schedule the job, not
   the day it first fails.
5. **Leave notifications on the device** until there is something to say
   that the device cannot know (§6).
6. **Keep the Dart as the specification** for any rule this SQL
   implements. When they disagree, the Dart has tests and the SQL does
   not.

---

## Appendix — where things live

| what | where |
| --- | --- |
| League rules (promotion, relegation, tiers) | `lib/features/community/domain/league.dart` |
| Their tests | `test/features/community/league_test.dart` |
| Tables (`leaderboard_stats`, `league_assignments`, `challenges`) | `supabase/migrations/020_leaderboards.sql` |
| Challenge seeding template | `supabase/sql/seed_challenge_example.sql` |
| Launch challenge content | `supabase/sql/seed_launch_challenges.sql` |
| Client reads and writes | `lib/features/community/data/community_repository.dart` |
| Local notifications | `lib/core/services/notification_service.dart` |
