# TTS Queue Fix — Tier A.1 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §5 R7 (TTS interruption race) and §1 B1 (same-tick `_tts.stop()` races).

## Problem

`AudioFeedback.speak()` called `await _tts.stop()` before every utterance. Any new `speak()` aborted the currently-playing phrase, so form warnings were cut off by rep milestones, milestones were cut off by warnings, and the user heard half-sentences.

## Solution

`lib/core/utils/audio_feedback.dart` now runs a single-worker priority pipeline:

1. **One playing utterance + a small queue.** No more unconditional `stop()` per call.
2. **`SpeechPriority` enum** with five levels:
   - `warning` (highest) — form / safety corrections
   - `cue` — mid-rep phase coaching
   - `milestone` — rep, set, session-level achievements + lifecycle announcements
   - `encouragement` — pacing feedback
   - `ambient` (lowest) — rest-phase and mid-set heartbeats
3. **Pre-emption ONLY upward.** A new phrase whose priority **strictly exceeds** the current phrase's priority calls `_tts.stop()`, inserts itself at the queue front, and the in-flight `speak()` finally-block plays it next. Equal or lower priority queues.
4. **Soft cap at 3 entries.** Burst of ambient cues can't crowd out a queued warning — lowest-priority tail entries are dropped past the cap.
5. **Phrase-level dedupe.** A `_phraseLastSpoken` map keyed by exact phrase string blocks re-queueing of the same line within `cooldown` (default 3 s). Rotating coaches still work because they emit different strings.
6. **Concurrent `init()` coalesced.** Multiple callers awaiting first-launch language enumeration no longer race.

## API change

```dart
// Before
_audio.speak(phrase);

// After (back-compat: defaults to milestone priority)
_audio.speak(phrase, priority: SpeechPriority.warning);
_audio.speak(phrase, priority: SpeechPriority.ambient);
```

Default priority is `milestone` so existing call sites compile unchanged. Upgraded the four sites where intent diverged:

| Site | Old | New |
|---|---|---|
| `_processImage` form warning | speak(warning) | warning |
| `_processImage` contextual cue | speak(cue) | cue |
| Rep milestone speech | speak(...) | milestone (explicit) |
| Pacing feedback | speak(...) | encouragement |
| Session/rest/intro/timer-complete | speak(...) | milestone (explicit) |

## Files changed
- `lib/core/utils/audio_feedback.dart` — full rewrite into queued architecture (~280 LOC, dispose-safe).
- `lib/features/workout/presentation/workout_camera_screen.dart` — added explicit priorities to five `_audio.speak` call sites.

## Behavior changes
- Form warnings never get cut off by milestones, cues, or pacing speech.
- Bursts of ambient/encouragement cues drop tail entries instead of pre-empting active speech.
- `_tts.stop()` only fires on (a) intentional pre-emption by a strictly-higher priority, (b) the smoke-test path, or (c) dispose.
- Same-phrase rapid re-emission is silently dropped within the cooldown window — the previous behavior used the same dedupe; preserved.

## Backward compatibility
All existing `_audio.speak(text)` callers continue to work (default = `SpeechPriority.milestone`, default cooldown = 3 s).

## Validation surface
- Plank: hip-sag warning interrupts an in-flight ambient heartbeat? Yes — `warning` > `ambient`.
- Push-up: rep-milestone "Yarıladın!" tries to interrupt the hip-sag warning? Blocked — `milestone` < `warning`, queued instead; played after warning finishes.
- Two ambient cues fire back-to-back? Both queue; played serially.
- Three ambient + one warning during a long set? Tail ambient drops; warning lands at front; everything else plays in priority order.
