# Workout background images — what to generate, and where to put it

**Phase 6 polish, item 10.** Generated 2026-08-01 against the live
Supabase catalogue (138 exercises) and `photos/exercises/` at build
`1.0.0+28`.

The redesigned camera-free workout screen puts the set counter over a
full-bleed photograph of the movement. **51 of the 138 exercises have no
photograph of their own.** They are listed below with a prompt each.

---

## 1. Nothing is broken while this is empty

Every exercise already renders a real photograph. The resolver falls back
to the exercise's *category* art — the cinematic set that has been
shipping on the Antrenman dashboard since Phase 67 — so the screen looks
finished today and each file you add only makes one exercise more
specific.

So this is a quality backlog, not a blocker. Generate them in whatever
order you like, in batches of any size, and ship whenever.

## 2. The whole procedure

1. Generate the image from the prompt.
2. Convert to WebP, around 1200×900 (4:3), quality ~85.
3. Save it into **`photos/workout_backgrounds/`** with **exactly** the
   filename listed.
4. Build.

**There is no list to update and no code to change.**
`WorkoutBackgroundRegistry` reads the app's own asset manifest, so a file
with the right name in the right directory is used on the next build and
a file with the wrong name is silently ignored (the exercise keeps its
category art). A test asserts that contract, and another asserts the
directory is still declared in `pubspec.yaml`.

The filename is the exercise's slug in PascalCase — `bulgarian_split_squat`
becomes `BulgarianSplitSquat.webp`. Every filename below is already
written out, so you never have to do that conversion yourself.

## 3. What makes these work as backgrounds

The screen draws a top-to-bottom scrim over the photograph, and the rep
counter sits dead centre. Three things follow, and they are in every
prompt:

- **Leave the left third quiet.** The subject sits right of centre.
- **No text of any kind.** Not a gym sign, not a plate marking, not a
  logo. Baked-in words cannot be translated, and this app is bilingual —
  the existing instructional images in `photos/exercises/` got this wrong
  (see §5) and it is worth not repeating.
- **Dark.** These sit under white type. A bright image fights the scrim
  and the counter stops being readable.

The prompts describe the same look the existing `photos/workouts/` art
has, so a mixed screen does not read as two different apps.

## 4. If you would rather do fewer

Ranked by how often a user actually sees them: the **core** and **legs**
groups are the ones that appear in nearly every generated plan. `chest`
and `back` next. `full body` last — those exercises appear mostly in HIIT
blocks, which move fast enough that the background barely registers.

---

## Core — 12

Falling back to `photos/workouts/core_steel_abs.webp` until these land.

### Ab Wheel Rollout

- **exercise** · `ab_wheel_rollout` · Ab Wheel Rollout
- **destination** · `photos/workout_backgrounds/`
- **filename** · `AbWheelRollout.webp`
- **prompt** ·

  > A single athlete performing an ab wheel rollout, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Bisiklet Mekiği

- **exercise** · `bicycle_crunch` · Bisiklet Mekiği
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BicycleCrunch.webp`
- **prompt** ·

  > A single athlete performing a bicycle crunch, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Kablo Mekik

- **exercise** · `cable_crunch` · Kablo Mekik
- **destination** · `photos/workout_backgrounds/`
- **filename** · `CableCrunch.webp`
- **prompt** ·

  > A single athlete performing a cable crunch, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Mekik

- **exercise** · `crunch` · Mekik
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Crunch.webp`
- **prompt** ·

  > A single athlete performing a crunch, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Flutter Kick

- **exercise** · `flutter_kick` · Flutter Kick
- **destination** · `photos/workout_backgrounds/`
- **filename** · `FlutterKick.webp`
- **prompt** ·

  > A single athlete performing a flutter kick, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Asılı Bacak Kaldırma

