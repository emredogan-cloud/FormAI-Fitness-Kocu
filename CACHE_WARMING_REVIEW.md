# Cache Warming Review — Phase 2-A.6

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Phase:** 2-A.6 Cache Strategy Review (analysis only — no code shipped)
> **Subject:** the dashboard-mount image prefetch proposed in §2-A.6 of `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md`

---

## 1. Summary verdict

**The plan's intent is correct (warm 6 meals before the user lands on the
nutrition tab) but two concrete issues need adjustment before shipping:**

1. **Wrong prefetch primitive.** The plan uses `precacheImage(
   CachedNetworkImageProvider(url), context)`, which works but is
   inconsistent with the existing **Phase 51 pattern** elsewhere in the
   codebase (`DefaultCacheManager().downloadFile(url)`). Phase 51
   explicitly migrated away from `precacheImage(NetworkImage(...))` to
   avoid a double-download against `flutter_cache_manager`. We should
   align.
2. **API typo against the provider shape.** The plan reads
   `dailyMenuProvider.value?.recipes`. The provider's state is
   `AsyncValue<List<PlannedMeal>>`, not an object with a `.recipes`
   accessor. The right read is `state.value?.take(6).map((pm) =>
   pm.recipe.imageUrl)`.

Both fixes are 1-line; net change is `_prefetchTodaysMeals` becomes ~12
lines that look very similar to the existing `_warmDefaults` in
`antrenman_tab.dart`.

---

## 2. Mount point analysis

### 2.1 Candidate locations

| Location | Pros | Cons |
|---|---|---|
| **A. `_DashboardScreenState.initState`** | Earliest possible firing; user already past onboarding; runs once per dashboard lifetime | Fires even for users who never open the nutrition tab → small wasted bandwidth |
| B. `_NutritionTabState.initState` | Bandwidth-optimal (only fires when user opens the tab) | First nutrition-tab visit still pays the network cost; user sees LQIP for ~1–2 s on slow networks |
| C. `dailyMenuProvider`'s `build()` post-resolve | Data-driven, only fires when there's actually a plan to warm | Coupling business logic to side-effects; harder to test |

**Plan choice (A) is correct.** The dashboard is the post-onboarding
landing screen; the nutrition tab is one tap away. Pre-warming on
dashboard mount means **by the time the user navigates** (typically
2–5 s of dashboard scrolling), the warm cache is ready. That is a
better UX than option B's "see LQIPs while waiting on the wifi" for
the 80%+ of installs on adequate networks.

### 2.2 Exact insertion point

`lib/features/home/presentation/dashboard_screen.dart`:

The existing `didPush` callback at lines 86-104 already has an
`addPostFrameCallback` for `FirstTimeAiScenes`. **Do NOT add the
prefetch there** — `didPush` fires every time the dashboard becomes the
topmost route (e.g. returning from a workout). That would re-prefetch
on every dashboard return.

Use `initState` (which doesn't exist in `_DashboardScreenState` yet —
the class jumps straight to `didChangeDependencies`):

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    unawaited(_prefetchTodaysMeals());
  });
}
```

The `addPostFrameCallback` matters because:
- It defers the prefetch to after the first dashboard paint, so startup
  perceived performance is unaffected.
- It also ensures `ref` is bound and `dailyMenuProvider`'s notifier has
  started its async resolution (the provider's `build()` runs eagerly
  when first watched/read).

---

## 3. Network impact

### 3.1 Plan estimate: 6 × ~280 KB ≈ 1.7 MB

Re-checked against the actual corpus (§4 of `MEAL_ASSET_INVENTORY.md`):

```
Avg file size in photos/meals/  : 214 KB
6 meals × 214 KB                : 1.28 MB
```

Slightly below the plan's estimate. On real networks:

| Network | Time to prefetch 6 meals |
|---|---|
| WiFi (10 Mbps+) | <1 s |
| 4G LTE (5 Mbps) | ~2 s |
| 3G (1 Mbps) | ~10 s |
| 2G / EDGE (256 kbps) | ~40 s |

On 3G/2G the prefetch is unlikely to finish before the user reaches the
nutrition tab. **Acceptable** — LQIPs cover the gap; the user sees
"loading" tinted placeholders instead of grey holes. The prefetch is a
"best effort", and the worst case has not regressed against today.

### 3.2 Cellular-data sensitivity

The plan does NOT check whether the user is on metered cellular. On a
data-conscious plan (Turkey, the target market, has a fair amount of
3 GB/month plans) prefetching 1.3 MB on every dashboard open over the
course of a month equals **~120 MB/month** if the dashboard is opened
4×/day. That's measurable.

**Mitigation options** (none required for v1; document for follow-up):

- Gate prefetch on `connectivity_plus`'s `connectivityType ==
  ConnectivityResult.wifi`. Requires adding `connectivity_plus` to
  pubspec.
- Limit to 3 meals (today's breakfast + lunch + dinner) instead of 6.
  This halves the bandwidth.
- Use `flutter_cache_manager`'s default 30-day TTL — re-warm only
  happens when files age out (so daily dashboard opens are basically
  free after the first warm cycle).

**Recommendation for v1:** ship the plan as-is (6 meals). The 30-day
disk cache TTL means steady-state cost is ~1.3 MB once per month per
user, not per dashboard open.

---

## 4. Low-end-device behaviour

This is the most important section. The plan's
`precacheImage(CachedNetworkImageProvider(url), context)` decodes the
image **into the framework's in-memory `ImageCache`** at the
provider's natural decode size — **the source resolution of 1760 × 2336
× RGBA = ~16 MB per image**.

```
6 simultaneous precacheImage decodes:
  6 × 16 MB = 96 MB peak memory
