# Phase 7 — Content & AI Localization

**Build:** `1.0.0+29` · **Branch:** `main`
**Status: complete.** Migrations 013–015 are applied to production and
verified live. The catalogue is 392 recipes, 100 % translated, and the
coach can only recommend food the app actually has.

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
tests                1051   (940 at the start of the phase)
hardcoded gate       0 in 0 files
ARB                  1532 keys · tr 100% · en 100%
recipe audit         0 findings · en 392/392 · baseline armed
CI                   green
build                1.0.0+29 · APK 134.5 MB
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

## 9. What is not done, and why

**No device walk.** The Redmi Note 12 — the primary validation device —
is not connected. The device that *is* connected (`AYXSUKIVJVPZ7HPZ`, the
Android 11 Redmi) reports `isKeyguardShowing=true` and is PIN-locked, as
it has been since Phase 5. adb can install to it and cannot drive it.
This is a physical limitation, not a skipped step, and the live read-path
test above is the substitute — it covers the data half of what a walk
would find and none of the layout half.

**What a walk still needs to check** (the surfaces this phase changed):

1. The nutrition tab's discovery chips in English — five chips, longer
   labels than the Turkish they replaced.
2. A recipe detail screen in English — the new ingredients section, and
   that the instructions block no longer repeats it.
3. The daily menu with an English catalogue — five distinct meals a day
   for fourteen days with no repeat is §9's actual user-facing test.
4. A recipe tile whose photograph does not exist yet, confirming it shows
   its meal-type cover rather than a gradient.
5. The favourites shopping-list export and the share sheet, in English.
6. The coach answering "what should I eat for breakfast" and naming a
   recipe that exists.

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
