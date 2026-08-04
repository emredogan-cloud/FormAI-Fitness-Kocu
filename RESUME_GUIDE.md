# RESUME GUIDE

Read this first. It is written so a session with no memory of the
previous one can continue without re-analysing the repository.

**Last updated:** 2026-08-04. Phase 8 stays closed as a split (RTL done,
three languages deferred). **Phase 11 is DEFERRED BY FOUNDER — do not
implement it.** **Phases 12 and 13 are COMPLETE. EVERY migration
001–026 is applied to production** (016 is deliberately unwritten) and
repository/production are in sync. Build `1.0.0+36`, 1455 tests.

**Phase 14 is IN PROGRESS — 4 of 8 features shipped. Read §2.0.0l
before anything else; it has the exact remainder.**

**The Phase-13 join-challenge blocker is FIXED and it was not what
anybody thought — read §2.0.0k. Five tables had been returning HTTP 500
in production since 2026-08-03, and blocking a user did nothing.**

---

## 1. Where we are

**Roadmap:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` — 18 phases, 5 waves.
Autonomous execution: no approval between phases. Each phase ends with
one `PHASE_NN_COMPLETION_REPORT.md`. Final deliverable at the very end:
`FORMAI_MASTER_COMPLETION_REPORT.md`.

| phase | state | report |
| --- | --- | --- |
| 1 · Rate & feedback loop | done | `PHASE_01_COMPLETION_REPORT.md` |
| 2 · Dynamic walkthrough I | done | `PHASE_02_COMPLETION_REPORT.md` |
| 3 · First-workout tutorial | done | `PHASE_03_COMPLETION_REPORT.md` |
| 3b · Phase-3 leftovers | done | `PHASE_3B_COMPLETION_REPORT.md` |
| 4 · Feature flags + disclosure | done | `PHASE_04_COMPLETION_REPORT.md` |
| 5 · i18n | done except 2 device surfaces | `PHASE_05_COMPLETION_REPORT.md` |
| 6 · English launch | done | `PHASE_06_COMPLETION_REPORT.md` |
| 6p · polish sprint | 12 of 12 done | `PHASE_06_POLISH_REPORT.md` |
| **7 · Content & AI localization** | **done + device walk** | `PHASE_07_COMPLETION_REPORT.md` |
| **8 · es / fr / de + RTL** | **closed as split** — RTL done, languages ⏸ deferred by founder | `PHASE_08_COMPLETION_REPORT.md` |
| **9 · Body metrics & trends** | **done + device walk** | `PHASE_09_COMPLETION_REPORT.md` |
| **9p · pre-Phase-10 polish** | **done + device walk** | `PRE_PHASE10_POLISH_REPORT.md` |
| **10 · Visual outcomes & reports** | **done + device walk** | `PHASE_10_COMPLETION_REPORT.md` |
| **11 · Accessibility** | ⏸ **DEFERRED BY FOUNDER** — full scope preserved | roadmap §PHASE 11 |
| **12 · Community I** | **done** | `PHASE_12_COMPLETION_REPORT.md` |
| **13 · Community II** | **done** — leaderboards, challenges | `PHASE_13_COMPLETION_REPORT.md` |
| **13p · pre-Phase-14 polish** | **done** | `PROJECT_PROGRESS_SUMMARY.md` |
| **14 · Content freshness** | **in progress — 4 of 8 shipped** (§2.0.0l) | `PHASE_14_PROGRESS_REPORT.md` |

**Branch:** `main`. **Build:** `1.0.0+36`. **Migrations 001–026 applied.**

---

## 2. Start here

### 2.0 Phase 7 is DONE — do not restart it

`PHASE_07_COMPLETION_REPORT.md` is the record. **Migrations 013, 014 and
015 are applied to production**, 392 recipes are 100 % translated, the
whole content pipeline is committed and re-runnable, and **the device
walk is done** — see §9 of that report for the six defects it found.

### 2.0.0 Phase 8 is CLOSED AS SPLIT — do not start the languages

**The founder deferred the international content half on 2026-08-02.**
It is a pause at full scope, **not a cancellation**, and the decision is
recorded in the roadmap's Phase 8 section and §0 of
`PHASE_08_COMPLETION_REPORT.md`.

**Done and kept:** RTL infrastructure, the RTL CI gate, the
directional-layout gate (`tool/check_directional_layout.dart`, ratchet
armed at 177), the two `CustomPainter` RTL fixes, the RTL sweep past the
paywall, and the directional audit.

**⏸ Do not touch without the founder saying so:** Spanish, French,
German, multilingual recipe content, multilingual exercise content, new
coach personas, per-locale ASO and store listings, regional pricing, the
translation-quality monitor, the market-selection method.

Two things the report says which save re-deriving:

- **The roadmap's "117 `EdgeInsets.fromLTRB`" is not RTL debt.** All 127
  of them are horizontally symmetric, so none mirrors wrong. The real
  surface is 121 directional `Alignment` and 55 `Positioned(left:/right:)`.
- **An `Alignment.centerLeft` does not overflow**, so no RTL layout sweep
  can ever catch it. That is why the static gate exists next to them.

Lowering the directional ratchet is **not** deferred — it is ongoing.
Each later phase converts the screens it touches and lowers the baseline;
the gate stops the number rising either way, so it needs no phase.

### 2.0.0b Phase 9 is DONE — read its report before Phase 10

`PHASE_09_COMPLETION_REPORT.md` is the record. Body metrics, the trend
maths, adherence, the coach wiring and a full device walk are all
shipped on `1.0.0+30`.

Four things from it that save re-deriving:

- **There is no onboarding goal weight and the app is not allowed to
  invent one.** `ai_personalization_engine.dart` carries a store-
  compliance rule against quantified outcome promises, which is why the
  12-week projection is qualitative. The target is stated by the USER
  and lives in `user_metrics.target_weight_kg`. Null is permanent and
  valid.
- **`017_body_metrics.sql` is written but NOT applied to production.**
  The feature is offline-first and complete without it; applying it is a
  separate safe step whenever the founder wants cross-device carry.
  It is 017 and not 013 because 013–015 are Phase 7's and 016 stays
  reserved for the unwritten `drop_legacy_tags`.
- **Blind spot #6: the layout sweeps were rendering spinners.** Fixed in
  `test/support/layout_probe.dart` and `locale_probe.dart`. Read those
  headers before writing another sweep.
- **The device walk found four defects**, two of which no gate in this
  repo can see (two controls saying the same thing; a FAB covering a
  delete button). See §8 of the report.

### 2.0.0c The pre-Phase-10 polish sprint is DONE

`PRE_PHASE10_POLISH_REPORT.md` is the record. Six founder tasks: the
exercise-image regeneration guide, the camera-free workout's dead
countdown, the "Your body" rebuild, a device walk, `+31` with both
artifacts, and the report.

Five things from it that save re-deriving:

- **`WorkoutSessionState.restSecondsRemaining` is the rest DURATION, not
  the remainder.** Tier-B.8 moved the live tick to
  `restCountdownProvider` and left the field frozen at rest entry. Any
  screen wanting a countdown must watch the provider. The camera-free
  screen did not, and shipped "40" for forty seconds.
- **Blind spot #8: a single lowercase word is the shape of a Dart
  identifier**, so `_isTechnical` in `check_hardcoded_strings.dart` was
  discarding every lowercase single-word label in the app before any
  label test ran. The gate now has a *rendered-argument* signal —
  `hint:` / `unit:` / `label:` / `title:` — which outranks the shape
  exclusions but deliberately NOT the composition one. Read its doc
  comment before touching it.
- **The "Your body" screen is hardcoded dark**, like the workout and
  camera screens, and uses a lime `#B8FF33` that is NOT
  `AppColors.neonGreen`. Both are the founder's reference; both are
  argued in the screen's class doc.