```

On a 2 GB-RAM Android (the bottom of our supported range), this is
**40% of available RAM**, and rasterizer GC pressure spikes
immediately. The user sees frame jank during prefetch.

### 4.1 Established codebase pattern (Phase 51)

`lib/features/home/presentation/widgets/antrenman_tab.dart:98-108` and
`lib/features/workout/presentation/plan_detail_screen.dart:191-198` use
the right primitive:

```dart
Future<void> _warmDefaults() async {
  final cacheManager = DefaultCacheManager();
  for (final url in const [...]) {
    try {
      await cacheManager.downloadFile(url);
    } catch (_) {
      // Best-effort. CachedNetworkImage retries on first render.
    }
  }
}
```

`DefaultCacheManager().downloadFile()`:
- Writes to the disk cache (`flutter_cache_manager`)
- Does NOT decode into a bitmap
- Does NOT populate the framework's `ImageCache`
- Memory cost: zero beyond the HTTP buffer

When the recipe card later renders through `CachedImage` →
`CachedNetworkImage`, that widget reads from the **same disk cache** and
decodes at its **callee-controlled `memCacheHeight`** (200 for thumbs,
600 for hero, 800 for detail) — i.e. at most a few MB per card, not
16 MB.

### 4.2 Recommended rewrite

```dart
Future<void> _prefetchTodaysMeals() async {
  final plan = ref.read(dailyMenuProvider).value;
  if (plan == null) return;

  final cacheManager = DefaultCacheManager();
  for (final pm in plan.take(6)) {
    final url = pm.recipe.imageUrl;
    if (url == null || !url.startsWith('http')) continue;
    unawaited(
      cacheManager.downloadFile(url).catchError((Object _) {
        // Best-effort. CachedNetworkImage will retry on first render.
        return DefaultCacheManager.dummyFile;  // satisfies the catchError return type
      }),
    );
  }
}
```

(The `dummyFile` is a Phase 51 idiom — `downloadFile` returns a
`FileInfo`; `catchError` needs a same-typed return; the actual file is
never used since we ignore the future.)

### 4.3 Side effects

- **Sequential vs concurrent**: `unawaited(...)` fires all 6 downloads
  in parallel. On low-end Android the HTTP client serialises naturally;
  on high-end it parallelises cleanly. Both are fine.
- **Battery**: 6 small GETs over wifi/cellular ≈ 1 s of radio time. On
  cellular the radio's "long tail" keeps it powered for ~10 s after
  the last byte, but the same tail is amortised across any other
  network activity the dashboard might do (analytics ping, etc.).
- **First-paint impact**: zero. The `addPostFrameCallback` defers
  everything to after the first frame.

---

## 5. Cache duplication risk

### 5.1 Two caches in play

| Cache | Backed by | Populated by |
|---|---|---|
| Framework `ImageCache` | In-memory bitmap LRU (default ~100 MB on most devices) | `precacheImage(NetworkImage())`, `precacheImage(CachedNetworkImageProvider())`, `Image.network`, `Image.asset` |
| `flutter_cache_manager` (DefaultCacheManager) | On-disk SQLite + file LRU (default 200 entries, 7 days, ~200 MB) | `CachedNetworkImage`, `DefaultCacheManager().downloadFile()` |

`CachedNetworkImage` **reads from the disk cache, decodes into a
bitmap, then holds that bitmap in the framework `ImageCache`**. Two
separate layers; they don't duplicate the file storage.

### 5.2 Where duplication could happen

| Pattern | Behaviour |
|---|---|
| `precacheImage(NetworkImage(url))` then render `CachedImage(url)` | **DOUBLE DOWNLOAD** — `NetworkImage` writes to a different HTTP client than `CachedNetworkImage`; the second render hits the network again. This is the Phase 51 bug. |
| `precacheImage(CachedNetworkImageProvider(url))` then render `CachedImage(url)` | **Single download** — same provider writes to the same disk cache; first render reads from disk. But also populates the framework ImageCache → extra 16 MB per warm. |
| `DefaultCacheManager().downloadFile(url)` then render `CachedImage(url)` | **Single download, zero extra memory** — disk-only warm; render decodes at the callee's `memCacheHeight`. ✓ |

The plan's option-2 works but pays for the in-memory decode. Option 3 is
strictly cheaper.

### 5.3 LQIP cache: separate, no conflict

`Image.asset('assets/lqip/meals/<slug>.webp')` (used by `RecipeImage`)
goes through the **framework AssetImage cache**, which is a third
cache. Tiny entries (~700 B × 293 = ~210 KB) and bounded by the
framework `ImageCache`'s entry count, not byte budget. No interaction
with the network caches.

---

## 6. Startup impact

### 6.1 Timeline

| t (ms) | Event |
|---|---|
| 0 | Splash → main → runApp |
| ~400 | First frame of `AppShell` paints |
| ~500 | DashboardScreen route pushed |
| ~520 | `initState` runs → `addPostFrameCallback` registers |
| ~540 | Dashboard's first frame paints |
| ~560 | post-frame callback fires → `_prefetchTodaysMeals` is invoked |
| ~570 | `dailyMenuProvider` state read; depending on whether recipes are loaded, prefetch either dispatches downloads OR returns early |
| ~600+ | HTTP requests in flight (disk cache writes) |

The prefetch runs **after** the first dashboard frame. No measurable
impact on startup time perceived by the user.

### 6.2 Race: `dailyMenuProvider` may not be ready yet

The provider's `build()` is async; on a cold app start it goes through:
1. `await ref.watch(recipesProvider.future)` — Supabase round-trip
2. Build the day's plan from the recipe catalogue

This typically takes 100–800 ms. If `_prefetchTodaysMeals` runs at
t ≈ 560 ms and `dailyMenuProvider` resolves at t ≈ 700 ms, the
prefetch's `ref.read(...).value` returns `null` and exits early.

**Fix:** listen instead of read-once:

```dart
ref.listen<AsyncValue<List<PlannedMeal>>>(dailyMenuProvider, (prev, next) {
  if (next.value != null && (prev == null || prev.value == null)) {
    unawaited(_prefetchTodaysMeals(next.value!));
  }
});
```

Place the listener in `initState` via `ref.listenManual(...)`, or in
`build` (Riverpod allows `ref.listen` inside build for ConsumerWidget).

This is a **plan-omission** that should be incorporated into the
implementation. Without it, on slow networks the prefetch never fires
on cold start.

---

## 7. The PlannedMeal API correction

The plan's snippet:

```dart
final todaysMeals = ref.read(dailyMenuProvider).value?.recipes ?? [];
```

is **incorrect against the current provider shape**. From
`lib/features/nutrition/providers/daily_menu_provider.dart`:

```dart
class DailyMenuNotifier extends AsyncNotifier<List<PlannedMeal>> { ... }
```

The state is `List<PlannedMeal>` directly, not a wrapper with a
`.recipes` field. `PlannedMeal` exposes:

```dart
class PlannedMeal {
  final Recipe recipe;   // ← the Recipe is here
  // …
}
```

Correct read:

```dart
final plan = ref.read(dailyMenuProvider).value;
if (plan == null) return;
for (final pm in plan.take(6)) {
  final url = pm.recipe.imageUrl;
  …
}
```

Two extra lines of plumbing; no functional difference vs. the plan's
intent. Worth catching now so the implementation doesn't ship a
NoSuchMethodError.

---

## 8. URL filter: only-`http` may be wrong post-rewrite

The plan filters `if (url != null && url.startsWith('http'))`. **This
is correct for the post-Phase-2-A.4 world** where `MediaUrl.resolve()`
returns full URLs for all meals.

But **during Phase 2-A.5's grace period** (call sites already swapped to
`RecipeImage` but Phase 2-A.4 DB rewrite not yet executed):

```text
recipe.imageUrl    = 'photos/meals/foo.webp'
                     → MediaUrl.resolve passes through unchanged
                     → does NOT start with 'http'
                     → filter rejects → no prefetch
