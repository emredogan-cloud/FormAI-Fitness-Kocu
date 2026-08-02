# Phase 8 — Market Expansion: Spanish, French, German & RTL Readiness

**Build:** `1.0.0+29` · **Branch:** `main`
**Status: IN PROGRESS.** RTL readiness (C13) is underway; the languages
are not started.

Roadmap: `TESTERS_COMMUNITY_PRODUCT_ROADMAP.md` §PHASE 8 (line 944).
Covers R3.1 (full scope) · C13 · C14.

---

## 1. Scoreboard

| roadmap item | state |
| --- | --- |
| C13 · RTL sweep past the paywall | ✅ 5 nutrition surfaces, was funnel-only |
| C13 · direction-neutrality gate in CI | ✅ ratchet armed at 177 |
| C13 · convert the 177 directional call sites | ⏳ ratchet holds the line; conversion is incremental |
| C13 · `CustomPainter` direction audit (18 painters) | ✅ 2 defects found and fixed |
| R3.1 · `es` / `fr` / `de` UI (1,534 ARB keys × 3) | ⏳ not started |
| R3.1 · `es` / `fr` / `de` recipes (392 rows × 3) | ⏳ not started |
| R3.1 · exercise catalogue (138 rows, still Turkish-only) | ⏳ not started |
| R3.1 · per-locale coach personas | ⏳ not started |
| R3.1 · market-selection method, documented | ⏳ not started |
| translation-quality monitor (>50 % length deviation) | ⏳ not started |
| C14 · per-locale store listings + ASO | ⏳ founder-side |
| regional pricing (RevenueCat) | ⏳ founder-side |

```
analyze              0 issues
tests                1070   (1064 at the start of the phase)
directional gate     177 in 43 files · baseline armed
CI                   green
locales shipped      tr, en
```

---

## 2. What is done

### 2.1 The RTL sweep stopped at the paywall

`test/i18n/rtl_readiness_test.dart` renders sixteen surfaces
right-to-left and **every one of them is part of the onboarding funnel.**
The screens a user spends the rest of their time in — including the
entire nutrition feature Phase 7 had just built — had never been rendered
in either direction by any automated pass. That is the wrong half of the
app to leave uncovered before claiming "ready to add Arabic without
structural work".

`test/i18n/rtl_app_sweep_test.dart` adds recipe detail, the discover
grid, the category list, favourites and the favourites empty state. All
five pass, which is worth stating plainly: this found no defects. The
value is the coverage, not a bug count.

### 2.2 The count the roadmap quotes is not the risk

The roadmap sizes RTL debt as "**117 `EdgeInsets.fromLTRB`**, 5
`EdgeInsets.only(left:/right:)` and 125 directional `Alignment`". Two of
those three numbers do not mean what they appear to.

`lib/` now holds **127 `EdgeInsets.fromLTRB` call sites and not one of
them is horizontally asymmetric** — every single one has `left == right`.
A symmetric `fromLTRB` is direction-neutral in effect; mirroring it
changes nothing. There is no debt there at all.

`EdgeInsets.only(left:/right:)` is down to **1**.

What is real: **121 directional `Alignment.*Left/*Right`** and **55
`Positioned(left:/right:)`**, most of them decorative overlays.

### 2.3 Two painters laid out localized copy left-to-right, always

Eighteen `CustomPainter`s. Two were wrong, and the line between those
two and the other sixteen is the useful part.

A painter has no `BuildContext`, so it cannot read the ambient direction
— it has to be handed one. Both `TextPainter`s in `lib/` were built with
a hardcoded `TextDirection.ltr`, and both lay out **ARB copy, not
tokens**: the tutorial's joint labels, which arrive as
`jointLabels(AppLocalizations.of(context))`, and the 12-week
trajectory's axis labels. In Arabic or Hebrew that resolves bidi
wrongly. Both now take `Directionality.of(context)`.

**The geometry deliberately did not move with it**, for two different
reasons that must not be conflated:

