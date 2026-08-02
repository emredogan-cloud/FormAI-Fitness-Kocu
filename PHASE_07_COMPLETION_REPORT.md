# Phase 7 — Content & AI Localization

**Build:** `1.0.0+29` · **Branch:** `main`
**Status: complete, device walk included.** Migrations 013–015 are applied
to production and verified live. The catalogue is 392 recipes, 100 %
translated, and the coach can only recommend food the app actually has.

**Updated 2026-08-02:** the device walk §9 said was impossible is **done**
— the "PIN-locked" Redmi only had its screen off. It found six defects,
all fixed and re-verified on the device. §9 is now the walk's record
rather than its excuse.

Plan: `PHASE_07_NUTRITION_I18N_PLAN.md`. Every numbered section below
maps to a section of it.

---

## 1. Scoreboard

| plan § | work | state |
| --- | --- | --- |
| 4.1 | `013_recipe_tag_tokens.sql` — token / label split | ✅ applied |
| 4.2 | `014_recipe_ingredients.sql` — structured ingredients | ✅ applied |
| 4.3 | `015_recipe_origin_and_diet.sql` — cuisine / diet / scope | ✅ applied |
| 3.2 | resolution layer + one-recipe-one-language rule | ✅ |
| 7 | `tool/recipe_pipeline/` — generate → validate → cost → review → seed | ✅ |
| 5.2 | 60 western bodybuilding recipes | ✅ |
| 5.3 | 40 international athlete recipes | ✅ |
| 6.3 | `tool/recipe_translation_audit.dart` in CI, ratcheting | ✅ |
| 5.1 | 292 Turkish recipes translated | ✅ 292 / 292 |
| 6.4 | glossary food section | ✅ |
| 7.3 | image fallback so no tile is blank | ✅ |
| — | nutrition AI reads the real catalogue, per locale | ✅ deployed |
| 4.4 | `016_drop_legacy_tags.sql` | ⏳ one release later, by design |

```
analyze              0 issues
tests                1064   (940 at the start of the phase, 1051 before the walk)
hardcoded gate       0 in 0 files
ARB                  1534 keys · tr 100% · en 100%
recipe audit         0 findings · en 392/392 · baseline armed
CI                   green
build                1.0.0+29 · APK 134.5 MB
device walk          DONE — 6 defects found and fixed, see §9
```

Live, read back from production after the last write:

```
recipes                        392   (292 Turkish + 60 American + 40 other)
en coverage                    392   title_en AND instructions_en
ingredient rows                2242  all with name_en
recipes with no tag token      0
recipes with a null image      0
recipes whose macros ≠ kcal    0
recipes making no diet claim   9     (granola ×8, Thai curry paste ×1)
```

---

## 2. The part that was not translation

§2 of the plan said most of the work would not be translation, and that
turned out to be right by roughly four to one. Three things had to be
true before a single word could move.

### 2.1 A tag was a query key and display copy at once

`nutrition_repository.dart` filtered with
`tags @> ARRAY['Pratik & Ekonomik']` and painted the same Turkish string
on the chip. That string could not be translated — translating it breaks
navigation — and could not stay.

Migration 013 splits it. `tag_tokens` carries identity behind a GIN
index; `recipe_tags` registers the six tokens; the app resolves token →
copy through ARB. **The label lives in ARB rather than in the table**,
which is a deliberate departure from a literal reading of §3.1: a chip
that only renders after a network round-trip is a worse chip, the six
tokens are a closed set, and `docs/i18n/README.md` already draws the line
at data identity. The table's label columns are what the audit checks and
what the pipeline writes.

Two bugs fell out of the backfill:

- **Four recipes were unreachable.** They carried `meal_type = 'main'`,
  which is not one of the five tokens `fetchRecipesByCategory` filters
  on, so they had never appeared in any category screen since they were
  seeded. They are dinners.
- **One recipe would have had no tag at all** — its only tags were
  singletons, values used once each. The backfill derives from macros
  using the exact thresholds `recipeTags()` already applied when `tags`
  was empty, so the rule moved rather than being invented twice. That
  client-side heuristic is now deleted; it never ran in production and a
  second copy of a rule the database applies is how the two drift.

### 2.2 Ingredients were prose

`instructions` was one text column with a `MALZEMELER:` block inside it,
and three surfaces each re-parsed it with their own splitter — two of
them carrying a comment promising a refactor when a third caller
appeared.

A Dart parser reads the block into (quantity, unit, name, note) and
**reports every line it is unsure about instead of guessing**, because a
missing quantity is a gap somebody can see and a wrong one is a recipe
that lies. 292 of 292 parsed clean, 1,642 rows, zero flagged.

