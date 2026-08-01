# Phase 7 — Nutrition internationalization

**Plan only. Nothing here is implemented.** Written 2026-08-01 against
build `1.0.0+28`, measured against the live catalogue rather than
remembered.

Phase 6 shipped an English app with a Turkish pantry. This is how that
gets fixed, in the order it has to happen.

---

## 1. What is actually there

Queried live, not assumed:

```
recipes                 292 rows, every one Turkish
meal_type               breakfast 61 · lunch 62 · dinner 59 · snack 55
                        dessert 51 · main 4        ← 'main' is a typo class
tags                    12 distinct, 6 real:
                        Pratik & Ekonomik 156 · Yüksek Protein 93
                        Düşük Kalori 50 · Hacim 35 · Sıkılaşma 27 · Vegan 13
                        (+6 singletons: Omega 3, Sağlıklı Yağ, Fitness,
                         Dengeli, Kahvaltı, Düşük Karbonhidrat)
image_url               292 / 292 present
instructions            avg 334 chars, 291 / 292 contain "MALZEMELER:"
ingredients (column)    exists, NULL on every row
locale columns          title_{en,es,fr,de}, instructions_{en,es,fr,de}
                        added by migration 011, NULL on every row
coverage view           public.content_translation_coverage, reports 0 %
```

Migration 011 already did the boring half of this: the columns exist, the
reads fall back to the Turkish column, and the coverage view answers
"what is left" without anyone writing the query again. Phase 7 is
allowed to assume all of that.

## 2. Three things must be fixed before a single word is translated

Translating first and fixing these afterwards means translating twice.

### 2.1 A tag is a query key *and* display copy at the same time

`nutrition_repository.dart` filters with
`.contains('tags', ['Pratik & Ekonomik'])`, which Postgres executes as
`tags @> ARRAY['Pratik & Ekonomik']`. The same Turkish string is rendered
on the category chip.

So the tag cannot be translated — translating it breaks the filter — and
cannot stay as-is — leaving it shows Turkish inside an English app. It
has to be **split into a stable token and a localised label**, and that
is a migration plus a repository change plus a UI change, not a
translation task.

This is the single largest piece of Phase 7 nutrition work and it is
invisible from the outside, so it is worth saying plainly: **most of the
effort is not translation.**

The 6 singleton tags are data-entry noise. Fold them into the 6 real
categories or drop them; do not build a token for a tag one recipe uses.

### 2.2 Ingredients are inside the instructions blob

`instructions` is one text field shaped:

```
MALZEMELER:
- 3 yumurta
- 50g sucuk dilimleri
...

HAZIRLANIŞI:
1. Sucuk dilimlerini orta ateşte tavada 1 dakika kavurun.
...
```

291 of 292 follow it. The `ingredients` column exists and is null.

Translating the blob whole is possible and wrong. An ingredient list is
**structured data pretending to be prose**: quantities and units must
survive translation byte-exact, "50g sucuk" needs a substitution note in
markets that do not sell sucuk, and a shopping-list feature (which this
app will want) cannot parse a paragraph. Split it now, while the split is
mechanical and one-time.

The 292nd row is the one that does not follow the shape. Find it and fix
it by hand before writing a parser that has to tolerate it.

### 2.3 The catalogue is culturally Turkish, not merely Turkish-language

Sucuk, menemen, mercimek çorbası. A perfect English translation of
`Yumurtalı Sucuklu Tava` is a recipe an American user cannot shop for.

Translation and localisation are different projects and Phase 7 needs
both. §5 is the content half.

---

## 3. Architecture

### 3.1 The shape

Keep `<column>_<lang>` on `recipes`. Migration 011 argued this and the
argument still holds: the catalogue is read on every nutrition screen,
the language count stays small, and a nullable column per language keeps
those reads single-table. Revisit past ~10 languages.

**Do not** put translations in a join table for the *recipe body*.
**Do** put them in a lookup table for *tags*, because tags are a closed
set of ~6 and are queried, not displayed-and-forgotten.

### 3.2 Resolution: one place, falling back once

```
recipeTitle(recipe, locale) =
    recipe.title_<locale>        if not null
    else recipe.title            (Turkish — the authored original)
```

Three properties this has to keep:

- **The fallback is Turkish, not English.** Turkish is the authored
  column and always populated; `title_en` is a translation that may not
  exist yet. Falling back to a possibly-null column produces blank cards.
