# Phase 9 — Performance Analytics I: Body Metrics & Trends

**Build:** `1.0.0+30` · **Branch:** `main`
**Status: COMPLETE**, device walk included.

Roadmap: `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` §PHASE 9.
Covers R7 (weight-loss dimension) · C1 · C3.

---

## 1. Scoreboard

| roadmap item | state |
| --- | --- |
| C1 · weight logging + trend chart (7d/30d/90d/all) | ✅ |
| C1 · smoothed trend line | ✅ trailing 7-day window, not an N-point average |
| C1 · goal weight drawn as a target line | ✅ **user-stated, never app-projected** — see §2 |
| C1 · body measurements (waist, chest, arm, thigh, hip) | ✅ |
| C1 · goal-projection reconciliation | ✅ against the user's own target |
| C3 · adherence & consistency score | ✅ week as a count, 30 days as a percentage |
| C3 · longest streak | ✅ |
| weekly weigh-in reminder, opt-in | ✅ its own consent row |
| trend insights in plain language | ✅ |
| migration, RLS user-scoped, indexed | ✅ `017_body_metrics.sql` — **not applied to prod yet** |
| offline-first repository, pending-sync | ✅ |
| pure, unit-tested trend calculator | ✅ 38 tests |
| day-0 backfill from the onboarding weight | ✅ |
| `body_metrics_screen` + Progress-tab summary card | ✅ two taps from the dashboard |
| coach reads body-metric trends | ✅ as numbers, per locale |
| plateau detection → proactive coach message | ✅ |
| analytics: weightLogged, measurementLogged, trendViewed, goalReconciliationViewed | ✅ **no measurement ever leaves the device** |
| LLM trend narrative in a monthly view | ⏳ belongs with Phase 10's monthly recap |
| device walk, both languages, both themes | ✅ 4 defects found, fixed, re-verified |
| measurement-guide illustrations | ⏳ asset request, founder-side |

```
analyze              0 issues
tests                1183  (1070 at the start of the phase)
ARB                  1600 keys · tr 100% · en 100% · all referenced
hardcoded strings    0 in 0 files
directional gate     177 · no regressions
recipe audit         0 findings
CI                   green
```

---

## 2. The roadmap asked for a goal weight the app is not allowed to have

Feature 1 says "the onboarding goal weight drawn as a target line" and
feature 3 says to reconcile against the onboarding 12-week projection.
Neither exists, and the reason they do not exist is deliberate.

`WizardState` captures a **current** weight and nothing else — no target,
no projected outcome. And `ai_personalization_engine.dart` carries this,
written into the code two dozen phases ago:

> Store-compliance note: never emit quantified outcome promises here
> ("4-8 kg", "%20-30") — Apple 1.4.1 / Play health-misrepresentation
> reject guaranteed numeric results. Qualitative, effort-conditional
> framing only.

That is why the 12-week trajectory in `act_4_revelation_steps.dart` is a
rising line with no numbers on it. Deriving a goal weight from it in
order to draw a target line would have quietly converted a compliant
qualitative promise into the exact quantified one two app stores reject.

**So the target is stated by the user**, stored in
`user_metrics.target_weight_kg`, and null is a permanent valid state: the
whole feature works with no target, no line and no nagging. Beyond
compliance it is the more honest arrangement — a target the user chose is
a commitment, and a target the app invented is a promise it has no way to
keep.

The reconciliation then compares real movement against **the user's own
number** over the same twelve-week arc, which is a fact about their data
rather than a prediction about their body.

---

## 3. Decisions worth carrying forward

### 3.1 The smoother is a trailing time window, not an N-point average

Body-metric logging is irregular by nature: daily for a fortnight, then a
holiday, then weekly. An N-point moving average treats those fourteen
days and the two weeks of silence as equal neighbours and drags the
post-holiday reading backwards into a period it says nothing about. A
±days window is the only smoother that reads a gap as a gap.

