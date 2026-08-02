# Phase 10 — Performance Analytics II: Visual Outcomes & Reports

**Status:** 🔄 **IN PROGRESS** — 3 of 7 features shipped.
**Date:** 2026-08-02 · **Build:** `1.0.0+31` · **Commits:** `f671f72`, `272d23d`
**Tests:** 1235 (was 1189 at phase start) · **`flutter analyze`:** 0 · **CI:** green

> This file is the live record. It is updated as features land rather
> than written at the end, so a session that picks the phase up mid-way
> knows exactly what exists and what does not. **§4 is where to resume.**

---

## 1. Goal

Make transformation *visible* and *shareable*, and make the store
listing's promise of "measurable results" literally true.

## 2. Feature status

| # | feature | roadmap | state |
| --- | --- | --- | --- |
| 1 | Progress photos, on-device | C2 | ⬜ not started |
| 2 | Before/after comparison | C2 | ⬜ not started |
| 3 | **30-day outcome report** | C39, P6 | ✅ **shipped** |
| 4 | **Milestone timeline** | C4 | ✅ **shipped** (inside the report) |
| 5 | Shareable report card | C4 | ⬜ not started |
| 6 | **Data export / portability** | C48 | ✅ **shipped** |
| 7 | Monthly recap notification | — | ⬜ not started |

---

## 3. What shipped

### 3.1 The aggregation core — `outcome_report.dart`

The spine everything else reads from: one typed value that the report
screen, a future share image and a future LLM narrative can all consume
without any of them re-deriving it.

**Pure.** No `BuildContext`, no providers, no `DateTime.now()` — the
moment is passed in. That is what makes 21 unit tests possible without a
`ProviderContainer`, and what stops the report depending on wall-clock
time. `outcome_report_provider.dart` is the only impure edge, and it is
plumbing only.

Three rules, inherited from Phase 9 and enforced by tests:

- **A missing section is missing, not zero.** A user who never weighed
  themselves did not stay the same weight, so `weight` is null rather
  than a delta of `0.0`.
- **Direction is never valence.** `BodyDelta` carries a signed change and
  nothing that says which way is good.
- **Nothing is extrapolated.** Every figure is a count or a difference
  over data that exists — which is also what keeps the artifact inside
  the store's rules on quantified outcome promises.

Two decisions worth their comments:

- **The deltas use the first and last reading, not the smoothed trend
  line.** A chart is about the shape of a month; this report sits above
  an entry list and has to agree with it.
- **Badges carry no unlock timestamp anywhere in the app** — they are
  derived predicates over current state, not dated rows. The timeline
  places them at the last session rather than inventing a date, and the
  copy says "earned" rather than "earned on". Storing unlock dates is a
  migration this phase does not need in order to be useful.

### 3.2 The report screen — `outcome_report_screen.dart`

Reachable from the Progress tab, directly under "Your body" — the card
above says what changed, this says what it took. The entry card renders
nothing until there are two sessions, reading `isSubstantive` off the
report rather than re-deriving the threshold, so the card and the screen
cannot disagree about whether there is anything to show.

**Dark-only**, like the polish sprint's "Your body" rebuild, for a reason
specific to this artifact: the roadmap asks for a keepsake that will be
screenshotted, and the one thing a screenshot must not do is arrive in
whichever theme the reader happened to have on.

Three refusals, each with a test:

1. **It never grades a body.** A delta is stated as two ends — "Waist —
   92 cm to 89 cm" — rather than as a signed difference, because a signed
   difference is one formatting decision away from reading like a score.
   A movement inside the instrument's own accuracy reads as "unchanged"
   rather than as `0.1 kg`, because that number is the error bar.
2. **It never reports a section it cannot support.** No readings gives a
   sentence saying so, framed as a fact rather than a lapse: *"You didn't
   log a measurement this month, so there's nothing to compare. The
   sessions above happened either way."*
3. **It never claims a session it did not see.** The energy figure
   carries a tilde and a footnote calling itself an estimate, because it
   is derived from completed days rather than measured.

A fourth, quieter one: the report names how many sessions were counted by
hand rather than by the camera, and only when that number is not zero.
It is there so a camera-free user's report reads as equal rather than
lesser — and the only way to be sure it does is to be able to see the
split.

### 3.3 Portability — `data_export_service.dart`

JSON and RFC-4180 CSV, delivered through the OS share sheet from the temp
directory — so an export the user cancels does not become a permanent
second copy of their data sitting in app storage. Offered at the bottom
of the report rather than buried in Settings, because that is the screen
where "can I keep this?" is a real question rather than a legal checkbox.

**Serialisation is pure; delivery is not.** Split deliberately: there is
no server-side copy to fall back on, so a CSV that quotes wrong is a
corrupted file in somebody's hands. Twelve tests, most aimed at the note
field — the only text a user types, and therefore the only one carrying
the commas, quotes and newlines that break a naive `join(',')`.

Storage units always, with a `units` field saying so. A file that
silently converted to pounds because imperial happened to be selected
would not merge with one taken a month later.

