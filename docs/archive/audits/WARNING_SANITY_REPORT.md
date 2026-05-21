# Warning Cooldown + Dedupe — Tier A.5 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §1 B2 (cooldown swallowing), audit Tier-A "no rapid-fire voice."

## Problem

With Tier A.1 (TTS queue) + Tier A.2 (mid-set heartbeat) + Tier A.4 (pacing checkpoints) + Tier S.3 (form warnings) all firing into the same speech pipeline, the user could plausibly hear:

- Mid-set ambient at t=18 s ("Karnını sık...")
- Form warning at t=18.2 s (analyzer detects sag)
- Halfway pacing at t=20 s (timer halfway)
- Mid-set ambient at t=36 s
- "Son iki tekrar" milestone at rep 6

…and the queue would happily serve all five. That is more density than is healthy. Tier A.5 codifies the sanity rules.

## Solution — Three-layer dedupe

### Layer 1: Analyzer-local cooldowns (already present, audited)

Every analyzer that emits a `formWarning` keeps a `_lastFormWarning` timestamp:

| Analyzer | Warning | Cooldown |
|---|---|---|
| CrunchAnalyzer | "Boynunu düz tut!" | 15 s |
| PlankAnalyzer | "Kalçanı düz tut..." | 8 s |
| ShoulderPressAnalyzer | "Kolları tam yukarı uzat!" | per-rep (only on partial commit) |
| SquatAnalyzer (Tier S.3) | "Göğsünü yukarı tut..." | 12 s |
| PushUpAnalyzer (Tier S.3) | "Kalçanı yukarı tut..." | 10 s |
| BicepsCurlAnalyzer (Tier S.3) | "Dirseğini gövdene yapışık tut!" | 12 s |
| LateralRaiseAnalyzer (Tier S.3) | "Kolları omuz hizasında tut..." | 12 s |

These prevent the analyzer from *emitting* a warning more than once per cooldown. The queue never sees duplicates from the analyzer side.

### Layer 2: Phrase-level dedupe in `AudioFeedback._phraseLastSpoken`

`AudioFeedback.speak(text, cooldown: ...)` ledger keyed by exact phrase string. A phrase that fired within the cooldown window is silently dropped on the next `speak()` call regardless of priority or queue depth.

Default cooldown = 3 s. Per-call overrides:

| Call site | Cooldown |
|---|---|
| Mid-set heartbeat | 14 s (CoachVoice) |
| Pacing checkpoint | 4 s (CoachVoice — short because each checkpoint is single-shot anyway) |
| Rest tick (commit 3) | 12 s |
| Form warning | 3 s default (analyzer cooldown is the binding gate) |

Different-phrase coaching (e.g. rotating mid-set lines) bypasses dedupe entirely because the key is the literal string.

### Layer 3: Queue soft cap

`AudioFeedback._maxQueueDepth = 3`. If a fourth `speak()` arrives while three are queued, the **lowest-priority** tail entry is dropped on enqueue. Net effect: a burst of ambient coaching cues cannot crowd out a queued warning, and the user never hears stale lines from > 4 s ago.

## Files changed
- All cooldowns + dedupe live inside `lib/core/utils/audio_feedback.dart` (Tier A.1) and `lib/features/workout/services/coach_voice.dart` (Tier A.2/A.4) — no separate file change for A.5.

## Behavior changes
- Same warning cannot repeat inside its analyzer cooldown (8–15 s).
- Same ambient line cannot repeat inside 14 s. Different lines bypass dedupe.
- Same pacing checkpoint cannot fire twice per set (independent `_firedTimedCheckpoints` set).
- Queue depth capped at 3; tail entries dropped on overflow.

## Density audit (worst-case 40 s plank)

| t (s) | Surface | Pri | Played? |
|---|---|---|---|
| 0 | "Sıradaki hareket: Plank. ..." | milestone | YES (intro) |
| ~3 | (intro ends) | — | — |
| 18 | Ambient: "Nefesini topla..." (core) | ambient | YES |
| 20 | Pacing: "Yarıladın, sık dişini..." | encouragement | YES (pre-empts ambient if still mid-phrase) |
| 24 | Analyzer warning: "Kalçanı düz tut!" | warning | YES (pre-empts) |
| 30 | Pacing: "Son on saniye, bırakma!" | encouragement | YES |
| 35 | Pacing: "Beş saniye, dayan!" | encouragement | YES |
| 36 | Ambient: "Beli yere yapışık tut..." | ambient | DROPPED (lower priority than queued/active, or dedupe — depending on order) |
| 40 | "Süre doldu, harika!" | milestone | YES |

Total: ~7–8 spoken phrases across 40 s. ~5 s of speech in 40 s of activity. Up from < 5 s pre-Tier-A. Below talk-radio density.