The parser earns its own tests because a wrong quantity is undetectable
downstream:

- `g` starts `göğsü`, so a unit must end on a word boundary — otherwise
  `180g tavuk göğsü` is 180 g of "öğsü".
- `kaşık` sits inside `çay kaşığı`, so long units match first.
- `küçük` is a size, not a measure, so units are a closed list rather
  than "the token after the number".

One recipe was a single unstructured sentence. Fixed **by hand, first**,
in its own reviewed file, keeping the author's own words: "biraz badem
sütü" got the note "biraz" rather than acquiring a millilitre count
nobody wrote. A parser bent to tolerate one malformed row will mis-read
the next.

**`instructions` keeps its `MALZEMELER:` half.** The plan says to trim it;
doing that now would leave every shipped client showing a recipe with no
ingredients, which is the same mistake as dropping `tags` in 013. It goes
in `016`, one release later.

### 2.3 The catalogue was culturally Turkish

Answered by §5 below. Migration 015 is what §5 selects on, and its
load-bearing decision is that **`locale_scope` orders and never
filters**. `where(scope contains language)` is one line shorter than a
sort and reads as obviously correct; it halves the catalogue for
everyone, and somebody who has heard of a dish and cannot find it
concludes the app does not have it. Three ranks, not two: a recipe scoped
to another language still appears, last.

---

## 3. One recipe, one language

The rule §3.2 singles out as most likely to be broken later, so it is
stated plainly in `domain/recipe_localization.dart` and has the most
tests in the phase.

`resolveRecipeLanguage` decides **once per row**, not per field. A recipe
with `title_en` and no `instructions_en` renders entirely in Turkish,
because an English title over Turkish steps reads as a bug rather than as
untranslated content — and that is exactly the state a half-finished
translation pass leaves rows in.

Ingredient names are part of that decision. A recipe whose title and
steps are English but whose shopping list is Turkish is the same defect
one layer down.

The fallback is **Turkish, never English**: `title` is `not null` on
every row and `title_en` is a translation that may not exist. A resolver
falling back to a possibly-null column produces blank cards, which looks
like a broken app rather than incomplete content.

---

## 4. The pipeline, and what it rejected

`generate → validate → cost → review → seed`, as `tool/recipe_pipeline/`.

**Nothing in it writes to the database.** Every path ends in a `.sql`
file and a markdown sheet a person reads, which is what makes an
unreviewed batch impossible rather than merely discouraged. **A rejected
proposal is deleted, not repaired** — there is no `--fix` and there will
not be one, because repairing means another pass over output already
known to be wrong and it produces plausible garbage that reads better
than the failure did.

`generate` is deliberately outside the tool, as `--proposals`. A model
writing that JSON and a person writing it by hand are the same input, so
the validator cannot be bypassed by whichever is convenient today. **The
100 recipes this phase ships went through the identical gate a future
batch will.**

`cost` is **not** the model review §7.1 describes, and does not claim to
be. It measures what can be measured — ingredients outside a normal
pantry, prep time, step count — and prints it. A claim that a model
reviewed something it did not is worse than no claim.

### What the gate caught

Seven rejections across the two batches, every one correct:

| what | why it mattered |
| --- | --- |
| `casein protein powder` read as dairy, `kazein protein tozu` did not | a casein pudding would have been labelled `dairy_free` |
| `corn tortillas` gluten-free in English, gluten in Turkish | the two languages disagreed about the same food |
| `tuna steak` read as fish AND meat | `steak` is a meat word |
| miso tofu soup at 235 kcal, under the lunch band | the macros were wrong, not the band — 200 g of firm tofu is not 235 kcal |
| a Greek dessert 100 % identical to `Tarçınlı Süzme Yoğurt` | a real duplicate; replaced rather than nudged past the check |
| `balzamik sirke` read as honey | `bal` starts `balzamik` — the fourth collision that three-letter word caused |
| a duplicate salmon-and-sweet-potato title | already in the catalogue |

Three of those came from one check: **classify each ingredient's English
and Turkish name independently and require them to agree.** It is the
only thing in the phase that can catch a mistranslated ingredient, and it
caught three.

### And what it caught in content that was already there

Running the pipeline's macro check over the 292 pre-existing recipes
found **six whose stated calories are 11–16 % away from their own
macros.** `Tencerede Tavuk Sote` claimed 515 kcal for a plate its macros
put at 435. Corrected toward the macros — the more specific claim, and
the rule the pipeline already enforces on new content. Two standards in
one catalogue is worse than either.

