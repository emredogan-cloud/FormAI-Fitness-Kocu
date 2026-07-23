# FormAI — Closed Test Polish Sprint · Part 2 Report

**Scope:** Complete the two remaining polish tasks — image-library refresh
(Task 5) and in-app UI-asset integration (Task 6) — with production quality and
zero regressions. Tasks 1–4 from Part 1 remain complete and untouched. The
Google Play closed test is **live**, so every change was made surgically and
verified before shipping.

**Branch:** `main` · **Build:** `1.0.0+16`
**Commits (this sprint):**

| Commit | Task | Title |
|--------|------|-------|
| `f16c39d` | 5 | polish(images): refresh onboarding goal tiles + workout category art |
| `7fa1052` | 6 | polish(assets): milestone medal + XP gem illustrations |

---

## 1. Summary

Both remaining tasks are complete, committed, and validated.

- **Task 5** — swapped the **6 weakest in-app photos** for the premium
  dark-neon set (`photos/new-image/`), overwriting the existing `.webp` files
  in place so **no code or pubspec change** was needed. Targeted the two
  highest-impact photographic surfaces: onboarding **goal selection** and the
  **workout-category cards**. Kept every image that already matches the design
  language (gender tiles, activity, nutrition, challenge hero, onboarding
  heroes, body-type selectors).
- **Task 6** — integrated **2 of the 8** UI illustration assets where they
  cleanly upgrade a Material-icon surface (a **milestone medal** on the level-up
  celebration, an **XP gem** on the Gelişim identity line). The other 6 were
  deliberately **not** used — each would have clashed with the palette,
  duplicated a real dynamic widget, or shipped with a background/halo defect.
  "Every integration must have a UX reason; if an asset reduces clarity, do not
  use it."

Everything is green: `flutter analyze` = 0 issues, **328 tests pass**, release
APK + AAB build and are release-signed.

---

## 2. Images replaced (Task 5)

All 6 replacements were **optimized before integration** (PNG → WebP q80,
resized to display resolution, metadata stripped) and written over the existing
asset path — so the app renders them through the unchanged `OnboardingImage`
(dark gradient scrim, `BoxFit.cover`) and workout-card widgets.

| Surface | Asset (overwritten in place) | New source | Old→New |
|---------|------------------------------|-----------|---------|
| Goal · "Daha fit görünmek" | `photos/hedefinneSadeceSix-Pack.webp` | `002-sixpack-girl` | 41→58 KB |
| Goal · "Kas yapmak" | `photos/hedefinneHacimKazanmak.webp` | `003-hypertrofy-man` | 106→104 KB |
| Goal · "Güçlenmek" | `photos/hedef_guclenmek.webp` | `001-sixpack-man` | 82→78 KB |
| Goal · "Göbek eritmek" | `photos/hedefinneSıkılaşmak.webp` | `006-hııt-girl` | 38→95 KB |
| Workout card · HIIT/abs | `photos/sınırlarınızorlabelirginkarınkarınkaslarıHIITnewfoto.webp` | `005-hııt-man` | 97→86 KB |
| Workout card · core/power | `photos/sınırlarınızorlademiraltıpaketgücünewfoto.webp` | `012-the-zone` | 135→53 KB |

**Net effect:** the `photos/` root shrank ~25 KB while every swapped surface
jumped a clear quality tier — the awkward glute close-up, the abstract
barbell-plate, and the two CGI-render category images became premium,
tonally-consistent dark-neon photographs. Verified with a before/after
comparison rendered under the real bottom-scrim.

**Deliberately kept** (already match the design language, per the brief):
gender tiles (clean standing portraits), activity-level tiles, the whole
nutrition set (on-brand food photography), the dashboard challenge hero
(regenerated in an earlier sprint), the onboarding act-1/act-2 heroes, and the
`vücutseçimi*` body-type selectors (tactful cartoon avatars are the right UX
for body-shape selection). The remaining new images (007-yoga, 008/018
nutrition, 009-concept, 010-motivation, 011-smart-watch, 013-017) had no
surface that they'd improve without displacing an image that already fits —
they are available for future use.

---

## 3. Assets integrated (Task 6)

The 8 assets in `assets/in-app-assets/` are flat, brightly-lit illustration
PNGs (1.5–2.4 MB each, opaque backgrounds baked in) — a different register from
the app's photographic language. I background-keyed each candidate to clean
transparency and judged it against a real dark surface. **Two** had a genuine,
conflict-free home:

| Asset | Processed → | Integration | Why it's an upgrade |
|-------|-------------|-------------|---------------------|
| `007-milestone` (medal) | `assets/illustrations/milestone_medal.webp` (320², 30 KB, transparent) | **Level-up celebration sigil** — `level_up_screen.dart` `_sigil`; the bronze medal replaces a bare `Icons.keyboard_double_arrow_up_rounded` chevron, floating in the screen's existing gold glow | The level-up palette is deliberately **gold/metallic**; a medal fits it exactly and reads "achievement earned" better than a chevron. Its center star is purple → ties back to the brand. |
| `008-` (gem) | `assets/illustrations/xp_gem.webp` (87×160, 5 KB, transparent) | **Gelişim identity line** — `gelisim_tab.dart`; a small purple gem glyph precedes the (previously plain-text) `Sv N · Title · N XP` line | On-brand neon-purple; adds a premium accent to a bare text line with **zero conflict** (nothing was there before). |

Both are declared under a new `assets/illustrations/` directory. A widget test
asserts the medal renders on the level-up screen.

### Assets deliberately NOT integrated (6 of 8)

| Asset | Reason skipped |
|-------|----------------|
| `005-streak-badge` (purple flame) | The streak system is intentionally **orange** (`#FF8A00`/`#F97316`) across 4 surfaces; a purple flame would create a palette clash unless the whole streak accent were recolored (out of scope, touches functional UI). |
| `003-progreess` (static 80% ring) | Would **duplicate and contradict** the real *animated* `_TrophyRing` (Gelişim) and `_CalorieRing` (nutrition) — a fixed "80%" next to live data reduces clarity. No empty-state slot exists for it. |
| `001-dumbell`, `004-diet` (avocado), `006-pro-tier-icon` (crown) | Baked **light-gray backgrounds** with soft drop shadows; keying leaves halo artifacts, and the bright/realistic tone clashes with the dark UI. Below production quality as cutouts. |
| `002-target-muscle-group` | No per-exercise muscle-diagram surface exists in the app; and the subject's dark tones merge with the dark background under keying. Nowhere to place it cleanly. |

---

## 4. Performance optimizations

- **Avoided ~54 MB of naive bloat.** The two source directories
  (`assets/in-app-assets/` 15 MB, `photos/new-image/` 39 MB) are **not**
  declared in `pubspec.yaml`, so none of the raw art ships. Only the 2 used
  illustration assets ship — **15 MB of raw PNG → 35 KB of keyed WebP**.
- **Task-5 images** were each resized to display resolution and re-encoded to
  WebP q80 with metadata stripped; the `photos/` root **shrank ~25 KB** despite
  the quality jump.
- **Relocated ~8.7 MB of untracked design-source PNGs** (`new_app_icon`,
  `new_form`, `new_paywall`, `Pasted image`, `kişisel_aı_raporun`) out of the
  bundled `photos/` root into `docs/reference-imagery/` — following the
  pubspec's own Phase-127 convention that reference imagery must not live in
  `photos/`. They were untracked (never in the canonical build) so this only
  cleans local builds, but the files are preserved for the founder.
- **pubspec hygiene:** the only new asset entry is `assets/illustrations/`
  (both files used); no unnecessary or dangling asset paths were added.
- **Image caching intact:** Task-5 swaps reuse the exact existing asset paths,
  so every `precacheImage` manifest and `CachedImage`/`Image.asset` call site
  keeps working unchanged; Task-6 assets load via `Image.asset` (framework
  `ImageCache`). No caching regression.

**Not touched (flagged for founder review):** two *committed* root PNGs still
ship unnecessarily — `First_opening.png` (~1.9 MB, referenced only by a code
comment) and `APP_ICON.png` (~1.9 MB, a source consumed by
`tool/format_play_store_assets.py`, not needed at runtime). Removing them would
shave ~3.8 MB from the shipped APK but requires a commit that moves founder
assets + updates a comment, so it's left as an explicit recommendation (§9)
rather than done blindly on a live build. Note also: `photos/` paths can be
served dynamically from Supabase (`media_url.dart` passes them through), so
"unused in `lib/`" is **not** proof an image is safe to delete — no content
photo was removed.

---

## 5. APK size

- **Release APK: 129.0 MB** (129,022,657 bytes) —
  `build/app/outputs/flutter-apk/app-release.apk`
- Release-signed with the production upload key (`key.properties` present →
  gradle `release` signingConfig).
- Built clean (`flutter clean` → `pub get` → build) after relocating the
  untracked source PNGs, so this reflects the true shippable size — **~9 MB
  smaller** than the pre-cleanup local build (138.2 MB).

## 6. AAB size

- **Release AAB: 107.9 MB** (107,863,588 bytes) —
  `build/app/outputs/bundle/release/app-release.aab`