- **exercise** · `hanging_leg_raise` · Asılı Bacak Kaldırma
- **destination** · `photos/workout_backgrounds/`
- **filename** · `HangingLegRaise.webp`
- **prompt** ·

  > A single athlete performing a hanging leg raise, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Bacak Kaldırma

- **exercise** · `leg_raise` · Bacak Kaldırma
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LegRaise.webp`
- **prompt** ·

  > A single athlete performing a leg raise, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Mountain Climber

- **exercise** · `mountain_climber` · Mountain Climber
- **destination** · `photos/workout_backgrounds/`
- **filename** · `MountainClimber.webp`
- **prompt** ·

  > A single athlete performing a mountain climber, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Plank

- **exercise** · `plank` · Plank
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Plank.webp`
- **prompt** ·

  > A single athlete performing a plank, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Rus Dönüşü

- **exercise** · `russian_twist` · Rus Dönüşü
- **destination** · `photos/workout_backgrounds/`
- **filename** · `RussianTwist.webp`
- **prompt** ·

  > A single athlete performing a russian twist, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Sit-up

- **exercise** · `situp` · Sit-up
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Situp.webp`
- **prompt** ·

  > A single athlete performing a situp, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Ağırlıklı Rus Dönüşü

- **exercise** · `weighted_russian_twist` · Ağırlıklı Rus Dönüşü
- **destination** · `photos/workout_backgrounds/`
- **filename** · `WeightedRussianTwist.webp`
- **prompt** ·

  > A single athlete performing a weighted russian twist, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Chest — 7

Falling back to `photos/workouts/chest_activation_growth.webp` until these land.

### Dambıl Bench Press

- **exercise** · `bench_press` · Dambıl Bench Press
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BenchPress.webp`
- **prompt** ·

  > A single athlete performing a bench press, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Göğüs Dip

- **exercise** · `chest_dip` · Göğüs Dip
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ChestDip.webp`
- **prompt** ·

  > A single athlete performing a chest dip, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Chest Fly

- **exercise** · `chest_fly` · Chest Fly
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ChestFly.webp`
- **prompt** ·

  > A single athlete performing a chest fly, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Yokuş Aşağı Şınav

- **exercise** · `decline_push_up` · Yokuş Aşağı Şınav
- **destination** · `photos/workout_backgrounds/`
- **filename** · `DeclinePushUp.webp`
- **prompt** ·

  > A single athlete performing a decline push up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Yokuş Yukarı Bench Press

- **exercise** · `incline_bench_press` · Yokuş Yukarı Bench Press
- **destination** · `photos/workout_backgrounds/`
- **filename** · `InclineBenchPress.webp`
- **prompt** ·

  > A single athlete performing an incline bench press, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Yokuş Yukarı Şınav

- **exercise** · `incline_push_up` · Yokuş Yukarı Şınav
- **destination** · `photos/workout_backgrounds/`
- **filename** · `InclinePushUp.webp`
- **prompt** ·

  > A single athlete performing an incline push up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Şınav

- **exercise** · `push_up` · Şınav
- **destination** · `photos/workout_backgrounds/`
- **filename** · `PushUp.webp`
- **prompt** ·

  > A single athlete performing a push up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Back — 5

Falling back to `photos/workouts/back_v_taper.webp` until these land.

### Barbell Row

- **exercise** · `barbell_row` · Barbell Row
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BarbellRow.webp`
- **prompt** ·

  > A single athlete performing a barbell row, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Chin-up

- **exercise** · `chin_up` · Chin-up
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ChinUp.webp`
- **prompt** ·

  > A single athlete performing a chin up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Lat Pulldown

- **exercise** · `lat_pulldown` · Lat Pulldown
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LatPulldown.webp`
- **prompt** ·

  > A single athlete performing a lat pulldown, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Pull-up

- **exercise** · `pull_up` · Pull-up
- **destination** · `photos/workout_backgrounds/`
- **filename** · `PullUp.webp`
- **prompt** ·

  > A single athlete performing a pull up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Superman

- **exercise** · `superman` · Superman
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Superman.webp`
- **prompt** ·

  > A single athlete performing a superman, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Shoulders — 5

