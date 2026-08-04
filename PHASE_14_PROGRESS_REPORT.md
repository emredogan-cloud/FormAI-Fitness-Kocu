# Phase 14 — Content Freshness Engine · progress report

**Status:** 🟡 **in progress** — 4 of 8 features shipped, 4 have their
rules built and tested but no surface. See §5 for the exact remainder.
**Roadmap:** R5 · P5 · C5 · C6 · C40 · C50
**Commits:** `87a8dec` (the blocker) → `07b7034` → `03a4360`
**Build:** 1.0.0+36 — **not bumped**, no APK/AAB built this session
**Tests:** 1453 (1384 at session start, 1388 after the blocker fix)
**Migrations applied to production:** `023`, `024`, `025`
**Device walk:** ❌ **not done — no device was connected this session**

---

## 0. The blocker came first, and it was not the blocker

The session opened with one named production issue: joining a challenge
from the device did nothing. The previous session had recorded it as
"`joinChallenge` returns false somewhere between `isOpen` and the
upsert" and could not investigate because the anon key was unreadable.

**The button was never the problem, and neither was the client.** The
first live RLS pass ever run against this database found five tables
answering HTTP 500:

```
GET /rest/v1/challenge_participants   500  42P17
GET /rest/v1/squad_members            500  42P17
GET /rest/v1/squads                   500  42P17
GET /rest/v1/activity_events          500  42P17
GET /rest/v1/activity_reactions       500  42P17

infinite recursion detected in policy for relation "squad_members"
infinite recursion detected in policy for relation "challenge_participants"
```

### 0.1 A policy that queries its own table recurses

Postgres applies row security to the tables a policy expression reads —
**including the table the policy is attached to** — so evaluating the
policy re-enters the policy. Two policies did exactly that
(`squad_members_select_member`, `challenge_participants_select_peers`).
The other three tables were collateral: they reference `squad_members`
in policies of their own and inherited its recursion.

**Squads and the entire activity feed had never worked in production.**
Not since `019` was applied on 2026-08-03. Nothing was hiding the
outage — Phase 12's device walk predates `019` and correctly saw "not
switched on yet"; Phase 13's walk opened the leaderboard and the
challenge list and never opened squads or the feed.

`022` is not implicated. Its subject was a *different* defect in the
same two policies (`m.squad_id = squad_id` resolving to
`m.squad_id = m.squad_id`) and that fix was correct. Qualifying a column
name does not change which table a subquery reads.

### 0.2 The same pass found that blocking did nothing

Verified against production with two real accounts:

| step | result |
| --- | --- |
| A publishes a public profile | B sees it ✅ |
| A blocks B | 201 |
| B reads A's profile again | **B still sees it** ❌ |

`blocks_select_own` deliberately shows a block row only to the blocker,
and a policy expression is evaluated **as the querying user**. So in
`not exists (... or (b.blocker_id = user_id and b.blocked_id = auth.uid()))`
the row that would match the second clause is invisible to exactly the
person it is meant to stop. Every policy carrying the "both directions"
comment had it — `019`'s profiles and friendships, `020`'s leaderboard
and league, `022`'s feed and challenge peers.

The blocker's own half worked, which is what let this survive review.
Only the direction that matters for safety was broken: you block
somebody so that **they** lose sight of **you**.

### 0.3 `023`, and why the helpers live in `private`

Both defects are one sentence: *a policy cannot read a table whose RLS
is part of the question it is trying to answer.* Three `security
definer` helpers now answer those questions past RLS.

They are in a **`private` schema, not `public`**, and that is the one
decision worth defending. PostgREST serves functions in the schemas it
is configured for, and `public` is one of them —
`public.is_blocked_with(uuid)` would be a REST endpoint any signed-in
user could call for any id, an enumerable "did this person block me?"
oracle. `private` is not an exposed schema.

`is_blocked_with` takes **one** argument and answers only about the
caller. Asking about two other people is not a question it answers.

