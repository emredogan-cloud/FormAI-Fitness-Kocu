# RESUME GUIDE

Read this first. It is written so a session with no memory of the
previous one can continue without re-analysing the repository.

**Last updated:** 2026-08-01, end of the Phase 5 engineering session.

---

## 1. Where we are

**Roadmap:** `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` — 18 phases, 5 waves.
Autonomous execution: no approval between phases. Each phase ends with
one `PHASE_NN_COMPLETION_REPORT.md`. Final deliverable at the very end:
`FORMAI_MASTER_COMPLETION_REPORT.md`.

| phase | state | report |
| --- | --- | --- |
| 1 · Rate & feedback loop | done | `PHASE_01_COMPLETION_REPORT.md` |
| 2 · Dynamic walkthrough I | done | `PHASE_02_COMPLETION_REPORT.md` |
| 3 · First-workout tutorial | done | `PHASE_03_COMPLETION_REPORT.md` |
| 3b · Phase-3 leftovers | done | `PHASE_3B_COMPLETION_REPORT.md` |
| 4 · Feature flags + disclosure | done | `PHASE_04_COMPLETION_REPORT.md` |
| **5 · i18n** | **engineering complete, device sweep ~1/3** | `PHASE_05_COMPLETION_REPORT.md` |
| 6 · next | **not started** | — |

**Branch:** `main`. **Build:** `1.0.0+24`.

---

## 2. Start here

### 2.1 Finish the Phase 5 device sweep

This is the only Phase 5 work left, and it is the reason Phase 5 is not
marked closed.

Verified on the Redmi at `1.0.0+24`: dashboard, plan detail, a live
camera workout (incl. rest overlay and exit dialog), nutrition
onboarding sheet.

**Not yet walked:** nutrition tab, progress (Gelişim) tab, profile,
discovery hub `/discover`, help centre `/help`, badges, the paywall, and
a full 19-step onboarding from a clean install.

The blocker is mechanical, not technical: the **nutrition-preferences
sheet is modal** and sits over the tab bar until it is completed, so
scripted taps cannot reach the other tabs. Complete that sheet first
(4 steps), then the tabs are reachable.

Two defects were found on the device this session and are already fixed
(detector chip rendering `UNKNOWN`; nutrition goal card overlapping its
own subtitle). Expect more of that class — the ones that survive tests
are the ones only a real screen shows.

### 2.2 Then Phase 6

Read the roadmap for the definition. `docs/i18n/ADDING_A_LOCALE.md` has
the i18n-side inheritance and a recommended order of work; its headline
is that the **unit toggle should land before any translation**, because
a US user reading `178 cm` looks like a bug rather than a gap.

---

## 3. Current numbers

```
analyze                     0 issues
tests                       849
hardcoded-string gate       0 in 0 files  (allowlist 204, printed per entry)
ARB                         1390 keys · tr 100% · 1390/1390 referenced
pseudo-locale sweep         18 surfaces × 3 viewports
RTL sweep                   16 surfaces
CI                          green through part 35
build                       1.0.0+24 · APK 133.7 MB
working tree                clean except pre-existing untracked founder files
```

`macos/Flutter/GeneratedPluginRegistrant.swift` has been modified since
before this session started. It is **not ours** — leave it.

---

## 4. How to verify anything

```bash
flutter analyze                                   # must be 0 — CI fails on infos too
flutter test                                      # 849
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_hardcoded_strings.dart        # ratchet, currently 0
dart run tool/arb_coverage.dart                   # parity + plural audit
dart run tool/gen_pseudo_localizations.dart --check
```

All five are CI steps. `flutter analyze` exits 1 on **info**-level lints,
which is how CI was red for four commits before this session noticed.

---

## 5. Gotchas that cost real time

1. **CI Flutter is 3.44.8, local is 3.41.9.** Newer framework assertions
   and lints cannot fire locally. *Local green ≠ done.* Always confirm
   CI. This has bitten four times: an `ExpansionTile` in a
   `DecoratedBox`, an orphaned `_EmptyState`, an unused ML Kit import,
   and six `curly_braces_in_flow_control_structures` infos.
2. **`dart format` moves trailing comments.** `// i18n-ignore` must be on
   the literal's own line *after* formatting. If the line is too long,
   hoist the literal to a named constant, or reorder `||` operands so
   the marked literal is not last.
3. **Localising a literal invalidates every enclosing `const`**, and the
   analyzer reports the innermost position. Loop: analyze → strip →
   repeat. The scratch `fixconst.sh` automates it.
4. **Widget tests need `localizationsDelegates`.** Missing ones throw
   "Null check operator used on a null value" from `AppLocalizations.of`.
   Adding the delegates makes the harness render the *same* Turkish, so
   every original assertion must still pass. If an assertion needs
   rewording, that is a real copy change — think about it.
5. **adb.** `adb devices` empty → `kill-server` / `start-server`.
   Displayed screenshot 923×2000 vs device 1080×2340 → **×1.17** for
   taps. `keyevent 111` dismisses a bottom sheet. `input text` breaks on
   spaces. Blind-tapping through a screen silently dismisses a
   `SpotlightTour` — any tap advances it — burning the one-shot.
