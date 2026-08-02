# Phase 10 — Performance Analytics II: Visual Outcomes & Reports

**Status:** ✅ **COMPLETE** — 7 of 7 features shipped, device walked.
**Date:** 2026-08-02 · **Build:** `1.0.0+32`
**Commits:** `f671f72`, `272d23d`, `adc86bf`, `fd53c96`, `e9ac79a`, `d060ef5`
**Tests:** 1258 (1189 at phase start) · **`flutter analyze`:** 0 · **CI:** green

---

## 1. Goal

Make transformation *visible* and *shareable*, and make the store
listing's promise of "measurable results" literally true.

## 2. Feature status

| # | feature | roadmap | state |
| --- | --- | --- | --- |
| 1 | Progress photos, on-device | C2 | ✅ shipped |
| 2 | Before/after comparison | C2 | ✅ shipped |
| 3 | 30-day outcome report | C39, P6 | ✅ shipped |
| 4 | Milestone timeline | C4 | ✅ shipped |
| 5 | Shareable report card | C4 | ✅ shipped |
| 6 | Data export / portability | C48 | ✅ shipped |
| 7 | Monthly recap | — | ✅ shipped |

Plus the two the roadmap lists outside the feature table: migration
`018` (metadata only, written and deliberately not applied) and the
account-deletion contract extension.

---

## 3. The aggregation core

`outcome_report.dart` is the spine everything else reads from — one
typed value the report screen, the share card and a future LLM narrative
all consume without re-deriving it.

**Pure.** No `BuildContext`, no providers, no `DateTime.now()`; the
moment is passed in. That is what makes 25 unit tests possible without a
`ProviderContainer` and what stops the report depending on wall-clock
time. `outcome_report_provider.dart` is the only impure edge and it is
plumbing.

Three rules, inherited from Phase 9 and enforced by tests:

- **A missing section is missing, not zero.** A user who never weighed
  themselves did not stay the same weight, so `weight` is null rather
  than a delta of `0.0`.
- **Direction is never valence.** `BodyDelta` carries a signed change and
  nothing that says which way is good.
- **Nothing is extrapolated.** Every figure is a count or a difference
  over data that exists — which is also what keeps the artifact inside
  the store's rules on quantified outcome promises.

Two decisions worth their comments: the deltas use the first and last
reading rather than the smoothed trend line, because this report sits
above an entry list and has to agree with it; and badges carry no unlock
timestamp anywhere in the app, so the timeline places them at the last
session rather than inventing a date.

## 4. The report screen

Reachable from the Progress tab under "Your body" — the card above says
what changed, this says what it took. The entry card renders nothing
until there are two sessions, reading `isSubstantive` off the report
rather than re-deriving the threshold.

**Dark-only**, for a reason specific to this artifact: the roadmap asks
for a keepsake that will be screenshotted, and the one thing a
screenshot must not do is arrive in whichever theme the reader happened
to have on.

Three refusals, each with a test:

1. **It never grades a body.** A delta is stated as two ends — "Weight —
   84.2 kg to 82.4 kg" — rather than as a signed difference, which is one
   formatting decision away from reading like a score. A movement inside
   the instrument's own accuracy reads as "unchanged" rather than as
   `0.1 kg`, because that number is the error bar.
2. **It never reports a section it cannot support.** No readings gives a
   sentence saying so, framed as a fact rather than a lapse.
3. **It never claims a session it did not see.** The energy figure
   carries a tilde and a footnote calling itself an estimate.

A fourth, quieter one: the report names how many sessions were counted by
hand rather than by the camera, and only when that number is not zero.
A camera-free user's report should read as equal rather than lesser, and
the only way to be sure it does is to be able to see the split.

## 5. Progress photos — the privacy position is structural

`ProgressPhotoRepository` has **no Supabase client, no `http`, no bucket,
no upload path** — not behind a flag, not behind a Pro gate, not in an
unreachable branch. The absence *is* the guarantee: a feature flag that
could be flipped to upload a photograph is a feature that uploads
photographs, and the only version of "your photos stay on your phone" a
user can verify is the one where the code to send them does not exist.