**Trailing, not centred**, because a centred window makes today's
smoothed value depend on data that does not exist yet — every point would
keep changing for a week after it was drawn, and a chart whose history
rewrites itself is not one anybody can trust. There is a test that pins
exactly this.

Seven days because a weight series is dominated by a weekly rhythm
(people eat differently at weekends) and a seven-day window cancels that
period exactly.

### 3.2 The slope is a regression, not last-minus-first

The two endpoints of a body-weight series are the two least trustworthy
numbers in it. One heavy dinner before the final weigh-in should not be
able to define a month's verdict, and with `(last − first) / weeks` it
does. Least squares over the smoothed series makes a single bad morning
cost a fraction of what it costs a two-point slope.

### 3.3 A day in the pending queue is local; everything else is remote

`WorkoutRepository` merges completion days with a set union, which is
correct because a day is either done or not — there is no third value to
disagree about. **A body metric carries a value**, so the same day can
exist locally and remotely saying different things, and "just union them"
silently picks whichever the language iterated last.

The rule is explicit and it is the only one that never writes a stale
value over a fresh one: a day the user typed on this device and has not
pushed yet survives the merge; a day that already synced may have been
re-logged from another device, and that edit is newer than this cache. A
weight chart that resurrects a number the user already corrected is worse
than one that briefly lacks it.

### 3.4 Direction is never valence

Nothing on this screen is coloured by whether a number went the way
somebody hoped. No red for a gain, no green for a loss, no confetti.
Up is the goal for a bulking user and the opposite for a cutting one, and
a recomposition user putting on two kilos of muscle is succeeding.

The trend maths returns `TrendDirection` and `GoalPace` — verdicts, not
sentences — and `body_metrics_copy.dart` is the single file where a
verdict becomes English or Turkish. The roadmap makes emotional safety a
first-class requirement for this phase, and a tone review is only
possible when there is one place to read.

### 3.5 Absence is stated as absence

One data point produces **"log once more — a trend starts at two points"**,
never "no change". The second is a claim about a body that one
observation cannot support.

Two observations on consecutive days are refused for the same reason:
body weight swings by more overnight than a good week moves it, so a
one-day span is noise wearing a trend's clothes. (It also produced "over
the last 1 days", which is how the rule got noticed.)

### 3.6 Adherence measures the promise, not the program

Completed comes from real session-log timestamps. Planned comes from
`weeklyWorkoutCountFor` — the cadence the onboarding report told this
user they would train at, now one public function instead of a rule
copied into two features.

It deliberately does **not** use the 30-day program's day numbers. Those
are a sequence, not a schedule: the calendar screen anchors day 1 at
"today minus however far you have got", so every completed day lands on a
day it was planned for and every adherence figure computed that way is
exactly 100 %. A number that cannot be anything but perfect is not a
measurement.

### 3.7 The current week is a count, not a percentage

**Found by a test, not by review.** Seeded on its install day, the
adherence card read **0 %** — the first version prorated the week's plan
to the days elapsed, so one session out of four on a Tuesday rendered as
a grade for a week with four days still in it.

Two guards now:

* the week is `"1 of 4"`, which says the same thing and cannot be
  misread as a verdict;
* the 30-day percentage waits for a week of history, below which it is an
  artefact of which weekday somebody installed on.

### 3.8 Analytics carry no measurements

Four events, and not one of them has a value attached. They answer "how
many people log, and how often", which is what the phase's success
criteria are written in. A body measurement inside a product-analytics
vendor would be the single most sensitive thing this app has ever
emitted, in exchange for nothing.

---

## 4. Blind spot #6 — the layout sweeps were measuring a spinner

The largest finding of the phase, and it is about the tests rather than
the app.

`pumpPseudo` and `pumpInLocale` both rendered **one frame** and asserted
on it — the frame in which every async provider is still `AsyncLoading`.
So for as long as those helpers have existed, the sweeps have been
proving that loading states do not overflow.

It was found the way the previous two blind spots were: by **injecting a
3000 px overflow** into a screen all three suites claimed to cover and
watching every one of them pass. A render-tree walk confirmed it — the
body-metrics screen never left its loading branch, and the nutrition
surfaces Phase 8 added "past the paywall" painted zero recipe cards.