- **It resolves in one place**, mirroring `core/utils/unit_system.dart`:
  a pure function with the locale passed in, not read from a
  `BuildContext` scattered through the repository.
- **Partial rows are normal.** A recipe with `title_en` but no
  `instructions_en` renders an English title over Turkish steps, which is
  worse than fully Turkish. So resolution is **per recipe, not per
  field**: if any required field is missing for the locale, the whole
  recipe renders in the fallback language. One recipe, one language.

That last rule is the one a later change is most likely to break, and it
deserves a test.

### 3.3 What is *not* translated

- `meal_type` — already an English token (`breakfast`), an enum, correct.
- Numbers: calories, macros, prep time.
- `image_url`.
- Ingredient quantities and units — see §4.2.

---

## 4. Schema and migrations

Four migrations, each independently shippable and each a no-op for
existing clients until the one after it lands.

### 4.1 `013_recipe_tag_tokens.sql`

```sql
create table public.recipe_tags (
  token        text primary key,          -- 'high_protein'
  sort_order   int  not null default 100,
  label_tr     text not null,
  label_en     text,
  label_es     text,
  label_fr     text,
  label_de     text
);

alter table public.recipes
  add column if not exists tag_tokens text[] not null default '{}';

create index if not exists recipes_tag_tokens_gin
  on public.recipes using gin (tag_tokens);
```

Then backfill `tag_tokens` from the Turkish `tags` array with a fixed
map, and **leave `tags` in place**. Dropping it in the same migration
would break every installed client the moment it applies; it gets dropped
in 016 after a release cycle.

Six tokens: `budget_friendly`, `high_protein`, `low_calorie`,
`bulking`, `toning`, `vegan`.

### 4.2 `014_recipe_ingredients.sql`

```sql
create table public.recipe_ingredients (
  recipe_id    uuid not null references public.recipes(id) on delete cascade,
  position     int  not null,
  quantity     numeric,                   -- 3, 50, null for "1 tutam"
  unit         text,                      -- 'g', 'ml', 'adet', null
  name_tr      text not null,
  name_en      text,
  name_es      text,
  name_fr      text,
  name_de      text,
  note_tr      text,                      -- substitutions, prep state
  note_en      text,
  primary key (recipe_id, position)
);
```

Populated by a one-off script that parses the `MALZEMELER:` block. The
script writes a review file for every line it could not parse rather than
guessing — a wrong quantity in a recipe is worse than a missing one.

`instructions` keeps only the `HAZIRLANIŞI:` half after this lands.

### 4.3 `015_recipe_origin_and_diet.sql`

What §5 needs to select on:

```sql
alter table public.recipes
  add column if not exists cuisine       text,     -- 'turkish','mediterranean',
                                                   -- 'american','asian','generic'
  add column if not exists diet_flags    text[] not null default '{}',
                                                   -- 'vegan','vegetarian','halal',
                                                   -- 'gluten_free','dairy_free','pork_free'
  add column if not exists locale_scope  text[] not null default '{}';
                                                   -- empty = show everywhere
```

`locale_scope` is the mechanism for "menemen leads for Turkish users,
overnight oats lead for American ones" **without hiding anything**. It
orders, it does not filter — a Turkish user browsing can still find a
protein pancake. Hiding recipes by locale is a trap: it halves the
catalogue for everyone and users notice.

`pork_free` is separate from `halal` deliberately. They are not the same
claim and conflating them is the kind of error that makes an app
untrustworthy in a market. And `sucuk` is beef in Turkey — the existing
rows need auditing, not assuming.

### 4.4 `016_drop_legacy_tags.sql`

Drops `recipes.tags` and the singleton values. **Only after** a release
carrying the 013 reader has been live long enough that the old client is
gone. Ships one phase later than the rest; noted here so it is not
forgotten.

---

## 5. Content: three catalogues, one table

The founder asked for localized meals, western bodybuilding meals and
international athlete meals. These are three *authoring briefs*, not
three tables — all three land in `recipes` with different `cuisine` and
`locale_scope`.

### 5.1 Localized meals — translate what exists

The 292 Turkish recipes, translated. Some of them are also
culture-portable (an omelette is an omelette); some are not (sucuk).