`progress_photo_privacy_test.dart` is the release gate the roadmap makes
a shipping condition, and it asserts the same thing twice on purpose:

- **The source scan** fails on any networking symbol or import. This is
  the load-bearing half — it proves there is no path, where a mock can
  only prove the paths a test happens to exercise.
- **The behavioural half** drives the whole write/read/delete cycle
  under an `HttpOverrides` that throws on every request, which catches a
  transitive upload the scan would miss.

**Probed before being trusted.** A flag-guarded upload added to the
repository fails the scan with the right message. A first probe using
`Supabase` failed at *compile* time instead — which is a stronger
outcome, but meant the scan itself had not run, so it was re-probed with
`Uri.parse`, which compiles.

Images live in the app-private documents directory, never the gallery: a
progress photo in the camera roll syncs to a cloud the user did not
choose and appears in a picker they hand to somebody else. The index
stores a file **name**, because the documents path is not stable across
installs and on iOS changes between launches.

### The ghost overlay is the feature

Week two taken from a different distance at a different angle shows the
photographer moving rather than the person changing. The previous photo
of the *same pose* is drawn over the viewfinder at 0.35 — faint enough
to guide, strong enough not to make people frame the photograph instead
of themselves. Same pose only: overlaying a front photo while somebody
lines up a side shot tells them to stand wrong.

The privacy line sits on the camera screen itself, per the roadmap's
explicit UX requirement, because somebody deciding whether to photograph
their own body is deciding *now*. The camera cache copy is deleted after
the bytes are saved — `takePicture` writes to a directory this feature
makes no promises about.

### Comparison is a wipe, not a side-by-side

Two photographs at half width each are two small photographs. One frame
with a draggable divider keeps the body at the size it was shot at, and
the eye compares the same region instead of tracking between two. Both
ends are user-selectable rather than pinned to first-and-latest —
somebody who took a bad photo on day one should not be stuck comparing
against it forever.

The divider and its captions are deliberately **not** direction-mirrored
and say so in the code: the split comes from `localPosition.dx`, so
mirroring would send it away from the finger dragging it. Same call
Phase 8 made about the trend chart's time axis.

## 6. The share card asks every time

`ShareOutcomeTemplate` renders at 1080×1920 and 1080×1080 beside the
existing progress and badge templates. Every line arrives already
formatted — the screen has the locale, the units and the report, and
re-deriving any of it in the template would be a second place for the
numbers to disagree with what the user just read.

**The options sheet is not a settings screen.** Nothing it holds is
remembered: every switch is off when it opens, every time. That is the
difference between "the user opted in" and "the user opted in once,
months ago, and has forgotten". Sessions, minutes and reps are always on
the card — they are the report's substance and disclose nothing about a
body — and everything that does is a decision made in the moment.

The photograph is the sharpest case and the roadmap's rule is that it is
never auto-included. It is off, it is last, it only appears as an option
when photos exist, and it is asked again next time. It is also the one
path in the whole photo feature by which an image can leave the handset,
which is why the consent is per-share rather than persisted.

`precacheImage` before the capture is not an optimisation: the off-screen
render gets two frames and 32 ms, and an undecoded image would simply be
absent — a card that silently drops the photograph somebody deliberately
opted in to is worse than one that fails.

## 7. Portability, and the monthly recap

`data_export_service.dart` — JSON and RFC-4180 CSV through the OS share
sheet, from the temp directory so an export the user cancels does not
become a permanent second copy of their data. Serialisation is pure and
delivery is not, split deliberately: there is no server-side copy to fall
back on, so a CSV that quotes wrong is a corrupted file in somebody's
hands. Twelve tests, most aimed at the note field — the only text a user
types, and therefore the only one carrying the commas, quotes and
newlines that break a naive `join(',')`.

**The recap is the same card wearing a different sentence.** A recap row
and a report row on the same tab would be two controls doing the same
thing — the defect class the Phase 9 walk found and the polish sprint
fixed. `OutcomeReportCard` reads `isRecapDue` and changes its title,
subtitle and glyph instead.

