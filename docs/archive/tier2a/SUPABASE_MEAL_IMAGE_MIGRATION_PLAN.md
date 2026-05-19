# Tier 2-A · `photos/meals/` → Supabase Storage CDN Migration Plan

> **Date:** 2026-05-16
> **Scope:** Move 64 MB of recipe images out of the APK bundle and onto Supabase Storage, delivered via CachedNetworkImage with bundled LQIP placeholders for offline + first-paint resilience.
> **Status:** **Design only — no execution per user instruction.** Awaiting go/no-go after Tier 1 validation.
> **Estimated impact:** −55 to −60 MB APK delivered to users on top of Tier 1 gains.

---

## 0. Why this migration is unusually safe

The codebase **already has the infrastructure** for this:

| Component | What it does | Where |
|---|---|---|
| `MediaUrl.resolve(raw, bucket: 'recipes_images')` | Routes `photos/...` → local asset, bare filename → CDN-or-Supabase URL, full URL → passthrough | `lib/core/utils/media_url.dart` |
| `CachedImage` widget | If URL starts with `http`, uses `CachedNetworkImage` (disk + memory cache); otherwise `Image.asset` | `lib/core/widgets/cached_image.dart` |
| `recipes_images` bucket | Already referenced in `Recipe.fromJson` | `lib/features/nutrition/domain/models/recipe.dart` |
| `cached_network_image` + `flutter_cache_manager` | Both already direct deps; no new packages | `pubspec.yaml` |

**The migration is mostly a data move + a DB column rewrite. No new Flutter code is required for the basic happy path.** The complexity below is LQIP, cache warming, and offline fallbacks — the things that make it feel premium rather than CDN-janky.

---

## 1. Architecture decision: bare-filename storage

The `MediaUrl.resolve()` function supports three URL shapes for `image_url`:

| Stored value | Resolves to | Notes |
|---|---|---|
| `photos/meals/foo.webp` | `photos/meals/foo.webp` (passthrough → `Image.asset`) | **Current state** |
| `foo.webp` | `<CDN_BASE_URL>/recipes_images/foo.webp` *(or)* `<SUPABASE_URL>/storage/v1/object/public/recipes_images/foo.webp` | **Target state** |
| `https://anywhere/foo.webp` | `https://anywhere/foo.webp` (passthrough) | For external Unsplash etc. |

We standardise on **bare filename** in the DB. This keeps the DB rows portable: flipping `CDN_BASE_URL` in `.env` instantly switches every recipe from "direct Supabase Storage" to "CDN-fronted" without a database migration.

---

## 2. Phase-by-phase execution plan

### Phase 2-A.1 — Backup & inventory (15 min, zero risk)

Snapshot the current state so the rollback is mechanical:

```bash
# 1. Backup the asset directory
mkdir -p /tmp/sixpack-meals-migration-backup
cp -r photos/meals /tmp/sixpack-meals-migration-backup/

# 2. Snapshot the recipes table (replace <PROJ> with your Supabase ref)
psql "$SUPABASE_DB_URL" -c "\copy (SELECT id, slug, image_url FROM recipes WHERE image_url LIKE 'photos/meals/%') TO '/tmp/sixpack-meals-migration-backup/recipes_image_url_before.csv' WITH CSV HEADER"

# 3. Capture row count for verification
psql "$SUPABASE_DB_URL" -c "SELECT COUNT(*) FROM recipes WHERE image_url LIKE 'photos/meals/%'"
```

Expected row count: ~298 (matches the 298 webp files in `photos/meals/`).

---

### Phase 2-A.2 — Generate LQIP placeholders (30 min, zero risk to prod)

Low-Quality Image Placeholders give first-paint sharpness before the full image streams in. Bundled with the APK so they work offline.

```python
# scripts/generate_meal_lqips.py — runs locally, writes to assets/lqip/meals/
from PIL import Image
import os

src = "photos/meals"
dst = "assets/lqip/meals"
os.makedirs(dst, exist_ok=True)
TARGET = 64  # 64×64 px keeps file size <2 KB while preserving recognizable color/composition

count = 0
total_bytes = 0
for fname in os.listdir(src):
    if not fname.endswith(".webp"): continue
    img = Image.open(os.path.join(src, fname)).convert("RGB")
    img.thumbnail((TARGET, TARGET))
    out = os.path.join(dst, fname)
    img.save(out, "WEBP", quality=50, method=6)
    count += 1
    total_bytes += os.path.getsize(out)
print(f"Generated {count} LQIPs, total {total_bytes/1024:.1f} KB")
```