- **`assets/body_metrics/` is artwork cut out of the design comps** with
  the black background converted to alpha. `assets/new-assets/` is the
  comp source and is deliberately NOT bundled.
- **All 87 files in `photos/exercises/` carry burned-in text**, and they
  are infographics rather than captioned photos — the filmstrips carry
  the actual coaching content. Regenerating them without moving that
  copy into the catalogue loses it. Prompts are in
  `EXERCISE_IMAGE_REGENERATION_GUIDE.html`, regenerated by
  `tool/gen_exercise_image_guide.py`.

### 2.0.0d Phase 10 is DONE — do not restart it

`PHASE_10_COMPLETION_REPORT.md` is the record. All seven features, the
migration, the account-deletion contract and a full device walk are
shipped on `1.0.0+32`.

Six things from it that save re-deriving:

- **`ProgressPhotoRepository` has NO network code, and that is the
  feature.** No Supabase client, no `http`, no bucket, not behind a flag.
  `progress_photo_privacy_test.dart` is a RELEASE GATE the roadmap makes
  a shipping condition: it scans the source for any networking symbol AND
  drives the whole cycle with every socket refused. If cloud backup is
  ever built it goes in a SEPARATE opt-in service — an upload branch
  inside the repository fails the gate, which is the point.
- **The photo metadata migration is `018`, not the roadmap's `014`.** 014
  is Phase 7's `recipe_ingredients`. Written, deliberately NOT applied,
  like 017.
- **Account deletion has a device half.** `delete_user` and
  `prefs.clear()` do not touch the documents directory;
  `AuthController.deleteAccount` calls
  `ProgressPhotoRepository.deleteEverything()` and a test pins it.
- **Share consent is per-share and never persisted.** Every toggle is off
  every time the sheet opens. Photos are off, last, and only offered when
  photos exist.
- **The monthly recap is `OutcomeReportCard` wearing a different
  sentence**, not a second card. `isRecapDue` is keyed to the user's own
  start date, not the wall calendar.
- **The comparison wipe deliberately does NOT mirror in RTL** and says so
  in the code: the split comes from `localPosition.dx`, so mirroring
  would send the divider away from the finger. Same call Phase 8 made
  about the trend chart's time axis.

### 2.0.0e Phase 11 is DEFERRED BY FOUNDER — do not implement it

Decided 2026-08-02, immediately after Phase 10. **Wave 4 starts at
Phase 12.**

It is a pause at full scope, not a cut. Nothing in the roadmap's Phase 11
section has been deleted, reduced or redesigned — all nine features, the
effort estimate, C16–C20, C49 and the success criteria are preserved
exactly. The deferral banner is at the top of that section.

Two things recorded there so a resume does not redo work: some
accessibility already shipped incidentally (Semantics on the workout rep
controls, the range selector, the pose selector and the photo pickers;
the 1.3 text-scale sweeps in CI; reduce-motion in `SpotlightTour`), and
the one known contrast defect — the "See all" pill at **3.03:1 in light
mode** — is still open and still Phase 11's remit.

### 2.0.0f Phase 12 is BUILT — it is blocked on ONE founder decision

**Everything the roadmap lists for Phase 12 is implemented.** Do not
rebuild any of it. `PHASE_12_COMPLETION_REPORT.md` §4 is the section to
read, and it now says one thing:

> **`supabase/migrations/019_social_profiles.sql` is written, argued,
> statically gated and NOT applied.** Until the founder applies it,
> every community screen honestly reads "Community isn't switched on
> yet", and the live RLS penetration pass cannot be run at all.

Shipped: the migration, the pure domain rules (26 tests), the static RLS
gate (14), the repository, four screens (profile, friends, squads, feed),
the feed writer, the profile card share, the referral→friend bridge, the
entry point, and seven analytics events. 69 new tests; build 1.0.0+33.

Things that save re-deriving:

- **The migration is `019`, not the roadmap's `015`.** 015 is Phase 7's
  `recipe_origin_and_diet`. 013–015 applied, 016 reserved, 017 body
  metrics, 018 progress photos, 019 social. **017, 018 and 019 are all
  written and NOT applied.**
- **A block beats ownership beats publication**, in that order, in
  `ProfileVisibility.resolve`. `blocks` is readable only by the blocker:
  the blocked user must not discover the block.
- **`rls_policy_test.dart` executes no SQL and says so.** It checks the
  SHAPE. The live penetration pass is still owed — see the report §4.2.
  Its own block-direction regex was wrong once, on a correct migration.
- **The feed's backfill guard is a clock, not a predicate, and that was
  earned.** Two structural rules were tried and both were defeated by an
  async detail: `markSessionDayAwarded` is unawaited (so a backlog
  splits across passes), and badges unlock a microtask after the
  workouts they came from (so the first quiet pass is not proof). See
  the report §3.7 before "simplifying" it back.
- **Community screens use `lib/core/theme/neon_surface.dart`.** It was
  extracted when the third screen wanted it. It is deliberately not a
  `ThemeExtension` — the reasoning is in its class doc.
- **`CommunityRepository`'s constructor reads `Supabase.instance`**, so
  a test that subclasses it must pass `client:` or it asserts.
- **A uiautomator dump with no text nodes is not an empty screen.** The
  community unavailable state dumps blank and screenshots correctly.

### 2.0.0g What Phase 12 deliberately did NOT build

