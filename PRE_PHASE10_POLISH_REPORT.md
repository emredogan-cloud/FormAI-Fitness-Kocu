# Pre-Phase-10 Polish Sprint — Completion Report

**Date:** 2026-08-02 · **Build:** `1.0.0+31` · **Commit:** `ad13944`
**Tests:** 1189 (was 1183) · **`flutter analyze`:** 0 · **CI:** green

Six tasks, all complete. The sprint's yield was five production defects
the test suite and seven CI gates were green across, and one gate blind
spot that had been hiding four of them.

---

## 0. What was asked, and what happened

| task | state |
| --- | --- |
| 1 · Exercise image regeneration guide + media strategy | ✅ `EXERCISE_IMAGE_REGENERATION_GUIDE.html`, 87 exercises |
| 2 · Fix the static workout UI | ✅ root-caused, fixed, verified on device |
| 3 · Apply the new "Your body" design | ✅ rebuilt to the reference |
| 4 · Physical device validation | ✅ Redmi `AYXSUKIVJVPZ7HPZ`, `1.0.0+31` |
| 5 · Build number, APK, AAB | ✅ `+30` → `+31`, both artifacts verified |
| 6 · Report | ✅ this file |

---

## 1. Bugs discovered and fixed

Five, all found by walking the app on a handset. None of them was
visible to any gate in the repository before this sprint.

### 1.1 The rest countdown was frozen — the founder's report, confirmed

`lib/features/workout/presentation/manual_workout_screen.dart`

**The founder was right, and the cause was a stale reader.** An earlier
performance change (Tier-B.8) moved the per-second rest tick out of
`WorkoutSessionState.restSecondsRemaining` and into its own
`restCountdownProvider`, so that one rest second stopped waking every
workout-state listener in the app. The session field was kept, but it
now holds the rest **duration**, frozen at rest entry.

The camera screen was moved to the provider. The camera-free screen was
not. It went on reading the frozen field, so the dial showed the same
number for the whole rest and the ring stayed at 100 %. Forty seconds of
"40".

The two stats under the dial made it worse rather than better: "REST
TIME 40s" and a dial reading 40 are two controls saying the same thing —
the defect class Phase 9's walk logged. With the countdown live they are
now the total and the remainder, which is what they were always meant to
be.

**Why no test caught it.** `manual_workout_screen_test.dart` seeded
`restSecondsRemaining: 30` and asserted `find.text('30')`. It was written
from the code's own assumption, so it passed for exactly as long as the
bug existed — the same shape as Phase 7's `find.text('LUNCH')` inside a
Turkish host. The replacement seeds the frozen field to **45** and the
live provider to **12** and asserts on 12, so a screen reading the wrong
source fails. Proven by reintroducing the defect: both new tests failed,
and passed again on revert.

**Verified on the device:** 37 → 30 across seven seconds, ring visibly
emptying. Screenshots in the walk log below.

### 1.2 The rest ring stepped instead of sweeping

Same file. The dial repainted once a second, so the arc jumped 1/40th of
a turn at a time. It is now tweened over exactly the tick interval, which
is the difference between a timer that looks alive and one that looks
stuck. `Tween(end:)` with a null `begin` lands on the first frame without
animating, so entering rest does not sweep the ring in from empty.

### 1.3 The camera-free screen never showed where you were in the day

`activeExerciseIndex` and the day's exercise count have been on the
session state since Phase 3, and the camera screen has rendered them the
whole time. The camera-free screen did not, so a user who declined the
camera could not tell whether they were two exercises from the end or
seven. Added as a slim animated bar plus the existing `exerciseProgress`
ARB key — no new state, no new copy.

### 1.4 "Your body" claimed a weight it had never been told

`lib/features/progress/presentation/body_metrics_screen.dart`

Found on the device, after the rebuild. The trend card read
**"↓ 1.8 kg vs 30 days ago"** while the insights sheet one tap away read
**"You're down 1.8 kg over the last 13 days."** 30 was the range the user
had selected; 13 was how far back the readings actually went.