`isRecapDue` is keyed to the user's **own** start date rather than the
wall calendar, because "your month" means the thirty days they trained.
Three-day window rather than one: the card only appears when the app is
opened, and a single-day window means anybody who skips a day never sees
one.

The notification rides the weigh-in reminder's switch rather than adding
a second one. `_nextInstanceOfDayOfMonth` clamps to the month's length,
because somebody who started on the 31st has no 31st in February and a
naive rollover would drift their recap to the 3rd.

## 8. Migration 018, and account deletion

**The roadmap's migration number is wrong and this is worth recording.**
It specifies `014_progress_photos_meta.sql`. 014 is Phase 7's
`recipe_ingredients`, applied to production; 013 and 015 are Phase 7's
too; 016 is reserved for the deliberately unwritten `drop_legacy_tags`,
described by that exact filename in four documents; 017 is Phase 9's
body metrics. **It is written as `018`.**

Metadata only: when, which pose, and a hash of the local filename. No
bytes, no path, no thumbnail, no dimensions, no EXIF, no bucket
reference. `cloud_ref` is nullable and stays null unless an opt-in
backup is ever built — which belongs in a separate service, never as a
branch inside the repository. Four RLS policies rather than one
`for all`, because a photograph is the most sensitive row this schema
holds and "which operations is a user allowed" should be legible one
line at a time.

**Written and deliberately NOT applied**, like 017. The feature is
complete without it; applying it is an independent, safe step whenever
the founder wants the cross-device notice.

**Account deletion reaches the handset.** `on delete cascade` removes the
server rows and `prefs.clear()` drops the index, but neither touches the
documents directory — so without an explicit call, deleting an account
would leave a stranger's progress photos on the phone for whoever signs
in next. `AuthController.deleteAccount` now calls `deleteEverything()`,
non-fatally (the account is already gone server-side; a filesystem error
must not turn a completed deletion into a reported failure), and a test
pins that it still does.

---

## 9. Physical device validation

**Device:** Redmi `AYXSUKIVJVPZ7HPZ` (M1908C3JGG, Android 11, 1080×2340),
app language English, `install -r` over `+31`.

Two full program days were driven to completion first — the report needs
two sessions before it renders anything, and walking an empty state
proves nothing. 36 and 40 driven interactions respectively, from the
view hierarchy rather than blind taps.

| surface | result |
| --- | --- |
| Camera-free workout, day progress | ✅ semantics read `17%, EXERCISE 1 / 6` |
| Progress tab · report entry card | ✅ `Your 30 days · 2 of 30 days` |
| Outcome report · completion + stats | ✅ 2 sessions, 4 minutes, 273 reps, 1 day |
| Outcome report · energy footnote | ✅ `~500 kcal` + "an estimate… not a measurement" |
| Outcome report · camera-free line | ✅ "2 of these you counted yourself" |
| Outcome report · body delta | ✅ `Weight — 84.2 kg to 82.4 kg`, both ends, no sign |
| Outcome report · timeline | ✅ four rows, chronological, badge named not id'd |
| Photo gallery · empty state | ✅ privacy line, not an instruction |
| Photo capture · permission + preview | ✅ front camera, pose selector, privacy line |
| Photo capture · ghost overlay | ✅ previous frame visible under the preview |
| Photo gallery · grouped by pose | ✅ `Front · 2 photos`, Compare appears at two |
| Before/after · wipe | ✅ divider, handle, Earlier/Later, both pickers |
| Share options sheet | ✅ three toggles, all off, "nothing unless you switch it on" |

### The defect the walk found

**Two photos taken the same day rendered two identical chips.** Both
pickers read "Aug 2, 2026" and there was no way to tell which was which
— the two-controls-saying-the-same-thing class again, third time in
three phases.

The information was there and the formatter was discarding it:
`ProgressPhoto.recordedAt` is a *moment*, deliberately unlike
`BodyMetric.recordedOn` which is a day, and `DateFormat.yMMMd` throws the
time away. The time is now added to every chip in the row rather than
only the colliding ones — a row where some carry a time and others do
not reads as a rendering fault — via `add_jm()`, so it stays one
locale-aware pattern rather than two strings joined by hand.