Not loose ends — decisions, recorded in the report §4.3:

1. **Avatars.** An image upload is a moderation surface, and this
   phase's whole position is that it carries no free content to
   moderate. The schema's `moderation_state` column is ready for it.
2. **Coach squad awareness.** Belongs with the coach's copy engine, and
   the coach has no squad-shaped input yet.
3. **Ranking of any kind.** The feed shows presence, not position. The
   roadmap puts ranking in Phase 13 on purpose.

### 2.0.0h Phase 13 is DONE — leaderboards and challenges are live

`PHASE_13_COMPLETION_REPORT.md` is the record. Build 1.0.0+34, 1376
tests, `020_leaderboards.sql` applied to production.

Things that save re-deriving:

- **`020` is the leaderboard migration.** The roadmap calls it `016`,
  which is reserved. 001–015 + `019` + `020` are applied; **`017` (body
  metrics) and `018` (progress photos) are still NOT applied** and were
  deliberately excluded — the approval named `019`, and those two would
  begin server-side storage of measurements and photo metadata.
- **The XP anti-gaming guarantee is a BOUND, not a promise**, and the
  migration header says so at length. XP is client-authoritative; the
  CHECK constraints and the plausibility trigger make the implausible
  impossible but cannot tell an honest week from a fabricated one.
  Eliminating that needs server-side session recording — Phase 15.
- **The caps exist twice** (`020` and `lib/features/community/domain/
  league.dart`) and `league_test.dart` reads the SQL to assert they
  match. Change one, change both.
- **Beginner protection is three constants in the domain layer** —
  `defaultScope`, the metric enum's declaration order, and
  `kRankTellsPosition`. They are there so they cannot be changed by
  editing a widget. Do not "simplify" them into the screen.
- **Pseudonymity and opt-out add no fields.** A private profile is
  ranked without a name because `public_profiles_select_published`
  requires `is_public`; opting out is deleting the `leaderboard_stats`
  row. There is no `opted_in` column and there should not be one.
- **The RLS gate was green about a file it had never opened.** It now
  reads every migration in `communityMigrations` — add to that list when
  you add a community migration. Its content-table exemption is derived
  from the schema (no `user_id`, no `auth.users`), not from a marker.
- **`supabase db push` from the repo root fails** — the CLI tries to
  parse `.env.local` as dotenv and it is freeform notes. Push from a
  staging workdir instead (copy `supabase/migrations` minus 017/018 plus
  `.temp/linked-project.json`, then `supabase link --project-ref
  xtvqhnjamwvmfcsahzxv`). Never source `.env.local`.
- **A policy cannot reference a table declared below it.** `019` failed
  its first push on exactly that (`blocks` under `public_profiles`).
  Migrations run in one transaction, so a failure rolls back whole.

### 2.0.0i What Phase 13 deliberately did NOT build

Recorded in the report §4.1–§4.3. Not loose ends:

1. **The weekly league rollover job.** Rules are written and tested;
   nothing writes a tier, because promotion is a scheduled server job
   and two clients computing it disagree. The Dart is the spec.
2. **Challenge content.** The table is live and empty; what to run is a
   founder call. `supabase/sql/seed_challenge_example.sql` is a
   documented one-paste template.
3. **Challenge progress auto-reporting**, tier artwork, coach rank copy,
   and 100k-user load testing — each blocked on one of the above or on
   data that does not exist yet.

### 2.0.0j PRE-PHASE-14 POLISH IS DONE · PHASE 14 IS NOT STARTED

Build **1.0.0+36**, **1384 tests**, all gates green, APK + AAB built.
Everything below already shipped — do not redo it.

**Task 1 · migrations.** 017, 018, 021, 022 applied. `supabase migration
list --linked` shows local == remote for 001–022. Push from a staging
workdir (see §2.0.0h) — never from the repo root, the CLI chokes on
`.env.local`. Out-of-order migrations need `--include-all`.

**Task 2 · bottom navigation.** Five tabs: Training · Nutrition ·
Progress · **Community** · Profile. Rebuilt as a custom bar because
`BottomNavigationBarType.fixed` shows every label always and 82 dp
cannot hold "Antrenman" beside a 24 dp icon. Capsule behind the selected
icon, label underneath at 10.5 sp in a `FittedBox`.
`kBottomNavItemCount` is the single source of truth for the tour's slice
count — **change it and the tour silently spotlights the wrong tab.**

**Task 3 · `SUPABASE_SCHEDULED_JOBS_GUIDE.md`** — complete, including
the full rollover function. Two of the four jobs asked for turn out not
to be jobs (challenge expiry and activation are a timestamp comparison),
and notifications stay on the device on purpose.

**Task 4 · challenges.** Six launch challenges live in production via
migration `021`. **Six of the ten suggested were refused** because the
engine cannot measure them — the reasoning is in `021`'s header and it
is the important part. Challenge progress now advances, hooked into the
XP listener beside the session ledger.

**Task 5 · production review — FOUR RLS HOLES FOUND AND FIXED.** See
`022`. Read this even if you read nothing else: inside a policy,
`m.squad_id = squad_id` is `m.squad_id = m.squad_id`, always true. Three
of the four had been live since community shipped, one was a write hole.
`rls_policy_test.dart` now catches the class, precisely (it reads each
table's real columns, so `s.id = squad_id` over `squads` is correctly
allowed).

**Known, unresolved, and worth an hour:** joining a challenge from the
device does not persist. The tap registers (Back works from the same
coordinates), no exception reaches logcat, and the card stays on "Join".
`joinChallenge` returns false somewhere between `isOpen` and the upsert.
It was NOT diagnosed — the anon key could not be read this session, so
no direct PostgREST query was possible. **Start here: run the insert by
hand in the SQL editor as a real user id and see what RLS says.**

### 2.0.0k THE JOIN BLOCKER IS FIXED — and five tables were down

`023_rls_recursion_and_block_direction.sql`, applied to production.
`PHASE_14_PROGRESS_REPORT.md` §0 is the full record. The short version,
because every line of it is worth knowing:

- **A policy that queries its own table recurses.** Postgres applies RLS
  to the tables a policy expression reads *including the one the policy
  is on*, so it re-enters itself: `42P17`, on every request, forever.
  `squad_members_select_member` and `challenge_participants_select_peers`
  both did it. `squads`, `activity_events` and `activity_reactions`
  reference `squad_members` in their own policies and died with it.
  **Squads and the whole activity feed had never worked in production.**
- **`022` did not cause it.** Its subject was a different defect in the
  same two policies. Qualifying a column name does not change which
  table a subquery reads.
