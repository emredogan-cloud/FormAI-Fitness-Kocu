# PHASE 3b COMPLETION REPORT — Practice Rep, In-Session Tutorial & Carried-Over Verification

| | |
|---|---|
| **Roadmap** | `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` → Wave 1, Phase 3 (residue) |
| **Covers** | R1.2 features 3 · 4 · 6 · remaining Phase 3 technical + AI items |
| **Commits** | `74fe81f` (phase) · `ba138d7` (device-QA fixes) · `3be7bb8` (follow-ups) |
| **Baseline** | `a3837d1` / build 1.0.0+21 → **`3be7bb8` / build 1.0.0+22** |
| **Quality** | analyze **0** · **629 tests** (was 527, **+102**) · `dart format` clean · **CI GREEN** |
| **Artifact** | release APK **126.4 MB** (obfuscated, split-debug-info) |
| **Devices** | Redmi M1908C3JGG (Android 11, 1080×2340) · Huawei ANE-LX1 (Android 9, 1080×2280) |
| **Status** | ✅ **COMPLETE** — one verification gap remains, and it is physical, not engineering (§7) |

---

## 1. Why this phase existed

`PHASE_03_COMPLETION_REPORT.md` §7 recorded, rather than hid, two roadmap
deliverables that did not ship: the **in-session tutorial layer** and the
**guided practice rep**. §6 recorded three open verification gaps. Phase 3b
existed to close all of it.

It closed more than that. Two physical devices were walked end-to-end from a
wiped install, and that pass found three defects that no test suite in the
repository would have caught — one of which made onboarding **impossible to
complete** on the second phone.

---

## 2. What shipped

### 2.1 Guided practice rep (roadmap feature 3)

A fourth stage between calibration and "ready": the user squats once and
watches the app count it.

The whole value of this stage is that **nothing about it is simulated**. It
runs the production `SquatAnalyzer` over real ML Kit landmarks, and the new
`TutorialPosePainter` labels exactly the four joints that analyzer reads —
shoulder, hip, knee, ankle. A test asserts that correspondence directly,
because a painter that claims to watch the knee while the analyzer reads the
hip would be a lie rendered at 15 fps and invisible in review.

A squat is the movement because the user is *already* standing at ~2 m in full
view from calibration; nothing they just achieved has to change.

Skipping is a first-class exit, always visible. A mobility limitation, a
crowded room, or simply not being dressed for it must not put a demo between
someone and their workout.

Extracted as `PracticeRepStage` — pure presentation, owns no camera, no
detector, no timers — which is what lets the entire stage be tested without a
camera platform channel.

### 2.2 In-session tutorial layer (roadmap feature 4)

Five `SpotlightTour` steps over the rep counter, the form indicator, the pause
control, the voice toggle and the next control. Once per install.

Anchors were added to the **existing Phase 2 `TourTargets` registry** rather
than a parallel workout-only one. The registry's job is "resolve a
spotlightable widget's rect", and that job does not change by feature.

Two decisions worth naming:

**Analysis is suspended by a dedicated `_tutorialActive` flag, not by
flipping `_isPaused`.** The layer spotlights the pause control *while
describing it*; that control showing "resume" mid-explanation is exactly the
confusion this phase exists to remove. Device screenshots confirm the pause
icon stays correct throughout.

**The one-shot can't be burned silently.** `showSpotlightTour` drops
unresolvable steps and returns `false` when that leaves nothing — at the call
site, indistinguishable from "the user skipped". Marking seen on that would
consume the tutorial without ever showing it. It now pre-checks that at least
one anchor resolves and lets a later transition retry.

### 2.3 Replayable setup guide (roadmap feature 6)

`?replay=1` from the workout overflow menu and from the manual screen's app
bar. A replay **returns the user where they came from** instead of launching a
workout, and skips a practice rep they have already done. Someone who taps
"remind me how to place the phone" has not asked to start a session.

### 2.4 Remaining Phase 3 technical + AI items

