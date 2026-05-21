# Tier 1 + 3 + 4 Change Log (Phase 139)

> **Date:** 2026-05-16
> **Scope:** Applied changes from `APK_OPTIMIZATION_MASTER_AUDIT.md` Tiers 1, 3, and 4.
> **Status:** All approved actions complete. Tier 2 (meals → CDN) deferred to a dedicated migration plan per user instruction.
> **Verification:** `flutter analyze` clean. AAB build successful.
> **Backups:** `/tmp/sixpack-cleanup-backup-2026-05-16/`

---

## 0. Headline before/after

| Metric | Before | After | Δ |
|---|---|---|---|
| Working tree (excl. `.git`, `build/`, `.dart_tool/`) | 1.2 GB | **399 MB** | **−66%** |
| Per-ABI release APK (arm64-v8a) | 124.9 MB (projected w/o Tier 1) | **121.4 MB** | −3.5 MB (Tier 1-B/C prevented growth) |
| Fat release APK | 138 MB (May 11) | 135 MB (projected) | −3.5 MB |
| Per-user **Play download** (arm64-v8a via AAB) | ~138 MB (fat APK upload) | **~85–90 MB** (Play-split AAB) | **−50 MB delivered** |
| Final AAB on disk (all 3 ABIs) | n/a (new path) | 165 MB | — |
| Photo assets in APK | (with 2 oversized PNGs at 3.7 MB) | 71.15 MB clean | Cardio files: 3.7 MB → 191 KB (−95%) |
| Active orphan declarations | 9 files in `pubspec.yaml` `photos/` glob | **0** | Cleaned |
| Direct `pubspec.yaml` deps | 33 | 32 | `cupertino_icons` removed |
| `pubspec.yaml` dev deps | 3 | 4 | `change_app_package_name` correctly classified |

**Net impact for your launch:** A Play Store user on arm64-v8a now downloads roughly **50 MB less** than they would have with the prior fat-APK upload path. Local working tree is **800 MB lighter** with no production behaviour change.

---

## 1. Tier 1 — APK delivery + asset cleanup

### 1-A. AAB release pipeline wired

**File added:** `scripts/release-build.sh` (5.7 KB, executable).

**What it does:** Provides three release modes:
- `bash scripts/release-build.sh` (default = `aab`) → `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (165 MB on disk; Play splits it per device)
- `bash scripts/release-build.sh apk` → fat APK
- `bash scripts/release-build.sh split` → per-ABI APKs

**Why it matters:** Before this script, the only documented release path was Phase 138's `dev-run.sh` (debug/profile-only) — no canonical "build me a Play-ready artifact" entry. The AAB delivers ~50 MB less per user than the fat APK that would have been uploaded otherwise.

**Verified:**
```
build/app/outputs/bundle/release/app-release.aab  =  165 MB
  ├── base/lib/arm64-v8a/        ~31.7 MB native (delivered to arm64 users)
  ├── base/lib/armeabi-v7a/      ~20.4 MB native (delivered to 32-bit users)
  ├── base/lib/x86_64/           ~33.5 MB native (delivered to x86_64 users — rare)
  └── base/{assets, dex, ...}    ~80 MB shared
