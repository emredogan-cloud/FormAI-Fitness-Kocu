# Phase 12 — Community I: Identity & Squads

**Status:** 🔄 **IN PROGRESS** — the foundation is in; the feature surfaces are not.
**Date:** 2026-08-02 · **Build:** `1.0.0+32` · **Commits:** `0c18f5c` → `841d872`
**Tests:** 1311 (1258 at phase start) · **`flutter analyze`:** 0 · **CI:** green

> This file is the live record, updated as work lands rather than
> written at the end — the same shape Phase 10's report had while it was
> open. **§4 is where to resume.**

---

## 1. Goal

Give users an identity worth showing and a small group worth showing up
for — the social accountability layer that makes fitness habits stick.

## 2. Feature status

| # | feature | roadmap | state |
| --- | --- | --- | --- |
| — | **Schema + RLS** (`019_social_profiles.sql`) | — | ✅ written, not applied |
| — | **Domain rules** (visibility, friendship, squad) | — | ✅ shipped, 26 tests |
| — | **RLS static gate** | testing §  | ✅ shipped, probed |
| — | **Repository** (`community_repository.dart`) | — | ✅ shipped |
| — | **Shared neon surface** (`neon_surface.dart`) | — | ✅ extracted |
| 1 | Public user profile | C24, R6 | ✅ shipped, 9 tests |
| 2 | Profile card sharing | C24 | ⬜ not started |
| 3 | Friends | C22 | ✅ shipped, 8 tests |
| 4 | Squads | C22 | ⬜ not started |
| 5 | Activity feed | C22 | ⬜ not started |
| 6 | Referral → friend bridge | C47 | ⬜ not started |
| 7 | Privacy & safety foundation | — | ✅ schema, visibility UI, block, report |

The foundation landed first deliberately: the roadmap calls RLS "the
highest-risk area in the roadmap", and a screen built on a schema that
has not been argued through is a screen that has to be rebuilt.

---

## 3. What shipped

### 3.1 Migration `019_social_profiles.sql` — **not** the roadmap's `015`

`015` is Phase 7's `recipe_origin_and_diet`, applied to production, as
are `013` and `014`. `016` is reserved for the deliberately unwritten
`drop_legacy_tags`, described by that exact filename in four documents;
`017` is Phase 9's body metrics; `018` is Phase 10's progress photos.
Same call as those two headers: **the gap is cheaper than the
confusion.**

Eight tables — `public_profiles`, `blocks`, `friendships`, `squads`,
`squad_members`, `activity_events`, `activity_reactions`,
`user_reports` — every one RLS-enabled, every policy written from the
reader's side and starting from "no".

The decisions that needed arguing, all of them in the file's header or
beside the statement they govern:

- **Nothing is visible until the owner makes it so.** All three
  visibility flags default `FALSE`: creating a profile is not publishing
  one. The roadmap states this as a UX principle, and a UX principle
  enforced only in the client is not enforced at all — the client is the
  part an attacker replaces.
- **Three booleans, not one enum.** A `public | friends | private` scale
  forces somebody who wants their level shown but their session count
  hidden to choose between two things they do not want. Field-level
  control is what the roadmap asks for and it is also what makes the
  resolution testable.
- **A block is symmetric and checked in both directions**, so the
  blocker disappears from the blocked user's view as well as the
  reverse — the roadmap requires a block to "fully sever visibility both
  ways". And `blocks` is readable **only by the blocker**: a blocked user
  discovering the block is the difference between a safety tool and an
  escalation.
- **One friendship row per pair, ordered `user_a < user_b`.** The
  mirrored-rows schema makes every query trivially "where user_id = me"
  and makes a half-written friendship possible, because two rows are two
  writes and the second can fail. `requester_id` is a separate column
  because the ordering does not encode who asked, and "accept" is
  offered only to the other party.