- **Blocking a user did nothing to their view of you.** `blocks` has its
  own RLS, a policy expression runs as the querying user, so the
  "someone blocked me" half of every symmetric check could never match.
  The blocker's half worked, which is why it survived review. Proved
  with two real accounts, before and after.
- **The fix is three `security definer` helpers in a `private` schema.**
  Private, not public: PostgREST serves `public` functions, and
  `public.is_blocked_with(uuid)` would be an enumerable "did this person
  block me?" endpoint. It takes ONE argument and answers only about the
  caller.
- **"No exception in logcat" was the wrong evidence.** `AppLogger.error`
  prints only under `kDebugMode`; in the release build the founder
  tested, it went to Sentry. In a release build, nothing in logcat is
  not no exception.
- **The gate now catches the class, and all five new checks were probed
  against the real defect.** The old "a block is checked in both
  directions" test was deleted rather than adjusted — it passed
  throughout the entire outage, because every check *was* symmetric and
  the data it read was not. Fifth time a gate here has been green about
  its own subject.

**Both of these are structural, not incidental. Before adding any
policy: it may not read its own table, and it may not read
`public.blocks`. Use the `private.*` helpers.**

**And then exercising the WRITES found a third one — `026`.** With every
table answering 200, **no user could create a squad.**
`createSquad` does `.insert({...}).select().single()`, and `.select()`
means `RETURNING`; Postgres applies the SELECT policy to a returned row,
and `squads_select_member` requires a `squad_members` row that
`createSquad` writes on the *next line*. `026` lets an owner read their
own squad, which is strictly less than `squads_update_owner` and
`squads_delete_owner` already grant them.

**A read probe cannot find that class.** Verify writes separately, and
remember that `.select()` after an insert silently adds a SELECT-policy
requirement to the write.

### 2.0.0l Phase 14 — IN PROGRESS · 4 of 8 features shipped

`PHASE_14_PROGRESS_REPORT.md` is the record and §5 is the exact
remainder. **Do not restart what is done.**

**Shipped:** migration `024` (`content_releases`, `content_drops`) and
`025` (seven rotating challenges — 13 live now), the What's New screen
with its route and dashboard trigger, `content_sync_service.dart`,
`program_progression.dart`, `lifecycle_campaigns.dart`,
`localized_copy.dart`, `docs/CONTENT_OPS.md` BÖLÜM II, all six analytics
events, and a real release note live in production for build 36.
+65 tests.

**Built but with NO SURFACE — this is the whole remainder:**

1. **Continuation paths screen** (day-31). Rules and **all ARB copy**
   already exist. Needs a screen that builds a `ProgramOutcome` from
   `workoutSessionProvider.days`, calls `recommend()`, renders four
   cards with one marked, and fires `programContinuationChosen`.
2. **Difficulty-tier wiring.** `DifficultyTier.token` matches the
   generator's `fitnessLevel` strings and a test pins it; nothing passes
   a chosen tier back into generation yet.
3. **New-content discovery surface.** `ContentDrop` + targeting + ARB +
   `seenContentDrops` all exist; no screen renders `drops()`.
4. **Campaign scheduling.** `nextCampaign()` is complete and tested;
   needs a `CampaignSend` ledger in prefs, ARB bodies, and
   `NotificationService` methods.

Four things that save re-deriving:

- **A release note is keyed to a BUILD NUMBER, not a date.** Play rolls
  a release out over days, so on release day both populations exist and
  a date-keyed note describes, to half of them, an app they do not have.
- **"Have you read it" is device state.** `024` has no `user_id`
  anywhere, so the tables hold nothing RLS must protect.
- **The sync cache stores raw JSON rows, not parsed objects**, so a
  client that learns a new field reads it out of a cache written by one
  that did not.
- **`recommend()` never advances a struggling user, and a tier advance
  carries no volume bump.** Both are the point, not an oversight.

**NOT verified: there was no device walk.** `adb devices` was empty all
session. The join fix is verified by reproducing the client's exact
PostgREST request as a real authenticated user, which shows the status
code and the row — but nothing was seen on a screen. **What's New has
never been rendered on a device.** No APK/AAB built; build not bumped.

### 2.0.1 The three things Phase 7 deliberately did NOT do

1. **`016_drop_legacy_tags.sql` is not written.** It drops
   `recipes.tags` and trims the `MALZEMELER:` half out of
   `instructions`. Both are safe only after a release carrying the
   013/014 readers has been live long enough that the old client is
   gone. Writing it now invites somebody to apply it now.
2. **The English has not been read by a native speaker.** 392 recipes of
   reviewed draft. The gate proves no Turkish survives; it cannot prove
   the English reads well.

### 2.0.2 How to run the content tooling

Everything is idempotent and everything writes a file a human reads
before it is applied. Nothing here talks to the database.

```bash
# validate a proposal batch without writing anything
dart run tool/recipe_pipeline/pipeline.dart \
    --proposals tool/recipe_pipeline/proposals/western.json \
    --catalogue <live_catalogue.json> --dry-run

# regenerate the proposal files from their Python briefs
python3 tool/recipe_pipeline/proposals/western.py
python3 tool/recipe_pipeline/proposals/international.py

# rebuild the English catalogue SQL
python3 tool/recipe_pipeline/translations/ingredients_en.py > out.sql
python3 tool/recipe_pipeline/translations/build_recipe_en.py \
    --catalogue <dump.json> > out.sql

# the gate, and its ratchet
dart run tool/recipe_translation_audit.dart
dart run tool/recipe_translation_audit.dart --list
dart run tool/recipe_translation_audit.dart --update-baseline

# the closest thing to a device walk without a device
flutter test --tags live \
    test/features/nutrition/live_catalogue_read_path_test.dart
```

`<live_catalogue.json>` and `<dump.json>` are dumps of the `recipes` /
`recipe_ingredients` tables. The introspection recipe is §7 below.

### 2.1 What Phase 6 left for someone else

**English screenshots and feature graphic**, and pasting
`docs/store/LISTING_EN.md` into Play Console → Manage translations. The
listing copy is written.

**Play Console pricing** — `docs/store/PRICING_SETUP.md` is the whole
procedure. **The price is decided** (§2, 2026-08-01): $3.99 / $9.99 /
$49.99 USD, yearly Most Popular, Turkish unchanged at ₺100 / ₺400 /
₺1200. What remains is Console + RevenueCat configuration; creating
`formai_pro_weekly` is what makes the weekly card appear, with no app
release.