Rule: **translate the recipe, annotate the ingredient.** `sucuk` stays
`sucuk` in the English title — it is a proper noun, like chorizo — and
`recipe_ingredients.note_en` says "Turkish beef sausage; chorizo or any
cured spiced sausage works." That respects the dish and still lets
someone shop.

Target: all 292, `cuisine = 'turkish'`, `locale_scope = {}`.

### 5.2 Western bodybuilding meals — authored new

The high-protein, macro-forward canon an English-speaking lifter expects
and will not find here: overnight oats, chicken and rice bowls, Greek
yoghurt bowls, protein pancakes, egg-white scrambles, beef and sweet
potato, casein pudding, tuna wraps.

Target: **60 recipes**, `cuisine = 'american'`,
`locale_scope = {'en'}`, weighted toward `high_protein` and `bulking`,
covering all five `meal_type`s.

Why 60: the app shows a daily menu of 4–5 meals. Below ~50 an English
user sees repeats inside a fortnight, which reads as an empty app.

### 5.3 International athlete meals — authored new

Cuisine-diverse, macro-legible, aimed at nobody's home country in
particular: Japanese salmon-rice bowls, Mexican egg-and-bean plates,
Indian paneer and dal, Greek and Levantine mezze, Korean tofu stews.

Target: **40 recipes**, `cuisine` per dish, `locale_scope = {}` — these
are the ones that make the catalogue feel worldly to *every* user,
including the Turkish one.

### 5.4 The order to do this in

1. **§5.2 first.** It is the difference between an English user finding a
   usable app and finding a translated Turkish one, and it needs no
   translation pipeline — it is authored in English and translated *to*
   Turkish afterwards.
2. **§5.1 second**, prioritised by usage: the ~120 recipes the daily-menu
   generator actually selects. The tail can lag.
3. **§5.3 last.** Pure upside, no user is blocked on it.

---

## 6. Translation workflow

### 6.1 Who translates

Not a human, and not raw model output either.

1. **Machine draft** — an LLM pass per recipe, with the glossary and
   the rules below in the prompt.
2. **Automated check** — the gate in §6.3.
3. **Native review** — a human reads the first 50 of each locale and
   spot-checks 10 % of the rest. Cooking vocabulary is where machine
   translation is worst: "kavur" is not "burn", "dinlendir" is not
   "rest it" in every context.

Budget the review. A catalogue with 400 confidently-wrong recipes is
worse than one with 292 honestly-Turkish ones.

### 6.2 Rules the prompt must carry

- **Never translate a quantity or a unit.** `50 g` stays `50 g`.
- **Never convert units.** The app has `unit_system.dart` for that and
  doing it in the translation makes it un-round-trippable.
- **Proper nouns stay** — sucuk, menemen, tzatziki — with a note.
- **Imperative mood** for steps, matching the Turkish.
- **One step per numbered line**, same count as the source. A translation
  that merges two steps breaks the step-by-step reader.
- **Do not invent** a nutrition claim, a health benefit, or a substitute
  the ingredient list does not carry.

That last one matters more than it looks: this app already refuses to
invent nutrition data server-side (verified in the Phase 6 coach work),
and a translation pass is exactly where such a claim sneaks in.

### 6.3 The gate

A `tool/recipe_translation_audit.dart` in the shape of the existing
`tool/arb_coverage.dart`, run in CI:

- every non-null `title_<lang>` has a matching `instructions_<lang>`
  (§3.2's one-recipe-one-language rule)
- step counts match the Turkish source
- every number in the source appears in the translation
- no Turkish-only character (ğ ş ı İ ç ö ü) in an `_en` column, except
  inside a known proper noun from the glossary
- `recipe_tags` has a label for every shipped locale
- coverage percentages, printed per locale, ratcheting like the
  hardcoded-string gate — coverage may rise and never fall

The Turkish-character check is the cheap one that catches the most: an
untranslated field copied forward is the common failure, and it is
invisible in a spot check.

### 6.4 Glossary

`docs/i18n/GLOSSARY.md` gains a food section — never-translate terms
(sucuk, menemen, pide, ayran, tarhana) with a one-line gloss each. Same
file, same discipline as the existing never-translate list.

---

## 7. AI-assisted recipe pipeline

For §5.2 and §5.3 — authoring 100 new recipes — and afterwards as the
tool that keeps the catalogue growing.

### 7.1 Shape

A `tool/recipe_pipeline/` CLI, not an app feature and not a Supabase
function. It runs on a laptop, writes proposals to disk, and never writes
to production directly.

```
generate → validate → cost → review → seed
```

**generate** — one LLM call per recipe against a brief (meal_type,
cuisine, macro target, diet flags, an ingredient budget). Structured
output, so it comes back as the row shape rather than prose to parse.

**validate** — deterministic, no model:
- macros are arithmetically consistent with the ingredient list
  (4/4/9 kcal per g of protein/carb/fat, within ±10 % of `calories`)
- `calories` is inside a sane band for the `meal_type`
- every ingredient has a quantity and unit
- `diet_flags` do not contradict the ingredients — a `vegan` recipe with
  yoghurt is rejected, not warned about
- no duplicate title, and no near-duplicate ingredient set against the
  existing 292

**cost** — a second model pass scoring plausibility, shopping difficulty
and whether an ordinary person would eat it. Cheap, and it catches the
"technically valid, nobody makes this" output that validation cannot.

**review** — writes a markdown sheet per batch, the same shape as
`WORKOUT_BACKGROUND_IMAGE_REQUESTS.md`, for a human to approve. Approval
is a file edit, not a database write.

**seed** — emits a `supabase/sql/phaseNN_recipes_batch_N.sql` of plain
inserts. Reviewable, replayable, revertible, and identical in kind to
every seed already in that directory.

### 7.2 The two rules that make this safe

- **The model never writes to the database.** Every path ends in SQL a
  human read. The validation step is not a formality — it is the thing
  that makes an unreviewed batch impossible to ship.
- **A rejected recipe is deleted, not repaired.** Repairing means another
  model call against output already known to be wrong, and it produces
  plausible garbage. Generation is the cheap part.

### 7.3 Images

100 new recipes need 100 photographs, and `image_url` is non-null on all
292 today — an empty tile would be the most visible regression of the
whole phase.

Same pattern as the workout backgrounds: generate prompts alongside the
recipes, write them to a request document, resolve at runtime with a
`meal_type`-level fallback so nothing is ever blank. `docs/MEAL_IMAGE_PROMPTS.md`
already exists and is the prompt style to match.

---

## 8. Order of work

| # | Work | Gates on | Ships alone |
| --- | --- | --- | --- |
| 1 | `013` tag tokens + repository + chips | — | yes |
| 2 | `014` ingredients + parser + review pass | — | yes |
| 3 | `015` cuisine / diet / locale_scope | — | yes |
| 4 | Resolution layer + per-recipe language rule + tests | 1 | yes |
| 5 | §7 pipeline, dry-run only | 2, 3 | n/a |
| 6 | §5.2 60 western recipes | 5 | yes |
| 7 | §6.3 audit gate in CI | 4 | yes |
| 8 | §5.1 translate 292, priority-first | 4, 7 | incrementally |
| 9 | §5.3 40 international recipes | 5 | yes |
| 10 | `016` drop legacy tags | 1 + one release | later phase |

1–4 are engineering and can run before any content exists. 6, 8 and 9 are
content and can run in parallel with each other once 5 is up.

## 9. How Phase 7 is judged done

```
content_translation_coverage    recipes en = 100 %
recipe rows                     292 + 100
recipes with tag_tokens         100 %
recipes with parsed ingredients 100 %
recipe images                   100 % non-null, 0 fallback tiles on
                                the top-120 daily-menu selection
tool/recipe_translation_audit   0 findings, ratchet armed in CI
native review                   first 50 en read, 10 % sampled
English daily menu              5 distinct meals/day for 14 days with
                                no repeat  ← the actual user-facing test
```

The last line is the one that matters. Everything above it is
instrumentation.

## 10. What this plan does not cover

- **Exercise content.** Migration 011 localised `exercises` too and this
  plan is nutrition only. The exercise catalogue is 138 rows with
  `name`, `description` and `short_tip`, and the same resolution layer
  from §3.2 serves it — but the instructional images carry burned-in
  text in two languages (see `WORKOUT_BACKGROUND_IMAGE_REQUESTS.md` §5),
  which is a content project of its own.
- **es / fr / de.** The columns exist and the plan is locale-agnostic,
  but nothing here proposes shipping them. Adding a third language is a
  content cost, not an engineering one, once `en` is done.
- **A shopping list.** §4.2 exists partly to make it possible. It is not
  Phase 7.
