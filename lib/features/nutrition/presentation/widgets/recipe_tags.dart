import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/recipe.dart';
import '../../domain/recipe_tag_token.dart';

/// The label colour for a chip filled with `tint` at 18 % alpha.
///
/// Phase 7 device walk · the label was `Colors.white` regardless of
/// theme. Over a dark surface an 18 % tint is dark and white reads
/// perfectly; over a white one the same fill is a pastel and white on it
/// measured **1.24:1 to 1.32:1** on the device — the labels were ghosts.
/// This is the "PREMIUM white on white" defect the Phase 6 device walk
/// found, on the surfaces Phase 7 added.
///
/// Light mode keeps the tag's own hue and drops its lightness to 0.22,
/// which is the highest value at which every one of the six tints clears
/// 4.5:1 against its own fill — the neon yellow `toning` is the binding
/// constraint at 5.22:1. Keeping the hue matters: the colour is how the
/// six categories are told apart at a glance.
///
/// [onImagery] is the exception and has to be passed explicitly. The
/// nutrition tab's compact card `Positioned`s its badge over the recipe
/// photograph, and a photograph does not change with the app's theme —
/// so that badge stays white in both, and swapping it for a dark label
/// because the *scaffold* went light would be reasoning about the wrong
/// backdrop.
Color recipeTagLabelColor(
  BuildContext context,
  Color tint, {
  bool onImagery = false,
}) {
  if (onImagery || context.isDarkMode) return Colors.white;
  return HSLColor.fromColor(tint).withLightness(0.22).toColor();
}

/// Neon-flavoured badge painted behind recipe thumbnails and under
/// detail titles. Each tag is a `(icon, label, tint)` triple; the
/// badge colours itself from `tint` so the three surface types
/// (discovery card, detail screen, next-best card) stay visually
/// harmonised.
class RecipeTagBadge extends StatelessWidget {
  const RecipeTagBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    this.compact = false,
    this.onImagery = false,
  });

  final String icon;
  final String label;
  final Color tint;

  /// `compact = true` renders smaller type + padding so the badge
  /// fits neatly on the discovery card's narrow footer.
  final bool compact;

  /// True when the badge is painted over a photograph rather than over
  /// the scaffold. See [recipeTagLabelColor].
  final bool onImagery;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    final fontSize = compact ? 10.0 : 11.0;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: tint.withValues(alpha: 0.18),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: fontSize)),
          const SizedBox(width: 4),
          // Phase 7 · a translated label is longer than the Turkish it
          // replaced ("Quick & affordable" against "Pratik & Ekonomik"),
          // and this badge sits on a card footer with no width to give.
          // Ellipsis rather than fade: the Phase 6 device walk found a
          // faded overflow reads as a complete, shorter, wrong string.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: recipeTagLabelColor(context, tint, onImagery: onImagery),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact `Wrap` of the recipe's applicable tags. Limits to [maxTags]
/// badges so the strip doesn't blow out the card footer when a recipe
/// qualifies for several categories.
class RecipeTagsStrip extends StatelessWidget {
  const RecipeTagsStrip({
    super.key,
    required this.recipe,
    this.maxTags = 2,
    this.compact = false,
    this.onImagery = false,
  });

  final Recipe recipe;
  final int maxTags;
  final bool compact;

  /// Forwarded to [RecipeTagBadge.onImagery].
  final bool onImagery;

  @override
  Widget build(BuildContext context) {
    final tags = recipeTags(AppLocalizations.of(context), recipe).take(maxTags);
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          RecipeTagBadge(
            icon: tag.icon,
            label: tag.label,
            tint: tag.tint,
            compact: compact,
            onImagery: onImagery,
          ),
      ],
    );
  }
}

/// Returns the badges a recipe should surface, in the order the server
/// stored them.
///
/// Phase 7 · this used to switch on `recipe.tags` — the Turkish `text[]`
/// — and fall back to a macro heuristic (protein ≥ 25 → "Yüksek
/// Protein", and so on) when that column was empty. Both are gone:
///
///   * The **switch** now keys on [Recipe.tagTokens], so the badge's copy
///     comes from ARB and its identity from the database. That is the
///     split migration `013_recipe_tag_tokens.sql` exists to make.
///   * The **heuristic** was moved into that migration's backfill and
///     deleted from here. It never ran in production — every one of the
///     292 catalogue rows was tagged, so the `isEmpty` branch was
///     unreachable — and keeping a second copy of a rule the database
///     now applies is exactly how the two drift.
///
/// A token this build has no label for renders nothing. See
/// `recipe_tag_token.dart` for why that beats echoing the raw token.
List<({String icon, String label, Color tint})> recipeTags(
  AppLocalizations l10n,
  Recipe recipe,
) {
  final badges = <({String icon, String label, Color tint})>[];
  for (final token in recipe.tagTokens) {
    final label = recipeTagLabel(l10n, token);
    final style = recipeTagStyle(token);
    if (label == null || style == null) continue;
    badges.add((icon: style.icon, label: label, tint: style.tint));
  }
  return badges;
}