---

## 5. The content

**60 western** (`cuisine = 'american'`, `locale_scope = {'en'}`):
overnight oats, chicken and rice bowls, Greek yoghurt bowls, protein
pancakes, egg-white scrambles, beef and sweet potato, casein pudding,
tuna wraps. 14 breakfasts, 13 lunches, 13 dinners, 12 snacks, 8 desserts.

**40 international** (`locale_scope = {}`): Japanese donburi, Mexican
tinga, Indian dal and paneer, Greek and Levantine mezze, Korean tofu
stew, Thai basil chicken. Empty scope on purpose — these are what make
the catalogue feel worldly to *every* user, including the Turkish one.

All 100 authored in both languages. A recipe that exists in one language
is a row that renders as a gap for half the users.

**Images.** 100 new recipes, no photography, and `image_url` non-null on
all 292 existing rows — an empty tile would have been the most visible
regression of the phase. `RecipeImageRegistry` resolves the way
`WorkoutBackgroundRegistry` does: bundled asset from the **manifest**,
else the meal type's cover, which is real food photography that already
ships. Dropping a file into `photos/meals/` is the entire procedure.
Prompts are in `docs/nutrition/MEAL_IMAGE_REQUESTS*.md`.

---

## 6. Translation

292 Turkish recipes, 298 distinct ingredient names, 49 prep-state notes.

**No quantity and no unit ever passed through a translation.** The
`INGREDIENTS:` half of every English instruction block is *assembled*
from `recipe_ingredients` — that is what migration 014 was for, and it
makes §6.2's first rule a property of the pipeline rather than a rule
somebody has to remember. Only the method steps were written by hand.

Cooking verbs are where machine translation is worst and the file says so
where a future editor will read it: `kavurmak` is to fry off until
coloured, not to burn; `dinlendirmek` is to rest, but dough relaxes and
meat settles; and in `tereyağını pul biberle yakın`, `yakmak` is to bloom
chilli in hot butter.

**A dish keeps its name.** menemen, çılbır, karnıyarık, mıhlama, kuymak,
erişte, mantı, aşure, ezogelin, imam bayıldı, sucuk, pastırma, tarhana.
The substitution lives in the ingredient note, where it can be specific —
"Turkish beef sausage; chorizo or any cured spiced sausage works" instead
of flattening sucuk into "sausage". `docs/i18n/GLOSSARY.md` now carries
that list and the audit **enforces** it: a Turkish-spelled word not on it
fails the build.

### The audit found four bugs in itself

Proving the batch is what exposed them:

1. Dart's `caseSensitive: false` does not fold `Ç→ç`, so every
   title-cased proper noun survived the scrub and reported as
   untranslated.
2. The obvious fix — the diet classifier's Turkish fold — maps `I→ı`,
   which turned `INGREDIENTS` into `ıngredıents` and reported all 199
   translated recipes as untranslated. **The check meant to prove they
   were translated said the opposite.**
3. Terms were scrubbed in list order, so `köfte` was removed before
   `çiğ köfte` could match, leaving a bare `çiğ`.
4. Four dish names were simply missing from the list.

---

## 7. Verification, and what a live read found

There is no device walk in this phase. §9 explains why.

What there is instead:
`test/features/nutrition/live_catalogue_read_path_test.dart` — six
assertions that fetch through the **same public endpoint the app uses**,
decode with the **same `Recipe.fromJson`**, and check what a reader would
see. Tagged `live` so it stays out of CI, which has no `.env` and should
not have a network-dependent suite.

It found a real defect on its first run. Every ingredient **name** had
been translated; the parenthetical the parser lifted off each line had
not, because notes are per-line and the glossary is keyed by ingredient.
An English reader was seeing `1 tomato (doğranmış)` and `15 g walnuts
(kırılmış)` — 49 distinct values across 335 rows. Fixed.

That is the same class of finding the Phase 6 device walk produced: not a
crash, not a missing key, not an overflow, just the wrong words on the
screen. It is why the check exists.

---

## 8. Decisions worth carrying forward

- **A tag label belongs in ARB; a tag token belongs in the database.**
  Identity and copy are different things and the moment one column tries
  to be both, the catalogue cannot be translated.
- **`locale_scope` orders, never filters.** Written into the migration
  comment, the resolver's doc and a test, because the filtering version
  is shorter and looks right.
- **`halal` is never derived.** It depends on how an animal was
  slaughtered, which no ingredient name records. Deriving it from "no
  pork" is the conflation that makes an app untrustworthy in a market.
  `pork_free` **is** derived, and the audit behind it is written down:
  all 297 ingredient names classified, sucuk and pastırma are beef, the
  only cured slice is turkey salami.
