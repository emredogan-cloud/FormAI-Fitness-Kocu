# PHASE 2 COMPLETION REPORT — Dynamic Walkthrough I: Feature Tour & Visibility

| | |
|---|---|
| **Roadmap** | `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` → Wave 1, Phase 2 |
| **Covers** | R1.1 · P3 · C27 · C28 · C37 · F-0.3 |
| **Commits** | `5bb55e6` (phase) · `68190e2` (orphan cleanup) |
| **Baseline** | `77680d9` / build 1.0.0+19 → **`68190e2` / build 1.0.0+20** |
| **Quality** | analyze **0** · **482 tests** (was 408, **+74**) · `dart format` clean · **CI GREEN** |
| **Artifact** | release APK **132.1 MB** (+0.6 MB — 4 showcase assets, 180 KB, plus code) |
| **Device** | Redmi M1908C3JGG (`AYXSUKIVJVPZ7HPZ`) |
| **Status** | ✅ **COMPLETE** |

---

## 1. Summary

The Testers Community's first and largest observation:

> *"Currently, there is no dynamic walkthrough or tutorial available for new
> users when they first open the app."*

They were right, and the codebase makes the reason precise. FormAI has a
*large* first-run experience — 19 onboarding steps — but every one of them
either collects data or builds emotional commitment. **Not one explains a
feature.** The single orientation surface, `FirstTimeAiScenes.dashboardWelcome`,
*names* the tabs in one sentence and auto-closes after 8 seconds. It tells;
it never shows.

Phase 2 adds the showing, in four layers:

| # | Deliverable | Roadmap ID |
|---|---|---|
| 1 | `SpotlightTour` — reusable coach-mark system | C27 |
| 2 | 5-step dashboard tour, running after the welcome scene | R1.1 |
| 3 | Replayable tour from Settings | R1.1 |
| 4 | 4-card post-paywall capability showcase | R1.1 |
| 5 | Contextual "Biliyor muydun?" tips engine | C28 |
| 6 | Discovery dots on never-opened tabs | C37 · P3 |
| 7 | Four private empty states consolidated into one, each gaining a CTA | C37 · F-0.3 |