- **The squad cap lives in `join_squad()`**, `SECURITY DEFINER`, with the
  count and the insert in one statement. A client that counts and then
  inserts has a race: two people joining a squad of eleven both read
  eleven and both succeed. It is also the only way to resolve an invite
  code without a select policy that would expose every squad row to
  every user. `revoke all … from public` because a `SECURITY DEFINER`
  function granted to `public` is a privilege escalation.
- **No free-text column anywhere.** Reactions only, which the roadmap
  notes "delivers most of the social reinforcement with a fraction of
  the moderation risk". There is nothing here to moderate.

**Written and NOT applied**, like `017` and `018`. Community is opt-in
and inert until a user creates a profile, so nothing regresses while it
is unapplied.

One thing recorded in the file rather than left to be discovered: a
squad whose **owner** deletes their account goes with them, because
`squads.owner_id` cascades. That is deliberate for now — a squad is the
owner's room — but it is the first thing to revisit if squads should
outlive their founders.

### 3.2 The rules, in Dart, pure

`lib/features/community/domain/models/community_models.dart`. No
Supabase, no providers, no `DateTime.now()`.

These rules are written **twice on purpose** — once as RLS, once here.
The policy is the boundary; this is the explanation, and it is the half
that can be executed. `ProfileVisibility.resolve` has an order and the
order is the point: **a block beats ownership beats publication.**
Getting that wrong is how a blocked user keeps seeing a profile because
they were also a friend.

26 tests, including the adversarial cases: that a declined request is not
re-sendable while the row stands, that the requester never gets an
Accept button on their own outgoing request, that a block outranks an
existing friendship, and that an unknown friendship status falls back to
`pending` rather than `accepted`.

### 3.3 The repository — `community_repository.dart`

One class, not four: profiles, friendships, squads and the feed are four
tables and one feature, nearly every screen needs two at once, and a
friend row is meaningless without the profile it points at.

**`019` is not applied, so that is a state rather than an error.**
`isAvailable()` answers once and caches; `_guard` turns a missing
relation into a fallback and **lets every other failure through**,
because a swallow-everything wrapper would hide a broken policy as an
empty list — the worst possible failure for a feature whose entire job
is showing the right people the right things.

Decisions worth repeating out of the file:

- **No cache and no offline queue**, unlike `BodyMetricsRepository`.
  Body metrics are the user's own data and must survive a plane; a squad
  feed is other people's activity, and a stale one is worse than an
  empty one.
- **`profileByHandle` returns null for "does not exist" and "not visible
  to you" alike.** RLS makes them indistinguishable and that is correct:
  a "this profile is private" message confirms the handle is taken.
- **Pair ordering happens here**, so a screen cannot produce a row the
  `user_a < user_b` constraint rejects.
- **Joining goes through the RPC**, never select-then-insert.
- **Actor names are joined at read time**, so a rename is not
  retroactively wrong across a whole feed.
- **An unknown activity kind is dropped**, not rendered as something
  else.
- **`recordActivity` writes nothing when the user is in no squad** — a
  non-participant should not pay for a write nobody can read.
- **Blocking deletes the friendship**, because an accepted friendship
  with somebody invisible to you is a state no screen can draw.
- **`moderation_state` is approved-or-nothing**: a null, a typo or a
  later build's new state all hide a profile rather than publish it.

### 3.4 The profile — `community_screen.dart`, `profile_editor_screen.dart`

Three states, and the order they are checked in is the feature: schema
unapplied → no profile → a profile. The first is where most users are
today, and it says the feature is off rather than showing an error; the
second is the opt-in default and leads with the promise rather than an
instruction.

**"Nothing is visible until you switch it on" is now written three
times** — the migration's `default false`, `ProfileVisibility.private`,
and an editor that never moves a flag on the user's behalf. Three
expressions of one rule, because each layer can be reached without the
others.

Smaller calls worth keeping: badges and stats disable when the profile is
not findable but are **not cleared**, so going private for a week returns
settings rather than a reset; the handle field folds uppercase rather
than rejecting it; a profile awaiting moderation says so, or somebody
spends a week wondering why their friend cannot find them; and the delete
confirmation names what is *not* lost, which is what stops somebody
keeping a profile out of fear.

