# Phase 6 — Polish Sprint

**Build:** `1.0.0+28` · **Branch:** `main` · **Tip:** `8e44e1a`
**Status: complete.** All twelve founder items are done. One founder-side
action is outstanding and is described in §6.

---

## 1. Scoreboard

| # | Item | State |
| --- | --- | --- |
| 1 | Paid tier renamed to **FormAI Premium** everywhere | ✅ |
| 2 | Migration `012_user_locale.sql` applied to production | ✅ verified live |
| 3 | Metric / Imperial exposed in Settings | ✅ |
| 4 | Language picker rebuilt to the reference | ✅ verified on device |
| 5 | AI coach mixed-language bug | ✅ verified against the live function |
| 6 | Spotlight tour → welcome popup ordering | ✅ verified on device |
| 7 | Paywall regional pricing | ✅ client done · store config is §6 |
| 8 | Four feature showcase screens | ✅ verified on device |
| 9 | Camera-free workout + rest redesign | ✅ verified on device |
| 10 | Workout background system + request doc | ✅ |
| 11 | Phase 7 nutrition localization plan | ✅ written, not implemented |
| 12 | Full two-language device validation | ✅ 8 defects found and fixed |

```
analyze  0 · tests 940 · gate 0 in 0 files · format clean
ARB      1527 keys · tr 100% · en 100% · all referenced
CI       green on 8e44e1a
build    1.0.0+28 · APK 134.5 MB · AAB 114.6 MB
```

Items 1–6 were delivered in the first half of this sprint and are
unchanged. What follows covers 7–12.

---

## 2. Paywall pricing (#7)

### The bug that was actually there

`_scalePriceString` hardcoded Turkish separators, so the struck-through
monthly-equivalent on the annual card rendered `$119,88` beside a real
`$9.99`. Same screen, two number systems, and the wrong one was the one
framing the discount.

Separators are now read off the store's own string, so whatever
conventions the store used for the real price are the conventions the
derived one inherits — correct in every market by construction.
`lib/core/utils/price_format.dart`, 13 unit tests covering tr-TR, en-US,
de-DE suffix currencies, fr-FR non-breaking-space grouping, zero-decimal
yen and rupiah, and multi-character prefixes.

The rule the null return already followed now holds throughout: state
nothing we cannot read off the store. `¥500` carries no grouping signal
at all, so nothing is grouped rather than a `,` being guessed into a
market that writes `.`.

### The weekly tier

The founder's lineup is weekly / monthly / yearly; the store sells
monthly / quarterly / yearly. The third plan card now resolves against
the live offering — quarterly today, weekly the moment `$rc_weekly`
appears in the current offering. **Publishing the SKU changes the paywall
with no app release**, and pulling it changes it back. Neither direction
can strand a user on a card whose SKU does not exist.

Weekly carries no savings framing, deliberately: it costs more per month
than monthly does, so "save N%" there would be false in the one direction
store policy actually polices.

### What was found in the numbers

**The target USD ladder is inverted.** At $2/week the weekly plan is
$8.67 a month against a $10 monthly plan, and $104 a year against $120 —
so no US user would ever buy monthly. TRY is fine (₺433 > ₺400 > ₺100).
Recommendation and alternatives are in `docs/store/PRICING_SETUP.md` §2;
$3.99 weekly restores the ordering.

That document is the founder-side half: it leads with the fact that
explains most "wrong price" reports — **Play bills in the Play account's
country, not the app's language**, so a Turkish account showing ₺ inside
an English app is correct — then gives the exact Play Console and
RevenueCat steps, the price-increase rules that apply to repricing ₺149 →
₺400, and a six-step verification.

---

## 3. The four showcase screens (#8)

Rebuilt from the references. Each card is now a framed hero carrying
live-looking stat panels, a headline whose closing phrase runs the brand
gradient, an assurance card, and a row of capability tiles. The copy
already matched — the references were designed from the ARB.

**Three decisions worth knowing about.**

**The asset that was lying.** `showcase_ai_coach.webp` shipped six
English UI labels baked into the photograph — `JOINT TRACKING`,
`12/12 ACTIVE`, `POWER OUTPUT`, `842 W`, `RANGE OF MOTION`, `FULL` — and
`docs/i18n/TEXT_IN_IMAGES.md` recorded the file as carrying no text. The
audit had read the filename, not the pixels. A Turkish user read them in
English in their first minute in the app. The asset is re-cropped from
the founder's own artwork with the panels gone, they are Flutter widgets
now, and a test asserts they render in Turkish. Same reasoning for the
30-day emblem, which is **painted** rather than bundled because the
supplied ring says `30 DAYS` and the headline beside it says `30 gün`.

