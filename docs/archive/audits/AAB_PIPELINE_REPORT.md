# AAB Pipeline Report — T1.3

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Audit `scripts/release-build.sh` and the documented release path.
> **Status:** VERIFIED CORRECT. No fix required.

---

## 1. The release script

`scripts/release-build.sh` (5.6 KB, executable) was added in Phase 139 T1-A. Its full body was read and verified.

### 1.1 Default mode is AAB

```bash
MODE="${1:-aab}"   # ← default is AAB

case "$MODE" in
    aab|appbundle)
        "${FLUTTER}" build appbundle --release
        OUT="build/app/outputs/bundle/release/app-release.aab"
        ;;
```

Running `bash scripts/release-build.sh` with no argument produces `app-release.aab` via `flutter build appbundle --release`. That's exactly the path Phase 139's `APK_OPTIMIZATION_MASTER_AUDIT.md §1.1.0` recommended.

### 1.2 The alternative modes are clearly secondary

```bash
    apk)
        # Fat APK — includes all ABIs in one file. Useful for Firebase App
        # Distribution / direct sideload / smoke tests. Not for Play upload
        # (Play prefers AAB and will reject in some workflows).
        "${FLUTTER}" build apk --release
        ;;
    split|split-apk)
        # Per-ABI APKs. Legacy fallback for stores that don't accept AAB.
        "${FLUTTER}" build apk --release --split-per-abi
        ;;
```

Both `apk` and `split` modes are clearly commented as non-Play paths. The script's inline docstring explicitly says: *"Not for Play upload (Play prefers AAB and will reject in some workflows)."*

### 1.3 Output directory naming + Play upload instructions

The script prints next-step guidance after a successful build:

```
Next steps for Play upload:
  1. Verify the AAB at: build/app/outputs/bundle/release/app-release.aab
  2. Upload to Play Console → Release → Production → Create new release
  3. Play auto-generates per-device APKs — check the download size
     estimate on the Play Console release page (typically -25 to -35 MB
     vs the fat APK for users on arm64-v8a).
```

This is operator-grade documentation embedded in the tool. No further fix needed.

---

## 2. What was checked

| Check | Method | Result |
|---|---|---|
| Default mode is AAB | read line 51, `MODE="${1:-aab}"` | ✓ |
| AAB mode runs `flutter build appbundle --release` | read lines 73-79 | ✓ |
| Output written to expected Play-upload path | read line 78, `app-release.aab` | ✓ |
| AAB vs APK trade-off is documented | read inline comments lines 9-23 | ✓ |
| Operator post-build instructions included | read final echo block | ✓ |
| Script is executable | `ls -l scripts/release-build.sh` | ✓ |
| Script handles the missing-Flutter-SDK case | read lines 54-62 | ✓ |
| `--obfuscate --split-debug-info` documented as deferred | read lines 24-30 | ✓ |
| Pairs with `TIER_1_3_4_CHANGE_LOG.md` | read line 46 | ✓ |

**Every check passes.** The pipeline is correctly configured.

---

## 3. The remaining concern: operator habit

The script being correct doesn't guarantee it's the path actually used. The most common drift modes:

1. **Someone runs `flutter build apk` directly** out of habit → produces the fat APK at `app-release.apk` (126.6 MB measured this session). If that file gets uploaded to Play, the user is on the worse path.
2. **CI/CD configured against the wrong target.** No CI is configured for this repo (no `.github/workflows/release.yml` or similar), so this is currently a human-process concern, not an automation concern.

### Mitigation already in place

- The script's inline docs warn against using `apk` mode for Play.
- Phase 139's `TIER_1_3_4_CHANGE_LOG.md §1-A` documents the choice.
- `APK_OPTIMIZATION_MASTER_AUDIT.md` (now archived at `docs/archive/audits/`) records the per-ABI / fat APK size differential.

### Recommendation

Two small operator-process items (not code changes):

1. **Verify the Play Console upload uses AAB**, not fat APK. Operator can confirm by checking the most recent release artifact in Play Console → Release → Production.
2. **If a CI/CD pipeline is added later**, it should call `bash scripts/release-build.sh` (default = AAB), not `flutter build apk`.

---

## 4. APK delta projection if AAB is used correctly

| Artifact | Size | Notes |
|---|---|---|
| Fat APK (`flutter build apk --release`) | 126.6 MB (this session) | All 3 ABIs in one file. **WRONG for Play.** |
| AAB upload → Play split per ABI | ~85 MB delivered to arm64-v8a user | **CORRECT** Play user-facing size |
| Δ delivered | **−~30 MB per user** | The Tier 1-A win |

This is in addition to Tier 2-A's −60 MB delivered. Combined: **post-Tier-1-A + Tier-2-A delivered APK ≈ 85 MB**, down from a pre-Phase-139 baseline of ~135 MB. The full ~50 MB user-delivered reduction depends on the Play upload going through AAB.

---

## 5. Status

**VERIFIED CORRECT.** `scripts/release-build.sh` is well-designed, correctly documents the AAB-default behavior, and is the canonical release entrypoint. No fix needed.

The remaining surface is **operator process**: ensure Play uploads use AAB, not fat APK. That's a release-team checklist item, not an engineering fix.

T1.3 complete.