### 3.5 Friends — `friends_screen.dart`

Three lists rather than one with a status chip: one list buries the only
rows needing a decision under the rows that do not. Incoming is first
because it is the only section that is somebody else waiting on you.

Writing it surfaced a redundancy worth recording — the "Friends" section
header repeats the screen's own title, so it now appears only when there
is another section to be distinguished from. On a screen with nothing but
friends it was the same word twice. A test caught it by not being able
to tell the two apart.

**The screen says less than it knows in two places, on purpose.** A
handle that does not exist and a handle whose owner has not published
produce the same message, because distinguishing them confirms a handle
is taken. Adding somebody who has blocked you says "you can't add this
person" rather than naming the block.

Block and report sit in the overflow on every friend row — the roadmap
asks for one tap from any profile, and somebody who needs them should not
be hunting a settings screen while upset. The block confirmation states
both halves of what a block does, symmetric and silent, because both are
the design rather than side effects.

`currentCommunityUserIdProvider` was extracted here: the screen had been
reaching into the repository for identity, which meant constructing a
Supabase client to answer "which side of this friendship am I on".

### 3.6 The shared neon surface

`lib/core/theme/neon_surface.dart`. "Your body", the outcome report and
the photo gallery each carried a private copy of the same seven colours,
and community would have been the fourth. Three copies is a coincidence;
four is a decision. Tokens plus `NeonCard` and `NeonPill` — the outcome
report's `_SoftCard` turned out to be exactly `NeonCard`'s non-gradient
case, so this is a deduplication rather than a new abstraction.

Deliberately **not** a `ThemeExtension`: an extension resolves off the
ambient theme, which is precisely what these screens have decided not to
do. Purely mechanical — the 269 tests over those screens, including the
pseudo-locale, English and RTL sweeps, pass unchanged.

### 3.7 The RLS gate, and what it is not

`test/features/community/rls_policy_test.dart` **executes no SQL** and
says so in its own header. The roadmap asks for penetration tests that
"verify a user cannot read another user's data via crafted queries";
that needs a live database and two sessions, and it is an operator task
recorded in §5 below.

What the gate does check on every CI run is the shape — the classes of
mistake that are invisible in review because the surrounding code looks
right:

- every created table is RLS-enabled (a table with policies above it and
  no `ENABLE` reads exactly like a protected one);
- every created table has at least one policy;
- no policy is `using (true)` or `with check (true)`;
- every policy constrains on `auth.uid()`;
- blocks are consulted in both directions everywhere they are consulted;
- every table cascades from `auth.users`, so account deletion reaches it.

**Probed before being trusted**, with three regressions that mirror how
this actually goes wrong: a permissive `using (true)`, a table with its
`enable row level security` line removed, and a one-directional block
check. Caught 3, 1 and 1 assertions respectively.

The first draft of the block check **failed on a correct migration** — a
non-greedy regex stopped at the first `)` and truncated the clause before
the `OR` it was looking for. Third time a gate in this repository has
been wrong about its own subject; it is worth assuming the next one is
too until a probe says otherwise.

---

## 4. Where to resume

In this order. Each is a commit.

### 4.1 Screens — squad and feed

Profile and friends are done. Two remain, and they are one unit: a squad
without a feed is a list of names, and the feed is squad-scoped by
construction.

Squad creation ≤ 3 taps and joining via a single link are the roadmap's
constraints. `join_squad()` and `CommunityRepository.joinSquad` already
exist; the screen is what is missing. — `lib/features/community/presentation/`

Profile, friends, squad, feed. The design language is settled: dark-only
neon on black like the outcome report and "Your body", `_NeonCard` and
the lime accent already exist in
`lib/features/progress/presentation/outcome_report_screen.dart` and
should be **lifted into a shared widget** rather than copied a third
time — that is the point at which duplication becomes a decision.

