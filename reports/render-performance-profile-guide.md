# Render Performance Profile Guide — Phase 122

> **Phase 122** · profiling protocol for the cinematic onboarding surfaces.
> **Status:** measurement instructions + decision rules. The user runs profile mode and reports findings.
> **One safe code-level fix** shipped in this commit: RepaintBoundary added at LivingCoachAvatar's outer level so parent-rebuild storms don't bubble repaints through the avatar subtree.

## 0. The principle

Every cinematic primitive in this rebuild was written with `RepaintBoundary` at its root. The audit (Phase 117) and stabilization (Phase 116) both established that the visible frame skipping was caused by a layout-assertion retry storm, not by motion cost. Until profile-mode data shows otherwise, **DO NOT remove or simplify** any motion primitive.

This guide is the protocol for collecting that data.

## 1. Setup — once per session

```bash
cd ~/Downloads/SixPack-AI

# 1.1 — make sure you're in profile mode, not debug.
flutter run --profile

# 1.2 — when the device shows the running app, the terminal prints:
#         A Dart VM Service ... is available at: http://127.0.0.1:5XXXX/...
#         The Flutter DevTools debugger and profiler ... is available at:
#           http://127.0.0.1:5YYYY/?uri=...
#       Open the SECOND URL in your browser.

# 1.3 — in DevTools, switch to the "Performance" tab.
#       (Not "CPU profiler" — that's for Dart code; we want the Flutter
#       per-frame chart.)

# 1.4 — at the top of the Performance tab, toggle ON "Track Widget Builds"
#       and "Track Layouts". These add overhead during capture but reveal
#       which widgets are causing slow frames.
```

You're now ready to walk the surfaces.

## 2. Per-surface profiling protocol

For each surface, the procedure is:

1. Navigate to the surface in the running app
2. In DevTools Performance, click "Start Recording"
3. Interact with the surface as a real user would (tap, scroll, wait)
4. Click "Stop Recording" after ~5–10 s
5. Examine the per-frame chart for slow frames (yellow / red bars)
6. For any slow frame, click it → expand the "Frame timing" panel → identify the dominant cost

Healthy frame budget: **16.67 ms** per frame at 60 fps. If you see frames > 33 ms (red), that's a real problem. Frames in the 16–33 ms range (yellow) are borderline; if they're rare, ignore. If they're frequent during a transition, the transition needs simplification.

### 2.1 — Scene transitions (Phase 99 SceneTransition)

**How to trigger:** advance from any onboarding step to the next (any tap that fires `_next()` in `onboarding_screen.dart`).