**The clean-install onboarding is now WALKED** — Phase 9 did the full
19-step run on the Redmi, age gate to dashboard. **The paywall interior
remains the one unverified surface**, carried since Phase 5; it is
auth-gated and destroys the session.

**Meal and workout photographs.** `docs/nutrition/MEAL_IMAGE_REQUESTS*.md`
and `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`. Nothing is broken while those
directories are empty — both fall back to real photography, and both
resolve from the asset manifest, so dropping a correctly-named file in is
the entire procedure.

## 3. Current numbers

```
analyze                     0 issues
tests                       1298
hardcoded-string gate       0 in 0 files  (allowlist 246, printed per entry)
ARB                         1687 keys · tr 100% · en 100% · all referenced
recipe catalogue            392 rows · en 392/392 · 2242 ingredient rows
recipe translation audit    0 findings · baseline armed at 392
locales shipped             tr, en
pseudo-locale sweep         18 surfaces × 3 viewports, scrolled through
English sweep               17 funnel + 5 app surfaces × 2 text scales
RTL sweep                   16 surfaces
CI                          green
build                       1.0.0+32 · APK 136.7 MB · AAB 115.8 MB
device walk                 DONE for Phase 10 — 1 defect found, fixed, re-walked
RTL sweep                   18 surfaces (body metrics added)
working tree                clean except pre-existing untracked founder files
```

`macos/Flutter/GeneratedPluginRegistrant.swift` has been modified since
before this session started. It is **not ours** — leave it.

---

## 4. How to verify anything

**Run ALL of these before every push, not the ones you changed code
near.** CI went red once in Phase 12 because the hardcoded-string gate
was skipped after a commit that only touched a repository — the tests
and the formatter were run and passed, and the gate would have caught a
Postgres error fragment in one second. A subset is not a check.

Note `dart format` too: CI runs it over **`.`**, not `lib test tool`.


```bash
flutter analyze                                   # must be 0 — CI fails on infos too
flutter test                                      # 1070
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_hardcoded_strings.dart        # ratchet, currently 0
dart run tool/check_hardcoded_strings.dart --list # every flagged line
dart run tool/arb_coverage.dart --strict          # parity, plurals, EN audit
dart run tool/gen_pseudo_localizations.dart --check
dart run tool/recipe_translation_audit.dart       # the CATALOGUE, not the UI
dart run tool/check_directional_layout.dart      # RTL ratchet, currently 177
dart run tool/check_directional_layout.dart --list
```

All of these are CI steps. `flutter analyze` exits 1 on **info**-level lints,
which is how CI was red for four commits before this session noticed.

---

## 5. Gotchas that cost real time

1. **CI Flutter is 3.44.8, local is 3.41.9.** Newer framework assertions
   and lints cannot fire locally. *Local green ≠ done.* Always confirm
   CI. This has bitten four times: an `ExpansionTile` in a
   `DecoratedBox`, an orphaned `_EmptyState`, an unused ML Kit import,
   and six `curly_braces_in_flow_control_structures` infos.
2. **`dart format` moves trailing comments.** `// i18n-ignore` must be on
   the literal's own line *after* formatting. If the line is too long,
   hoist the literal to a named constant, or reorder `||` operands so
   the marked literal is not last.
3. **Localising a literal invalidates every enclosing `const`**, and the
   analyzer reports the innermost position. Loop: analyze → strip →
   repeat. The scratch `fixconst.sh` automates it.
4. **Widget tests need `localizationsDelegates`.** Missing ones throw
   "Null check operator used on a null value" from `AppLocalizations.of`.
   Adding the delegates makes the harness render the *same* Turkish, so
   every original assertion must still pass. If an assertion needs
   rewording, that is a real copy change — think about it.
5. **adb.** `adb devices` empty → `kill-server` / `start-server`.
   Displayed screenshot 923×2000 vs device 1080×2340 → **×1.17** for
   taps. `keyevent 111` dismisses a bottom sheet. `input text` breaks on
   spaces. Blind-tapping through a screen silently dismisses a
   `SpotlightTour` — any tap advances it — burning the one-shot.
6. **The founder's other app** `com.ehliyetegitim.ehliyet_akademi` steals
   foreground focus: `adb shell am force-stop` it before verifying.
7. **The local build is upload-key signed.** If the installed build came
   from Play, `install -r` fails `INSTALL_FAILED_UPDATE_INCOMPATIBLE` and
   you must `adb uninstall` first — which loses the session and forces a
   19-step onboarding re-walk. +24 installed over +23 cleanly, so both
   are currently upload-signed.
8. **`dart format` also moves an `// i18n-ignore` that follows an
   opening brace**, not just a long line — `if (x) { // i18n-ignore`
   becomes a comment on the block's first line. When a marker will not
   stay put, hoist the literal to a named top-level constant; that is
   what `auth_error_messages.dart` does now.
9. **An overflow is reported from `paint`, not layout.** A viewport
   paints its visible area plus a 250 px cache extent, so a broken
   widget further down a scroll view is silently clean. `scrollThrough`
   in `test/support/layout_probe.dart` is why the sweeps see it.
10. **Widening the gate means adding a SIGNAL, not removing an
    exclusion.** Un-excluding a literal still leaves it failing the
    Turkish and label tests, so the count stays at zero and looks fine.
    Prove any widening with a synthetic probe file under `lib/`.
11. **MIUI revokes "Install via USB".** `INSTALL_FAILED_USER_RESTRICTED`
    is not a signing problem and no adb flag works around it —
    `install -r`, `-d`, `-t` and push-then-`pm install` all fail
    identically. It needs a Mi-account re-authorization on the handset.
12. **A green gate is a claim about its own heuristics.** Twice now a
    rule written to catch a class of bug did not fire on that exact bug.
    The `%82` case had TWO independent reasons and the first fix looked
    correct while the gate still reported zero. Only a synthetic probe
    file under `lib/` found it. Probe every widening.
13. **`TextOverflow.fade` on a sentence hides that it was cut.** The
    social-proof privacy claim read as a complete, shorter, false
    sentence. Use `ellipsis` so an overflow looks like one.
14. **Never source `.env.local`.** It is freeform notes, not dotenv, and
   sourcing it *executes* `flutter build apk`. The Supabase CLI also
   parses `./.env.local` as dotenv and fails on it, which is why the CLI
   is always run from a scratch dir holding a copy of `supabase/`.
15. **Dart's `caseSensitive: false` does not fold `Ç→ç`.** A regex meant
   to match a Turkish proper noun case-insensitively silently misses the
   title-cased form. Fold explicitly.