The card was not merely inconsistent — it was making a claim about the
user's weight on a day the app has no reading for. The delta line now
reads `TrendSummary.spanDays`, which is the number `trendSentence` has
always used, so the two agree by construction rather than by
coincidence. Pinned by a test that seeds a 13-day span inside the 30-day
range and asserts both surfaces say 13.

This is the Phase 7 lesson again: **the cross-check between two
independent sources is where the defects are.** Nobody had put those two
sentences on the same screen before.

### 1.5 Four Turkish words and an email label, live in the English app

Found while walking the Progress tab:

- `gelisim_tab.dart` — **"WORKOUT TIME · 0 dk"**. `dk` is `dakika`.
- `weekly_retrospective_card.dart` — a stat row reading
  **"0 antrenman · 0 dakika · 0 tekrar"**.
- `auth_screen.dart` — the sign-in email field labelled **"E-posta"**,
  hardcoded, with `authEmailLabel` already sitting in the ARB **unused**.

All five now resolve through `AppLocalizations`. Two new keys
(`progressUnitMinutes`, `progressUnitWorkouts`); the other three reuse
keys that already existed.

---

## 2. Blind spot #8 — a lowercase word is the shape of an identifier

The four unit leaks above matter less than the reason the gate could not
see them.

`tool/check_hardcoded_strings.dart` reported **0 in 0 files** the whole
time. `'dk'`, `'antrenman'`, `'dakika'` and `'tekrar'` are each a single
lowercase word, and `_isTechnical`'s "identifiers / tokens" pattern —
`^[a-z][a-zA-Z0-9]*$` — discarded every one of them before any label test
ran. Every lowercase single-word label in the app was invisible.

**Shape cannot fix this.** `'dakika'` and `'padding'` are the same
shape. What separates them is *where the literal goes*: a literal passed
as `hint:`, `unit:`, `label:` or `title:` is going to be rendered — that
is what those parameters mean.

So the gate gained a **rendered-argument signal**, which outranks the two
shape exclusions for the same reason the `%`-ordering signal outranks
them: the exclusion fires first and would swallow the hit. Per the
standing rule, it was proven with a synthetic probe file under `lib/`
before being trusted — and the probe earned its keep twice:

1. The first draft outranked the *composition* exclusion as well, and the
   probe immediately flagged three `label: '$count'` literals. Composition
   now still wins: a bare interpolation under a rendering argument is
   still just a number.
2. The first parameter list included `message:` and `prefix:`. The probe
   flagged a Sentry breadcrumb and a temp-file name. Both were dropped;
   only parameters that mean "this is display text" remain.

**It found a fifth leak nobody was looking for** — the `E-posta` label —
on its first honest run.

Three genuine non-copy literals it surfaced are now marked with
`// i18n-ignore` and a reason (`kcal`, `cm`/`kg`, the referral-code
alphabet `ABC123`). One false positive was removed by naming what the
code was doing instead of suppressing it: two onboarding captions joined
two ARB strings with a literal `\n` under a `caption:` argument, and now
call a `_twoLine` helper. The allowlist total moved 244 → 246, reported
per entry as designed.

Gate state after the widening: **0 in 0 files**, honestly.

---

## 3. Dynamic UI improvements

The founder's brief listed nine classes of element that should be live.
The audit's finding is that **six of the nine were already live** and the
value was in naming which three were not.

| element | before | after |
| --- | --- | --- |
| Rest countdown | frozen at the rest duration | live, per second |
| Rest progress ring | stuck at 100 % | sweeps, tweened over the tick |
| Rest "REST TIME" stat | duplicated the dial | the total, distinct from the remainder |
| Day progress / completion | **absent** | animated bar + "EXERCISE 2 / 6" |
| Repetition counter | live off `currentReps` | unchanged |
| Set track / set pill | live off `currentSet` | unchanged |
| Session-complete percentage | live off the session | unchanged |
| Weight trend chart | static line | gradient stroke, axes, lit end dot |
| Trend delta | absent | live, and honest about its window |

Two things were deliberately **not** made dynamic:

- **Elapsed workout time.** There is no session start timestamp on the
  state to render. `_setStartedAt` exists inside the notifier for
  logging, is private, and is per-set rather than per-session. Exposing
  it is a state change, not a UI change, and inventing a clock from
  nothing would have been worse than the static number the founder
  reported.
