# Phase 12 — Community I: Identity & Squads

**Status:** 🔄 **IN PROGRESS** — the foundation is in; the feature surfaces are not.
**Date:** 2026-08-02 · **Build:** `1.0.0+32` · **Commits:** `0c18f5c` → `f00925d`
**Tests:** 1327 (1258 at phase start) · **`flutter analyze`:** 0 · **CI:** green

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
| — | **Schema + RLS** (`019_social_profiles.sql`) | — | ✅ **APPLIED to production 2026-08-03** |
| — | **Domain rules** (visibility, friendship, squad) | — | ✅ shipped, 26 tests |
| — | **RLS static gate** | testing §  | ✅ shipped, probed |
| — | **Repository** (`community_repository.dart`) | — | ✅ shipped |
| — | **Shared neon surface** (`neon_surface.dart`) | — | ✅ extracted |
| 1 | Public user profile | C24, R6 | ✅ shipped, 9 tests |
| 2 | Profile card sharing | C24 | ✅ shipped, 6 tests |
| 3 | Friends | C22 | ✅ shipped, 8 tests |
| 4 | Squads | C22 | ✅ shipped, 5 tests |
| 5 | Activity feed | C22 | ✅ shipped + writer, 5 tests |
| 6 | Referral → friend bridge | C47 | ✅ shipped |
| 7 | Privacy & safety foundation | — | ✅ schema, visibility UI, block, report |
| — | **Entry point** (Progress tab row) | — | ✅ shipped, on device |
| — | **Analytics** (7 events) | — | ✅ shipped |

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

### 3.6 Squads and the feed — `squad_screen.dart`, `squad_feed_screen.dart`

Shipped together because a squad without a feed is a list of names.

Every row reads "7 of 12" rather than "7 members", so the ceiling is
never a surprise at the moment somebody tries to invite a friend. The
invite code drops `I`, `O`, `0` and `1` — it gets read aloud and typed
off a screenshot, and those are the pairs people get wrong. Uniqueness
comes from the table's constraint rather than a lookup, because
check-then-insert races.

Writing the join flow surfaced that **`Squad.cannotJoin` was tested and
wired to nothing.** `join_squad()` is idempotent, so it returns the same
value whether the caller just joined or was already a member — only the
client can tell those apart, which is exactly what that method is for.

**The feed shows presence, not ranking**, per the roadmap: no positions,
no totals compared between people, no ordering but time. Ranking arrives
in Phase 13 and putting it here would spend that phase's design budget
early. Three reactions, no text field, nothing to moderate. A zero count
is absent rather than rendered as "0" — a row of zeroes reads as nobody
caring, which is the wrong note for a feed whose job is encouragement.

A squad member whose profile is private still has events in the feed,
because the policy scopes events by squad rather than by profile
visibility. Their line reads "Someone": a blank name looks broken, and
"Someone" is true.

### 3.7 What reaches the feed — `xp_award_listener.dart`

The feed had no writer. It publishes from the XP listener rather than a
listener of its own, because that is where "is this new?" is already
answered and a second component asking it would be a second, subtly
different answer.

**The guard on what reaches a squad took three attempts, and the first
two were wrong in ways only a test found:**

1. *Per-pass* — reject a pass that credits more than one workout day.
   `markSessionDayAwarded` is async and unawaited, so crediting XP
   re-enters `_evaluate` before the ledger lands and a restored backlog
   arrives as several small passes, each looking live on its own.
2. *First-quiet-pass* — treat the first pass that credits nothing as
   proof the ledger has caught up. Badges are derived from session logs
   and unlock a microtask **after** the workouts they came from are
   credited, so the quiet pass lands in the gap and the badge publishes
   anyway.
3. *Time since mount* — what actually distinguishes a live signal is
   that the app was already running when it happened. Publishing is off
   for `kFeedPublishAfterMount` (3 s). A crude clock beats a clever
   predicate when the clever ones keep being wrong, and a workout takes
   minutes.

One line per level *reached*, not one per level crossed — a single
workout can cross two on the early curve, and "reached 4" then "reached
5" reads as a bug. Fire and forget, because a feed write must never
delay the XP the user sees. No retry: a queue would eventually post
"trained today" about a Tuesday, and a missing line is a smaller wrong
than a false one.

