# Asosystem Gitignore Report — T1.2

> **Branch:** `feature/cdn-meal-migration`
> **Date:** 2026-05-19
> **Action:** Added `asosystem/` to root `.gitignore`.
> **Status:** APPLIED. asosystem/ now correctly ignored.

---

## 1. What changed

Root `.gitignore`, single addition after the `Beslenme-Photos/` entry:

```diff
 # Phase 40: untracked personal nutrition reference photography. Kept
 # off-repo because the folder is ~MB of user-owned shots with no
 # production asset binding in pubspec.yaml.
 Beslenme-Photos/
+
+# Tier 3 · standalone Vite + Tailwind ASO landing-page project that
+# lives alongside the Flutter app for convenience. Not a Flutter
+# dependency, not declared in pubspec, never bundled. 245 MB of
+# node_modules + Vite exports that asosystem/.gitignore already
+# excludes internally — but the asosystem/ root itself wasn't
+# gitignored, so a `git add .` from someone unaware would stage 700+
+# unrelated files. Pin it shut here. To work on it, just `cd
+# asosystem/ && npm run dev`; git operations from the Flutter root
+# stay clean.
+asosystem/
```

Pure protection. No deletion. asosystem/ stays on disk usable.

---

## 2. Verification

```
$ git check-ignore -v asosystem/
.gitignore:94:asosystem/    asosystem/
```

Confirmed: rule on line 94 of `.gitignore` matches `asosystem/`.

```
$ git status --porcelain | grep -i asosystem
(no output — asosystem entries removed from untracked list)
```

Confirmed: git no longer sees asosystem/* as untracked.

---

## 3. Impact

| Metric | Before | After |
|---|---|---|
| `asosystem/` visibility to git | untracked (~700+ shown via `??`) | ignored (invisible) |
| Risk of accidental `git add .` staging unrelated 245 MB | **HIGH** | **eliminated** |
| Disk size of `asosystem/` | 245 MB | 245 MB (unchanged — file still there) |
| Bundled into APK? | No (never was) | No (never was) |
| Pushed to GitHub remote? | No (was untracked) | No (now ignored) |

The change is **protection-only**. It does not affect the asosystem
project's own functionality — `cd asosystem && npm run dev` still
works exactly as before.

---

## 4. Status

**APPLIED.** asosystem/ is git-invisible from the Flutter repo root. To continue working on the Vite project, `cd asosystem` and use the asosystem-internal toolchain unchanged. T1.2 complete.