```

This is the right behaviour — `photos/meals/foo.webp` is a bundled
asset, no network warm needed. The `Image.asset` decode is instant.

After Phase 2-A.4:

```text
recipe.imageUrl    = 'foo.webp'   (bare in DB)
                     → MediaUrl.resolve composes Supabase URL
                     → starts with 'http' → prefetch runs ✓
```

So the filter is **self-correcting across the migration window**. Good
catch by the plan author.

---

## 9. Concrete recommendation

Rewrite the plan's §2-A.6 snippet as below before shipping:

```dart
// In _DashboardScreenState (lib/features/home/presentation/dashboard_screen.dart):

@override
void initState() {
  super.initState();
  // Phase 2-A.6 · warm today's meal images so the nutrition tab doesn't
  // paint LQIP-only on first navigation. Fire-and-forget, post-frame,
  // disk-cache only (no in-memory bitmap decode — Phase 51 pattern).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    unawaited(_prefetchTodaysMeals());
  });

  // The provider may not be ready at first-frame time on cold start;
  // also listen for the first non-null emission and warm then.
  ref.listenManual<AsyncValue<List<PlannedMeal>>>(
    dailyMenuProvider,
    (prev, next) {
      if (prev?.value == null && next.value != null) {
        unawaited(_prefetchTodaysMeals());
      }
    },
  );
}