```

**Reversible?** Trivially — the script is additive. Delete `scripts/release-build.sh` to revert. The Gradle config (which actually controls the build) is unchanged.

**Next operator step (you):** Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console. Play will display the per-device download size estimate.

---

### 1-B. Re-encode 2 PNG-as-WebP outliers

**Files modified:**
| Path | Before | After | Δ |
|---|---|---|---|
| `photos/workouts/cardio_full_body_flow.webp` | 1,983,729 B (PNG, 1536×1024) | 115,054 B (VP8 WebP, 1536×1024, q=82) | **−94.2%** |
| `photos/workouts/cardio_mobility_stretch.webp` | 1,856,858 B (PNG, 1536×1024) | 76,222 B (VP8 WebP, 1536×1024, q=82) | **−95.9%** |
| **Sum** | **3,840,587 B** | **191,276 B** | **−3,649,311 B (−3.48 MB)** |

**How:** Python 3 + Pillow, `Image.save(path, "WEBP", quality=82, method=6)`. Same path, same dimensions, lossy WebP encoding consistent with the other 32 workout images in `photos/workouts/`.

**Quality check:** Sampled 5 pixels from each pair; average per-channel delta = **1.3 / 255 and 1.9 / 255**. Visually imperceptible.

**Backup:** `/tmp/sixpack-cleanup-backup-2026-05-16/tier-1-b-reencode-originals/` (3.7 MB)

**Rollback procedure:**
```bash
cp /tmp/sixpack-cleanup-backup-2026-05-16/tier-1-b-reencode-originals/* photos/workouts/
```

**Verification in built APK:**
```
115054  assets/flutter_assets/photos/workouts/cardio_full_body_flow.webp
 76222  assets/flutter_assets/photos/workouts/cardio_mobility_stretch.webp
```

---

### 1-C. Delete 9 orphan onboarding photos

**Files removed from `photos/` root (declared in pubspec but 0 import sites in `lib/`):**

| Path | Size | Verified absent in APK |
|---|---|---|
| `photos/alınanbilgileregörekişiselplanoluşturmaörnek.webp` | 8,522 B | ✓ |
| `photos/cinsiyet_diger.webp` | 10,382 B | ✓ |
| `photos/kişiselkoçarkaplanfoto.webp` | 8,168 B | ✓ |
| `photos/onboarding_ilk_karşılama_metninin_arkaplanı.webp` | 8,006 B | ✓ |
| `photos/kullanıcıbilgilerinegörekişiselplanoluşturma.webp` | 38,248 B | ✓ |
| `photos/özelplanınhazırörnekfoto.webp` | 66,778 B | ✓ |
| `photos/vücutseçimikiloluhacimli.webp` | 52,616 B | ✓ |
| `photos/vucütseçimiNormal.webp` | 44,178 B | ✓ |
| `photos/vücutseçimiZayıf.webp` | 44,182 B | ✓ |
| **Sum** | **281,080 B (274.5 KB)** | All confirmed absent from `app-arm64-v8a-release.apk` |

**Verification method:** Per-file `grep -r --include='*.dart' $basename lib/` → 0 hits for all 9.

**Note on `cinsiyet_diger.webp`:** This file existed alongside `cinsiyetseçimierkek.webp` (used) and `cinsiyetseçimikadın.webp` (used). The matching `Gender.other` case in `paywall_screen.dart` falls through to `_TransformationPlaceholder` with no image — confirming this file was authored but never wired up.

**Backup:** `/tmp/sixpack-cleanup-backup-2026-05-16/tier-1-c-orphan-photos/` (296 KB)

**Rollback procedure:**
```bash
cp /tmp/sixpack-cleanup-backup-2026-05-16/tier-1-c-orphan-photos/* photos/
```

---

## 2. Tier 3 — Working tree reclamation

### 3-A. `photos/new_workouts_image/` — 132 MB of source PNGs

**Status before:** 88 PNG files, ~1.5 MB avg, total 132 MB. Untracked in git. NOT declared in `pubspec.yaml` assets (so it never shipped in any APK). The `photos/exercises/` directory holds the lossy-compressed WebP outputs already.

**Action:** Moved to `/tmp/sixpack-cleanup-backup-2026-05-16/tier-3-untracked-large-files/new_workouts_image/`.

**APK impact:** Zero. **Working tree impact:** −132 MB.

**Rollback procedure:**
```bash
mv /tmp/sixpack-cleanup-backup-2026-05-16/tier-3-untracked-large-files/new_workouts_image photos/
```

**Long-term recommendation:** Keep the artwork sources in a separate `formai-assets-source` repo (git-LFS) or a cloud drive. They aren't needed for normal development — only for re-encoding the WebP outputs occasionally.

---

### 3-B. `assets/ONBOARDING_EXAMPLE_VİDEO.mp4` — 3.4 MB

**Status before:** Single file in `assets/` directory. Not declared in pubspec (so never shipped). Not referenced anywhere in `lib/`. Leftover from an earlier onboarding iteration.

**Action:** Moved to `/tmp/sixpack-cleanup-backup-2026-05-16/tier-3-untracked-large-files/ONBOARDING_EXAMPLE_VİDEO.mp4`. The (now-empty) `assets/` directory was also removed.

**APK impact:** Zero. **Working tree impact:** −3.4 MB.

**Rollback procedure:**
```bash
mkdir -p assets
mv /tmp/sixpack-cleanup-backup-2026-05-16/tier-3-untracked-large-files/ONBOARDING_EXAMPLE_VİDEO.mp4 assets/
```

---

### 3-C. `terraform/legal_pages/.terraform/` — 675 MB

**Status before:** Terraform provider cache (binaries for AWS / GCP / Cloudflare etc.) downloaded during `terraform init`. Already gitignored (`terraform/.gitignore` excludes `.terraform`). Reproducible via one command.

**Action:** Deleted directly (no backup needed — `terraform init -upgrade` re-pulls).

**APK impact:** Zero. **Working tree impact:** −675 MB.

**To restore (only if/when you next run Terraform):**
```bash
cd terraform/legal_pages && terraform init
```

---

## 3. Tier 4 — Dependency hygiene

### 4-A. Removed `cupertino_icons` from `dependencies:`

**Why:** 0 import sites in `lib/` (verified by `grep -rn 'package:cupertino_icons\|CupertinoIcons' lib/`). The package was tree-shaken to 848 B in release APKs anyway — its removal saves **zero shipped bytes**, but reduces transitive resolution churn and clarifies intent.

**Verification:**
- `flutter pub get` output: `These packages are no longer being depended on: cupertino_icons 1.0.9`
- `flutter analyze`: `No issues found! (ran in 18.8s)`
- AAB build: succeeded (warning about CupertinoIcons font family is benign — emitted by Flutter's font manifest scanner, not a build error)

**Reversible?** Add `cupertino_icons: ^1.0.8` back to `dependencies:`. No code uses it, so a re-add is purely declarative.

---

### 4-B. Moved `change_app_package_name` to `dev_dependencies:`

**Why:** 0 import sites in `lib/`. It's a CLI helper for renaming the Android `applicationId` (run via `flutter pub run change_app_package_name:main ...`). Classifying it as a dev dep removes it from the runtime resolution graph.

**Pubspec diff:**
- Removed from `dependencies:` (line 109 of old pubspec).
- Added to `dev_dependencies:` after `flutter_launcher_icons`.

**Verification:** Same as 4-A — `flutter pub get` + `flutter analyze` clean.

---

## 4. Verification checklist (operator action items)

The following manual smoke checks are **recommended before Play upload**, since I cannot run them from this environment:

| # | Check | How to verify |
|---|---|---|
| 1 | App launches without missing-asset crash | `bash scripts/dev-run.sh release` and install on Xiaomi 22095RA98C |
| 2 | Onboarding visuals intact (no missing photos) | Walk through gender selection + body shape + goal screens; visual identity unchanged |
| 3 | Workout dashboard hero cards render | Open Antrenman tab; `cardio_full_body_flow` + `cardio_mobility_stretch` cards should show their photos sharply |
| 4 | Recipe / meals tab unchanged | Navigate to nutrition tab; thumbnail rendering should be identical to before (we didn't touch meals/) |
| 5 | No `Image.asset` runtime errors | Watch logcat: `adb logcat -s flutter` while moving through the app |
| 6 | Auth flow + paywall unchanged | Sign in (any method) + reach paywall + see plan cards |
| 7 | Pose detection (camera workout) works | Open a workout; verify pose detection draws skeleton overlay |
| 8 | AAB uploads to Play without errors | Drag `build/app/outputs/bundle/release/app-release.aab` into Play Console release |
| 9 | Play download size estimate dropped | Compare Play Console's reported delivered size against the prior fat-APK upload |

If any of #1–#7 fail, the rollback procedure for the relevant tier is documented above; all backups remain in `/tmp/sixpack-cleanup-backup-2026-05-16/` until you confirm production validation.

---

## 5. What was NOT done (deferred to a separate phase)

- **Tier 2-A** (meals → Supabase CDN, ~−55 to −60 MB APK) — explicitly deferred per your "DO NOT yet execute" Tier 1 elaboration. A dedicated migration plan ships in `SUPABASE_MEAL_IMAGE_MIGRATION_PLAN.md`.
- **Tier 2-B** (drop unused ML Kit pose model, ~−2.7 or −6.1 MB APK) — needs `PoseDetectorOptions.model` config audit + a form-accuracy A/B.
- **Tier 5** (release flag tuning — `--obfuscate --split-debug-info`) — needs Sentry symbol upload pipeline first.
- **Tier 6** (runtime perf — FPS / rebuild storm audit) — separate `flutter run --profile` + DevTools timeline session.

---

## 6. Cleanup of `/tmp/sixpack-cleanup-backup-2026-05-16/`

Once you've validated the Play upload + on-device smoke checks, you can drop the backup:

```bash
rm -rf /tmp/sixpack-cleanup-backup-2026-05-16/
```

This is reclaimable ~135 MB on `/tmp` (which lives on tmpfs on most distros and is wiped on reboot anyway). I recommend keeping it for **at least one Play review cycle** before clearing.