**The hero overlay is a canvas, not device space.** Everything drawn onto
a photograph lays out in a fixed 4:3 canvas that is then scaled to the
hero. The panels are a picture of the product's UI, so they shrink with
the picture instead of reflowing inside it, and no translation length can
push one out of the frame — the frame it must fit is the canvas, not the
phone. Device-space positioning overflowed by 87 px at 320×640 under
pseudo-localisation. The canvas also opts out of the text scaler:
enlarging a screenshot's own labels is not what a reader who scaled their
text up asked for, and growing type inside a fixed canvas was the
remaining overflow.

**The gradient is on one span.** A `ShaderMask` is the obvious reach for
gradient text and paints every glyph in the paragraph, which would have
lost the emphasis the design is built on. It is a `foreground` shader on
the accent span, through a shader spanning the paragraph's width — so the
accent picks up the slice of purple-to-lime sitting under where those
words actually land, and no second colour has to be authored per
language. The accent is its own ARB key and `splitHighlighted` fails soft
when a translation drops it, which is right at runtime and silent in
review, so a test asserts every headline contains its accent in every
locale.

The four `*Proof` keys are retired; the assurance card replaced them.

---

## 4. Camera-free workout, rest, and backgrounds (#9, #10)

The workout screen was a centred column on a flat background using about
half the display. It is now the reference design: a full-bleed photograph
of the movement carrying the set pill, the exercise name and the rep
counter, with the mode banner above and the set track and button below.
Rest is the countdown dial, the encouragement card and the two stat tiles.

### The background resolves itself

`WorkoutBackgroundRegistry` answers "which photograph" in three steps:
the exercise's own background if one is bundled, else its category's art,
else nothing. **Step one is a lookup against the app's own asset
manifest, not a list in the file** — so dropping
`photos/workout_backgrounds/WeightedSitUp.webp` in and building is the
entire procedure. A test fails if that contract breaks, and another fails
if `pubspec.yaml` stops declaring the directory, because a file that
never reaches the APK cannot be found by any lookup.

Step two is why nothing looks unfinished: **all 138 exercises render real
photography today**, reusing the cinematic set already shipping on the
Antrenman dashboard. 51 have no art of their own;
`WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` lists every one with a filename
and a prompt, generated from the live Supabase catalogue so it cannot
drift from what the app asks for.

`photos/exercises/` was the obvious place to reuse and is the wrong one:
those 87 files are instructional before/after panels, bright, with
captions burned into the pixels — some English, some Turkish, so each
language sees the other's on some exercises. Not fixable by translating a
string and not an engineering fix. Recorded in the request doc §5 and in
`TEXT_IN_IMAGES.md`.

### Elastic, not breakpointed

The rep cluster is 280 px wide at its design size and a 320 px phone's
card is 260. At a 1.3 text scale the chrome alone is 41 px taller than
that phone's screen. Rather than pick breakpoints: each band inside the
card takes a share of the height and scales down inside it, the count
scales inside its ring so the ring stays a ring, and the column scrolls
when the chrome genuinely does not fit.

`Expanded` was the obvious shape for the card and is wrong at the edges —
it can only shrink to zero, so it squeezes the counter into illegibility
and then overflows anyway.

---

## 5. Device validation (#12) — what a walk finds that a suite cannot

A full pass on the **Redmi Note 12** (Android 13, 1080×2408), English
then Turkish, dark then light: language step, coach intro, name capture,
the eleven-question wizard, the AI report, the commitment and social
proof screens, the auth gate, all four showcase cards, the dashboard, the
spotlight tour, the welcome scene, plan detail, camera setup, the
camera-free workout, rest, profile, and settings.

**Eight defects.** None of them was an overflow, a missing key or a
hardcoded literal, which is why 934 tests and five gates were green
across every one.

### The gate said zero and the screen said `%82`

The hook screen rendered `%82` — Turkish symbol placement — inside the
English app, from a literal `Text('%82')`. There is a rule in
`check_hardcoded_strings.dart` written specifically to catch this (blind
spot #6, added in Phase 6 after the progress tab shipped `%0` to English
users). It did not fire, for two independent reasons:

1. It only recognised a `%` next to an **interpolation**. `%82` has a
   value for the symbol to sit before; the value is just written out. A
   hardcoded number is exactly as locale-ordered as an interpolated one,
   and more likely to be wrong, because nothing about it looks like copy.
2. Even after widening that, the literal never reached the rule.
   `_isTechnical` runs first and its "pure punctuation / numbers" pattern
   matches `%82` whole, so it was discarded as technical before anything
   asked whether it was ordered.