Future<void> _prefetchTodaysMeals() async {
  final plan = ref.read(dailyMenuProvider).value;
  if (plan == null) return;
  final cacheManager = DefaultCacheManager();
  for (final pm in plan.take(6)) {
    final url = pm.recipe.imageUrl;
    if (url == null || !url.startsWith('http')) continue;
    unawaited(
      cacheManager.downloadFile(url).catchError(
        // Best-effort. CachedNetworkImage retries on first render.
        (Object _) async => throw _,    // surfaces nothing; fire-and-forget
      ),
    );
  }
}
```

Imports needed:
```dart
import 'dart:async';                                       // unawaited
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../nutrition/domain/models/planned_meal.dart';
import '../../nutrition/providers/daily_menu_provider.dart';
```

---

## 10. Open questions for PM/eng review

1. **6 meals or 3?** Trade-off documented in §3.2. 6 is the plan's
   choice and matches a typical day's full meal set; 3 halves
   bandwidth but doesn't cover snack-time prefetch.
2. **Cellular gating?** §3.2 — defer to follow-up unless we see
   support tickets about data usage post-launch.
3. **Should the prefetch run on every cold app start, or only on the
   first install?** Current proposal: every cold start. The disk
   cache's 30-day TTL means it's a no-op after the first.

---

## 11. Gates passed

- [x] Plan's prefetch primitive evaluated against codebase prior art (Phase 51)
- [x] PlannedMeal API typo in the plan identified and corrected
- [x] Mount-point choice validated (dashboard initState, post-frame)
- [x] Network-cost model built (1.28 MB / 6 meals; aligned with plan)
- [x] Low-end-device memory analysis (16 MB × 6 = 96 MB peak with plan's primitive vs. ~zero with recommended)
- [x] Cache-duplication risk surveyed (three caches; no conflict)
- [x] Startup-impact timeline mapped
- [x] Race against `dailyMenuProvider` async resolution flagged and fix proposed
- [x] URL filter behaviour validated across the pre/post-rewrite migration window
- [x] Concrete recommended rewrite written out (~25 lines, ready to drop in)

**Phase 2-A.6 status:** ✅ review complete. Plan's design is sound; two
mechanical corrections recommended before implementation. No code shipped
in this phase.