- **The rest screen's encouragement card.** It is copy, not state.

---

## 4. Task 3 — the "Your body" rebuild

Rebuilt from `photos/new-image/your-body.png` against comps `021`–`026`.

**The six comps are design references, not drop-in assets** — every one
of them has English text rendered into the pixels, which is the exact
problem Task 1 exists to fix elsewhere in the app. Shipping them as
images would have put untranslatable copy into a bilingual screen. So the
layout is rebuilt in Flutter with every string from ARB, and the parts of
the comps that are genuinely artwork were **cut out of the PNGs** — five
neon icons and the 3D dumbbell, with the black background converted to
alpha by treating the neon as additive and un-premultiplying it. They
live in `assets/body_metrics/` (~180 KB) and are declared in
`pubspec.yaml`; `assets/new-assets/` itself is not bundled.

Cards sit at 16 dp gutters, which is **91 % of a 360 dp phone** — the
proportion measured off the reference, and what the founder's "about 90 %
of the available visual space" asks for.

### Architectural decisions

1. **The surface is dark-only**, like the workout and camera screens.
   Light mode ships and a user can choose it, but the reference is neon
   on pure black and there is no light rendering of it that is not an
   approximation. Hardcoding the canvas also retires the defect class
   that has bitten this app three times — `Colors.white` over a tint fill
   that is dark in one theme and pastel in the other — because the
   backdrop no longer changes.
2. **The lime accent is the reference's, not the app's.**
   `AppColors.neonGreen` is `#39FF14`; every green sampled off the comp
   is around `#B8FF33`. Defined locally rather than promoted into
   `AppColors` until a second screen wants it.
3. **The delta line is one colour whichever way the arrow points.** The
   comp colours a loss green. Colouring a direction is precisely what
   Phase 9 ruled out — down is the goal for one user and the opposite for
   another. The arrow carries the direction; lime is this screen's "now"
   accent, which is how the comp uses it everywhere else.
4. **The comp's entry row shows a clock time. There isn't one.**
   `BodyMetric.recordedOn` is a day; `dayOf` strips the time on the way
   in and one entry per day is the model. The mock reads 14:34 because
   that is when the screenshot was taken. The second line carries the
   other measures logged that day instead, which is real.
5. **Three controls in the comp had no existing behaviour**, so each was
   given an honest one rather than a decorative one. "View insights"
   opens the trend sentence, the plateau note and the goal
   reconciliation — all of which used to sit inline, and the screen is
   better for having the compact delta on the surface and the paragraphs
   one tap away. The ⓘ explains why the line is smoothed and why nothing
   on the screen is coloured. "View all" expands the entry list, and
   appears only past three entries.
6. **The chart gained a gradient along the time axis**, not by value —
   purple at the oldest reading, lime at the newest, so it reads
   "then → now". A gradient keyed to the value would be valence
   colouring by the back door. The area fill needed a two-axis fade,
   which one `Paint` cannot do, so the hue ramp is composited with a
   vertical alpha ramp through `BlendMode.dstIn`.

### What the tests had to become

Moving three cards into a sheet made three `findsNothing` assertions pass
for the wrong reason — they would have stayed green whatever the plateau
and goal logic did. Each now opens the sheet first, and the helper
asserts the pill exists before tapping it. The tone rules those tests
guard (states a loss without praising it; does not repeat the distance at
somebody moving away from their target) are unchanged and still enforced.

The pseudo-locale sweep caught a **42 px overflow** on a 320 px card on
its first run against the rebuild — an inflexible pill in a `Row`. Fixed
before it reached the device.

---

## 5. Task 1 — the exercise image library

`EXERCISE_IMAGE_REGENERATION_GUIDE.html` (165 KB, self-contained,
per-prompt copy buttons, filter by name and by media class), generated by
`tool/gen_exercise_image_guide.py` so it can be regenerated when the
library changes. The script cross-checks `photos/exercises/` against
`ExerciseMediaRegistry._localImageSlugs` and fails rather than silently
omitting anything; they are currently in exact 1:1 correspondence, 87 and
87, with no orphans either way.