A suite that renders an empty state and reports "no overflow" is worse
than no suite, because it is evidence of the wrong thing.

The fix is six zero-duration pumps, each draining one round of
microtasks, which is what a `FutureProvider` needs to reach `Data`.
Bounded rather than `pumpAndSettle`, which never returns on the surfaces
here that run a deliberately infinite animation.

### What the honest sweeps found immediately

**The category recipe card overflowed by 143 px** — pre-existing, on a
Phase 8 surface that phase's report signed off as swept. Five inflexible
children beside a 120 px thumbnail leave ~199 px; two macro labels in a
longer language need 342. Now a `Wrap` of icon+label units. Ellipsis was
the other option and it is worse: a truncated calorie count reads as a
wrong number, not a cut one. The card's fixed 140 px height became a
minimum, because it had already been raised once for exactly this and
raising a magic constant per language is a rule somebody has to
rediscover.

**The goal card's header overflowed by 98 px** — new. A `Text` in a Row's
inflexible slot lays out on one line at full intrinsic width, so a longer
"Week 5 of 12" pushes the row off the card. Fixed there and in the two
other places this phase had written the same shape.

---

## 5. Migration

**`017_body_metrics.sql`, not `013`.** The roadmap names it 013; 013, 014
and 015 were taken by Phase 7 and are applied to production, and 016 is
reserved for the deliberately-unwritten `016_drop_legacy_tags.sql`, which
four documents describe by that exact filename. The gap is cheaper than
the confusion.

**Not yet applied to production.** The app is offline-first and complete
without it — every entry writes locally and queues — so applying it is a
separate, safe step whenever the founder wants the cross-device carry.

Two things in it worth knowing:

* **One row per user per calendar day**, enforced by a unique key on
  `(user_id, recorded_on)` where `recorded_on` is a `date`. Weighing
  yourself twice on Tuesday is one observation measured twice; storing
  both would make the trend depend on what time of day somebody opened
  the app.
* **Every measurement is nullable and an all-null row is rejected.** A
  user who only weighs themselves must not be forced to invent a thigh
  circumference, and a user who tracks waist while deliberately not
  looking at the scale must be able to.

There is no public read on this table and there never will be — not the
aggregate, not for the Phase 13 leaderboards.

---

## 6. Files

```
supabase/migrations/017_body_metrics.sql

lib/features/progress/domain/models/body_metric.dart      BodyMeasure + one day's entry
lib/features/progress/domain/trend_calculator.dart        pure maths; verdicts, never copy
lib/features/progress/data/body_metrics_repository.dart   offline-first + the merge rule
lib/features/progress/providers/target_weight_provider.dart   the user's own number
lib/features/progress/providers/adherence_provider.dart   promise vs reality
lib/features/progress/presentation/body_metrics_screen.dart
lib/features/progress/presentation/body_metrics_copy.dart every charged sentence, one file
lib/features/progress/presentation/widgets/body_trend_chart.dart
lib/features/progress/presentation/widgets/body_metric_entry_sheet.dart
lib/features/progress/presentation/widgets/body_metrics_summary_card.dart

test/features/progress/domain/trend_calculator_test.dart        38
test/features/progress/data/body_metrics_repository_test.dart   30
test/features/progress/presentation/body_metrics_screen_test.dart  21
test/features/progress/providers/adherence_provider_test.dart   12
test/support/layout_probe.dart      blind spot #6 lives in its header
test/support/locale_probe.dart      same fix
```

---

## 7. Verification

```bash
flutter analyze                                   # 0
flutter test                                      # 1183
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_hardcoded_strings.dart        # 0 in 0 files
dart run tool/arb_coverage.dart --strict          # 1600 keys, all referenced
dart run tool/gen_pseudo_localizations.dart --check
dart run tool/check_directional_layout.dart       # 177, no regressions
dart run tool/recipe_translation_audit.dart       # 0 findings
flutter test test/i18n/                           # every sweep, now honest
```