What this does not claim: a working block is always inferable from
absence, and no policy prevents that. `019`'s stated property — the
blocked user cannot *discover* the block — is weaker after `023` than
its comment implies, and was worth less before it, because the block did
not work at all. Widening `blocks_select_own` to both parties would hand
over an enumerable list and is strictly worse.

### 0.4 Verified, both directions, against production

| probe | before `023` | after `023` |
| --- | --- | --- |
| join a challenge as a real user | 500 · `42P17` | **201, row lands, reads back** |
| all 12 community tables | 5 × 500 | **12 × 200** |
| A blocks B, B reads A | B still sees A | **B loses sight of A** |
| B reads the `blocks` row itself | 0 rows | 0 rows (unchanged, correct) |
| client writes to a content table | — | **403** |

Every probe ran with throwaway accounts created and deleted through the
admin API. Production holds no diagnostic residue: `auth.users` has no
`formai-diag.invalid` address, and the founder's single
`public_profiles` row is untouched.

### 0.5 Why "no exception in logcat" was the wrong evidence

`AppLogger.error` prints only under `kDebugMode`. The founder was
testing a **release** build, so the `PostgrestException` was captured to
Sentry and logcat was silent by design. The previous session's
inference — no log, therefore no throw, therefore an early `return
false` — was reasonable and wrong. **In a release build, "nothing in
logcat" is not "no exception."**

### 0.6 The gate now catches the class

`rls_policy_test.dart` gained five checks, and all five were **probed
against the real defect before being trusted**:

| probe | result |
| --- | --- |
| self-referencing policy reintroduced | FIRED |
| a policy reads `public.blocks` directly again | FIRED |
| `is_blocked_with` made one-directional | FIRED |
| a helper stops constraining on `auth.uid()` | FIRED |
| a helper loses `security definer` | FIRED |

The `auth.uid()` check had to be widened, because three policies now
constrain on the caller *inside a helper*. It was widened with a
**signal**: the helper's own body is read and must contain `auth.uid()`.
"Calls a private helper" would have been a free pass. A helper that
stopped constraining on the caller now takes every policy that calls it
down with it, which is the correct blast radius.

The old "a block is checked in both directions" test was **deleted, not
adjusted**. It passed throughout the entire outage. Every block check
named `blocker_id` on both sides of an `or`, exactly as it demanded, and
the blocks still did not work. The property worth checking turned out to
be a different one: nothing may read `public.blocks` from inside a
policy at all.

This is the **fifth** time a gate in this repository has been confidently
green about its own subject.

---

## 1. Feature status

| # | feature | roadmap | state |
| --- | --- | --- | --- |
| — | **Migration `024`** (releases + drops) | — | ✅ applied to production |
| — | **Migration `025`** (rotating challenges) | — | ✅ applied · 13 challenges live |
| 1 | **What's New surface** | C5, R5 | ✅ shipped · first note live |
| 2 | **Content pipeline & cadence** | C6, R5 | ✅ `docs/CONTENT_OPS.md` BÖLÜM II |
| 3 | **Rotating challenge library** | C6 | ✅ 7 added · 2 shapes refused (§3.3) |
| 4 | **Post-program continuation** | C40, R5 | 🟡 rules + copy · **no screen** |
| 5 | **Beginner → advanced branching** | C40, P5 | 🟡 tiers + overload · **not wired to the generator** |
| 6 | **New-content discovery** | C6 | 🟡 schema + targeting · **no surface** |
| 7 | **Lifecycle campaigns** | C50 | 🟡 rules + cap · **not wired to notifications** |
| 8 | **Seasonal & event content** | C6 | 🟡 `expires_at` + New Year · Ramadan nutrition not built |
| — | **Analytics** (6 events) | — | ✅ defined · 1 of 6 fired (§5.2) |

---

## 2. What shipped

### 2.1 A release note is keyed to a build, not a date