- Built with `--obfuscate --split-debug-info=build/symbols` (symbols retained
  in `build/symbols/` for crash de-obfuscation), release-signed. This is the
  Play-upload artifact.

---

## 7. Device verification

Redmi device `AYXSUKIVJVPZ7HPZ`. The previous install (`+15`) was
**uninstalled** and the new **`+16`** release APK installed fresh —
`versionCode=16` confirmed on device via `dumpsys package`. Walked the
fresh-install onboarding flow:

| Target | Result |
|--------|--------|
| **Task 5 · goal tiles** (flagship surface) | ✅ **Confirmed.** On "Hedefin ne?" (step 3/11) all four swapped photos render — Göbek eritmek (jump-rope woman), Kas yapmak (bodybuilder), Daha fit görünmek (fit woman), Güçlenmek (muscular man). Premium dark-neon, cleanly cover-cropped in the half-tile treatment, tonally consistent — a clear jump from the old crops. |
| **Kept gender tiles** | ✅ On "Cinsiyetin?" (2/11) the retained `cinsiyet*` photos render cleanly (woman / man) — confirms the "keep what already fits" decision. |
| **Task 3 · new coach** (Part 1, regression check) | ✅ The human-trainer avatar renders correctly across the bonding screen, the name-chat header, the gender AI-note, and the living-avatar interlude — no regression. |
| **Live coach LLM** | ✅ Personalized name reply + goal interlude generated live (Claude online). |
| **Stability** | ✅ No crashes, no layout overflow, no asset-load errors through the walked flow. |

**Verified by mechanism (not separately walked on-device):** reaching the
remaining two surfaces requires completing all 11 onboarding steps + plan
generation + the paywall gate. Rather than grind that on a live device:
- **Task 5 · workout-category cards** render through the *exact same* path as
  the confirmed goal tiles (a bundled `photos/…` asset resolved to
  `Image.asset`) — the mechanism is proven by the goal-tile result.
- **Task 6 · level-up medal** is covered by a **passing widget test** that
  asserts the medal image renders on `LevelUpScreen` (a real level-up event
  can't be forced in a fresh session).
- **Task 6 · XP gem** renders via the same `Image.asset` path and sits on the
  Gelişim tab behind full onboarding.

**Part-1 items** (paywall, premium popup, launcher icon) are unchanged in
Part 2 and were verified during Part 1 (launcher icon confirmed via the app
switcher; paywall covered by 328 widget tests).

---

## 8. Validation results

| Check | Result |
|-------|--------|
| `flutter clean` + `flutter pub get` | ✅ clean |
| `flutter analyze` | ✅ **0 issues** |
| `flutter test` | ✅ **328 tests pass** (incl. updated level-up medal-sigil assertion) |
| Release APK build | ✅ succeeds, release-signed |
| Release AAB build | ✅ succeeds, obfuscated + release-signed |
| Regressions | None — Task 5 changed only image bytes on existing paths; Task 6 added 2 assets + swapped a chevron for a medal and prepended a gem glyph. RevenueCat, onboarding, workout, nutrition, and coach logic untouched. |

---

## 9. Remaining optional polish ideas

- **Unused new images (12 of 18):** `007-yoga`, `009-concept-aikoç`,
  `010-motivation`, `011-smart-watch`, `013-night-cardio`, `014-community`,
  `015-morning-workout`, `016-Strength`, `017-dynamism`, `018-healthy-life`,
  and the two nutrition shots (`008`/`018`) are premium and on-brand but had no
  surface to improve without displacing an image that already fits. Natural
  future homes: a community/referral banner (`014`), a tracking upsell
  (`011-smart-watch`), a mobility/recovery category (`007-yoga`).
- **Committed-asset APK trim (~3.8 MB):** relocate `First_opening.png` (unused,
  comment-only) and `APP_ICON.png` (build-tooling source) out of the bundled
  `photos/` root — a clean founder-approved commit could recover this.
- **Streak accent decision:** if the founder wants the purple `005-streak-badge`
  flame, it needs the streak system's deliberate orange accent recolored to
  purple across its 4 surfaces — a design decision, not a drop-in.
- **Level-up medal on the badges summary:** the same medal could replace the
  `Icons.military_tech_rounded` summary medallion on `badges_screen.dart` for
  consistency (left out to keep this sprint's surface count tight).
- **Play upload:** this build is `1.0.0+16` (the prior closed-test build was
  `+15`); confirm the version code before uploading.

---

*Prepared for the FormAI closed-test polish sprint, Part 2. Single deliverable,
as requested — no intermediate reports were produced.*