**Expected output:** ~298 LQIPs at <2 KB each = ~600 KB total bundled in the APK. Compare against the **−64 MB** we just removed = net **−63.4 MB**.

Add `assets/lqip/meals/` to `pubspec.yaml` `assets:` block.

---

### Phase 2-A.3 — Upload to Supabase Storage (30 min, prod write)

```bash
# Using supabase-cli + python or rclone — both work. Example with the CLI:
supabase storage cp ./photos/meals/ "ss:///recipes_images/" --recursive --content-type 'image/webp'

# Or via Python script using supabase-py:
# (requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY)
```

**Bucket configuration** (one-time setup, idempotent):
```sql
-- Ensure bucket exists, public, with sensible cache headers
INSERT INTO storage.buckets (id, name, public)
VALUES ('recipes_images', 'recipes_images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Cache-Control for 30 days (image versions only change when slug changes)
UPDATE storage.objects
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
  'cacheControl', 'public, max-age=2592000, immutable'
)
WHERE bucket_id = 'recipes_images' AND name LIKE '%.webp';
```

**Verify upload:** open any URL like `https://<proj>.supabase.co/storage/v1/object/public/recipes_images/firin_tarcinli_elma.webp` in a browser. Should render the photo.

---

### Phase 2-A.4 — Database rewrite (5 min, prod write, REVERSIBLE)

```sql
-- Run on production after Phase 2-A.3 has uploaded all 298 files.
-- Strip the 'photos/meals/' prefix so MediaUrl.resolve() routes through
-- the CDN/Supabase Storage instead of looking for a bundled asset.
BEGIN;

UPDATE recipes
SET image_url = SUBSTRING(image_url FROM LENGTH('photos/meals/') + 1)
WHERE image_url LIKE 'photos/meals/%';

-- Verification: every row should now look like a bare filename
SELECT COUNT(*) AS ok FROM recipes WHERE image_url LIKE '%.webp' AND image_url NOT LIKE '%/%';
-- Expected: ~298

COMMIT;
```

**Rollback:**
```sql
BEGIN;
UPDATE recipes
SET image_url = 'photos/meals/' || image_url
WHERE image_url LIKE '%.webp' AND image_url NOT LIKE '%/%';
COMMIT;
```

(Or restore from the CSV snapshot.)

---

### Phase 2-A.5 — Code changes (Flutter)

Surprisingly thin. Three edits.

#### 5.1 — Add LQIP-aware `RecipeImage` widget

A wrapper around `CachedImage` that displays the bundled LQIP underneath the streaming photo, so first paint is sharp.

```dart
// lib/features/nutrition/presentation/widgets/recipe_image.dart  (new file)
import 'package:flutter/material.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../domain/models/recipe.dart';

/// Phase 139 · meal image with bundled LQIP placeholder. The LQIP is
/// a ~1 KB 64×64 WebP shipped under `assets/lqip/meals/<slug>.webp`;
/// the full image streams from `recipes_images` Supabase Storage via
/// CachedNetworkImage's disk cache. First paint is the LQIP scaled up
/// + blurred, so the user never sees a grey hole — even on a cold
/// cache + slow network. The full image fades in over the LQIP when
/// it lands.
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.url,
    required this.slug,
    this.fit = BoxFit.cover,
    this.memCacheHeight = 600,
  });

  final String url;
  final String slug;
  final BoxFit fit;
  final int memCacheHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // LQIP: bundled, instant, blurred up to fill the slot. Acts as
        // both first-paint placeholder AND offline fallback (if the
        // network image never resolves, the LQIP stays visible).
        Image.asset(
          'assets/lqip/meals/$slug.webp',
          fit: fit,
          // No errorBuilder — a missing LQIP just falls back to the
          // CachedImage's default placeholder beneath.
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          // Decode at a small size; we're blurring it anyway.
          cacheHeight: 64,
        ),
        // Full-quality image streamed from CDN/Supabase. CachedImage
        // already handles disk caching, fade-in, and a branded error
        // panel if the URL 404s.
        CachedImage(
          url: url,
          fit: fit,
          memCacheHeight: memCacheHeight,
        ),
      ],
    );
  }
}
```