---

## 8. The device walk — done, 2026-08-02

Redmi `AYXSUKIVJVPZ7HPZ`, build `1.0.0+30`, a **full clean-install
onboarding walk** (age gate → consent → language → 11-question wizard →
equipment → auth-skip → showcase → dashboard), then the Phase 9 surfaces
in **both languages and both themes**.

| surface | verdict |
| --- | --- |
| Progress-tab summary card, empty | ✅ |
| Progress-tab summary card, with data | ✅ after D3 |
| body screen, empty state | ✅ after D1 |
| body screen, populated | ✅ after D2, D3 |
| entry sheet, weight + note | ✅ |
| date picker, future dates refused | ✅ |
| adherence card on a fresh install | ✅ — the guards hold, see below |
| English, light mode, whole screen | ✅ |
| weekly retrospective card | ✅ after D4 |

**The adherence guards were the thing most worth seeing on a device**,
because they are guards against a card being cruel rather than against a
crash. On a same-day install with nothing logged, the card reads
`0 of 4` for the week and `Nothing scheduled yet.` for thirty days — not
`0 %` twice. That is the §3.7 defect, caught by a test before the walk
and confirmed absent on the handset.

### What it found

**D1 · The empty state offered the same action twice.** Its own centred
button and the extended FAB, the same words, one screen. The eye stops
to ask whether they do different things. The FAB is now suppressed until
there is something to add to; the empty state's button is the better
placement because it is part of the sentence explaining what logging
buys.

**D2 · The FAB sat on top of the last entry's delete button.** 96 px of
bottom padding against a ~72 px extended FAB, so the one destructive
control on the screen was unreachable for the most recent row — the row
somebody is most likely to want to correct. Now 140 px.

**D3 · The app discarded the precision the user typed.** Enter `82.4` and
the screen says `82 kg`. Worse: re-opening that day pre-fills `82`, so
editing anything else about the entry silently writes the tenth away.
`formatWeight` defaults to zero decimals, which is right on a profile
card and wrong on a screen whose entire purpose is small changes over
time — the comment justifying that default reasons about *pounds*, where
a tenth is false precision; for kilograms it is exactly what people
track. One decimal here, and `_trimZeros` means a round 80 still reads
`80 kg`.

**D4 · The weekly retrospective said every unit twice, in both shipped
languages.** "Bu hafta **0 antrenman antrenman** yaptın, **0 dakika
dakika** çalıştın ve **0 tekrar tekrar** tamamladın." English the same:
"you did 0 workouts workouts". The value keys already carry the unit —
that is *why* they exist, so English can say "1 workout" and "2
workouts" — and the sentence repeated it. Pre-existing, on the Progress
tab, every Sunday, since the card shipped. Nothing had looked.

### Carried, not fixed

**The chart itself has not been seen with two points on a device.**
Logging a second entry needs the date picker, and a blind adb tap
sequence through a Material date dialog dismissed the sheet twice
without saving. The painter is covered by the pseudo, English and RTL
sweeps — which, as of this phase, genuinely render it — but a
`CustomPainter` is exactly the kind of thing this repo has learned not
to sign off from a test alone. It wants one human tap.

For the same reason **the target sheet, the goal-reconciliation card and
the plateau card have not been seen on a handset.** All three need data
spanning weeks. They are unit- and widget-tested, including the
emotional-safety assertions, and the goal card's overflow was found and
fixed by the sweeps.

### What the walk cost, and what that says

Four defects on surfaces that 1,179 tests and seven CI gates were green
across. Two of them (D1, D2) are things no automated check in this repo
looks for — "these two controls say the same thing" and "this floating
button covers that one" are not overflow, not contrast, not a missing
translation. One (D3) is data loss that every test agreed with, because
every test asserted the formatter's own output. And one (D4) had been
shipping in both languages since the card was written.

That is the same lesson Phase 7's walk recorded, and it has now held
three phases running: **a test written from the code's own assumption
agrees with it.**