Rebuilt, reinstalled and re-verified on the handset: `Aug 2 8:32 PM` and
`Aug 2 8:35 PM`.

---

## 10. Artifacts

```
APK   build/app/outputs/flutter-apk/app-release.apk     136.7 MB   136,689,671 B
AAB   build/app/outputs/bundle/release/app-release.aab  115.8 MB   115,759,265 B

package        com.emredogan.formaifit
versionCode    32
versionName    1.0.0
minSdk         24        targetSdk 36        compileSdk 36
```

Built from `d060ef5`, after every gate was green and after the device
defect in §9 was fixed.

## 11. Verification

```
flutter analyze                        0 issues
flutter test                           1258 passing  (1189 at phase start)
dart format                            clean
tool/check_hardcoded_strings.dart      0 in 0 files
tool/arb_coverage.dart --strict        1687 keys · tr 100% · en 100% · all referenced
tool/gen_pseudo_localizations.dart     up to date
tool/check_directional_layout.dart     177 · no regressions
CI                                     green
```

**+69 tests this phase**: 25 on the aggregation and the recap trigger, 13
on the report screen, 12 on the export format, 10 on photo privacy and
the deletion contract, 6 on the gallery, 3 on the comparison.

### What the tests caught before a device could

- `CrossAxisAlignment.stretch` on a `Row` inside a `ListView` hands
  infinite height to its children. `IntrinsicHeight` is what "stretch"
  was reaching for.
- The completion card and a section header rendered the same string
  twice — one label doing two jobs.
- `pumpAndSettle` hangs on a loading spinner, the trap Phase 9 recorded.
  Every suite here uses bounded pumps.
- Re-pumping a `ProviderScope` whose only change is the value inside an
  override reuses the element tree, so a two-scenario test needs an
  explicit unmount. Third time this has bitten.
- Photos that exist with no pose having two showed no Compare button and
  no explanation, which reads as a missing feature rather than a
  threshold.

---

## 12. Architectural decisions

1. **The aggregation is a pure function, not a provider.** Providers are
   plumbing; the arithmetic needs to be provably right, and the only way
   to test it against a fixed calendar is to hand it the date.
2. **Copy is a separate file from the maths**, following
   `body_metrics_copy.dart`. Somebody reviewing whether the report is
   kind should be able to read one file end to end.
3. **A delta is two ends, never a signed difference.** The roadmap asks
   for no body-shape judgement anywhere; stating both ends makes that
   structural rather than a matter of wording.
4. **The threshold for "there is a report here" lives on the report.**
   `isSubstantive` is read by the entry card and the screen, so they
   cannot drift apart.
5. **The privacy promise is the absence of code, not a setting.** No
   upload path exists, and a test refuses to let one appear.
6. **The photo index is metadata; the bytes are files.** Megabytes in a
   synchronously-loaded preferences blob would slow every launch forever.
7. **Export is two CSVs, not one.** Sessions and measurements share
   nothing but a person.
8. **Share consent is per-share, never persisted.** "Opted in once,
   months ago, and has forgotten" is not consent.
9. **The recap reuses the report card rather than adding a second one.**
   Two controls that do the same thing is a defect this codebase has
   already shipped twice.
10. **A badge that has outlived its copy drops its timeline row** rather
    than rendering an id at a person. Ids are persisted; copy is not.

---

## 13. Carried forward

- **The AI narrative** the roadmap sketches (an LLM-authored summary
  grounded strictly in logged data) is **not built**. `OutcomeReport` is
  deliberately pure and serialisable so it can be prompt input, and the
  anti-fabrication persona rules plus the store-compliance rule against
  quantified outcome promises both apply harder here than anywhere. It is
  a coach-side change rather than a Phase 10 screen, and it is recorded
  here rather than silently dropped.
- **Migration 018 is written and not applied**, by design. See §8.
- **On-device visual change detection between photos** (the roadmap's
  optional, descriptive, non-judgemental variant) is not built. The
  descriptive-not-judgemental constraint is the whole difficulty and it
  needs a model this app does not ship; building a body-rating by
  accident is the one outcome this phase was most careful to avoid.