- **An unrecognised ingredient silences the whole recipe.** A missing
  `vegan` flag costs one recipe one filter; a wrong one serves a vegan a
  bowl of yoghurt. Nine recipes make no claim today — granola and Thai
  curry paste, both genuinely two different foods sold under one name.
- **Two copies of a mapping are acceptable only when something proves
  they agree.** The unit glossary exists in Dart and in Python because
  one is a Flutter app and the other is a build script;
  `test/tool/unit_glossary_parity_test.dart` is what makes that
  survivable.
- **The cross-check between independent sources is where the defects
  are.** The dietitian's hand tags versus the derived flags found a
  recipe tagged Vegan containing 10 g of honey, shipping since Phase 24.
  The English name versus the Turkish name found three mistranslations.
  The pipeline's macro rule versus the old catalogue found six recipes
  lying about their calories. None of those is visible from inside one
  source.

---

## 9. The device walk — done, 2026-08-02

**The Redmi was never PIN-locked.** It reported `isKeyguardShowing=true`
because its **screen was off**. `input keyevent KEYCODE_WAKEUP` followed
by `wm dismiss-keyguard` unlocks it — the keyguard is non-secure, and
`locksettings get-disabled` returning `false` with a null
`lockscreen.password_type` says so. Two phases of "physically
unverifiable" were a wrong reading of one dumpsys line. It is a working
validation device and §10 of `RESUME_GUIDE.md` has been corrected.

All six surfaces walked, in **both languages**, **both themes**, on
`1.0.0+29`. The walk found **six defects**, all fixed, rebuilt,
reinstalled and re-verified on the device.

| § 9 item | verdict |
| --- | --- |
| 1 · discovery chips in English | ✅ five chips — but see D2 |
| 2 · recipe detail in English | ✅ after D5 |
| 3 · daily menu, English catalogue | ✅ four distinct slots, both languages |
| 4 · tile with no photograph | ✅ meal-type cover, never a gradient |
| 5 · shopping-list export + share sheet | ✅ |
| 6 · coach naming a real recipe | ✅ same four recipes, each language |

### What it found

**D1 · `92%` in the Turkish app.** `feature_showcase_screen.dart` painted
the literal `'92%'` on the form-score chip, marked `i18n-ignore` as an
"illustrative figure". The figure is illustrative; **where the percent
sign sits is orthography**. Turkish writes `%92`, and `%100 Gizli` two
rows below it on the same screen got that right. Now
`showcaseHeroFormScoreValue`, following the `act5StatOnDevice` precedent.

**D2 · a discovery chip answered "how far have you scrolled?"** The chips
filtered the *resident* pages of the paginated catalogue client-side. Tap
"Yüksek Protein" on open — the first chip, above the fold, the natural
first action — and it reported **12 recipes. The catalogue has 175.**
Scrolling did not fix it: a 12-card grid never reaches the bottom that
triggers the next page, so the wrong number stayed wrong for as long as
the user looked at it. Measured on the live catalogue:

```
                  on open   true
high_protein         12      175
low_calorie           3       81
bulking               6       62
toning                3       54
vegan                 1       12
```

`fetchRecipesByCategory`'s own doc comment describes this exact bug —
Phase 83 fixed it for the category screen and nobody carried the fix
across. Phase 7 then added a fifth chip and grew the catalogue from ~35
rows to 392, which is what turned a latent bug into "this app has one
vegan recipe". Now `fetchRecipesByTagToken` — the same
`tag_tokens @> ARRAY[token]` predicate on the same GIN index migration
013 added.

**D3 · the meal-type pill painted a database token at the user.** A
Turkish reader saw **`SNACK`** sitting above a fully translated title, tag
strip and ingredient list. The labels already existed for the daily-plan
timeline; `dessert` was missing because the timeline has four slots and
the catalogue has five meal types. The screen's own test asserted
`find.text('LUNCH')` inside a `Locale('tr')` host — **the test was
pinning the defect in place.**

**D4 · the language picker did not apply to content.** Phase 6's
load-bearing decision is that the picker applies live. It applied to
chrome only: switching to English left every recipe title, ingredient and
instruction in Turkish until the app was restarted, because the
repository resolves language at decode time and nothing invalidated the
rows already fetched. The next-best-meal card read **"Tavuklu Souvlaki
Kasesi" under the English sentence "You're falling short on protein."**
That is the half-translated state `resolveRecipeLanguage` refuses to
produce one row at a time, reproduced across the whole catalogue.
`nutritionRepositoryProvider` now watches `localeProvider`.