Falling back to `photos/workouts/shoulders_giant.webp` until these land.

### Arnold Press

- **exercise** · `arnold_press` · Arnold Press
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ArnoldPress.webp`
- **prompt** ·

  > A single athlete performing an arnold press, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Front Raise

- **exercise** · `front_raise` · Front Raise
- **destination** · `photos/workout_backgrounds/`
- **filename** · `FrontRaise.webp`
- **prompt** ·

  > A single athlete performing a front raise, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Lateral Raise

- **exercise** · `lateral_raise` · Lateral Raise
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LateralRaise.webp`
- **prompt** ·

  > A single athlete performing a lateral raise, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Pike Şınav

- **exercise** · `pike_push_up` · Pike Şınav
- **destination** · `photos/workout_backgrounds/`
- **filename** · `PikePushUp.webp`
- **prompt** ·

  > A single athlete performing a pike push up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Shoulder Press

- **exercise** · `shoulder_press` · Shoulder Press
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ShoulderPress.webp`
- **prompt** ·

  > A single athlete performing a shoulder press, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Arms — 7

Falling back to `photos/workouts/arms_steel.webp` until these land.

### Biceps Curl

- **exercise** · `biceps_curl` · Biceps Curl
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BicepsCurl.webp`
- **prompt** ·

  > A single athlete performing a biceps curl, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Yakın Tutuş Şınav

- **exercise** · `close_grip_push_up` · Yakın Tutuş Şınav
- **destination** · `photos/workout_backgrounds/`
- **filename** · `CloseGripPushUp.webp`
- **prompt** ·

  > A single athlete performing a close grip push up, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Konsantrasyon Curl

- **exercise** · `concentration_curl` · Konsantrasyon Curl
- **destination** · `photos/workout_backgrounds/`
- **filename** · `ConcentrationCurl.webp`
- **prompt** ·

  > A single athlete performing a concentration curl, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Hammer Curl

- **exercise** · `hammer_curl` · Hammer Curl
- **destination** · `photos/workout_backgrounds/`
- **filename** · `HammerCurl.webp`
- **prompt** ·

  > A single athlete performing a hammer curl, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Skull Crusher

- **exercise** · `skull_crusher` · Skull Crusher
- **destination** · `photos/workout_backgrounds/`
- **filename** · `SkullCrusher.webp`
- **prompt** ·

  > A single athlete performing a skull crusher, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Triceps Dip

- **exercise** · `triceps_dip` · Triceps Dip
- **destination** · `photos/workout_backgrounds/`
- **filename** · `TricepsDip.webp`
- **prompt** ·

  > A single athlete performing a triceps dip, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Triceps Pushdown

- **exercise** · `triceps_pushdown` · Triceps Pushdown
- **destination** · `photos/workout_backgrounds/`
- **filename** · `TricepsPushdown.webp`
- **prompt** ·

  > A single athlete performing a triceps pushdown, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Legs — 10

Falling back to `photos/workouts/legs_power_day.webp` until these land.

### Barbell Squat

- **exercise** · `barbell_squat` · Barbell Squat
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BarbellSquat.webp`
- **prompt** ·

  > A single athlete performing a barbell squat, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Bulgar Split Squat

- **exercise** · `bulgarian_split_squat` · Bulgar Split Squat
- **destination** · `photos/workout_backgrounds/`
- **filename** · `BulgarianSplitSquat.webp`
- **prompt** ·

  > A single athlete performing a bulgarian split squat, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Calf Raise

- **exercise** · `calf_raise` · Calf Raise
- **destination** · `photos/workout_backgrounds/`
- **filename** · `CalfRaise.webp`
- **prompt** ·

  > A single athlete performing a calf raise, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Leg Curl

- **exercise** · `leg_curl` · Leg Curl
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LegCurl.webp`
- **prompt** ·

  > A single athlete performing a leg curl, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Leg Extension

