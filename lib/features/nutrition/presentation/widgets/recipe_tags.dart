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
/// qualifies for several categories. Selection is delegated to
/// [recipeTags], which prefers dietitian-curated `recipe.tags` and
/// falls back to macro-based heuristics.
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

/// Returns the tags a recipe should surface in the UI, in priority
/// order. Two paths:
///
///   1. **Dietitian-curated**: if `recipe.tags` is populated (Phase 24
///      seed), map each known label onto a styled badge. Unknown labels
///      still render but with a neutral tint so ad-hoc tags don't crash
///      the layout.
///   2. **Macro-heuristic fallback**: when `recipe.tags` is empty (legacy
///      rows, or user-generated recipes without explicit tagging), fall
///      back to the macro thresholds introduced in phase 23.2:
///         • 🔥 Yüksek Protein — ≥25 g protein
///         • 🥗 Düşük Kalori — ≤400 kcal
///         • 💪 Hacim — ≥500 kcal
///         • ⚡ Hızlı — ≤15 min prep time
///
/// The five canonical phase-24 tags each have a dedicated icon/tint:
///   • 🔥 Yüksek Protein (protein-blue)
///   • 🥗 Düşük Kalori (neon-green)
///   • 💪 Hacim (neon-pink)
///   • ✨ Sıkılaşma (neon-yellow)
///   • 🌱 Vegan (deep-green)
List<({String icon, String label, Color tint})> recipeTags(Recipe recipe) {
  if (recipe.tags.isNotEmpty) {
    return recipe.tags.map(_badgeForCuratedTag).toList(growable: false);
  }

  // Macro-heuristic fallback for legacy rows with no `tags` value.
  const highProtein = (
    icon: '🔥',
    label: 'Yüksek Protein', // i18n-ignore
    tint: Color(0xFF4DA6FF),
  );
  const lowCalorie = (
    icon: '🥗',
    label: 'Düşük Kalori', // i18n-ignore
    tint: Color(0xFF39FF14),
  );
  const bulk = (
    icon: '💪',
    label: 'Hacim', // i18n-ignore
    tint: Color(0xFFFF4DDB),
  );
  const fast = (
    icon: '⚡',
    label: 'Hızlı', // i18n-ignore
    tint: Color(0xFFEAFF00),
  );

  final tags = <({String icon, String label, Color tint})>[];
  if (recipe.protein >= 25) tags.add(highProtein);
  if (recipe.calories <= 400) tags.add(lowCalorie);
  if (recipe.calories >= 500) tags.add(bulk);
  if (recipe.prepTimeMinutes <= 15) tags.add(fast);
  return tags;
}

// Roadmap Phase 5 · these strings are CONTENT, not UI chrome, and are
// deliberately not extracted to ARB.
//
// The switch keys on `recipe.tags` — values stored in the Supabase
// `recipes` rows — so the case labels are data identities, not copy. The
// returned `label` is the same value echoed back for display. Localising
// it here would mean the app showed an English tag for a row the
// database still calls "Yüksek Protein", and the two would drift the
// moment a new tag shipped.
//
// Content localisation is Phase 7's job, through the per-locale columns
// migration 011 added. Until then the display value follows the stored
// value, which is the only self-consistent option.
({String icon, String label, Color tint}) _badgeForCuratedTag(String tag) {
  switch (tag) {
    // i18n-ignore
    case 'Yüksek Protein': // i18n-ignore
      return (
        icon: '🔥',
        label: 'Yüksek Protein', // i18n-ignore
        tint: const Color(0xFF4DA6FF)
      );
    case 'Düşük Kalori': // i18n-ignore
      return (
        icon: '🥗',
        label: 'Düşük Kalori', // i18n-ignore
        tint: const Color(0xFF39FF14)
      ); // i18n-ignore
    case 'Hacim': // i18n-ignore
      return (
        icon: '💪',
        label: 'Hacim', // i18n-ignore
        tint: const Color(0xFFFF4DDB),
      );
    case 'Sıkılaşma': // i18n-ignore
      return (
        icon: '✨',
        label: 'Sıkılaşma', // i18n-ignore
        tint: const Color(0xFFEAFF00)
      ); // i18n-ignore
    case 'Vegan': // i18n-ignore
      return (
        icon: '🌱',
        label: 'Vegan', // i18n-ignore
        tint: const Color(0xFF39C46B),
      );
    default:
      // Neutral neon-purple for any server-side tag we don't yet know
      // about; keeps the UI stable while new categories roll out.
      return (icon: '•', label: tag, tint: const Color(0xFF8E5BFF));
  }
}