**All 87 files carry burned-in text.** A dark-band heuristic said two of
them were clean; both turned out to be dirty when actually looked at —
one has a white caption bar instead of a black one, the other captions
each cell of a 2×3 grid. The same lesson as §2, in a throwaway script.

**They are not captioned photographs. They are infographics**, in four
layouts:

| layout | count | what the pixels carry |
| --- | --- | --- |
| Two-panel before/after · `800×437` | 37 | a caption bar top *and* bottom; sometimes English over Turkish, sometimes the same English twice |
| Step filmstrip · `800×533` | 48 | a title, 3–6 numbered steps each with a Turkish instruction paragraph, per-frame time chips, a `TOPLAM SÜRE` timeline |
| Frame grid · `800×436` | 2 | a 2×3 contact sheet with English per-frame captions |

The consequence is stated plainly at the top of the guide: on the
filmstrips **the text is the coaching content** — the steps, the tempo,
the breathing cues, the muscles worked. Generating a clean photograph
deletes it. That is still the right move, because content burned into a
pixel cannot be translated, corrected, resized, read by a screen reader
or scaled with the user's text size. But the replacement is only complete
when that content lands in the exercise catalogue beside `description`
and `short_tip`. **The images and the step copy are one project, not
two.**

Every prompt says "centred, generous margin on all four sides" because
`ExerciseGuidePlayer` renders these with `BoxFit.cover` and a Ken Burns
pan-zoom: the frame is cropped and the crop moves. That is also why a
burned-in caption bar is doubly wrong here — the pan can slice it in
half.

**Drop-in contract:** same folder, same filename, no code change at all.
`localImagePath()` derives the path from the slug and
`photos/exercises/` is already declared in `pubspec.yaml`. Aspect ratio
is free because `cover` crops to the slot.

### Media strategy recommendation

The dividing line is not the muscle group. It is **whether one frame can
show what the exercise is.**