- **exercise** · `leg_extension` · Leg Extension
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LegExtension.webp`
- **prompt** ·

  > A single athlete performing a leg extension, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Leg Press

- **exercise** · `leg_press` · Leg Press
- **destination** · `photos/workout_backgrounds/`
- **filename** · `LegPress.webp`
- **prompt** ·

  > A single athlete performing a leg press, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Lunge

- **exercise** · `lunge` · Lunge
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Lunge.webp`
- **prompt** ·

  > A single athlete performing a lunge, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Romen Deadlift

- **exercise** · `romanian_deadlift` · Romen Deadlift
- **destination** · `photos/workout_backgrounds/`
- **filename** · `RomanianDeadlift.webp`
- **prompt** ·

  > A single athlete performing a romanian deadlift, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Squat

- **exercise** · `squat` · Squat
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Squat.webp`
- **prompt** ·

  > A single athlete performing a squat, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Wall Sit

- **exercise** · `wall_sit` · Wall Sit
- **destination** · `photos/workout_backgrounds/`
- **filename** · `WallSit.webp`
- **prompt** ·

  > A single athlete performing a wall sit, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.


## Full body — 5

Falling back to `photos/workouts/cardio_full_body_flow.webp` until these land.

### Burpee

- **exercise** · `burpee` · Burpee
- **destination** · `photos/workout_backgrounds/`
- **filename** · `Burpee.webp`
- **prompt** ·

  > A single athlete performing a burpee, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### High Knees

- **exercise** · `high_knees` · High Knees
- **destination** · `photos/workout_backgrounds/`
- **filename** · `HighKnees.webp`
- **prompt** ·

  > A single athlete performing a high knees, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Jump Squat

- **exercise** · `jump_squat` · Jump Squat
- **destination** · `photos/workout_backgrounds/`
- **filename** · `JumpSquat.webp`
- **prompt** ·

  > A single athlete performing a jump squat, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### Jumping Jack

- **exercise** · `jumping_jack` · Jumping Jack
- **destination** · `photos/workout_backgrounds/`
- **filename** · `JumpingJack.webp`
- **prompt** ·

  > A single athlete performing a jumping jack, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

### İp Atlama

- **exercise** · `skipping_rope` · İp Atlama
- **destination** · `photos/workout_backgrounds/`
- **filename** · `SkippingRope.webp`
- **prompt** ·

  > A single athlete performing a skipping rope, caught mid-repetition at the hardest point of the movement, positioned to the right of frame with the left third empty, dark industrial gym at night, deep black background, violet and magenta neon strip lighting from behind, strong rim light on the muscles, high contrast, cinematic colour grade, visible sweat and skin detail, shallow depth of field, ultra realistic fitness photography, highly detailed, 4k. 4:3 landscape. No text, no watermark, no logo, no on-screen graphics.

---

## 5. Two things found while building this, neither of them blocking

**`photos/exercises/` has baked-in text, in two languages.** Those 87
files are the instructional before/after panels shown by the exercise
guide, and they carry captions burned into the pixels — some English
(`BEFORE: STARTING POSITION`), some Turkish (`ÖNCE: BAŞLANGIÇ DURUŞU`).
So a Turkish user reads English on some exercises and an English user
reads Turkish on others, and neither can be fixed by translating a
string. Regenerating them is a real content project, not an engineering
fix, so it is recorded here rather than attempted. `docs/i18n/TEXT_IN_IMAGES.md`
now says so out loud.

**`ExerciseMediaRegistry` still needs a code edit per file.** It is the
older sibling of the registry this document describes: it decides which
exercises have a bundled instructional image, and it does it from a
hand-written `Set<String>` that has to be edited whenever a file is added.
Its own doc comment describes the two-step dance. Nothing is broken today,
but it is the same problem the manifest lookup solves, and it is the
obvious next thing to fold in.
