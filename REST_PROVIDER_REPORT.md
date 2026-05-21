# Rest Countdown Provider Split — Tier B.8 Report

**Closes:** WORKOUT_INTELLIGENCE_AUDIT.md §5 U12 (workoutSessionProvider re-emits on every rest tick).

## Problem

The session-state model previously held the live rest countdown in `WorkoutSessionState.restSecondsRemaining`. The rest timer mutated `state = AsyncData(current.copyWith(restSecondsRemaining: remaining))` once per second. Every tick:

1. Riverpod re-emitted `workoutSessionProvider` value.
2. The camera screen's `ref.watch(workoutSessionProvider)` re-rendered the whole tree.
3. The camera screen's `ref.listen` body ran (most of it was no-op branches).
4. The iOS Live Activity sync code inside that listener fired an `updateWorkout` to the platform channel — even though only one field changed.

Net: 1 Hz wake-up on the whole workout subtree throughout every rest window.

## Solution

Add a dedicated `restCountdownProvider` (Notifier<int>) for the per-second decrement. The session state's `restSecondsRemaining` field is preserved but now holds the **initial** rest duration (frozen at rest entry); the live tick lives only in the new provider.

### Tick path
- Rest entry: session state mutates ONCE with `isResting: true` and `restSecondsRemaining: N`; the new provider gets `N`.
- Each tick: only the new provider gets the decremented value.
- Rest exit / skip: session state mutates ONCE with `isResting: false` and `restSecondsRemaining: 0`; the new provider gets `0`.

### Consumer changes
- **RestOverlay** in `workout_camera_screen._buildSession`: now wraps the overlay construction in `ref.watch(restCountdownProvider)` and passes the live value as `secondsRemaining`. Only the rest overlay re-renders on tick — the rest of `_buildSession` is gated by `session.isResting` (a session-state field that doesn't change per tick).
- **Live Activity sync**: untouched. The sync block inside `ref.listen` already only fires on real session transitions (`exerciseChanged || setChanged || justStartedRest || justFinishedRest || justStartedPrep || justFinishedPrep`). With the per-tick state mutation removed, the listener now only fires on those real transitions — exactly when Live Activity should get an update. Per-second pushes to the platform channel are eliminated.

### Riverpod 3 caveat

The Riverpod 3.x removal of `StateProvider` was the only API friction. Implemented as a tiny `Notifier<int>` with a `set(int)` helper — call sites pass through `ref.read(restCountdownProvider.notifier).set(value)` instead of the older `.state = value`. The notifier itself owns mutation discipline.

## Files changed
- `lib/features/workout/providers/workout_provider.dart` — new `RestCountdownNotifier` + `restCountdownProvider`. `_enterRest` and `skipRest` now write to the new provider instead of repeatedly copying the session state. ~45 LOC net.
- `lib/features/workout/presentation/workout_camera_screen.dart` — `_buildSession` watches the new provider when rendering the rest overlay. 4-line addition.

## Behavior changes
- During rest: `workoutSessionProvider` only re-emits on rest enter and rest exit. Tick decrement updates a separate, smaller provider.
- The camera screen's full subtree no longer re-renders 60 times during a 60 s rest — only the rest overlay does.
- The camera screen's `ref.listen` body no longer runs per-tick — it only fires on real session transitions.
- iOS Live Activity no longer gets per-second `updateWorkout` calls — it gets updates only on session-transition boundaries, which is the intended cadence.

## Behavior parity
- The countdown displayed in the rest overlay ticks exactly as before.
- Skip rest still works (now clears both the session state and the countdown provider).
- Rest end → prep start sequencing is unchanged.
- Inter-set vs inter-exercise rest distinction (`_restPrecedesExerciseChange`) is unchanged.

## Validation
- Start a 60 s rest, watch the overlay countdown tick from 60 → 0 with no UI lag.
- Tap "skip rest" mid-countdown — overlay disappears immediately, countdown provider clears to 0.
- Confirm the camera screen's ambient mid-set heartbeat does NOT fire during rest (it's gated by the existing `isResting` flag on session state, which still flips correctly).
- Confirm Live Activity (iOS) reflects rest entry/exit without per-second updates.