---

## 4. Where to resume

### 4.1 The migration number in the roadmap is wrong

The roadmap specifies **`014_progress_photos_meta.sql`**. `014` is taken —
it is Phase 7's `recipe_ingredients`. Migrations `001`–`015` are applied
to production, `016` is reserved for the unwritten `drop_legacy_tags`,
and `017_body_metrics.sql` is written but not applied.

**The photo metadata migration is `018`.** Anyone starting feature 1
should write it as `018_progress_photos_meta.sql` and not spend twenty
minutes rediscovering this.

### 4.2 Progress photos (feature 1) — the largest remaining piece

Needs, in order:

1. `lib/features/progress/data/progress_photo_repository.dart` —
   app-private local storage via `path_provider`, no cloud upload. The
   `camera` package is already a dependency (the workout screen uses it),
   so there is no new plugin to add.
2. `photo_capture_screen.dart` with a ghost overlay of the previous photo
   for repeatable framing.
3. `018_progress_photos_meta.sql` — **metadata only**. `recorded_at`,
   `local_path_hash`, optional `cloud_ref`. Image bytes never leave the
   device unless the user opts in.
4. The privacy line stated **at capture time**, not in a policy.
5. **The network-assertion test the roadmap makes a release gate**: prove
   photo bytes are never transmitted without explicit opt-in. This is the
   one test in the phase that must exist before the feature ships, not
   after.
6. The account-deletion contract extension — photos and exports removed
   with the account (`006_delete_user.sql`).

### 4.3 Before/after comparison (feature 2)

Pure Flutter once feature 1 exists; a slider compare over two dated
photos. Blocked only by there being no photos yet.

### 4.4 Shareable report card (feature 5)

`OutcomeReport` is already the right shape to render from — that was the
point of building it first. Needs a template in `share_templates.dart`
beside the existing ones, at 1080×1920 and 1080×1080, plus per-metric
opt-in controls defaulting conservative (**photos off**).

### 4.5 Monthly recap (feature 7)

The lighter recurring version. The notification service and the weekly
retrospective card are both already in place; this is a schedule and a
second card rather than new machinery.

### 4.6 The AI narrative

The roadmap asks for an LLM-authored summary grounded strictly in logged
data. `OutcomeReport` is deliberately serialisable into a prompt. The
existing anti-fabrication persona rules apply, and the store-compliance
rule against quantified outcome promises applies harder here than
anywhere — the narrative must describe what happened, never project.

### 4.7 Not yet walked on a device

Everything in §3 is covered by widget and unit tests but **has not been
seen on a handset**. The polish sprint's lesson stands: the device found
five defects that 1,183 tests and seven gates were green across. The
report screen in particular has a dense stat grid and a timeline whose
row count varies, which is exactly the shape that overflows.

---

## 5. Verification

```
flutter analyze                        0 issues
flutter test                           1235 passing  (1189 at phase start)
dart format                            clean
tool/check_hardcoded_strings.dart      0 in 0 files
tool/arb_coverage.dart --strict        1650 keys · tr 100% · en 100% · all referenced
tool/gen_pseudo_localizations.dart     up to date
tool/check_directional_layout.dart     177 · no regressions
CI                                     green
```

**+46 tests** this phase so far: 21 on the aggregation, 13 on the screen
(most of them about missing sections), 12 on the export format.

### What the tests caught before a device could

- `CrossAxisAlignment.stretch` on a `Row` inside a `ListView` hands
  infinite height to its children. `IntrinsicHeight` is what "stretch"
  was reaching for.
- The completion card and the section header rendered the same string
  twice — one label doing two jobs.
- `pumpAndSettle` hangs on the report's loading spinner, the same trap
  Phase 9 recorded. The suite uses bounded pumps.
- Re-pumping a `ProviderScope` whose only change is the value inside an
  override reuses the element tree, so a two-scenario test needs an
  explicit unmount between them. Second time this has bitten.

---

## 6. Architectural decisions

1. **The aggregation is a pure function, not a provider.** Providers are
   plumbing; the arithmetic is the part that needs to be provably right,
   and the only way to test it against a fixed calendar is to hand it the
   date.
2. **Copy is a separate file from the maths**, following
   `body_metrics_copy.dart`. The tone of this artifact is the hard part,
   and somebody reviewing whether the report is kind should be able to
   read one file end to end without arithmetic in between.
3. **A delta is two ends, never a signed difference.** The roadmap asks
   for "no body-shape judgement anywhere"; stating both ends is what makes
   that structural rather than a matter of wording.
4. **The threshold for "there is a report here" lives on the report.**
   `isSubstantive` is read by both the entry card and the screen, so they
   cannot drift apart.
5. **Export is two CSVs, not one.** Sessions and measurements share
   nothing but a person; flattening them would mean a column set that is
   mostly empty on every row.
6. **A badge that has outlived its copy drops its timeline row** rather
   than rendering an id at a person. Ids are persisted; copy is not.