**What to watch:**
- The 480 ms cross-fade window — there should be ~28 frames recorded
- Both old + new scene render simultaneously during the cross-fade — this is by design (cinematic depth)
- Each scene has FadeTransition + SlideTransition + Transform.scale wrapping it (Phase 99's `_SceneFrame` function in `scene_transition.dart`)

**Acceptable:** all frames < 16 ms during the cross-fade.

**If frames > 16 ms during cross-fade:**
- Identify which scene is the heavy one — likely `DynamicReportStep` (most layered) or `PrePaywallSummaryStep` (paywall backdrop sits behind)
- Mitigation: increase `MotionTokens.sceneCrossfade` from 480 ms → 600 ms (gives more frame budget per frame)
- Or: skip the scene scale (set `scale: 1.0 + 0.0 * t` in `_SceneFrame`)
- Last resort: reduce overlap to a slide-only transition

### 2.2 — AmbientParticles (Phase 100, 113, 115)

**How to trigger:** the analysis-illusion screen, dynamic-report screen, social-proof screen, paywall, and several interludes all run AmbientParticles continuously.

**What to watch:**
- Steady-state frame cost while the screen is idle (no user interaction)
- Look at the "Raster" timeline — the GPU side of the frame pipeline

**Acceptable:** < 4 ms per frame raster cost from the particles widget alone.

**If > 4 ms raster:**
- The `_MotesPainter.paint` is repainting too aggressively, OR
- Too many simultaneous AmbientParticles instances (each with own controller)
- Mitigation: drop `count` from 8/10 to 6
- Or: increase `driftDuration` from 22-30 s to 40-60 s (slower controller = less per-second updates)
- Or: remove from one of the screens with low emotional priority for particles (e.g., the social proof scene at minimum density already, but could go to 4)

### 2.3 — LivingCoachAvatar (Phase 105 + 122)

**How to trigger:** the coach intro, name capture, both interludes, the analysis illusion, the dynamic report, and the social proof screen all render LivingCoachAvatar.

**What to watch:**
- Whether parent-rebuild events (e.g., name capture's keystroke listener) trigger avatar repaints
- Phase 122's RepaintBoundary should make this impossible — the avatar's dirty region is isolated
- During mood transitions, expect a 500 ms window with 4 active controllers (old halo, new halo, old glow, new glow)

**Acceptable:**
- Steady state (no mood change): < 2 ms from the avatar widget
- During mood transition (500 ms window): < 8 ms per frame (the cross-fade is the most expensive moment)

**If steady-state > 2 ms:**
- The RepaintBoundary may not be effective (a parent SizedBox could be issuing paint requests). Verify by toggling DevTools "Highlight repaints" — flashing colors mark dirty regions.
- Mitigation: add explicit RepaintBoundary at the parent of LivingCoachAvatar in the offending scene.

**If transition > 8 ms:**
- The mood AnimatedSwitcher cross-fade has 2 _AvatarLayers active simultaneously, each with BreathingBox + GlowPulse. Could simplify to a tween between mood configs (no cross-fade).
- This is a behavioral change — would feel less alive — only do if the cost is actually breaking frame budget.

### 2.4 — Mood transitions specifically

**How to trigger:** the most visible mood transition is in `name_capture_step.dart` when the user submits their name (mood goes `listening` → `proud`).

**What to watch:**
- The 500 ms cross-fade duration plus the 700 ms scale tween that overlaps it
- Total 1.2 s window where both old and new state coexist
- Check both Build timeline (widget build cost) and Raster timeline (GPU compositing cost)

**Acceptable:** < 16 ms per frame during the entire transition window.

**If > 16 ms:**
- Lower the overlap by reducing `AnimatedSwitcher` duration from 500 ms → 380 ms
- Or simplify by removing AnimatedScale (drop the per-mood scale variations — moods become halo-color/speed-only)

### 2.5 — Paywall backdrop layers (Phase 115)

**How to trigger:** complete the wizard (or use a dev shortcut) and land on the paywall (dark mode).

**What to watch:**
- The 5 `_BackdropImage` widgets each have a Transform.rotate + Opacity + ClipRRect + Image
- Single `_drift` AnimationController (30 s repeat) drives parallax for all 5
- The AnimatedBuilder rebuilds at 60 fps for 30 seconds — that's 1800 rebuilds before a single full cycle

**Acceptable:** < 6 ms per frame from the backdrop subtree.

**If > 6 ms:**
- Reduce `count` (lose 1-2 photos)
- Increase `_drift` duration from 30 s → 60 s (cuts AnimatedBuilder rebuild rate in half — same visual smoothness, half the per-second work)
- Or convert from per-frame parallax to step-tick: only update positions every 5th or 10th frame
- Or: bake the photos into a single pre-composited static image (loses the parallax but keeps the depth feel — last-resort tradeoff)

### 2.6 — Transformation graph (Phase 112, _TrajectoryPainter)

**How to trigger:** advance to the dynamic-report screen.

**What to watch:**
- The 1.6 s `_draw` AnimationController drives 96 frames of CustomPaint
- Each paint draws gridlines + area-fill gradient + line stroke + glow + 2 dots + 2 labels
- After completion, the controller stops; painter does NOT repaint

**Acceptable:** < 3 ms per frame during the 1.6 s draw window.

**If > 3 ms:**
- Cache the gridlines (they don't change between frames — pre-compose into a Picture once)
- Skip the `MaskFilter.blur` on the line stroke (sigma 5 is GPU-expensive at small widths) — replaces with a solid stroke + 1 wider semi-transparent stroke
- Reduce the `_TrajectoryPainter.peakAlpha` blur sigma

### 2.7 — Auto-scrolling testimonials (Phase 113)

**How to trigger:** advance to the social-proof scene.

**What to watch:**
- Single 30 s AnimationController calling `_scroll.jumpTo` per tick
- ListView.builder with tripled item count
- Each card renders Container + 5 Icon stars + 2 Text widgets
- Modular scroll position math wraps without a visible seam

**Acceptable:** < 3 ms per frame from the auto-scroll.

**If > 3 ms:**
- The per-frame `jumpTo` may be triggering unnecessary scroll-position notifications — investigate
- Could throttle to update once per 16ms regardless of controller value (avoid duplicate updates within the same vsync)
- Or: simplify card decoration (drop one BoxShadow)

### 2.8 — Composing dots (Phase 110)

**How to trigger:** the setup-thinking step shows ComposingDots for 2.2 s.

**What to watch:**
- 3 dots, each with sine-bell opacity + scale, single shared controller
- AnimatedBuilder rebuilds the row at 60 fps

**Acceptable:** < 1 ms per frame.

**If > 1 ms (very unlikely):**
- This widget is already minimal. Investigate if there's something else on the screen that's the actual cost.

## 3. Whole-screen budgets (rough heuristics)

When you take a 5-second recording on a screen and look at the average frame cost:

| Screen | Acceptable avg frame cost | Notes |
|---|---|---|
| Welcome (Act 1) | < 8 ms | Background pan + breathing title + glow CTA |
| Coach intro (Act 2) | < 10 ms | Living avatar + typewriter + bg pan |
| Name capture | < 8 ms | Chat bubbles + small avatar + input |
| Setup thinking | < 10 ms | Avatar (with wobble) + composing dots + atmosphere |
| Gender / Goal / etc. | < 6 ms | Standard option cards |
| Body feelings | < 6 ms | ListView + tile cards (lightweight) |
| Pain point | < 6 ms | Hybrid card UI |
| Analysis illusion | < 12 ms | Rotating core + atmospheric breath + particles + avatar in thinking mood |
| Dynamic report | < 12 ms | Particles + 7 staggered reveals + morphing numbers + trajectory + breathing assessment + confidence bar |
| Social proof | < 8 ms | Auto-scrolling testimonials + avatar |
| Pre-paywall summary | < 10 ms | Plan card + breathing + trust booster + coach panel |
| Paywall | < 12 ms (dark mode) | Backdrop parallax + content cards |

**These are heuristic budgets, not strict thresholds.** A single frame at 14 ms on a screen with 8 ms average is fine. A sustained 16+ ms average is concerning.

## 4. The triage decision tree

If a screen consistently exceeds its budget:

```
Is the >16 ms cost in the BUILD timeline or the RASTER timeline?

├── BUILD (widget rebuilds)
│   ├── Identify which widget's setState is firing per frame
│   ├── Check if it can be moved to a smaller scope (extract to its own
│   │   stateful widget so only that subtree rebuilds)
│   ├── Check if AnimatedBuilder's `child:` slot is being used to skip
│   │   rebuilds of stable subtrees
│   └── Check if a Riverpod `select` could narrow the watched value
│
└── RASTER (GPU compositing)
    ├── Identify which subtree is dirty per frame (DevTools "Highlight
    │   repaints")
    ├── Add RepaintBoundary at the offending parent
    ├── Or simplify the visual (one fewer BoxShadow, one fewer Opacity
    │   layer, etc)
    └── If MaskFilter.blur is in the hot path, consider replacing with
        precomputed blurred asset
```

## 5. What this commit also fixed

Single targeted change in `lib/features/onboarding/presentation/widgets/living_coach_avatar.dart`:

```dart
// Before:
return SizedBox(width: size, height: size, child: AnimatedScale(...));

// After:
return RepaintBoundary(
  child: SizedBox(width: size, height: size, child: AnimatedScale(...)),
);
```

Why: the avatar's inner `BreathingBox` + `GlowPulse` are RepaintBoundary-isolated, but the outer chain (`SizedBox → AnimatedScale → AnimatedSwitcher → Stack`) was unprotected. When a parent like `NameCaptureStep` rebuilds (its keystroke listener calls `setState` on every char typed), the parent's repaint request previously flowed through the entire avatar subtree even though nothing visible changed. The new outer RepaintBoundary terminates that propagation — the parent's dirty region stops at the avatar boundary.

This is the only safe code-level fix in Phase 122. Other potential optimizations (reducing AmbientParticles density, simplifying mood transitions, baking the paywall backdrop) all require profile-mode evidence first.

## 6. What I will NOT do without device data

- Reduce AmbientParticles count or framerate
- Simplify mood transition cross-fade
- Drop layered effects on the dynamic-report screen
- Cache anything that's currently computed per-frame
- Remove the slow-drift parallax on paywall backdrop

Each of these would erode emotional quality. None should ship without a profile recording showing the cost is real.

## 7. The escalation path

After running profile mode and finding genuine bottlenecks:

1. Capture the profile JSON via DevTools "Save profile"
2. Note: which surface, what action triggered the slow frame, what was the dominant cost (build / layout / paint / raster)
3. Open a tuning task referencing the specific widget + the profile data
4. Apply the smallest possible change
5. Re-profile to confirm savings
6. Decide: is the saved frame budget worth the visual loss?

The goal is **measured optimization, never speculative**.

---

## 8. Summary of Phase 122 deliverables

| Deliverable | Status |
|---|---|
| RepaintBoundary added at LivingCoachAvatar root | ✅ shipped this commit |
| Per-surface profiling protocol (this doc) | ✅ |
| Whole-screen budget heuristics | ✅ §3 |
| Triage decision tree | ✅ §4 |
| Refusal to speculatively simplify | ✅ §6 |

The cinematic onboarding's "alive" feel is one of the product's strongest differentiators. Treat every potential simplification as a debit against that. Pay it only when profile data demands it.