Both guard cases were probed by reintroducing the defect; both tests
fail without it.

### 3.8 The profile card — `share_templates.dart`, `community_models.dart`

Same shape as `ShareOutcomeTemplate`: already-formatted lines, no
arithmetic, so there stays exactly one place in the app where a number
becomes a string. The only difference is order — a name is the subject
here, so it is the large type and the handle sits under it.

The contents are a pure function, `profileCardStats`, rather than an
inline condition at the share button. An image is the one surface where
a privacy choice cannot be taken back, so "what may leave the device"
should be readable and tested in one place. `isPublic` does **not** gate
it — a share is an act by the owner — but `showStats` and `showBadges`
do, because they are about the numbers rather than about who may look.
Both off is not an error: name, handle and branding is still a card.

Nothing in the suite had ever pumped a share template — they were only
exercised through the off-screen capture path — so the first attempt
threw in `_BrandFooter` (no localizations delegate) and overflowed by
99 924 px (no 1080×1920 surface). The harness now supplies both.

### 3.9 The way in — one row on the Progress tab

All four screens existed and were routed, and **nothing navigated to
them**; the phase was unreachable. The choice was a fifth bottom-nav tab
or a row, and the phase's own rule settles it: a user who never touches
community must see no change, and a new tab is a change to everybody's
app the moment it ships. Under the badges is also the right neighbour,
because a profile is mostly the badges plus a name.

Shown unconditionally, including when the schema is not applied — the
destination reports that state in a sentence, which is a better answer
than a row that silently is not there. Verified on device (§5).

### 3.10 The referral bridge — `referral_friend_bridge.dart` (C47)

`referrals` has recorded who invited whom since migration `007`, so the
person-to-person link already exists and the work is noticing it. The
`referrals_self_read` policy lets an invitee read their own row, so the
referrer's id needs **no migration** — changing `redeem_referral()`'s
signature to hand it back would be a migration bought for one
round-trip.

It is an offer, never an action. Redeeming a code is a transaction about
a reward; silently creating a friendship out of it would be a second
thing the user did not ask for, on a surface where they were thinking
about something else.

**The dialog does not name the referrer.** Their profile may be private,
and resolving a name to show somebody who has not agreed to be seen is
the exact leak the visibility flags exist to prevent.

Every failure is quiet — no profile, no schema, no row, an existing
request, a block in either direction. This rides on top of a flow that
already succeeded, and interrupting a successful redemption with an
error about a different feature is the wrong trade. The reasons come
from `FriendRules.cannotRequest`, so this file is not a second opinion
on the same question.

### 3.11 Analytics — seven events, no identities

No name, handle, bio, squad name or user id leaves the device. The
phase's success criteria ask how many people create a profile, add a
friend, join a squad, and whether a squad changes retention — every one
is answerable from a bare count, and the identities are exactly the part
a product-analytics vendor has no business holding. Same rule the
Phase-9 body-metrics block is written to.

`profileCreated` fires only on a first save, because an edit is a
different behaviour and counting it as a creation would inflate the one
number the phase is judged on. `friendAdded` fires on **accept**, never
on send: an unanswered request is not a friendship. `feedReaction` does
not fire on an undo — the question is how much encouragement the feed
produces, and an undo is not a negative amount of it.

### 3.12 The shared neon surface

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

### 3.13 The RLS gate, and what it is not

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

Everything the roadmap lists for Phase 12 is built. What is left is
either **blocked on a founder decision** or **only checkable against an
applied schema**, and those are the same decision.

### 4.1 `019` is APPLIED — and it did not work the first time

Applied to production **2026-08-03** on founder approval. The community
surface is live.

**It failed on first contact with a real database**, and the failure is
worth more than the fix:

```
ERROR: relation "public.blocks" does not exist (SQLSTATE 42P01)
```

`public_profiles_select_published` filters blocked pairs, and `blocks`
was declared fifty lines *below* it — under a section header that
already read *"Blocks — declared before anything that references them"*.
The intent was written down and the file did not match it.

**The static RLS gate could not have caught this, and that is the
lesson.** It reads policy shape from the text — RLS enabled, no
`using (true)`, `auth.uid()` present, blocks checked in both directions
— and every one of those assertions was true of a file that could not
execute. A third gate in this codebase has now been confidently green
about something it does not actually measure.