16. **The Turkish fold (`I→ı`) is wrong for English text.** Applying it
   to a string that is supposed to be English turns `INGREDIENTS` into
   `ıngredıents`. The right fold depends on which language you are
   reading, not on which language the app is in.
17. **Scrub a term list longest-first.** `köfte` removed before
   `çiğ köfte` can match leaves a bare `çiğ` behind and reports it as an
   untranslated word.
18. **Substring matching on short Turkish words is a trap.** `un`
   (flour) is inside `olgun` and `limonun`; `bal` (honey) starts
   `balık`, `balığı` and `balzamik`; `hindi` (turkey) starts
   `hindistan cevizi`; `su` (water) starts `sucuk`. Match at a word
   start and keep an explicit not-followed-by list.
19. **`isKeyguardShowing=true` does not mean PIN-locked.** It is also
    what an asleep phone reports. Wake it and call `wm dismiss-keyguard`
    before concluding anything; `locksettings get-disabled` and
    `settings get secure lockscreen.password_type` distinguish a
    non-secure keyguard from a real credential. This one line cost two
    phases of "physically unverifiable" device work.
20. **A client-side filter over a paginated list lies, and scrolling
    does not fix it.** The filtered view is short, so it never reaches
    the bottom that triggers the next page — the wrong count is stable,
    which is what makes it convincing. Push the predicate into Postgres.
    This has now been the same bug twice: the category screen in Phase
    83, the discovery chips in Phase 7.
21. **A test written from the code's own assumption agrees with it.**
    `recipe_detail_screen_test.dart` asserted `find.text('LUNCH')` inside
    a `Locale('tr')` host and passed for as long as the bug existed. When
    a test encodes a raw token, a hardcoded colour or an untranslated
    string as *expected*, it is pinning a defect, not guarding against
    one.
22. **`Colors.white` on a `tint.withValues(alpha: 0.18)` fill is a
    light-mode bug every time.** Over a dark scaffold the fill is dark
    and white is right; over a light one it is a pastel and the label
    measures ~1.3:1. Third occurrence in this app. When a badge sits on a
    *photograph* the theme is the wrong thing to branch on — the backdrop
    does not change — so that case needs its own explicit flag.
23. **A parse marker embedded in content is per-language.** Phase 7 made
    `instructions` bilingual, so a splitter that knew only `MALZEMELER:`
    silently matched nothing on English rows and fell through to a
    render-the-whole-blob branch. Localise the *marker list*, never the
    marker.
24. **"Applies live" has to include content, not just chrome.** The
    language picker flipped every ARB string instantly and left the whole
    recipe catalogue in the old language until restart, because the
    repository resolves language at decode time and nothing invalidated
    the rows already fetched. Anything that caches server data keyed by
    locale needs to watch `localeProvider`.
25. **A single `pump()` renders the frame where every async provider is
   still loading.** For two years the layout sweeps proved that spinners
   do not overflow. Found by injecting a 3000 px overflow into a screen
   all three suites covered and watching every one still pass. Drain
   microtasks with bounded zero-duration pumps — never `pumpAndSettle`,
   which hangs on this app's infinite animations.
26. **`git add -A` in this repo stages the founder's private planning
   material.** Fifteen files, deliberately untracked for eight phases,
   went into a PUBLIC repository. They are gitignored now. Stage paths,
   not wildcards.
27. **A formatter's default is an argument about a use case, not a
   fact.** `formatWeight` rounds to whole units because a profile card
   wants that; on a screen about small changes over time it silently
   destroyed the tenth the user typed. Read *why* a default exists
   before inheriting it.
28. **Running a subset of the gates is not running the gates.** CI went
   red in Phase 12 after a commit where the tests and the formatter were
   run and the hardcoded-string gate was not. It takes one second and it
   caught a Postgres error fragment (`'does not exist'` — two lowercase
   words with a space, exactly what `_labelShape` is for). §4 lists them
   all; run them all.
29. **A rendered argument is a signal the shape rules cannot supply.**
   `'dakika'` and `'padding'` are the same shape — one lowercase word —
   so the hardcoded-string gate's identifier exclusion swallowed every
   lowercase label in the app. What separates them is the parameter they
   are passed to. Signal, not un-exclusion, and the probe caught the
   first draft over-reaching twice.
30. **A recipe seed must be idempotent by a stable id.** Ids are derived
   from the proposal slug via `uuid_generate_v5`, so re-running after an
   edit updates instead of duplicating the catalogue — and the duplicate
   check has to exclude the batch's own earlier rows, or the second run
   rejects everything the first one wrote.
31. **A policy may not read the table it is attached to.** Postgres
   applies RLS to a policy expression's own table, so it re-enters the
   policy: `42P17`, on every request. Five tables were down in
   production for a day because of two such policies. Route the
   predicate through a `security definer` helper.
32. **A policy may not read `public.blocks` either**, for the same
   reason one layer along: `blocks_select_own` hides the row from the
   blocked user, and a policy runs as the querying user, so the
   "someone blocked me" direction never matches. Every block check in
   this schema was symmetric and none of them worked.
33. **A `security definer` helper belongs in `private`, not `public`.**
   PostgREST serves `public` functions as RPC, so
   `public.is_blocked_with(uuid)` would be an enumerable oracle.
34. **In a release build, nothing in logcat is not no exception.**
   `AppLogger.error` prints only under `kDebugMode` and captures to
   Sentry otherwise. This misread cost a whole phase's diagnosis.
35. **Copy the migration into the staging workdir before pushing**, and
   copy ALL of `supabase/.temp/` — the `project-ref` file matters, not
   just `linked-project.json`. `025` went in before `024` this session
   because only `025` had been copied across.
36. **`library;` goes above the imports, not below them**, and a `$$`
   function body's semicolons break any `split(';')` SQL parser.

---

## 6. Architecture decisions from Phase 5

- **One string = one ARB key = one whole sentence.** Never concatenate
  localised fragments; clause order is not universal. When part of a
  sentence needs styling or a tap target, keep the sentence whole and
  split it at render time with `core/utils/text_span_split.dart`.
- **Copy in a `const` catalogue** becomes `String Function(AppLocalizations)`
  and the collection drops `const`. Tokens stay literal.
- **Three things are not copy**, each marked `// i18n-ignore` with a
  reason: data identity (values that come from Supabase), prompt
  scaffolding (never rendered; Phase 7 does per-locale personas
  server-side), and diagnostics (the gate skips these automatically).
- **`core/utils/app_copy.dart` is the one locale source for tree-less
  surfaces** — notifications, home widget, TTS. `main.dart`'s
  `localeResolutionCallback` assigns it.
