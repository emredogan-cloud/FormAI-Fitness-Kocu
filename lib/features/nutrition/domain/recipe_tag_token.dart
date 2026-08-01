/// Roadmap Phase 7 · the six recipe category tokens, and how each one
/// becomes something a human can read.
///
/// ## Why this file exists
///
/// Before Phase 7 a recipe category was one Turkish string doing two
/// jobs: `nutrition_repository.dart` filtered with
/// `tags @> ARRAY['Pratik & Ekonomik']` and the same string was painted
/// on the chip. That string could not be translated — translating it
/// breaks the filter — and could not stay, because it showed Turkish
/// inside an English app.
///
/// Migration `013_recipe_tag_tokens.sql` split it. The database now
/// stores `tag_tokens` — `budget_friendly`, `high_protein`, … — which
/// are **data identity and are never translated**, and this file is the
/// only place a token turns into copy.
///
/// ## Where the label comes from
///
/// ARB, not the `recipe_tags` table, even though that table carries
/// label columns. `docs/i18n/README.md` draws the line at data identity:
/// a token is identity, a label is copy, and copy belongs where the
/// coverage gate, the pseudo-locale sweep and the offline guarantee
/// already apply. A chip that only renders after a network round-trip is
/// a worse chip, and the six tokens are a closed set — the plan is
/// explicit that a category one recipe uses is not a category.
///
/// The server-side labels are the record the translation audit checks
/// and what the recipe pipeline writes; they are not what the app reads.
///
/// ## Unknown tokens
///
/// [recipeTagLabel] returns null rather than echoing the raw token. A
/// chip reading `high_protein` is worse than no chip: it leaks a
/// database identifier into the product and looks like a bug to
/// everyone except the person who wrote it. A seventh token needs an app
/// release to get a label — which it also needs to get an icon and a
/// tint, so nothing is lost.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The tokens migration 013 seeded into `public.recipe_tags`, in the
/// `sort_order` that table gives them.
///
/// Duplicated from the database on purpose: the chip row has to lay out
/// before any network call resolves, and the audit gate asserts the two
/// lists agree. A constant that CI proves correct beats a fetch.
const List<String> kRecipeTagTokens = [
  'budget_friendly',
  'high_protein',
  'low_calorie',
  'bulking',
  'toning',
  'vegan',
];

/// The subset offered as filter chips on the discovery surfaces.
///
/// `budget_friendly` is deliberately absent, and was absent before
/// Phase 7 too. It already has a dashboard strip of its own with five
/// meal-type sub-cards and a `/category/budget` route; repeating it as a
/// chip would give the largest bucket in the catalogue — 156 of 292 rows
/// — two entry points on one screen and filter out almost nothing when
/// tapped.
const List<String> kRecipeFilterTokens = [
  'high_protein',
  'low_calorie',
  'bulking',
  'toning',
  'vegan',
];

/// Localized label for [token], or null if this build does not know it.
///
/// Pure, with the localizations passed in rather than read from a
/// `BuildContext` — the same shape `unit_system.dart` uses, and what
/// lets the whole mapping be unit-tested without a widget tree.
String? recipeTagLabel(AppLocalizations l10n, String token) => switch (token) {
      // Reuses the dashboard section's own key. The strip and the chip
      // name the same bucket, and two ARB keys holding the same sentence
      // is how they drift.
      'budget_friendly' => l10n.nutritionQuickMealsTitle,
      'high_protein' => l10n.recipeTagHighProtein,
      'low_calorie' => l10n.recipeTagLowCalorie,
      'bulking' => l10n.recipeTagBulking,
      'toning' => l10n.recipeTagToning,
      'vegan' => l10n.recipeTagVegan,
      _ => null,
    };

/// Emoji + tint for [token]. Presentation only — no copy — so it lives
/// beside the label map rather than in the widget, keeping "everything
/// that is per-token" in one file.
({String icon, Color tint})? recipeTagStyle(String token) => switch (token) {
      'budget_friendly' => (icon: '💰', tint: const Color(0xFF8E5BFF)),
      'high_protein' => (icon: '🔥', tint: const Color(0xFF4DA6FF)),
      'low_calorie' => (icon: '🥗', tint: const Color(0xFF39FF14)),
      'bulking' => (icon: '💪', tint: const Color(0xFFFF4DDB)),
      'toning' => (icon: '✨', tint: const Color(0xFFEAFF00)),
      'vegan' => (icon: '🌱', tint: const Color(0xFF39C46B)),
      _ => null,
    };