| Item | Shipped |
|---|---|
| `session_log` `source` (camera/manual) | Tolerant parse; pre-existing logs read as `camera`, which is what they were |
| Voice-coach mute | Gated once inside `AudioFeedback.speak` — a mute each of twelve call sites had to remember is a mute that leaks |
| `firstCameraSession` + `workoutMode` on `CoachContext` | Coach can reference the setup just finished, and never promises form feedback to a camera-free user |
| Analytics | `tutorialCalibrationFailed`, `tutorialPracticeRep`, `inSessionTutorialFinished`, `tutorialReplayed`, `voiceCoachToggled` |
| `TutorialPosePainter` | Joint-labelling variant (roadmap technical work) |
| `CameraFrameConverter.analysedSize` | Rotation-aware frame geometry, shared by coverage maths and the overlay |

---

## 3. What device verification found

Three defects, none of which any test in the repository would have caught.

### 3.1 The AI report CTA was unreachable on the second phone (P0)

On the Huawei (1080×2280) the report's fixed-height children overflowed the
viewport. "KİŞİSEL PLANIMI AL" was clipped at the bottom edge and **would not
accept a tap** — repeatedly, at four different points inside its visible band.
Onboarding could not be completed on that phone at all.

This is the **third** time a fixed-height onboarding layout has pushed its
primary CTA out of reach in this app (RC-17 paywall, RC-18 Başla). It is fixed
the same proven way: the body scrolls, the conclusion and CTA are
structurally outside that scroll area, so no viewport height can hide them.

The new test asserts **reachability, not pixels** — the CTA must be inside the
viewport *and* actually fire its callback, at three viewport sizes and at a
1.3 text scale.

### 3.2 The in-session tutorial never fired on an already-active session

The layer was attempted only from the session `ref.listen`, which fires on
transitions. Entering the camera screen mid-workout — switching over from
camera-free mode, which is a shipped path — produces no transition after
mount, so the user silently never learned the controls. Now also attempted
from a post-frame callback on the data branch.

Found by walking the exact path a camera-free user takes when they change
their mind.

### 3.3 The first-run welcome cinematic never auto-closed

Reproduced twice, once on a completely clean install with no interference:
the dashboard welcome scene sat past 22 s against its own 8 s
`autoCloseAfter`. It is a full-screen, non-dismissible route with no visible
exit — the only way out is the system back button, which nothing on screen
suggests.

The same scene closes correctly in a widget test. That rules out a fixable
logic error in the timer and makes it an environment-dependent failure, so the
remedy is a watchdog rather than a speculative rewrite: a second timer calls
`removeRoute` on that exact route past its deadline, and **logs when it has
to**, which turns a currently-invisible failure into something diagnosable.
`removeRoute` targets the route object, so it cannot pop something the user
navigated to meanwhile, and it no-ops entirely on the normal path.

### 3.4 Two smaller ones

* `TutorialPosePainter` threw on a degenerate canvas (clamp max below min) —
  found by test, would have crashed the live camera screen.
* Three fixed `Text`s inside `Row`s on the report overflowed horizontally at
  360 dp / 1.3 text scale. The CTA now scales down rather than ellipsising: a
  primary CTA reading "KİŞİSEL PLA…" is worse than one a point smaller.

---

## 4. The three carried-over verification gaps

All three unlocked at `completedDays >= 1`, and a full day was completed on
the Redmi to close them.

| # | Gap | Result |
|---|---|---|
| 1 | **Phase 1 rating cinematic** | ✅ Fired after the first completed workout — "İlk adımı attın." with the 5-star row. **Sentiment routing also verified**: 2★ routed to the in-app feedback sheet, *not* the Play Store |
| 2 | **Phase 2 discovery tip card** | ✅ "BİLİYOR MUYDUN?" card surfaced on the dashboard with its dismiss affordance |
| 3 | **Day completion in manual mode** | ✅ "Gün 1 Tamam!" → day marked complete, program advanced to Day 2, and the whole downstream chain fired: streak 1 · 150 XP · Sv 1 · %3 program · **"İlk Adım" badge unlocked** |