- **Pseudo-localisation lives in `test/`**, generated from the generated
  localisations class. Not a third ARB — that would put a second
  ~1300-method class in the release binary and a resolvable language
  code in `supportedLocales`.
- **Layout assertions are "no overflow", not "these pixels".** No image
  goldens; reasoning in `docs/i18n/README.md`. Phase 6 held to this
  against the roadmap's "10 goldens" and met the intent with 22 surfaces
  asserting no-overflow and no-Turkish instead.

## 6b. Architecture decisions from Phase 6

- **`Locale?` where null means follow the device.** "Never asked" and
  "chose Turkish" are different states; the first tracks a phone whose
  language may change. Choosing device-follow stores the token `system`
  rather than clearing the key, so an explicit reset is durable.
- **The picker applies live.** Someone who cannot read the current
  language should not have to trust a label they cannot parse.
- **`deviceLocale()` for "what would happen if you had not chosen".**
  `Localizations.localeOf` returns the active locale, which is the
  override when there is one.
- **Personas are authored per locale, never translated**, and selection
  is server-side so a language ships without an app release. The prompt
  scaffolding — including the summariser — goes with the persona: its
  output becomes the coach's memory, so summarising in the wrong
  language poisons every later turn.
- **American English**, recorded in `docs/i18n/GLOSSARY.md`. The Phase 6
  draft mixed both varieties and read unproofed.
- **The gate is bilingual.** An English literal in `lib/` is as wrong as
  a Turkish one.

## 6c. Architecture decisions from Phase 7

- **A tag TOKEN belongs in the database; a tag LABEL belongs in ARB.**
  The moment one column tries to be both, the catalogue cannot be
  translated without breaking navigation. `recipe_tags` keeps label
  columns anyway — they are what the audit checks and what the pipeline
  writes, not what the app reads.
- **One recipe, one language.** `resolveRecipeLanguage` decides per ROW,
  not per field. An English title over Turkish steps reads as a bug
  rather than as untranslated content, and it is exactly the state a
  half-finished translation pass leaves rows in. Ingredient names are
  part of that decision.
- **The fallback is Turkish, never English.** `title` is `not null` on
  every row; `title_en` may not exist. Falling back to a possibly-null
  column produces blank cards.
- **`locale_scope` orders, it never filters.** Filtering is one line
  shorter and looks obviously correct; it halves the catalogue for
  everyone. Three ranks, not two — a recipe scoped to another language
  still appears, last.
- **A quantity never passes through a translation.** The `INGREDIENTS:`
  half of every `instructions_en` is ASSEMBLED from `recipe_ingredients`,
  which is what migration 014 was for. Only method steps are authored by
  hand. That makes "never translate a unit" a property of the pipeline
  rather than a rule somebody has to remember.
- **A unit is NAMED, never converted.** `yemek kaşığı` → `tbsp`, not
  `15 ml`. `unit_system.dart` is where conversion belongs and a value
  converted during translation cannot be converted back.
- **`halal` is never derived; `pork_free` is.** Halal depends on how an
  animal was slaughtered, which no ingredient name records. Conflating
  them is what makes an app untrustworthy in a market.
- **An unrecognised ingredient silences the whole recipe.** A missing
  `vegan` flag costs one filter; a wrong one serves a vegan yoghurt.
- **The model never writes to the database, and a rejected proposal is
  deleted rather than repaired.** Repairing means another pass over
  output already known to be wrong.
- **Two copies of a mapping are acceptable only when something proves
  they agree.** The unit glossary is in Dart and in Python because one is
  a Flutter app and the other is a build script;
  `test/tool/unit_glossary_parity_test.dart` is what makes that safe.
- **The cross-check between independent sources is where the defects
  are.** Every Phase 7 finding in pre-existing content came from
  comparing two things nobody had compared: hand tags against derived
  flags, English names against Turkish ones, a new macro rule against an
  old catalogue.

---

## 7. Migrations

`001`–`015` applied to production and verified live.

Phase 7 added three, each independently shippable and each a no-op for
existing clients until the one after it lands:

- **`013_recipe_tag_tokens.sql`** — `recipe_tags` registry,
  `recipes.tag_tokens` + GIN index, backfill from the Turkish `tags`
  column. `tags` deliberately left in place.
- **`014_recipe_ingredients.sql`** — the structured ingredient table plus
  `recipe_ingredient_coverage`. `instructions` deliberately keeps its
  `MALZEMELER:` half.
- **`015_recipe_origin_and_diet.sql`** — `cuisine`, `diet_flags`,
  `locale_scope`.

**`016_drop_legacy_tags.sql` is NOT written**, on purpose. See §2.0.1.

Seed and patch files live in `supabase/sql/phase07_*.sql` and are all
re-runnable.