**D5 · English recipes printed their ingredients twice.** `_split` knew
`MALZEMELER:` / `HAZIRLANIŞI:` / `YAPILIŞ:`. `build_recipe_en.py` writes
`INGREDIENTS:` / `METHOD:`. An English blob therefore matched no header,
fell through to the unstructured branch and printed the raw blob whole —
the ingredient list from the structured rows, then the identical list
again underneath. This is §9 item 2, and it was failing. The same
Turkish-only gap existed in `recipe_ingredient_lines.dart`, the
documented fallback for an un-migrated client; fixed there too, though no
live row reaches it.

**D6 · the tag badges were white on white in light mode.** Every badge
and the meal-type pill drew `Colors.white` on `tint` at 18 % alpha. Over
the dark scaffold that fill is dark and white is right; over the light one
it is a pastel. Measured on the device: **1.32:1, 1.24:1, 1.32:1** — the
labels were ghosts. This is the "PREMIUM white on white" defect the Phase
6 walk found, recurring on the surfaces Phase 7 added. Light mode now
keeps each tag's hue at lightness 0.22, the highest value at which all six
tints clear 4.5:1 against their own fill; re-measured on the device at
**9.43:1 to 12.20:1**, with dark mode unchanged at 13–16:1.

The one exception is explicit: the nutrition tab `Positioned`s its badge
**over the photograph**, and a photograph does not change with the app's
theme, so that call site passes `onImagery: true` and stays white. Getting
that wrong would have been reasoning about the wrong backdrop.

### Carried, not fixed

**The "See all" pill measures 3.03:1 in light mode** — pale purple on
pale lavender. It is legible but below AA for its size, it predates Phase
7, and contrast is Phase 11's explicit remit. Spot-fixing one colour
outside a systematic pass invites an inconsistent palette. Logged for
Phase 11.

**A locally-built debug APK renders the bottom-nav labels as an oversized
clipped "For…".** Seen only on `--debug`, which is not a shipping
artifact; the release build renders `Antrenman / Beslenme / Gelişim /
Profil` and `Training / Nutrition / Progress / Profile` correctly, checked
in both languages and both themes. No Flutter exception in logcat. Not
diagnosed further — the debug build existed only to reach the
premium-gated daily menu, via the `kDebugMode` dev-pro override.

### What the walk cost, and what that says

Six defects on surfaces that 1,051 tests, six CI gates and a live
read-path test were all green across. Four of them — D2, D3, D5, D6 —
are **the same defect class the codebase had already solved somewhere
else**: a page-1-blind filter, a token painted as copy, a Turkish-only
parse marker, a white label on a pale fill. Each fix existed; none had
been carried to the surface Phase 7 changed. The device is where that
shows up, because a test written from the same assumption as the code
agrees with it.

**`016_drop_legacy_tags.sql` is not written.** It drops `recipes.tags`
and trims the `MALZEMELER:` half out of `instructions`. Both are safe
only after a release carrying the 013/014 readers has been live long
enough that the old client is gone. Writing it now would invite somebody
to apply it now.

**The English has not been read by a native speaker.** 392 recipes of
reviewed, internally consistent draft. The gate proves no Turkish
survives; it cannot prove the English is idiomatic.

**es / fr / de.** The columns exist, the resolver is locale-agnostic and
the audit loops over `kShippedLocales`. Adding a language is a content
cost now, not an engineering one.

---

## 10. Verification commands

```bash
flutter analyze                                       # 0
flutter test                                          # 1051
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_hardcoded_strings.dart            # 0 in 0 files
dart run tool/arb_coverage.dart --strict              # 1532 keys
dart run tool/gen_pseudo_localizations.dart --check
dart run tool/recipe_translation_audit.dart           # 0 findings, en 392/392
flutter test --tags live \
  test/features/nutrition/live_catalogue_read_path_test.dart
flutter build apk --release                           # 134.5 MB
```

Re-running the content tooling (all idempotent, all write files a human
reads before anything is applied):

```bash
dart run tool/recipe_pipeline/parse_catalogue.dart --input <dump> --sql … --review …
dart run tool/recipe_pipeline/classify_catalogue.dart --input <dump> --sql … --review …
dart run tool/recipe_pipeline/pipeline.dart --proposals … --catalogue … --dry-run
python3 tool/recipe_pipeline/proposals/western.py
python3 tool/recipe_pipeline/translations/ingredients_en.py
python3 tool/recipe_pipeline/translations/build_recipe_en.py --catalogue <dump>
```