---

## 5. Device verification — full ledger

**Redmi M1908C3JGG · Android 11 · 1080×2340** (wiped and re-walked twice)

| # | Verified | Result |
|---|---|---|
| 1 | Age gate → consent → Başla hero | ✅ |
| 2 | Onboarding LLM name chat | ✅ Live Claude reply, personalised |
| 3 | 11-step wizard → AI report → commitment | ✅ |
| 4 | **Report CTA pinned + body scrollable** | ✅ Assessment text fully readable by scrolling; CTA never moves |
| 5 | Post-paywall feature showcase (Phase 2) | ✅ 4 cards, skip works |
| 6 | Welcome scene + dashboard tour resolve | ✅ Clean dashboard |
| 7 | Discovery dots on unvisited tabs (Phase 2 C37) | ✅ Present, cleared on visit |
| 8 | Router intercepts first `/workout` → tutorial | ✅ |
| 9 | Placement stage + privacy note | ✅ |
| 10 | Camera opens, live ML Kit | ✅ First try; correct `partiallyVisible` verdict on an upper-body frame |
| 11 | Camera-free path (C21) | ✅ Real plan data |
| 12 | **Setup-guide replay from manual screen** | ✅ Opens, returns to the session |
| 13 | **Setup-guide replay from workout overflow** | ✅ "Kamera kurulumunu tekrar göster" |
| 14 | **Voice toggle** | ✅ Icon flips to muted, persists |
| 15 | **In-session tutorial — all 5 steps** | ✅ Correct targets, computed bubble placement above/below, "Anladım" on the last step |
| 16 | **Analysis suspended during the tour** | ✅ Detector `UNKNOWN` throughout, `DOWN` immediately after — suspend *and* resume both work |
| 17 | Full day completion | ✅ + rating cinematic + tip card + badge (§4) |

**Huawei ANE-LX1 · Android 9 · 1080×2280 · 0.5× animation scale**

| # | Verified | Result |
|---|---|---|
| 1 | Age gate → consent → Başla hero | ✅ RC-18 fold fix holds on a second aspect ratio |
| 2 | Onboarding chat **offline fallback** | ✅ Scripted reply — the designed no-network path, exercised for the first time |
| 3 | 11-step wizard → AI report | ✅ |
| 4 | **Report CTA (pre-fix)** | ❌ Clipped and untappable → §3.1 |
| 5 | **Report CTA (post-fix)** | ✅ Onboarding advances past step 10/11 |
| 6 | Commitment step 11/11 | ✅ CTA fully visible |

The Huawei has **no network** (no SIM, no reachable WiFi), so guest sign-in —
which needs Supabase auth — cannot complete there. Its coverage is bounded to
the offline surfaces above. That is a device-environment limit, not a product
defect, and the offline fallback it did exercise is a path the Redmi never
reaches.

---

## 6. Testing

**629 tests pass (was 527, +102). analyze 0. format clean. CI green.**