The whole migration ran in one transaction, so the failed attempt rolled
back cleanly and production was never in a partial state. The fix moved
the entire `blocks` section above `Profiles`; the second push succeeded.

**Only `019` was applied.** `017` (body metrics) and `018` (progress
photo metadata) remain pending and were deliberately excluded: the
approval named `019`, and both of the others would begin server-side
storage of measurements and photo metadata — a privacy-relevant change
that should not ride along on somebody else's decision. `supabase db
push` applies everything pending, so they were staged out of the
migrations directory for the duration of the push and restored after.

### 4.2 Owed the moment `019` is applied

- **The live RLS penetration pass.** Two real authenticated sessions
  attempting cross-user reads on every table. §3.13 explains why the CI
  gate is deliberately not this — and §4.1 is now a worked example of a
  file that passed the gate and could not execute. **This needs the
  project's anon key**, which this session was not permitted to read;
  everything else it needs is in place now that `019` is live.
- **A second device walk** covering the paths that are currently dark:
  create a profile, send and accept a request, create and join a squad,
  react on the feed, share a card, redeem a referral and take the offer.

### 4.3 Deliberately not built in this phase

- **Avatars** — a Storage bucket with size limits plus the moderation
  hook the schema's `moderation_state` column already expects. Left out
  because an image upload is a moderation surface, and this phase's
  whole position is that it carries no free content to moderate.
  Building it is a phase-sized decision of its own, not a loose end.
- **Coach squad awareness** ("three people in your squad trained
  today") — real social proof from real data, but it belongs with the
  coach's copy engine rather than in a community screen, and the coach
  has no squad-shaped input yet. Recorded here so it is not lost.
- **Ranking of any kind.** The feed shows presence, not position, and
  the roadmap puts ranking in Phase 13 on purpose. Adding it here would
  spend that phase's design budget early.

---

## 5. Verification

```
flutter analyze                        0 issues
flutter test                           1327 passing  (1258 at phase start)
dart format --set-exit-if-changed .    clean · 406 files · 0 changed
tool/check_hardcoded_strings.dart      no regressions
tool/arb_coverage.dart --strict        1790 keys · tr 100% · en 100% · all referenced
tool/recipe_translation_audit.dart     no findings, coverage held
tool/gen_pseudo_localizations.dart     up to date · 1790 members
tool/check_directional_layout.dart     177 · no regressions
CI                                     green through f00925d
release APK                            1.0.0+33 · 137.3 MB
release AAB                            1.0.0+33 · 116.0 MB
```

**Device walk** — Redmi, release build 1.0.0+33, `019` not applied:

| checked | result |
| --- | --- |
| Community row renders under the badges on the Progress tab | ✅ |
| Row opens `/community` | ✅ |
| Unapplied schema reads "Community isn't switched on yet" | ✅ |
| Four tabs swept — no crash, no overflow, no Flutter error in logcat | ✅ |

The uiautomator dump returns no text nodes for the unavailable state;
the screenshot is what confirmed the copy. Worth remembering — a silent
dump is not an empty screen.

**What the walk could not reach**: every path behind an applied `019`
(§4.2). Those are dark on this device by construction, not by omission.

**+69 tests**: 26 on the domain rules, 14 on the RLS shape, 9 on the
community screen, 8 on friends (including that an outgoing request never
offers its sender an Accept button, and that a declined row appears in
no list), 5 on squads, 5 on what reaches the feed, 6 on the profile
card. The two feed-guard tests and the card's visibility filter were
probed by reintroducing the defect.

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
8. **A crude clock beat two clever predicates.** The feed's backfill
   guard is time-since-mount because the two structural rules that
   preceded it were each defeated by an async detail (§3.7). When a
   predicate has been wrong twice, the next one should be the boring
   one.
9. **What may leave the device as an image is a pure function.** Not an
   `if` at the share button — `profileCardStats`, testable and readable
   in one place, because an image is the surface where a privacy choice
   cannot be taken back.
10. **The referral bridge offers; it never acts.** A recorded referral
    is a link that already exists, but turning it into a friendship is
    a decision that belongs to the user, on a screen where they were
    thinking about a reward.
11. **A row, not a tab.** The entry point had to make community
    reachable without changing the app for anybody who ignores it, and
    a fifth bottom-nav item changes it for everybody on ship day.
