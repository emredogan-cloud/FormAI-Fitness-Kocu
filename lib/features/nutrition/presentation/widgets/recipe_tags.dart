import 'package:flutter/material.dart';

import '../../domain/models/recipe.dart';

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
  });

  final String icon;
  final String label;
  final Color tint;

  /// `compact = true` renders smaller type + padding so the badge
  /// fits neatly on the discovery card's narrow footer.
  final bool compact;

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
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact `Wrap` of the recipe's applicable tags. Limits to [maxTags]
/// badges so the strip doesn't blow out the card footer when a recipe
/// qualifies for several categories. The selection respects tier
/// ordering from [recipeTags] (high-protein → low-calorie → bulk →
/// fast), so the most informative tag wins.
class RecipeTagsStrip extends StatelessWidget {
  const RecipeTagsStrip({
    super.key,
    required this.recipe,
    this.maxTags = 2,
    this.compact = false,
  });

  final Recipe recipe;
  final int maxTags;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tags = recipeTags(recipe).take(maxTags);
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
          ),
      ],
    );
  }
}

/// Category tags a recipe qualifies for, in priority order:
///
///   1. 🔥 Yüksek Protein — ≥25 g protein.
///   2. 🥗 Düşük Kalori — ≤400 kcal.
///   3. 💪 Hacim — ≥500 kcal (the bulk-friendly tier).
///   4. ⚡ Hızlı — ≤15 min prep time.
///
/// A recipe can match several simultaneously (e.g. a high-protein
/// 10-minute recipe gets both tags). Callers typically [take] the first
/// one or two so the card stays readable.
List<({String icon, String label, Color tint})> recipeTags(Recipe recipe) {
  const highProtein = (
    icon: '🔥',
    label: 'Yüksek Protein',
    tint: Color(0xFF4DA6FF),
  );
  const lowCalorie = (
    icon: '🥗',
    label: 'Düşük Kalori',
    tint: Color(0xFF39FF14),
  );
  const bulk = (
    icon: '💪',
    label: 'Hacim',
    tint: Color(0xFFFF4DDB),
  );
  const fast = (
    icon: '⚡',
    label: 'Hızlı',
    tint: Color(0xFFEAFF00),
  );

  final tags = <({String icon, String label, Color tint})>[];
  if (recipe.protein >= 25) tags.add(highProtein);
  if (recipe.calories <= 400) tags.add(lowCalorie);
  if (recipe.calories >= 500) tags.add(bulk);
  if (recipe.prepTimeMinutes <= 15) tags.add(fast);
  return tags;
}