| Concern | Tests | Notable assertions |
|---|---|---|
| Practice-rep stage | 13 | **Every labelled joint is one `SquatAnalyzer` actually reads**; the analyzer under it is the production class; live rep count is the analyzer's; cue rendered verbatim; skip fires and is ≥48 dp; rep count is a screen-reader live region; 1.3 scale on a narrow phone |
| Tutorial pose painter | 14 | Never throws on missing / empty / off-frame / low-confidence landmarks; **zero-size canvas** (the bug it caught); label flips inward at the right edge; `shouldRepaint` on label changes and against a plain `PosePainter` |
| Report fold | 8 | CTA inside the viewport at 3 sizes; **actually fires its callback** on the short viewport that exposed the bug; no overflow at 1.3 scale; body scrolls |
| First-run scene | 5 | Closes with no interaction; user lands back on the host screen; one-shot latches; already-seen users get nothing; **flag set before the push** so a stuck scene can't become a permanent trap |
| Camera tutorial screen | 13 | Opens on placement not a permission prompt; privacy claim at the decision moment; camera-free path records manual mode **and lands on the manual surface**; sets nothing until a terminal choice; replay preserves flags |
| Session source | 12 | Token stability; **a v1 log with no `source` parses as camera, not an error**; malformed degrades without throwing |
| Voice mute | 8 | Nothing reaches the platform when muted; **checked before `init`** so it can't be defeated by an early call site; blocks even `warning` priority; muting mid-utterance stops the engine |
| Frame geometry | 6 | 90°/270° swap; the two helpers can never disagree; documents the 1.33× coverage error the swap prevents |
| Tour anchors | 10 | All five resolve to distinct non-empty rects; geometry sane; panel unchanged when keys are absent |
| Preferences | 12 | Voice defaults **on**; practice-rep flag independent of the tutorial flag; an upgrading user isn't treated as having done the practice rep |

### The CI/local toolchain gap

Phases 1–3 each hit a CI-only finding. Phase 3b hit **none** — every failure
this phase came from device QA instead. Local Flutter 3.41.9 vs CI 3.44.8
remains the standing caveat, and every commit here was held open until CI went
green.

---

## 7. The one remaining gap, stated plainly

**The practice rep and the "Seni görüyorum" success stage were not seen on a
device.** Both require a full body in frame at ~2 m — a person physically
standing back from the phone, which is not drivable over adb. The camera was
live, ML Kit was reading a real person, and the framing verdict was correct
(`partiallyVisible` for an upper-body frame) — but the frame never contained a
whole body, so calibration never confirmed and the stage after it never
rendered.

What *is* proven: the analyzer is the production one, the labelled joints match
what it reads, the stage renders and behaves correctly under test, and the path
into it is the same `evaluateFraming` → stabilizer → success transition that 29
tests cover and that returned correct verdicts on live landmarks.

This is a **physical-subject limitation, not an engineering gap**. It needs one
person to stand two metres from the phone and squat once.

Also still open from Phase 3: `RequiredView` is defined and tested but not
applied per exercise — that needs per-exercise view metadata in the catalogue
and belongs with a content pass.

~70 new Turkish string literals join the backlog awaiting Phase 5 ARB
extraction.

---

## 8. Files changed

**31 files · +2,990 / −159**

**New — production (2)**: `widgets/practice_rep_stage.dart` ·
`TutorialPosePainter` (in `pose_painter.dart`)

**Modified — production (12)**: `camera_tutorial_screen` (practice stage,
replay, setup voice, failure analytics) · `workout_camera_screen` (tour, voice
toggle, overflow menu, tour anchors) · `manual_workout_screen` (guide entry) ·
`workout_control_panel` (optional anchors) · `tour_targets` (5 workout keys) ·
`app_preferences` (voice + practice flags) · `audio_feedback` (mute gate) ·
`session_log_model` (`SessionSource`) · `workout_provider` (log provenance) ·
`coach_context` + `coach_providers` (2 flags) · `camera_frame_converter`
(`analysedSize`) · `app_router` (replay route) · `analytics_service` (5 events)
· `act_4_revelation_steps` (pinned CTA + overflow fixes) ·
`first_time_ai_scenes` (watchdog)

**New — tests (8)**: practice-rep stage · tutorial pose painter · report fold ·
first-run scene · camera tutorial screen · session source · voice mute · frame
geometry · tour anchors · Phase 3b preferences

---

## 9. Next phase

**Phase 4 — Progressive Disclosure & Feature-Flag Infrastructure**
(R1.3 · C7 · C28 · C36 · P3). The flag layer is the most reusable thing left in
Wave 1: staged rollouts, kill switches and the onboarding A/B test all depend
on it, as does every later wave.

---

*Phase 3b complete. `3be7bb8` on `main`, CI green, build 1.0.0+22.*