Supabase CLI notes: run it from a scratch dir holding a copy of
`supabase/` (it parses the repo's `.env.local` as dotenv and fails); the
direct DB host is IPv6-only so use the **session pooler** at
`aws-0-eu-west-1.pooler.supabase.com:5432` with user
`postgres.<project-ref>`; there is no `psql` on this box — a venv with
`psycopg2` is the introspection tool, and the DB password is in
`.env.local` (read it, never source it).

`supabase functions deploy coach-chat --no-verify-jwt` is how the edge
function ships; it needs the same scratch-dir treatment.

---

## 8. Known limitations

- **The practice rep and the "Seni görüyorum" success stage have never
  been seen on a device.** Both need a person standing ~2 m back doing a
  squat. Not drivable over adb. Carried since Phase 3.
- **`RequiredView` is defined and tested but not applied per exercise** —
  needs catalogue view metadata; belongs with a content pass.
- **English has not been read by a native speaker.** It is a reviewed,
  internally consistent draft with accurate key descriptions.
- **The physical-data wheels are still metric-only.** Settings exposes
  Metric/Imperial and the profile editor honours it, but the onboarding
  wheels are labelled `cm`/`kg` directly.
- **`photos/exercises/` carries burned-in captions in two languages.**
  The 87 instructional panels have text in the pixels — some English,
  some Turkish — so each language sees the other's on some exercises.
  A content project, not an engineering fix. See
  `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` §5.
- **`ExerciseMediaRegistry` still needs a code edit per file**, unlike
  the manifest-driven `WorkoutBackgroundRegistry` beside it.
- **51 of 138 exercises have no background of their own** and render
  their category's art. Prompts are in the request doc.
- **The EXERCISE catalogue is still Turkish.** Migration 011 localised
  both tables and Phase 7 only did recipes. 138 exercise rows with
  `name`, `description` and `short_tip` render in Turkish inside the
  English app, visible on the workout screen. The same resolution layer
  from `recipe_localization.dart` serves them — but the instructional
  images carry burned-in text in two languages, which is a content
  project of its own.
- **Nine recipes make no dietary claim.** Granola (×8) and Thai green
  curry paste (×1) are genuinely two different foods sold under one name,
  so the classifier stays silent rather than guessing. That is correct,
  not a gap.
- **The "See all" pill measures 3.03:1 in light mode** — legible but
  below AA for its size. Pre-dates Phase 7; contrast is Phase 11's remit,
  so it is logged there rather than spot-fixed.
- **A locally-built `--debug` APK renders the bottom-nav labels as an
  oversized clipped "For…".** Release is correct in both languages and
  both themes; not diagnosed further.
- **`Positioned` with explicit `left:`/`right:`** remains in a few
  decorative overlays. `PositionedDirectional` when next touched.
- **Google Sign-In is broken** and is a founder-side Google Cloud SHA-1
  registration task, not an engineering one. Email and guest work.
  Details in `FORMAI_CONFIGURATION_MASTER_GUIDE.md` §2.

---

## 9. Files that matter

```
tool/check_hardcoded_strings.dart      the ratchet + allowlist (read its header)
tool/arb_coverage.dart                 parity, unused keys, plural audit
tool/gen_pseudo_localizations.dart     generates test/support/pseudo_localizations.dart
tool/hardcoded_strings_baseline.json   per-file counts; currently empty
tool/check_directional_layout.dart     RTL ratchet — read its header for what it does NOT flag
tool/directional_layout_baseline.json  per-file counts; armed at 177
test/i18n/rtl_app_sweep_test.dart      RTL past the paywall (the older sweep is funnel-only)

lib/l10n/app_en.arb                    TEMPLATE — values AND @key metadata
lib/l10n/app_tr.arb                    values only (house convention)
lib/core/utils/text_span_split.dart    splitHighlighted / splitLinked
lib/core/utils/pseudo_locale.dart      pseudoLocalize
lib/core/utils/app_copy.dart           locale for tree-less surfaces
lib/core/utils/unit_system.dart        metric/imperial, storage always metric
lib/core/utils/price_format.dart       scaleStorePrice — separators from the store

test/support/layout_probe.dart         sweepPseudoLayouts / sweepRtlLayout
test/i18n/pseudo_locale_sweep_test.dart
test/i18n/rtl_readiness_test.dart
test/i18n/english_locale_sweep_test.dart  17 funnel surfaces, in English
test/i18n/english_app_sweep_test.dart     5 post-onboarding surfaces
test/i18n/locale_resolution_test.dart     the policy + the hot switch
test/support/locale_probe.dart            expectNoTurkish — the second detector

docs/i18n/README.md                    the runbook — read before touching a string
docs/i18n/GLOSSARY.md                  never-translate + legally load-bearing claims
docs/i18n/TEXT_IN_IMAGES.md            verdict: no image carries localisable text
docs/i18n/ADDING_A_LOCALE.md           what a second locale costs
docs/store/LISTING_EN.md               English store copy + what is founder-side
docs/store/PRICING_SETUP.md            Play/RevenueCat pricing, and the USD ladder problem
WORKOUT_BACKGROUND_IMAGE_REQUESTS.md   51 exercises, filenames + prompts
PHASE_07_NUTRITION_I18N_PLAN.md        the plan; NOT started

lib/features/workout/data/workout_background_registry.dart  manifest-driven art
tool/coach_eval.md                     the 12 scenarios, now in both languages

tool/recipe_translation_audit.dart     the CATALOGUE gate — titles, steps, ingredients
tool/recipe_translation_baseline.json  its ratchet; en coverage may rise, never fall
tool/recipe_pipeline/ingredient_parser.dart   MALZEMELER: → rows; reports, never guesses
tool/recipe_pipeline/diet_classifier.dart     ingredient → diet flags, TR and EN tables
tool/recipe_pipeline/recipe_proposal.dart     the deterministic validator
tool/recipe_pipeline/pipeline.dart            generate → validate → cost → review → seed
tool/recipe_pipeline/proposals/*.py           the 100 authored recipes, as briefs
tool/recipe_pipeline/translations/*.py        the glossaries and the assembler

lib/features/nutrition/domain/recipe_localization.dart   one recipe, one language
lib/features/nutrition/domain/recipe_tag_token.dart      token → label + style
lib/features/nutrition/domain/models/recipe_ingredient.dart  localizedUnit lives here
lib/features/nutrition/data/recipe_image_registry.dart   manifest-driven meal art

test/features/nutrition/live_catalogue_read_path_test.dart  --tags live; needs .env
docs/nutrition/                        every review sheet the tooling generates
```

---

## 10. Devices

- **Redmi Note 12 `jfzxugsgnnvsrsg6`** (22095RA98C, Android 13,
  1080×2408) — **the primary from now on.** Unlocked, `1.0.0+27`
  clean-installed, device language Turkish. All Phase-6-polish device
  work was done here.
- **Redmi `AYXSUKIVJVPZ7HPZ`** (M1908C3JGG, Android 11, 1080×2340,
  **×1.17** for taps read off a screenshot; `uiautomator` dumps are
  already in real coordinates) — **FULLY USABLE. It was never
  PIN-locked.** Phases 5 and 7 both recorded it as locked on the strength
  of `isKeyguardShowing=true`, which is equally what an asleep phone
  reports. Two of the three Phase 7 device gaps were this misreading. To
  drive it:

  ```bash
  adb -s AYXSUKIVJVPZ7HPZ shell input keyevent KEYCODE_WAKEUP
  adb -s AYXSUKIVJVPZ7HPZ shell wm dismiss-keyguard
  # isKeyguardShowing / mInputRestricted / mDreamingLockscreen all go false
  ```

  `locksettings get-disabled` → `false` and `settings get secure
  lockscreen.password_type` → `null` is how you tell a non-secure
  keyguard from a real PIN **before** concluding a device is unusable.
  `install -r` works; the whole Phase 7 walk ran here on `1.0.0+29`.
  It currently holds a **clean install awaiting onboarding** — the walk
  ended with an uninstall/reinstall cycle to swap a debug build back out.
- **Huawei `89U4C18908003735`** (ANE-LX1, Android 9, 1080×2280, ×1.14,
  animation scale 0.5) — **no network**, so guest sign-in cannot
  complete and it only covers offline surfaces. It does exercise the
  onboarding chat's offline fallback, which the Redmi never reaches. Its
  nav bar eats taps below raw y≈2150.