- `PosePainter._project` mirrors x on `cameraLensDirection == front`.
  That is the selfie mirror. Tying it to reading direction would draw
  the skeleton flipped against the body it is tracking and put the
  coaching on the wrong limb — a correctness bug wearing a layout bug's
  clothes.
- The trajectory curve plots twelve weeks against time. A time axis is
  not text; mirroring it would say the user gets worse.

The other sixteen are radial or particle work — rings, arcs, hexes,
sparkles, scrims — with no direction to assume. The two Google logo
painters must not mirror at all: it is a brand mark.

### 2.4 A gate the layout sweeps cannot be

`tool/check_directional_layout.dart`, wired into CI.

The distinction it exists for: **an `Alignment.centerLeft` does not
overflow.** It lays out perfectly, on the wrong side. Every RTL sweep in
this repo asserts "nothing overflowed", so none of them can see it, and
no amount of adding surfaces will change that. Only reading the source
can. The sweep and the gate are complements, not duplicates — and until
now only the half that cannot see this class of defect existed.

It **ratchets**, for the same reason `check_hardcoded_strings.dart` does:
a gate that fails on day one against 177 pre-existing call sites is a
gate somebody disables in week one. The baseline is per-file; converting
a screen lowers it and nothing raises it.

It flags seven kinds: directional `Alignment`, `TextAlign.left/right`,
`EdgeInsets.only(left:/right:)`, **asymmetric** `fromLTRB`,
`Positioned(left:/right:)`, a hardcoded `textDirection:` on a
`TextPainter` (§2.3's defect class), and nothing else. `// rtl-ignore` with a
reason is the escape, for a position that is genuinely absolute.

**Probed before it was trusted**, per the rule two phases of blind gates
earned. A synthetic file under `lib/` carrying every violation kind flags each
of them and nothing else; the correct forms (`AlignmentDirectional`,
`PositionedDirectional`, `EdgeInsetsDirectional`, symmetric `fromLTRB`,
an ambient `textDirection:`) and an `// rtl-ignore` line stay clean.
The §2.3 rule was probed the same way after the two fixes landed, and
the total staying at 177 is what proves they did. A gate
that reports zero because its regex never matches is the failure mode
this repo has hit twice.

---

## 3. What is next, in order

1. **Convert the 121 alignments and 55 positioned**, screen by screen,
   lowering the baseline as each goes. Decorative overlays may legitimately
   keep an absolute side — that is what `// rtl-ignore` is for, with the
   reason written down.
2. **The translation-quality monitor** — flag ARB values whose length
   deviates > 50 % from the template. Cheap, and it wants to exist before
   three languages of copy land, not after.
3. **`es` / `fr` / `de`.** This is the large one and it is content, not
   engineering: 1,534 ARB keys and 392 recipe rows per language, plus the
   138 Turkish-only exercise rows that no locale has yet. The rails are
   built — `kShippedLocales`, the locale-agnostic resolver, the audit
   that loops over locales — so the engineering cost is a `supportedLocales`
   entry, a persona and a scaffold entry per language.
4. **Per-locale coach personas**, authored not translated, server-side —
   the Phase 6 decision, which means a language ships without an app
   release.

### The honest sizing

The roadmap budgets **8–12 dev-days per language plus ~10 days RTL**.
Nothing in what is done so far contradicts that. A machine-authored draft
of 1,534 keys × 3 is achievable in a session; a draft a native speaker
would sign off on is not, and Phase 7's English is already carrying that
same caveat unresolved. Whoever picks this up should decide deliberately
whether three more languages of unreviewed draft is the right thing to
ship, or whether one reviewed language beats three unreviewed ones.

---

## 4. Verification

```bash
flutter analyze                                   # 0
flutter test                                      # 1070
dart run tool/check_directional_layout.dart       # 177, no regressions
dart run tool/check_directional_layout.dart --list
dart run tool/check_directional_layout.dart --baseline
flutter test test/i18n/                           # both RTL sweeps
```