The one non-obvious decision in `024`. Play rolls a release out over
days, so on release day **both populations exist at once**, and a note
published for the new build would describe, to half the users, an app
they do not have. A client asks for the newest note **at or below its
own build**; the staged rollout is then correct by construction rather
than by content ops remembering. It also means a note can be authored
and published before the build reaches anybody, which is the workflow
content ops actually wants.

### 2.2 "Have you read it" is device state

There is no `user_id` anywhere in `024`. Whether you have seen a
changelog lives in `SharedPreferences`, which keeps both tables free of
user data — so RLS has nothing to protect and the static gate can prove
it — and works on the first launch after an update, which is exactly
when a phone may still be on the store's network rather than the user's.
The failure mode is seeing a changelog twice on a new device. Same call
Phase 10 made about progress photos and Phase 13 made about leaderboard
opt-out: the guarantee is that the data is not on the server.

### 2.3 The day-31 rules, and the one that matters

Four paths, one marked, none automatic. `recommend()` is grounded in
what actually happened — `completedDays / totalDays`, which the app
already has.

**Somebody who finished 11 of 30 days is offered the SAME program at the
SAME load.** More volume is not the fix for a program that beat you, and
offering "advance to the next level" to a person who half-finished is
how they quit. A tier advance likewise carries **no** volume bump: two
increases at once, and when the next month goes badly neither can be
blamed.

An advanced user who finishes strongly is offered a change of focus,
because there is no fourth tier — that dead end is the thing this phase
exists to remove.

The overload constant is **read back out of
`workout_generator_service.dart` by a test**, so the screen cannot
promise a progression the generator does not build. Same shape as
`league_test.dart` reading the leaderboard SQL.

### 2.4 The sync service answers from cache, always

The roadmap requires graceful degradation to bundled content offline.
The naive shape is a live fetch, and the naive shape makes a plane turn
What's New into an error. So every read answers from the cache and the
network only ever refreshes it: the offline case is "no new content",
which is the correct appearance of an app with no new content.

The cache holds **raw JSON, not parsed objects**, so a client that
learns a new field reads it out of a cache written by a client that did
not. An app updated after a month offline shows the new content
immediately rather than after its first successful sync.

### 2.5 The frequency cap is the campaign feature

A 14-day-lapsed user is simultaneously eligible for a win-back, a
streak-risk alert and whatever content landed while they were away —
three notifications, one person, one day, each individually justified.
So the decision is made in one place against the whole history: **two
per rolling week, 48 hours apart minimum**, plus a per-campaign
cooldown. `nextCampaign` is the only door, so no call site can ask what
is due and forget to ask whether it is allowed.

The daily reminder is **not** capped, and that is a property rather than
an exemption: the cap governs what the *app* decides to send, and the
user picked that one's time themselves.

There is deliberately no fourth win-back. A user 30 days gone who does
not return is not reachable by another notification, and sending one is
how an app earns an uninstall instead of a dormant install.

### 2.6 Two challenge shapes refused, again, in writing

The roadmap's rotating library names five shapes. Three are measurable
(`sessions` over a week, `streak` for a habit builder, `sessions` over
sixty days) and two are not: **body-part focuses** and
**equipment-specific tracks** both need the engine to know what a
session trained, and it does not — a session is a session.

They are not dropped as ideas. They are why
`content_drops.target_levels` and `content_drops.requires_equipment`
exist: such a track ships as a **content drop pointing at a plan**,
which is an announcement the app can make honestly, rather than as a
challenge whose progress bar would never move. A challenge that cannot
count what it promised tells the user they did nothing.

### 2.7 One duplicated helper was removed rather than added to

Phase 14 needed the locale → language → `en` → null fallback that
`Challenge` already implemented. Rather than write a second copy, it
moved to `core/utils/localized_copy.dart` and `Challenge` now calls it.
A fallback chain that differs between two content types is a bug nobody
would think to look for.