#### 5.2 — Swap meal-image call sites

Find every `CachedImage(url: recipe.imageUrl ...)` in `lib/features/nutrition/` and replace with `RecipeImage(url: recipe.imageUrl, slug: recipe.slug, ...)`. Estimated touch: 4–6 widget files. The `Recipe` model already exposes `slug`.

#### 5.3 — Pubspec: drop `photos/meals/`, add `assets/lqip/meals/`

```yaml
flutter:
  assets:
    - .env
    - "photos/"
    # REMOVED: - "photos/meals/"     # now CDN-served, see SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md
    - "photos/workouts/"
    - "photos/exercises/"
    - "assets/lqip/meals/"   # bundled 64×64 LQIPs for first-paint
```

---

### Phase 2-A.6 — Cache warming on dashboard open

Drop-in prefetch for today's + tomorrow's meals so the user never sees a placeholder on the meal cards they actually look at.

```dart
// In dashboard mount (lib/features/home/...):
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _prefetchTodaysMeals();
  });
}

Future<void> _prefetchTodaysMeals() async {
  final todaysMeals = ref.read(dailyMenuProvider).value?.recipes ?? [];
  for (final recipe in todaysMeals.take(6)) {
    final url = recipe.imageUrl;
    if (url != null && url.startsWith('http')) {
      // Fire-and-forget. cached_network_image dedupes if a network
      // request is already in flight for the same URL.
      unawaited(precacheImage(
        CachedNetworkImageProvider(url),
        context,
      ));
    }
  }
}
```

**Impact:** ~6 photos × ~280 KB each = ~1.7 MB downloaded in the background after dashboard mount. Far cheaper than shipping 64 MB upfront, and only paid once per install (then cached).

---

### Phase 2-A.7 — Delete local `photos/meals/`

After 2-A.5 ships and a release build is verified showing meal images correctly:

```bash
mkdir -p /tmp/sixpack-meals-migration-backup
mv photos/meals /tmp/sixpack-meals-migration-backup/  # already done in 2-A.1 above
```

Verify the next `flutter build appbundle --release` produces an AAB ~55–60 MB smaller.

---

## 3. Failure modes + mitigations

| Failure | Likelihood | Mitigation |
|---|---|---|
| User on flaky network never gets the full image | Common | LQIP stays visible indefinitely. User sees a sharp-enough placeholder, not a grey hole. |
| Supabase Storage outage during launch hour | Rare | LQIP fallback covers; `CachedImage`'s `errorWidget` renders the branded fallback panel. No crash. |
| CDN cache invalidation on a renamed image | Possible | We don't rename images — the slug → filename mapping is immutable. The `Cache-Control: immutable` header is therefore safe. |
| Cold-start dashboard sees no images at all (zero cache, zero network) | Edge case | LQIPs are bundled, so dashboard cards never show pure blank. |
| Recipe row in DB has full URL (Unsplash legacy) | Existing behaviour | `MediaUrl.resolve()` already passes those through unchanged. No change needed. |
| Admin uploads a new meal photo via the admin panel | Existing flow | Admin panel writes to `recipes_images` already (see `admin_recipe_form.dart`). New photos land in the same bucket the migration just populated. |
| First-time install on a low-end Android in airplane mode | Acceptable | LQIPs render correctly, user can browse meal names + macros + LQIP; full image landings come when network restores. |

---

## 4. Rollback procedure

If any step fails or production smoke tests show meal images broken, the rollback is mechanical:

```bash
# 1. Revert the DB
psql "$SUPABASE_DB_URL" <<'SQL'
BEGIN;
UPDATE recipes
SET image_url = 'photos/meals/' || image_url
WHERE image_url LIKE '%.webp' AND image_url NOT LIKE '%/%';
COMMIT;
SQL

# 2. Restore the local assets
cp -r /tmp/sixpack-meals-migration-backup/meals photos/

# 3. Revert pubspec.yaml (git checkout pubspec.yaml)

# 4. Rebuild AAB; users now see local-asset-backed meals again
bash scripts/release-build.sh aab
```