Roadmap UX constraints, all load-bearing:

- **Opt-in by default, everywhere.** A user who never touches community
  must see no change. That means no entry point on the dashboard until a
  profile exists — the same rule `OutcomeReportCard` follows.
- Squad creation ≤ 3 taps; joining via a single link.
- The feed shows **presence, not ranking** in this phase. Ranking
  arrives deliberately in Phase 13 and putting it here would spend that
  phase's design budget early.
- Safety controls reachable in one tap from any profile.

### 4.2 Profile card share template

`ShareOutcomeTemplate` in `lib/core/widgets/share_templates.dart` is the
model to follow — it takes already-formatted lines and does no
arithmetic. A profile card is the same shape with different content.

### 4.3 Referral → friend bridge (C47)

`lib/features/referral/` and migration `007` already create the
person-to-person link. The bridge is: after `redeem_referral` succeeds,
offer a friend request to the referrer. Converting an acquisition
mechanic into a retention one is the whole point, so it belongs at the
moment of redemption rather than in a settings screen.

### 4.4 Activity events on the existing hooks

`xp_award_listener` and `badge_unlocks_provider` already fire on workout
completion, badge unlock and level-up. Events are written from there, and
**only when the user is in a squad** — writing events nobody can read is
how a feature that is off still costs a round trip.

### 4.5 Analytics

`profileCreated/Viewed/Shared`, `friendAdded`, `squadCreated/Joined`,
`feedReaction`. `AnalyticsService` is the pattern.

### 4.6 Still owed by the phase

- **The live RLS penetration pass.** Two real sessions against an applied
  `019`, attempting cross-user reads on every table. §3.3 explains why
  the CI gate is not this.
- **Avatar handling** — a Storage bucket with size limits and the
  moderation hook the schema's `moderation_state` column already expects.
- **Coach squad awareness** ("three people in your squad trained today"),
  which is real social proof from real data and belongs with the coach
  rather than in a screen.
- **Device walk**, build, and the founder-side decision on whether to
  apply `019`.

---

## 5. Verification

```
flutter analyze                        0 issues
flutter test                           1298 passing  (1258 at phase start)
dart format                            clean
tool/check_hardcoded_strings.dart      0 in 0 files
tool/arb_coverage.dart --strict        1687 keys · tr 100% · en 100% · all referenced
tool/check_directional_layout.dart     177 · no regressions
CI                                     green
```

**+53 tests so far**: 26 on the domain rules, 14 on the RLS shape, 9 on
the community screen, 8 on friends (including that an outgoing request
never offers its sender an Accept button, and that a declined row
appears in no list).

One CI incident, and it was process rather than code: `059f531` went red
because the hardcoded-string gate was skipped after a commit that only
touched a repository. A Postgres error fragment (`'does not exist'` — two
lowercase words with a space) is exactly what `_labelShape` catches, and
one second of gate would have found it. `RESUME_GUIDE.md` §4 now opens
with the instruction to run every gate before every push, and gotcha 28
names the miss.

---

## 6. Architectural decisions

1. **The schema was argued before a screen was drawn.** The roadmap names
   RLS the highest-risk area; a screen on an unexamined schema has to be
   rebuilt when the schema moves.
2. **The rules exist twice, deliberately.** RLS is the boundary and
   cannot be bypassed; the Dart is the explanation and can be executed.
   Neither is sufficient alone.
3. **Default-deny everywhere.** Every policy starts from "no" and every
   visibility flag defaults false.
4. **A block outranks everything**, including ownership in the resolver,
   and is invisible to the person blocked.
5. **One friendship row, ordered.** Atomicity by construction beats
   convenience in a query.
6. **The size cap is server-side and atomic.** The client's check is a
   courtesy; `join_squad()` is the guarantee.
7. **No free text in this phase.** Reactions carry most of the social
   value and none of the moderation burden — and the schema has no
   column to regret.