Both are closed. **A synthetic probe under `lib/` is what established
both** — the first widening looked correct and the gate still reported
zero; only the probe showed the literal was being dropped upstream. That
is the second time this lesson has been paid for: a green gate is a claim
about its own heuristics, and the only way to test the claim is to feed
it something it must catch.

### The other seven

| What | Where | Why the suite missed it |
| --- | --- | --- |
| A rest day's subtitle read **"Req."** (EN) / **"İst."** (TR) — `planRequestedAbbrev`, an abbreviation of "requested" meant for a cramped exercise row | plan detail | Correct key, correct render, wrong meaning. Wrong in Turkish just as long; the English made it obvious |
| **"PREMIUM" white on white** in light mode, ~1.3:1 | dashboard header | The fill is a translucent neon gradient that resolves near-white on a light scaffold; the label was hardcoded `Colors.white` |
| A **privacy claim cut mid-sentence** — "…the analysis runs entirely" and nothing | social proof | English needs 4 lines in a card sized for 3, and `TextOverflow.fade` hid the cut so it read as a shorter sentence that was false |
| **"LIVE FORM ANALYSIS"** → "LIVE FORM ANALY…" | social proof | Badge sized for Turkish |
| **"DAILY CALORIES"** → "DAILY CAL…" | AI report | Same |
| Two loader phrases **cross-faded on top of each other** — "AssEstimating body-fat ratiotial…", four times per run | AI analysis loader | `AnimatedSwitcher` stacks outgoing and incoming at the same position; a plain fade paints both |
| The workout card's **bottom third was a black box** | camera-free workout | Scrim bottom stop at 94% opaque; the card stopped reading as a photograph, which is the point of the redesign |

All fixed, all pushed, CI green.

### What the walk confirmed working

The coach speaks English end to end including the name greeting and the
empathy turn; the tour runs before the welcome scene; the language switch
applies live with the screen behind the sheet flipping instantly; light
mode is legible across settings and the dashboard; Metric/Imperial and
the Premium rename are live; the camera setup screen localises distance
to feet for English; and all four showcase cards plus both workout
screens render on device as designed, with the emblems keying correctly
and the painted 30-day ring intact.

### Two things it could not confirm

**The last build is not on the device.** After the eight fixes were
committed the Note 12 began refusing installs with
`INSTALL_FAILED_USER_RESTRICTED` — MIUI's "Install via USB" authorization
had lapsed mid-session. `adb install`, `-d`, `-t`, and push-then-`pm
install` all fail identically, and the toggle needs a Mi-account
re-authorization on the handset. So the fixes in §5 are verified by
analyze, 940 tests, five gates and CI, but the *last* build was walked
only up to the point the defects were found. See §6.

**The paywall interior and a clean-install onboarding** remain unwalked,
both carried from Phase 5. The paywall needs a signed-in session; a clean
install destroys the session everything else depends on.

---

## 6. Founder actions

1. **Re-enable "Install via USB"** on the Redmi Note 12 (Developer
   options; needs a Mi account and network). Then
   `adb install -r build/app/outputs/flutter-apk/app-release.apk` and
   re-walk the six surfaces in §5's table. Nothing blocks on this — the
   fixes are green in CI — but it is the honest way to close #12.
2. **Decide the USD weekly price** (§2). Everything else in
   `docs/store/PRICING_SETUP.md` can proceed without it; the weekly SKU
   cannot.
3. **Play Console + RevenueCat**, per `docs/store/PRICING_SETUP.md` §3
   and §4: reprice the three products with explicit US prices seeded from
   USD rather than auto-converted from ₺, create `formai_pro_weekly`, and
   attach the `FormAI Pro` entitlement to it.
4. **Generate workout backgrounds** at your own pace from
   `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`. Nothing is broken while it is
   empty.
5. **Read the Phase 7 plan** (`PHASE_07_NUTRITION_I18N_PLAN.md`) and
   approve or redirect. Phase 7 is deliberately not started.

---

## 7. Verification

```
flutter analyze                                      0 issues
flutter test                                         940
dart format --output=none --set-exit-if-changed      clean
dart run tool/check_hardcoded_strings.dart           0 in 0 files
dart run tool/arb_coverage.dart --strict             1527 keys · tr 100% · en 100%
dart run tool/gen_pseudo_localizations.dart --check  up to date
gh run list                                          success @ 8e44e1a
flutter build apk --release                          134.5 MB
flutter build appbundle --release                    114.6 MB
```

Device: Redmi Note 12, Android 13, 1080×2408, font scale 1.0, both
languages, both themes.