---

## 3. Verification

```
flutter analyze                        0 issues
flutter test                           1453 passing  (1384 at session start)
dart format --set-exit-if-changed .    clean · 424 files · 0 changed
tool/check_hardcoded_strings.dart      no regressions
tool/arb_coverage.dart --strict        tr 100% · en 100% · all referenced
tool/gen_pseudo_localizations.dart     up to date · 1846 members
tool/recipe_translation_audit.dart     no findings, coverage held
tool/check_directional_layout.dart     no regressions
CI                                     green on 87a8dec
supabase migration list --linked       local == remote, 001–025
```

**Live production probes** (throwaway accounts, all deleted):

| checked | result |
| --- | --- |
| join a challenge end to end | ✅ 201, row lands, reads back |
| all 12 community tables reachable | ✅ 12 × 200 |
| block severs visibility for the blocked user | ✅ |
| `blocks` row still invisible to the blocked user | ✅ |
| `content_releases` readable by a signed-in client | ✅ note present |
| `content_drops` readable | ✅ (empty) |
| client write to `content_releases` | ✅ refused, 403 |
| 13 challenges live, windows staggered | ✅ |

### 3.1 What is NOT verified

* **No device walk.** `adb devices` was empty for the whole session. The
  join fix is verified by reproducing the client's exact PostgREST
  request as a real authenticated user — which is stronger evidence than
  a tap, because it shows the status code and the row — but **nothing on
  a screen was seen this session.**
* **What's New has never been rendered on a device.** The screen, the
  route, the dashboard trigger and the production note all exist; the
  first person to run build 36 will be the first to see it.
* **No APK or AAB was built**, and the build number was not bumped.

---

## 4. Architectural decisions

1. **The recursion fix touches only the two self-referencing policies.**
   `squads`, `activity_events` and `activity_reactions` recover
   untouched — they failed only because the policy they reached was
   itself recursive.
2. **The helpers are in `private`, not `public`**, so PostgREST cannot
   serve them as an enumerable oracle.
3. **`is_blocked_with` is one-argument.** It answers only about the
   caller.
4. **The gate's `auth.uid()` widening reads the helper's body.** A
   signal, not an exemption.
5. **A release note is keyed to a build number**, which makes a staged
   rollout correct by construction.
6. **"Seen" is device state**, so `024` holds no user data at all.
7. **The sync cache stores raw rows**, so a newer client reads an older
   client's cache correctly.
8. **The continuation recommendation never advances a struggling user**,
   and a tier change never stacks a volume bump on top of itself.
9. **The overload constant is derived from the generator by a test**, so
   the two cannot drift.
10. **The frequency cap governs app-initiated sends only**, which is a
    property of who chose the notification rather than a name-based
    exemption.
11. **Two challenge shapes were refused in writing** rather than shipped
    unmeasurable.

---

## 5. Where to resume — the exact remainder

### 5.1 Four features have rules and no surface

Each is a screen or a wiring job on top of pure, tested logic. Nothing
below needs new schema or new decisions.

1. **Continuation paths screen** (feature 4/5). `program_progression.dart`
   is complete and tested; **all the ARB copy is already written** —
   `programCompleteTitle`, `programCompleteBody`, `continueRepeatTitle`,
   `continueRepeatSameTitle`, `continueAdvanceTitle`,
   `continueSwitchTitle`, `continueMaintenanceTitle`, their bodies,
   `continueRecommended`, `tierBeginner/Intermediate/Advanced`,
   `fitTooHard/TooEasy/WellMatched`. What is missing: a screen that
   builds a `ProgramOutcome` from `workoutSessionProvider.days`, calls
   `recommend()`, renders four cards with one marked, fires
   `AnalyticsService.programContinuationChosen`, and hands the chosen
   tier's `token` back to `WorkoutGeneratorService`. Trigger point: the
   day-30 completion path, beside the existing Year-in-Review one-shot.