6. **The founder's other app** `com.ehliyetegitim.ehliyet_akademi` steals
   foreground focus: `adb shell am force-stop` it before verifying.
7. **The local build is upload-key signed.** If the installed build came
   from Play, `install -r` fails `INSTALL_FAILED_UPDATE_INCOMPATIBLE` and
   you must `adb uninstall` first — which loses the session and forces a
   19-step onboarding re-walk. +24 installed over +23 cleanly, so both
   are currently upload-signed.
8. **Never source `.env.local`.** It is freeform notes, not dotenv, and
   sourcing it *executes* `flutter build apk`.

---

## 6. Architecture decisions from Phase 5

- **One string = one ARB key = one whole sentence.** Never concatenate
  localised fragments; clause order is not universal. When part of a
  sentence needs styling or a tap target, keep the sentence whole and
  split it at render time with `core/utils/text_span_split.dart`.
- **Copy in a `const` catalogue** becomes `String Function(AppLocalizations)`
  and the collection drops `const`. Tokens stay literal.
- **Three things are not copy**, each marked `// i18n-ignore` with a
  reason: data identity (values that come from Supabase), prompt
  scaffolding (never rendered; Phase 7 does per-locale personas
  server-side), and diagnostics (the gate skips these automatically).
- **`core/utils/app_copy.dart` is the one locale source for tree-less
  surfaces** — notifications, home widget, TTS. `main.dart`'s
  `localeResolutionCallback` assigns it.
- **Pseudo-localisation lives in `test/`**, generated from the generated
  localisations class. Not a third ARB — that would put a second
  ~1300-method class in the release binary and a resolvable language
  code in `supportedLocales`.
- **Layout assertions are "no overflow", not "these pixels".** No image
  goldens; reasoning in `docs/i18n/README.md`.

---

## 7. Migrations

`001`–`011` applied to production and verified live (history, RLS on 9
tables, seeded flags matching compiled defaults, anon read 200 / write
401).

Supabase CLI notes: run it from a scratch dir holding a copy of
`supabase/`; the direct DB host is IPv6-only so use the **session
pooler**; there is no `psql` on this box — a venv with `psycopg2` is the
introspection tool.

---

## 8. Known limitations

- **The practice rep and the "Seni görüyorum" success stage have never
  been seen on a device.** Both need a person standing ~2 m back doing a
  squat. Not drivable over adb. Carried since Phase 3.
- **`RequiredView` is defined and tested but not applied per exercise** —
  needs catalogue view metadata; belongs with a content pass.
- **Units are metric-only in the UI.** `unit_system.dart` converts
  correctly and is tested (including the 12-inch carry, so it can never
  render `5'12"`), but no toggle exposes it and the physical-data wheels
  are labelled `cm`/`kg` directly.
- **English ARB values have not been reviewed by a native speaker.** They
  are a well-formed first draft with accurate descriptions, not a
  shippable locale.
- **Content is not translated.** Migration 011 added the columns;
  nothing is written to them. Phase 7.
- **`Positioned` with explicit `left:`/`right:`** remains in a few
  decorative overlays. `PositionedDirectional` when next touched.
- **Google Sign-In is broken** and is a founder-side Google Cloud SHA-1
  registration task, not an engineering one. Email and guest work.
  Details in `FORMAI_CONFIGURATION_MASTER_GUIDE.md` §2.

---

## 9. Files that matter

```
tool/check_hardcoded_strings.dart      the ratchet + allowlist (read its header)
tool/arb_coverage.dart                 parity, unused keys, plural audit
tool/gen_pseudo_localizations.dart     generates test/support/pseudo_localizations.dart
tool/hardcoded_strings_baseline.json   per-file counts; currently empty

lib/l10n/app_en.arb                    TEMPLATE — values AND @key metadata
lib/l10n/app_tr.arb                    values only (house convention)
lib/core/utils/text_span_split.dart    splitHighlighted / splitLinked
lib/core/utils/pseudo_locale.dart      pseudoLocalize
lib/core/utils/app_copy.dart           locale for tree-less surfaces
lib/core/utils/unit_system.dart        metric/imperial, storage always metric

test/support/layout_probe.dart         sweepPseudoLayouts / sweepRtlLayout
test/i18n/pseudo_locale_sweep_test.dart
test/i18n/rtl_readiness_test.dart

docs/i18n/README.md                    the runbook — read before touching a string
docs/i18n/GLOSSARY.md                  never-translate + legally load-bearing claims
docs/i18n/TEXT_IN_IMAGES.md            verdict: no image carries localisable text
docs/i18n/ADDING_A_LOCALE.md           what a second locale costs
```

---

## 10. Devices

- **Redmi `AYXSUKIVJVPZ7HPZ`** (M1908C3JGG, Android 11, 1080×2340,
  **×1.17**) — the primary. Online, `1.0.0+24` installed.
- **Huawei `89U4C18908003735`** (ANE-LX1, Android 9, 1080×2280, ×1.14,
  animation scale 0.5) — **no network**, so guest sign-in cannot
  complete and it only covers offline surfaces. It does exercise the
  onboarding chat's offline fallback, which the Redmi never reaches. Its
  nav bar eats taps below raw y≈2150.