The CDN-uploaded files don't need to be deleted on rollback — they cost ~5 cents/month at Supabase egress and provide a future option.

---

## 5. QA checklist (gate for shipping)

Before marking the migration complete:

| # | Check | Method |
|---|---|---|
| 1 | All 298 images uploaded to `recipes_images` | `psql -c "SELECT COUNT(*) FROM storage.objects WHERE bucket_id='recipes_images' AND name LIKE '%.webp'"` |
| 2 | Random spot-check: 5 meal photos open in a browser via the public URL | Manual |
| 3 | All 298 DB rows have bare-filename `image_url` | `SELECT COUNT(*) FROM recipes WHERE image_url LIKE '%/%'` should be 0 (excluding external URLs) |
| 4 | LQIP bundle exists for every recipe | `ls assets/lqip/meals/ \| wc -l` matches recipe count |
| 5 | Cold-app first nutrition tab visit shows LQIPs before full images | Manual, slow-network test |
| 6 | After 30-second wait, full images replace LQIPs sharply | Manual |
| 7 | Airplane mode: nutrition tab shows LQIPs, no crashes, no console errors | Manual |
| 8 | App restart: cached photos load instantly (no re-download) | Manual; logcat should show no network requests |
| 9 | Release AAB size dropped by 55–60 MB | `du -sh build/app/outputs/bundle/release/app-release.aab` |
| 10 | All existing meal-image call sites swapped to `RecipeImage` widget | `grep -r "CachedImage.*recipe\." lib/features/nutrition/` should be empty |

---

## 6. Estimated effort + timeline

| Phase | Effort | Risk | Reversible? |
|---|---|---|---|
| 2-A.1 backup & inventory | 15 min | 🟢 zero | n/a |
| 2-A.2 LQIP generation | 30 min | 🟢 zero | trivially |
| 2-A.3 Supabase upload | 30 min (mostly waiting) | 🟢 low | files stay in bucket; harmless |
| 2-A.4 DB rewrite | 5 min | 🟡 medium (prod DB write) | full rollback SQL ready |
| 2-A.5 Flutter code edits | 1–2 hr | 🟢 low | git revert |
| 2-A.6 Cache-warming | 30 min | 🟢 low | git revert |
| 2-A.7 Delete local `photos/meals/` | 1 min | 🟢 zero (backup retained) | mv from /tmp |
| Verification + smoke test | 1 hr | — | — |
| **Total** | **~4 hr active work** | 🟡 medium overall | full rollback in <10 min |

---

## 7. Decision points needing your input

Before I execute this plan (when you approve), I need:

- **Supabase project ref / connection string** — so the upload + DB scripts know which project to target.
- **Whether `recipes_images` bucket already has any photos** — if PM has uploaded admin-form photos there, our slug-named uploads must not collide. (Plan as-written assumes the bucket is empty of slug-named files.)
- **PM/UX approval of LQIP appearance** — I can render a sample LQIP set + a side-by-side preview before bulk-generating.
- **Whether to ship this in the SAME release as Tier 1** or a separate Play release after Tier 1 is validated in production.

---

## 8. What this plan deliberately doesn't do

- **No new dependencies** — uses `cached_network_image` + `flutter_cache_manager` already in pubspec.
- **No bucket-policy changes** — `recipes_images` is already public per existing migrations.
- **No widget rewrite** — `CachedImage` is preserved; `RecipeImage` is a thin LQIP wrapper that composes it.
- **No DB schema change** — same column, same type, just different values. Easier rollback than an `ALTER TABLE`.
- **No image quality drop** — we keep the same WebP files; just relocate them. (Tier 2-C "recompress at lower quality" is a separate proposal, not bundled here.)
- **No CDN signup** — Supabase Storage's built-in public URL is sufficient. If you want CloudFlare / BunnyCDN in front of it later, `MediaUrl.resolve()` already handles that via `CDN_BASE_URL` in `.env` — no code change required.