2. **Difficulty-tier wiring** (feature 5). `DifficultyTier.token`
   matches the generator's `fitnessLevel` strings exactly and a test
   pins that. Nothing yet passes a chosen tier back into plan
   generation, and `progressedReps` is not applied anywhere.

3. **New-content discovery surface** (feature 6). `ContentDrop`,
   `ContentAudience` and the whole targeting matrix are shipped and
   tested; `contentSyncServiceProvider.drops()` returns them; ARB has
   `discoveryNewBadge`, `discoveryNewContentTitle`,
   `discoveryNewContentEmpty`; `AppPreferences.seenContentDrops` and
   `markContentDropsSeen` exist. What is missing: a section on
   `discovery_hub_screen.dart` (or the dashboard) that filters `drops()`
   by `isLive(now)` and `matches(audience)`, badges the unseen ones, and
   fires `newContentDiscovered` on tap. The audience is built from
   `prefs.goal`, the stored fitness level, `Localizations.localeOf` and
   `prefs.hasEquipment`.

4. **Campaign scheduling** (feature 7). `lifecycle_campaigns.dart` is
   complete and tested. What is missing: a ledger of `CampaignSend`s in
   `SharedPreferences`, a listener that calls `nextCampaign(...)` on
   resume, ARB copy for each campaign body (warm, never guilt-based —
   *"Seni özledik"*, not *"3 gündür antrenman yapmadın"*), and
   `NotificationService` methods to schedule them with their own
   notification ids. `campaignSent/Opened/Converted` are already defined
   in `AnalyticsService`.

### 5.2 Analytics: defined, mostly not fired

All six Phase 14 events exist on `AnalyticsService`. Only
`whatsNewViewed` is wired (from `WhatsNewScreen.initState`).
`newContentDiscovered`, `programContinuationChosen`, `campaignSent`,
`campaignOpened` and `campaignConverted` will start firing when §5.1's
surfaces land.

### 5.3 Deliberately not built

* **Ramadan-aware nutrition scheduling** (part of feature 8). It is not
  a content drop — it is a change to when the nutrition planner places
  meals, which touches the meal engine rather than this phase's tables.
  The New Year challenge and `expires_at` cover the announcement half of
  seasonal content; the scheduling half is its own piece of work.
* **Coach-personalised content recommendation** and **coach-authored
  continuation copy** (the roadmap's AI work). Both need §5.1's surfaces
  to exist first — a coach line about a continuation path is worth
  nothing until there is a path to choose.
* **LLM-assisted content generation pipeline.** The recipe pipeline
  (`tool/recipe_pipeline/`) is the existing precedent and extending it to
  workout descriptions is a content-tooling project, not a screen.
* **What's New illustration set, seasonal art, hero imagery per
  challenge.** Every challenge card renders correctly without one.

### 5.4 Things that will bite

1. **`supabase db push` from a staging workdir only** — never the repo
   root, the CLI parses `.env.local` as dotenv and it is freeform notes.
   Copy `supabase/migrations` **and all of `supabase/.temp/`** (the
   `project-ref` file matters, not just `linked-project.json`).
2. **Copy the migration into the staging dir before pushing it.** `025`
   was applied before `024` this session because only `025` had been
   copied across. `--include-all` fixed it, and `supabase migration list
   --linked` now shows local == remote for 001–025, but the history rows
   are out of order.
3. **`library;` must precede imports**, not follow them. Two files cost
   a compile cycle to this.
4. **A function body's semicolons break a `split(';')` SQL parser.**
   `rls_policy_test.dart` parses `private.*` helpers out of the raw text
   for exactly this reason, and `019`'s `join_squad` has only ever been
   checked with `sql.contains` for the same reason.
5. **`dart run tool/gen_pseudo_localizations.dart`** after every ARB
   change, or `flutter analyze` fails on
   `test/support/pseudo_localizations.dart` with a missing-override
   error that names the new keys.