The cinematic welcome scene is **kept**, not replaced. The two are layered
deliberately: the scene carries the emotional beat (*"bugün dönüşümünün ilk
günü"*), the tour carries the functional one (where things are). Merging them
would have cost the first and cheapened the second.

---

## 2. Architecture

### 2.1 SpotlightTour: one step = dim, punch a hole, say a sentence

That is the entire vocabulary, and it is enough for every tour the roadmap
still needs — Phase 3's in-workout tutorial layer and Phase 4's feature-unlock
reveals both reuse this widget rather than growing their own.

Four constraints, each drawn from a way coach-mark layers usually fail:

1. **Skip is on every step, including the first.** A tour the user cannot
   escape is a tour that earns a 1-star review.
2. **A missing target drops its step; it never crashes.** Targets resolve at
   *present* time from GlobalKeys. If a widget moved, unmounted or scrolled
   away, `rect()` returns null and the step is filtered out. If that leaves
   nothing, the tour silently doesn't show. A teaching layer must never be able
   to break the app it is teaching.
3. **Bubble placement is computed, not configured.** The card goes below the
   hole when there's more room below and above otherwise. This app has already
   shipped two fixed-height fold regressions (RC-17 paywall, RC-18 Başla); the
   lesson is applied up front rather than after a third.
4. **Reduce-motion aware.** With `disableAnimations` the hole and card jump
   between steps instead of tweening. The tour still completes and still
   teaches.

It presents as a **transparent route** (`opaque: false`, transparent barrier),
so the real UI is genuinely visible through the hole — not a screenshot, not a
reconstruction of the target widget.

### 2.2 Nav targets are derived geometrically, not keyed

The first implementation keyed each `BottomNavigationBarItem.icon` via
`KeyedSubtree`. That is subtly broken: the framework renders `activeIcon` for
the selected tab, so the key detaches and `rectOf` returns **null for whichever
tab the user is currently on** — the step would silently vanish.

The shipped version puts **one** key on the nav bar and derives item rects:

```dart
Rect? navItemRect(int index, {int count = 4}) {
  final bar = rectOf(navBar);
  if (bar == null) return null;
  final slice = bar.width / count;
  final centerX = bar.left + slice * (index + 0.5);
  final halfWidth = (slice * 0.42).clamp(28.0, 56.0);
  return Rect.fromLTRB(centerX - halfWidth, bar.top, centerX + halfWidth, bar.bottom);
}
```

`BottomNavigationBarType.fixed` divides width equally, so the slice is *exact*
rather than approximate. The width clamp stops a tablet-width bar producing a
126 px highlight around a 24 px icon. Device screenshots confirm the hole lands
precisely on each item.

### 2.3 The showcase is interposed by a router redirect

The paywall has **three** `context.go('/')` exits — purchase success, explicit
dismiss, and the Pro self-redirect — and all three sit inside RevenueCat
purchase/entitlement code that earlier phases deliberately keep byte-untouched.

So the showcase is not wired at those exits. The router's own redirect does it:

```dart
if (path == AppRoutes.dashboard && !prefs.seenFeatureShowcase) {
  return AppRoutes.featureShowcase;
}
```

One interception covers every path to the dashboard, `paywall_screen.dart` is
not modified at all, and there is one place to get it right instead of three.

### 2.4 A tab-request channel instead of lifting state

The Settings replay row has to put the user back on Antrenman before replaying
(the tour's content targets live there, and an off-screen `IndexedStack` branch
resolves to stale rects). Lifting `_index` out of `_DashboardScreenState` would
have touched every celebration, nutrition-prompt and badge path that reads it.

Instead, a one-way request channel:

```dart
final dashboardTabRequestProvider = NotifierProvider<…, DashboardTabRequest?>(…);
DashboardScreen.requestTab(ref, 0);
```

The request carries a monotonically-bumped `seq` alongside the index, so two
consecutive requests for the *same* tab still notify — without it, equality
would swallow the second one. The dashboard applies it via `listenManual`, never
during build. Phase 4's progressive disclosure needs the same channel.

### 2.5 `hasChattedWithCoach` reads ground truth, not a proxy

The `coach_unused` tip targets users who have trained but never talked to the
coach. A "did they open the screen" flag would be wrong — and so would a
length check on the stored transcript, because the transcript **also holds the
coach's opening greeting**. Either would report "has chatted" for exactly the
user the tip exists to reach.

The implementation parses the coach feature's own persisted transcript and looks
for a turn with `c != true` — an actual *user* message. It needs zero changes to
the coach feature, and a corrupt payload degrades to `false` rather than
throwing.

### 2.6 Empty states: four implementations became one

Before: `favorites_screen`, `discover_recipes_screen`, `nutrition_tab` and
`category_recipes` each had a private `_EmptyState`. Two had icon + title +
body; two had a bare sentence in a box. **None had a CTA**, so every empty state
dead-ended — which is precisely the "users don't know what the app can do"
problem the report was about.

One shared `EmptyState` now carries the anatomy — haloed icon → title → body →
optional CTA — and every migrated call site gained an action: *Tarifleri Keşfet*
from favourites, *Filtreyi Kaldır* from a filtered-empty grid. A test asserts a
CTA renders only when **both** label and handler are supplied, so a half-wired
call site produces no button rather than a dead one.

---

## 3. Files changed

**29 files · +3,566 / −211** (across both commits)

### New — production (7)
| File | Purpose |
|---|---|
| `lib/core/widgets/spotlight_tour.dart` | The coach-mark system (C27) |
| `lib/core/services/tour_targets.dart` | Key registry, `navItemRect`, `clampAboveNav` |
| `lib/core/services/tour_service.dart` | Tour definitions, gating, replay |
| `lib/core/widgets/empty_state.dart` | The one shared empty state (C37) |
| `lib/features/onboarding/presentation/feature_showcase_screen.dart` | 4-card showcase (R1.1) |
| `lib/features/home/domain/discovery_tips.dart` | Tip catalogue + pure `selectTip` (C28) |
| `lib/features/home/presentation/widgets/discovery_tip_card.dart` | The tip slot UI |

### Modified — production (8)
`dashboard_screen.dart` (tour wiring, tab-request channel, tip slot, nav dots) ·
`app_preferences.dart` (tour/showcase flags, visited tabs, dismissed tips,
`hasChattedWithCoach`) · `analytics_service.dart` (9 new events) ·
`app_router.dart` (`/showcase` route + redirect) · `profile_tab.dart` (replay
row) · `antrenman_tab.dart` (tour keys) · `nutrition_tab.dart`,
`favorites_screen.dart`, `discover_recipes_screen.dart` (empty-state migration)

### New — assets (4)
`showcase_form_analysis.webp` · `showcase_ai_coach.webp` · `showcase_plan.webp`
· `showcase_nutrition.webp` — derived from the previously-unused
`photos/new-image/` set, resized to 900×600 and WebP-compressed. **180 KB
total.** The source directory is deliberately undeclared in `pubspec.yaml`
(39 MB); this follows the Phase-127 asset-hygiene convention of optimising into
the declared `assets/illustrations/`.

### New — tests (7)
`spotlight_tour_test.dart` (12) · `tour_targets_test.dart` (17) ·
`discovery_tips_test.dart` (15) · `feature_showcase_screen_test.dart` (7) ·
`discovery_tip_card_test.dart` (7) · `empty_state_test.dart` (7) ·
`app_preferences_phase2_test.dart` (12)

---

## 4. Testing

**482 tests pass (was 408 — +74). analyze 0. format clean. CI green.**

| Concern | Tests | Notable assertions |
|---|---|---|
| Spotlight tour | 12 | Skip present on step 1; unresolvable step dropped; a fully-unresolvable tour shows nothing; scrim tap advances; **placement flips above/below based on target position**; reduce-motion completes; copy reaches a screen reader; 1.3 text scale |
| Target geometry | 17 | Even slice + centring per index; full bar height; width capped on wide bars and floored on narrow; unmounted/out-of-range → null; zero-size → null; `clampAboveNav` trims, passes through, and nulls when nothing usable remains; keys are stable across reads |
| Tips policy | 15 | Declaration order = priority; dismissal permanent and promotes the next match; each tip's gates; catalogue integrity — **CTA label and route are all-or-nothing** |
| Showcase | 7 | All 4 cards walk; CTA swaps on the last; **skip also sets the flag** (a skipped showcase must not reappear); flag + route on finish; 1.3 scale; 320×640 |
| Tip card | 7 | No CTA without a route; dismiss + CTA callbacks; 44dp target; screen-reader dismissal; narrow phone at 1.3 |
| Empty state | 7 | Anatomy degrades gracefully; **CTA only when both label and handler given**; 48dp target; compact mode; semantics; 1.3 scale |
| Preferences | 12 | Flags; visited-tab first-vs-repeat return value; corrupt entries skipped; **`hasChattedWithCoach` false for a greeting-only transcript**, true on a user turn, false on empty text, false on corrupt/non-list payloads |

### Three real bugs found

1. **Nav-item keys detach on selection** — caught while reasoning about
   `activeIcon`, before shipping. Replaced with the geometric derivation.
2. **The tip dismiss target rendered 40dp** despite 44dp constraints:
   `visualDensity: compact` subtracts *after* constraints resolve. Caught by a
   test asserting the minimum.
3. **The step-1 hole extended behind the bottom nav** — tab content scrolls
   under it, so the plan card's true rect does too, drawing the highlight ring
   across the nav row. Caught on device; fixed with `clampAboveNav` and pinned
   by 5 tests.

### The CI/local toolchain gap, again

Phase 1 recorded that **CI runs Flutter 3.44.8 while this machine runs 3.41.9**.
Phase 2 hit it a second time: an orphaned `_EmptyState` class left behind by the
consolidation was reported `unused_element` by CI's analyzer and **not reported
at all locally**. Same class of failure as Phase 1's `ExpansionTile`/
`DecoratedBox` assertion.

The working rule stands and is now proven twice: **local green is necessary but
not sufficient — a phase is not done until CI is green.**

---

## 5. Screens verified on device

| # | Verified | Result |
|---|---|---|
| 1 | Router redirect → showcase | ✅ Fired automatically on the way to the dashboard |
| 2 | Showcase card 1 | ✅ Image, eyebrow, title, body, proof point, dots (1/4), Atla, DEVAM |
| 3 | Showcase walk | ✅ All 4 cards; dots track; **CTA swaps to BAŞLAYALIM on the last** |
| 4 | Showcase finish | ✅ Routes to the dashboard; does not reappear |
| 5 | Tour step 1 (plan card) | ✅ Hole + neon ring on the card; bubble **above** it |
| 6 | Tour step 2 (coach card) | ✅ Hole slides up; bubble **below** it — placement adapting |
| 7 | Tour step 3 (Beslenme nav) | ✅ Hole lands precisely on the nav item |
| 8 | Tour step 5 (Profil nav) | ✅ Last step; CTA swapped to "Anladım" |
| 9 | Tour completion | ✅ Dismisses cleanly; dashboard intact; no replay |
| 10 | Settings replay row | ✅ "Uygulama Turu" switches to Antrenman and re-runs from step 1 |
| 11 | Discovery dots | ✅ On Beslenme/Gelişim/Profil, absent on Antrenman |
| 12 | Dot retirement | ✅ Profil's dot gone after visiting it; others remain |
| 13 | `clampAboveNav` fix | ✅ Ring stops at the nav top (verified against the pre-fix screenshot) |

### No regressions
Dashboard, weekly goal card, coach entry card, plan hero, bottom nav, Profil
settings list (including the Phase 1 rows) all render and behave as before.

### Device note
A different app of the founder's (`com.ehliyetegitim.ehliyet_akademi`)
repeatedly stole foreground focus mid-session and absorbed two taps intended for
FormAI. It was force-stopped to complete verification. No FormAI state was
affected — the showcase flag was still unconsumed afterwards, which is how the
interference was detected.

---

## 6. Known limitations

1. **The tip card was not device-verified.** Every shipped tip requires
   `completedDays >= 1`, and the test account has zero completed workouts
   (completing one needs real camera reps). The *absence* of a tip was verified
   as correct. Covered by 22 tests (policy + widget). Same gap as Phase 1's
   rating scene — both want one device pass that includes a real workout.

2. **Migrated empty states were not device-verified.** Reaching them needs
   specific data states (no favourites, a filter matching nothing). Covered by
   the shared-widget tests plus an extended `discover_recipes_screen_test` that
   now asserts the CTA actually clears the filter and the results return.

3. **The tour targets only the Antrenman tab and the nav.** It teaches *where
   things are*, not what each tab contains. Per-tab tours are a natural
   extension the `SpotlightTour` system already supports — deliberately not
   built here, because five steps is at the edge of what a first-run tour can
   spend before it becomes the thing users skip.

4. **Showcase imagery is generic fitness photography**, selected from existing
   unused assets rather than commissioned to depict the actual features. A
   screenshot of real pose-detection would be more persuasive on card 1; that
   needs a device capture session and belongs with the Phase 3 camera work.

5. **~40 new Turkish string literals** join the ~1,483 awaiting Phase 5 ARB
   extraction. Tour and tip copy is already held as data (not inline in
   widgets), which makes that extraction mechanical.

6. **Tour analytics are wired but unverified end-to-end.** `tour_started`,
   `tour_step_viewed`, `tour_completed` / `tour_skipped` and `tab_first_visit`
   all fire through the existing PostHog facade; confirming they land in the
   dashboard is founder-side and belongs with Phase 15's analytics work.

---

## 7. Next phase

**Phase 3 — Dynamic Walkthrough II: Interactive First-Workout Tutorial**
(R1.2 · P6 · C26 · C21). Roadmap estimate L / ~12–16 dev-days — the largest
Wave 1 phase, and the one with the highest business impact in the roadmap's
own scoring (5/5 on both UX and business).

Deliverables: guided camera setup (permission → placement → lighting →
framing); the "I can see you" calibration moment where the pose engine
illuminates and the coach confirms; one guided practice rep before the real
session; an in-session tutorial layer for the first workout only; and a
camera-free path with manual rep logging.

Groundwork from Phase 2: `SpotlightTour` is built and tested, so the in-session
tutorial layer is a set of step definitions rather than a new system.

**This is the phase that most needs a real device workout**, which also closes
the two verification gaps carried from Phases 1 and 2 (the rating scene and the
tip card both unlock at `completedDays >= 1`).

---

*Phase 2 complete. `68190e2` on `main`, CI green, build 1.0.0+20.*
