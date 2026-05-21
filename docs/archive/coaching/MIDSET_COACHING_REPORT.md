# Mid-Set Coaching — Tier A.2 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §2 Issue B (voice silence after intro), §8 Tier-A B-fix-1.

## Problem

For 13 of 17 analyzer classes, the only voice during an active set was the rep-milestone announcements ("Yarıladın!" at rep target/2, "Son iki tekrar!" at target-2). For sets with `targetReps < 4`, even those didn't fire. Active-time TTS density was ~6 s of speech per ~52 s of activity — the user heard the 3-second intro then silence.

## Solution

New helper `lib/features/workout/services/coach_voice.dart` owns the active-set voice rhythm. The camera screen calls `coach.startSet(exercise)` when the user transitions from prep/rest into active work, and `coach.endSet()` when the set ends (rest entry, exercise change, session complete, screen pop).

### Mid-set heartbeat

- **Cadence:** every 18 s while active. Dense enough to feel coached, not chatty.
- **Priority:** `SpeechPriority.ambient` — the lowest queue level. A real form warning or rep milestone pre-empts it cleanly through the queue's priority rules (TTS_QUEUE_FIX_REPORT.md).
- **Category-aware copy:** rotating pools keyed by `ExerciseCategory`, with a cardio override:

  | Category | Sample lines |
  |---|---|
  | Cardio | "Ritmini koru, nefesini tutma." / "Tempoyu sabit tut, patlama anı geliyor." |
  | Legs | "Kontrollü in, patlayarak kalk." / "Topuğuna bas, dizlerin hizada kalsın." |
  | Chest | "Hareketi aceleye getirme, kasları hisset." / "Omuz bıçaklarını sıkı tut, kontrolü kaybetme." |
  | Back | "Kürek kemiklerini sıkıştır, sırtla çek." / "Hareketi sonuna kadar götür." |
  | Shoulders | "Yavaş ve kontrollü kaldır, sallama." / "Tepe noktada bir an dur." |
  | Arms | "Dirseğini sabit tut, hareketi izole et." / "Bileği gevşek tut, kası çalıştır." |
  | Core | "Karnını sık, nefesin akıyor olsun." / "Beli yere yapışık tut, hareketi yüklenme." |
  | FullBody | "Bütün vücudu kullan, ritmi düşürme." / "Kontrol senin elinde, devam!" |

  Each pool is 3–4 entries. The rotation index increments per emission so the user hears each line at most once per ~60–80 s of active work.

- **Phrase-level cooldown:** 14 s. Different lines bypass dedupe and play normally; the same line cannot re-fire inside the cooldown window even if the rotation index wraps.

### Lifecycle hooks

- `startSet(exercise)` — captures category + cardio flag, resets rotation index and fired-checkpoint set, schedules the 18 s heartbeat.
- `endSet()` — cancels the heartbeat, clears state. Called on rest entry, exercise change, session complete, dispose, screen pop.
- `onPause()` / `onResume()` — pauses the heartbeat without losing rotation state; the user's next rep resumes where they left off.
- `dispose()` — cancels everything.

## Files changed
- `lib/features/workout/services/coach_voice.dart` — new file. ~230 LOC. Owns rotation pools, fired-checkpoint set, and timers.
- `lib/features/workout/presentation/workout_camera_screen.dart` — instantiates a `CoachVoice` field, wires `startSet`/`endSet`/`onPause`/`onResume`/`dispose` into the existing lifecycle hooks.

## Behavior changes
- During an active set, ambient coaching lines fire every 18 s in priority `ambient`, immediately yielding to any form warning, milestone, or contextual cue.
- The first heartbeat lands at t = 18 s after set start — long enough that the intro line ("Sıradaki hareket: ...") has finished and short enough that the user hears voice within the first half of any non-trivial set.
- Different categories sound different. Cardio overrides category-specific copy when `Exercise.isCardio == true` (burpee, jumping jack, etc.).

## Validation surface
- Push-up 8 reps: intro at t=0, mid-set ambient at t=18 s, mid-set ambient at t=36 s, milestone at rep target/2, "Son iki tekrar!" at rep target-2. Pacing speech (if analyzer emits) at `encouragement` priority — outranks ambient so it pre-empts a stale ambient phrase.
- Plank 40 s: intro at t=0, mid-set ambient at t=18 s, halfway pacing at t=20 s (covered by Tier A.4), mid-set ambient at t=36 s, "Son on saniye!" at t=30 s remaining... wait, halfway pacing has higher priority and will pre-empt — see PACE_SYSTEM_REPORT.md.
- Mid-set warning (e.g. hip sag): pre-empts the ambient heartbeat through the queue's `warning > ambient` rule.