- **9 isometric holds** (plank, dead hang, child's pose, the stretches) —
  a still is not a compromise, it is the exercise. Never spend a video
  budget here.
- **59 single-plane strength movements** (presses, rows, curls, squats,
  hinges) — a still at the hardest position is sufficient, and arguably
  better than a loop: the position that gets corrected is the one the
  user has to be shown, and a loop shows it for a fraction of a second.
- **19 ballistic, locomotive and multi-position movements** (burpees,
  swings, jumps, crawls, carries, shuffles, cleans, thrusters, wall
  walks) — these genuinely require a loop. A still of a kettlebell swing
  and a still of a front raise are the same photograph; the information
  is the *path*, and a frame cannot carry a path. This is also exactly
  the set the filmstrip layout was invented to fake.

Five recommendations, in the guide in full:

1. **Two tiers, not one.** A bundled WebP still for every exercise — the
   offline floor. A hosted loop *on top* for the 19 that need one. Never
   ship a movement with only a loop.
2. **The loop has to be hosted, today.** `ExerciseGuidePlayer` passes
   only `http` paths to the video controller and deliberately drops
   bundled asset paths to the fallback tile — a branch added because
   malformed-URL inputs were crashing. Good outcome anyway: 19 loops in
   the binary would cost more than the entire current image library.
3. **Make `ExerciseMediaRegistry` manifest-driven.** It still needs a
   hand edit to a `Set<String>` per file. `WorkoutBackgroundRegistry`
   beside it already resolves from the asset manifest. Porting that
   removes the one step in this pipeline a person can forget.
4. **Silent, muted, 3–5 s, no audio track.** These play beside a live
   voice coach.
5. **The step copy goes to the database, not the pixels** — which is also
   what makes the next language a content task rather than 87 more
   renders.

---

## 6. Physical device validation

**Device:** Redmi `AYXSUKIVJVPZ7HPZ` (M1908C3JGG, Android 11, 1080×2340),
device language Turkish, app language English. `install -r` over
`1.0.0+30`, no uninstall needed — both builds upload-key signed.

Blind-tapping proved unreliable on the entry sheet (two attempts
dismissed it), so the walk switched to driving from `uiautomator dump`
coordinates, which are already in real device space and need no ×1.17
correction.

| surface | result |
| --- | --- |
| Dashboard → Progress tab | ✅ · found the `dk` and `antrenman/dakika/tekrar` leaks |
| Your body · empty-ish (1 entry) | ✅ matches the reference |
| Your body · about sheet (ⓘ) | ✅ dark chrome, both paragraphs |
| Log a measurement · date picker | ✅ back-dated entry saved |
| Your body · populated chart | ✅ gradient stroke, both axes, lit end dot |
| Your body · insights sheet | ✅ · **found the 30-vs-13 defect** |
| Your body · entries + floating action | ✅ list clears the button at rest |
| Workout · camera-free active set | ✅ · day progress bar renders |
| Workout · camera-free rest | ✅ · **37 → 30, ring emptying** |

Regressions found during the walk: **2** (§1.4, §1.5). Both fixed, and
then **re-walked on the final `+31` build** rather than trusted to the
test suite — the fixes landed after the first walk, so the first walk had
not seen them:

| re-verified | reads |
| --- | --- |
| Progress · workout-time tile | `0 min` (was `0 dk`) |
| Progress · weekly retrospective chips | `0 workouts · 0 min · 0 reps` (was `antrenman · dakika · tekrar`) |
| Your body · trend card | `1.8 kg vs 13 days ago` (was `vs 30 days ago`) |

Nothing else on the modified screens regressed.

**Carried, not regressions.** The exercise catalogue still renders
Turkish names and tips inside the English app ("Ağırlıklı Sit-up",
"Tip: Karnınla çek…"). That is the documented Phase 7 limitation — 138
rows of `name`, `description` and `short_tip` that migration 011
localised and Phase 7 did not translate — and it is the other half of the
project §5 describes.

---

## 7. Artifacts

Build number `1.0.0+30` → **`1.0.0+31`**.

```
APK   build/app/outputs/flutter-apk/app-release.apk    136.2 MB   136,164,779 B
AAB   build/app/outputs/bundle/release/app-release.aab 115.5 MB   115,528,620 B
```

Both built from commit `ad13944`, after every gate was green.

**Verified:**

```
package        com.emredogan.formaifit
versionCode    31
versionName    1.0.0
minSdk         24        targetSdk 36        compileSdk 36
signer         CN=FormAI, OU=FormAI, O=FormAI, L=Istanbul, ST=Istanbul, C=TR
SHA-1          cf37a2de76f2fac0305d18d34c7be2d5db4d08b3
AAB contents   1,639 files
```

The APK is **upload-key signed**, which is what makes `adb install -r`
work over the `+30` already on the handset — no uninstall, no onboarding
re-walk. It is not the Play signing key; nothing about that changed.

The AAB is the artifact for Play. The APK is for sideloading and was the
one walked in §6.

---

## 8. Verification

```
flutter analyze                        0 issues
flutter test                           1189 passing  (was 1183)
dart format                            clean
tool/check_hardcoded_strings.dart      0 in 0 files  (allowlist 246, widened heuristic)
tool/arb_coverage.dart --strict        1613 keys · tr 100% · en 100% · all referenced
tool/gen_pseudo_localizations.dart     up to date (1613 members)
tool/check_directional_layout.dart     177 · no regressions
tool/recipe_translation_audit.dart     0 findings
CI                                     green (CI + Secret Scan)
```

Six new tests: two pinning the live countdown from two independent
sources, one on the day progress bar, two on the delta line's colour and
window, one on the 30-vs-13 defect.

The directional-layout ratchet is unchanged at 177 rather than raised:
the rebuild's eight new `Alignment` and `EdgeInsets.fromLTRB` sites were
converted to their directional equivalents rather than baselined.

---

## 9. Founder-side, unchanged

Nothing in this sprint moved these. Carried from Phase 9:

1. **Play Console + RevenueCat** per `docs/store/PRICING_SETUP.md` §3–§4.
   Price decided: $3.99 / $9.99 / $49.99 USD, Turkish unchanged.
2. **The meal and workout photographs**, plus — new from this sprint —
   **the 87 exercise images**, whose prompts are now written and
   copy-ready in `EXERCISE_IMAGE_REGENERATION_GUIDE.html`.
3. **A native-speaker read of the English.**
