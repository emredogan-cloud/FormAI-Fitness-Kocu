# App Icon Replacement Report

**Date:** 2026-05-23
**Branch:** feature/cdn-meal-migration
**Scope:** Replace the FormAI launcher / Play Store / home-screen icon (not onboarding artwork).

---

## 1. Icon system in use

| Layer | Tool / file | Notes |
|---|---|---|
| Generator | `flutter_launcher_icons: ^0.14.1` (dev_dependency in `pubspec.yaml`) | Runs at `flutter pub run flutter_launcher_icons` |
| Source PNG | `tool/app_icon.png` | Required input for the generator |
| Android targets | `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/launcher_icon.png` | Referenced by `AndroidManifest.xml` via `android:icon="@mipmap/launcher_icon"` |
| iOS targets | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png` | 19 PNG sizes regenerated |
| Adaptive icon | **Not configured** | See § 4 below |

Generator config block (`pubspec.yaml`, lines 216-220):

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "tool/app_icon.png"
  remove_alpha_ios: true
```

## 2. Source swap

- **From:** `tool/app_icon.png` (md5 `b1e1e02f…`, 1.32 MB, prior content)
- **To:** Copied from `photos/APP_ICON.png` (md5 `cc9c8cf3…`, 1.84 MB, 1254×1254 RGB, no alpha)

Single `cp` operation: `cp photos/APP_ICON.png tool/app_icon.png`. md5 confirmed identical after copy.

## 3. Files regenerated (md5 diff confirms swap)

### Android — `mipmap-*/launcher_icon.png`

| Density | Before (md5) | After (md5) | Size |
|---|---|---|---|
| mdpi    | `2aa6e75b…` | `0fa8e9e3…` | 8 KB |
| hdpi    | `5071a983…` | `73880d66…` | 12 KB |
| xhdpi   | `454e0644…` | `b3913bb9…` | 20 KB |
| xxhdpi  | `24a14337…` | `e535018c…` | 36 KB |
| xxxhdpi | `cfc39971…` | `845e9fe7…` | 60 KB |

`AndroidManifest.xml` already references `@mipmap/launcher_icon` for both `<application android:icon>` and the Sentry/PostHog metadata icon — no manifest change needed.

The legacy `ic_launcher.png` files (~544 B – 1.4 KB) in each mipmap directory are pre-existing Flutter scaffolding from `flutter create`; they are **unreferenced** by the manifest and were intentionally left untouched (would be scope creep to delete here).

### iOS — `AppIcon.appiconset/Icon-App-*.png`

All 19 PNG variants regenerated and re-shrunk by the generator. Spot check: `Icon-App-1024x1024@1x.png` md5 went from `76eb6b4e…` to `4f9a7726…`. Full list visible in `git status` (M on every Icon-App-*.png).

`remove_alpha_ios: true` ensured the iOS variants are opaque — required for App Store submission. Source PNG was already RGB (no alpha channel), so this was a no-op confirmation rather than a destructive flatten.

## 4. Adaptive icon status

**Not enabled, intentionally unchanged.**

- No `mipmap-anydpi-v26/` directory exists in the repo.
- No `drawable*/ic_launcher_foreground*` assets exist.
- `pubspec.yaml`'s `flutter_launcher_icons:` block does not declare `adaptive_icon_foreground` or `adaptive_icon_background`.

The current pipeline ships a square / round-cornered legacy launcher icon to every Android density bucket. This is the same shape FormAI has historically used and matches the prior production icon's behavior on Android 8+ devices (the OS draws the legacy icon inside its own theme mask).

**If adaptive icon is desired** (Android 8+ pill / squircle / circle device themes), the follow-up is:

1. Provide a transparent-background foreground PNG (1024×1024, art safe-zone ≤ 66 % of canvas).
2. Add to `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     adaptive_icon_background: "#000000"  # or a color/asset
     adaptive_icon_foreground: "tool/app_icon_foreground.png"
   ```
3. Re-run `flutter pub run flutter_launcher_icons` — the generator will create `mipmap-anydpi-v26/launcher_icon.xml` plus `drawable-*/ic_launcher_foreground.png` files automatically.

That work is out of scope for this commit (the user's brief said "foreground/background **if adaptive**" — current config isn't).

## 5. Validation performed

1. **Source byte-identity:** `md5sum photos/APP_ICON.png tool/app_icon.png` → matching hashes after copy.
2. **Generator success:** `flutter pub run flutter_launcher_icons` output `✓ Successfully generated launcher icons` with no errors / warnings.
3. **All 5 Android mipmap PNGs changed:** new md5s differ from baseline (table above).
4. **All 19 iOS AppIcon PNGs changed:** verified via `git diff --stat` showing 19 `Bin … -> …` size changes under `AppIcon.appiconset/`.
5. **Manifest unchanged:** still points at `@mipmap/launcher_icon`, which is exactly the resource name the generator wrote.

`flutter clean` was deliberately **not** run prior to icon regeneration — the generator writes directly to source-controlled `res/` and `Assets.xcassets/` paths, not the build cache, so `build/` state has no effect on icon output.

## 6. Rebuild instructions

For a clean release build that picks up the new icon:

```bash
# from repo root
export PATH="$HOME/dev/flutter/bin:$PATH"

flutter clean
flutter pub get

# Android release AAB (for Play Store upload)
flutter build appbundle --release

# Android release APK (for sideload / QA)
flutter build apk --release

# iOS (run on macOS)
flutter build ipa --release
```

For local quick-check on an Android device: `flutter run --release` and inspect the launcher icon on the device home screen.

**Play Store note:** Google Play also has a separate 512×512 store-listing icon that is managed inside the Play Console (not in the repo). This commit replaces the *bundled* launcher icon only. The store-listing artwork must be updated manually in the Play Console if it should match the new design.

## 7. Files in this commit

```
M  tool/app_icon.png                                                 (source swap)
M  android/app/src/main/res/mipmap-mdpi/launcher_icon.png            (regenerated)
M  android/app/src/main/res/mipmap-hdpi/launcher_icon.png            (regenerated)
M  android/app/src/main/res/mipmap-xhdpi/launcher_icon.png           (regenerated)
M  android/app/src/main/res/mipmap-xxhdpi/launcher_icon.png          (regenerated)
M  android/app/src/main/res/mipmap-xxxhdpi/launcher_icon.png         (regenerated)
M  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png      (19 sizes regenerated)
A  APP_ICON_REPLACEMENT_REPORT.md                                    (this file)
```

Pre-existing modifications (`logs.txt`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `pubspec.lock`, `web/public/privacy.html`) were intentionally **not** staged — kept out to honor the "small isolated commit" instruction.
