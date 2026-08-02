import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/share_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/branded_media_fallback.dart';
import '../../../core/widgets/top_toast.dart';
import 'widgets/recipe_image.dart';
import '../../monetization/models/locked_feature_type.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../monetization/services/premium_gate_service.dart';
import '../../referral/providers/referral_provider.dart';
import '../domain/models/daily_meal_slot.dart';
import '../domain/models/recipe.dart';
import '../domain/recipe_ingredient_lines.dart';
import '../providers/daily_menu_provider.dart';
import '../providers/favorite_recipes_provider.dart';
import 'widgets/recipe_tags.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

/// Full recipe view opened from the discovery gallery (pushed via
/// `/recipe` with `state.extra == recipe`) or any other place that has
/// a [Recipe] in hand.
///
/// Layout follows the phase 22.3 spec:
///   • SliverAppBar with full-bleed image behind a vertical gradient
///     so the back button stays readable.
///   • Body: title + prep-time row, 4-tile macro breakdown, and the
///     instructions paragraph (line-height 1.5).
///   • Sticky "Plana Ekle" CTA at the bottom that toasts + pops for MVP.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    // Phase 53C · drop the hardcoded `0xFF0B0B12` scaffold + sliver bg
    // so the active theme's `scaffoldBackgroundColor` (lightBg in
    // light, darkBg in dark) drives both surfaces. Title + meta copy
    // pull through onSurface so the dark text stays legible on the
    // off-white scaffold.
    final scheme = context.colors;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: scheme.surface,
            elevation: 0,
            leading: const _BackButton(),
            // Phase 54B · share affordance in the AppBar. Sits on the
            // hero image so the icon needs the same dark-translucent
            // chip treatment as `_BackButton` to stay readable on
            // bright photography.
            //
            // Phase 56 Lite · favourite toggle paired with share. Heart
            // first (more frequent action), share second.
            actions: [
              _FavoriteRecipeButton(recipe: recipe),
              _ShareRecipeButton(recipe: recipe),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(
                  imageUrl: recipe.imageUrl, mealType: recipe.mealType),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealTypePill(mealType: recipe.mealType),
                  const SizedBox(height: 12),
                  Text(
                    recipe.title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category badges (🔥 Yüksek Protein, 🥗 Düşük Kalori,
                  // 💪 Hacim, ⚡ Hızlı) — up to three at full size so the
                  // user can scan the recipe's macro profile at a glance.
                  RecipeTagsStrip(recipe: recipe, maxTags: 3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)
                            .minutesShort(recipe.prepTimeMinutes),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _MacroTilesRow(recipe: recipe),
                  const SizedBox(height: 28),
                  _IngredientsSection(recipe: recipe),
                  if ((recipe.instructions ?? '').trim().isNotEmpty)
                    _InstructionsSection(
                      text: recipe.instructions!,
                      // Phase 7 · when the structured rows rendered
                      // above, the blob's own MALZEMELER: half is the
                      // same list a second time. `instructions` keeps
                      // carrying it until migration 016 so shipped
                      // clients keep working, which makes hiding it a
                      // client-side decision for exactly one release.
                      skipIngredientBlock: recipe.ingredientRows.isNotEmpty,
                    ),
                  // Leave headroom for the sticky CTA so long instruction
                  // blocks don't get visually eaten by the button.
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AddToPlanButton(recipe: recipe),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    this.mealType,
  });
  final String? imageUrl;

  /// Phase 7 · the recipe's meal type, so a tile whose photograph has
  /// not been generated yet falls back to that type's cover image
  /// rather than a branded gradient. See RecipeImageRegistry.
  final String? mealType;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final image = (url != null && url.isNotEmpty)
        ? RecipeImage(
            url: url,
            mealType: mealType,
            fit: BoxFit.cover,
            memCacheHeight: 800,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : _fallback();
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        // Top gradient: keeps the back button + status bar readable even
        // on bright photography.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom fade so the body's first line of text doesn't fight
        // the photo's details.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0B0B12).withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Phase 57 · standardised on `BrandedMediaFallback` so a missing
  // recipe hero reads as "intentional empty state" rather than the
  // anonymous purple gradient + restaurant icon. The fallback ships
  // its own gradient + wordmark + contextual icon, so the previous
  // local copy is dead.
  Widget _fallback() =>
      const BrandedMediaFallback(icon: Icons.restaurant_rounded);
}

/// Phase 56 Lite · AppBar favourite toggle. Reads the favourites set
/// via Riverpod so the heart fill tracks the persisted state across
/// every detail screen instance — opening the same recipe a second
/// time inherits whatever the user toggled the first time.
class _FavoriteRecipeButton extends ConsumerWidget {
  const _FavoriteRecipeButton({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteRecipesProvider).contains(recipe.id);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final added = await ref
                .read(favoriteRecipesProvider.notifier)
                .toggle(recipe.id);
            // Stronger thump on add (positive action), softer on
            // remove (correction). Same haptic primitive the rest of
            // the app uses, so taps feel consistent across surfaces.
            if (added) {
              AppHaptics.success();
            } else {
              AppHaptics.secondaryTap();
            }
            // Phase 57 · top-of-screen confirmation toast. Bottom
            // SnackBar collides with the sticky "Plana Ekle" CTA on
            // this screen, so the PM asked for a top-anchored drop-down
            // for the favourite micro-interaction. `TopToast.show`
            // self-dismisses; we surface the same affordance for the
            // remove-from-favourites path so the visual feedback is
            // symmetric.
            if (!context.mounted) return;
            TopToast.show(
              context,
              message: added
                  ? AppLocalizations.of(context).recipeFavoriteAdded
                  : AppLocalizations.of(context).recipeFavoriteRemoved,
              icon: added ? Icons.favorite : Icons.favorite_border,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? const Color(0xFFFF4D6D) : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 54B · AppBar share icon. Reads the user's referral code so
/// the dispatched share text carries `formai://r/<code>`. Uses the
/// same dark-translucent chip treatment as `_BackButton` so it stays
/// legible on bright recipe photography.
class _ShareRecipeButton extends ConsumerWidget {
  const _ShareRecipeButton({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(referralCodeProvider).value;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            AppHaptics.secondaryTap();
            ShareService.instance.shareRecipe(
              l10n: AppLocalizations.of(context),
              recipe: recipe,
              userCode: code,
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MealTypePill extends StatelessWidget {
  const _MealTypePill({required this.mealType});
  final String mealType;

  /// Phase 7 device walk · `recipes.meal_type` is identity, not copy.
  /// This pill used to render `mealType.toUpperCase()`, so a Turkish
  /// reader got the English word `SNACK` sitting directly above a fully
  /// translated title, tag strip and ingredient list — the same
  /// token-painted-at-the-user defect the `recipe_tags` split was for,
  /// one screen further in.
  ///
  /// The labels already existed for the daily-plan timeline; the fifth
  /// value, `dessert`, is new here because the timeline has four slots
  /// and the catalogue has five meal types.
  ///
  /// An unrecognised value falls through to the raw token rather than
  /// disappearing: a visibly wrong pill is what got this one noticed,
  /// and a silently absent one would not have been.
  String _label(AppLocalizations l10n) => switch (mealType.toLowerCase()) {
        'breakfast' => l10n.mealBreakfastUpper,
        'lunch' => l10n.mealLunchUpper,
        'dinner' => l10n.mealDinnerUpper,
        'snack' => l10n.mealSnackUpper,
        'dessert' => l10n.mealDessertUpper,
        _ => mealType.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _neon.withValues(alpha: 0.18),
        border: Border.all(color: _neon.withValues(alpha: 0.55)),
      ),
      child: Text(
        _label(AppLocalizations.of(context)),
        style: TextStyle(
          // Same 18 %-tint-plus-white-label problem as the tag badges:
          // 1.32:1 on a light scaffold. See recipeTagLabelColor.
          color: recipeTagLabelColor(context, _neon),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// Four vertical tiles for Calories / Protein / Carbs / Fat. Equal-width
/// via `Expanded` so the row stays balanced regardless of text length.
class _MacroTilesRow extends StatelessWidget {
  const _MacroTilesRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MacroTile(
            label: AppLocalizations.of(context).recipeCalories,
            value: '${recipe.calories}',
            unit: 'kcal', // i18n-ignore — unit symbol, never-translate
            // Phase 53D · pull text colour from the active theme so
            // the kcal tile reads charcoal on a white card / white on
            // a dark card. The other three tiles keep their macro
            // brand tints (protein blue, carbs pink, fat yellow)
            // because those are the macro-bar colours used elsewhere.
            color: context.colors.onSurface,
            accent: _neon,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: AppLocalizations.of(context).recipeProtein,
            value: '${recipe.protein}',
            unit: 'g',
            color: _proteinColor,
            accent: _proteinColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: AppLocalizations.of(context).macroCarbChipUpper,
            value: '${recipe.carbs}',
            unit: 'g',
            color: _carbsColor,
            accent: _carbsColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroTile(
            label: AppLocalizations.of(context).recipeFat,
            value: '${recipe.fat}',
            unit: 'g',
            color: _fatColor,
            accent: _fatColor,
          ),
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Phase 53D · macro tile chrome flips with the theme. Surface picks
    // a faint card tone in light mode so the colour-on-card contrast
    // works; the unit suffix ("kcal" / "g") leans on onSurface for the
    // same reason.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 12),
                ],
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses the seed recipes' "MALZEMELER: …\n\nHAZIRLANIŞI: …" shape
/// into two visually distinct blocks. Legacy recipes (plain prose,
/// no section headers) fall through to a single block with the
/// original 14 px / 1.5 line height so they still read cleanly.
/// Roadmap Phase 7 · the recipe's ingredients, as data.
///
/// Renders `public.recipe_ingredients` when the row carries them and the
/// legacy `MALZEMELER:` scan when it does not, through the one resolver
/// in `domain/recipe_ingredient_lines.dart`. Renders nothing at all when
/// a recipe genuinely states no ingredients — an empty "Malzemeler"
/// heading is worse than no heading.
class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final lines = recipeIngredientLines(recipe);
    if (lines.isEmpty) return const SizedBox.shrink();
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
              label: AppLocalizations.of(context).recipeIngredients),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // The line wraps rather than ellipsising: "2 yemek
                  // kaşığı sızma zeytinyağı" is longer in English than
                  // Turkish and a cut ingredient is a wrong ingredient.
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  const _InstructionsSection({
    required this.text,
    this.skipIngredientBlock = false,
  });
  final String text;

  /// Drops the `MALZEMELER:` half, because [_IngredientsSection] already
  /// rendered it from structured rows.
  final bool skipIngredientBlock;

  /// Parse markers embedded in the stored recipe text, NOT UI copy.
  ///
  /// The instruction body arrives from Supabase with these literal
  /// headers in it and is split on them. Localising the marker would
  /// stop it matching the row it is parsing. The *display* heading is
  /// localised in [_headingFor]; the marker that finds it is data, and
  /// moves with the content in Phase 7.
  ///
  /// Phase 7 device walk · which is exactly why the English markers have
  /// to be listed too. `build_recipe_en.py` writes `INGREDIENTS:` and
  /// `METHOD:` into `instructions_en`, neither of which was here, so an
  /// English recipe matched no header at all, fell through to the
  /// unstructured branch and printed the raw blob — the ingredient list
  /// once in [_IngredientsSection] and again underneath it. A row is one
  /// language (`resolveRecipeLanguage`), so a blob only ever carries one
  /// of these pairs and matching against all of them cannot cross them.
  static const List<String> _sectionHeaders = [
    'MALZEMELER:', // i18n-ignore
    'HAZIRLANIŞI:', // i18n-ignore
    'YAPILIŞ:', // i18n-ignore — two of the oldest seed rows spell it so
    'INGREDIENTS:', // i18n-ignore
    'METHOD:', // i18n-ignore
  ];

  /// The headers whose block [_IngredientsSection] can replace — one per
  /// shipped language, because the blob is in the recipe's language and
  /// not in the app's.
  static const Set<String> _ingredientHeaders = {
    'MALZEMELER:', // i18n-ignore
    'INGREDIENTS:', // i18n-ignore
  };

  @override
  Widget build(BuildContext context) {
    // Phase 53D · the instruction body was hardcoded `Colors.white70`
    // → invisible on a white scaffold. Pull through onSurface with
    // 0.85 alpha so the body text stays slightly softer than the
    // section heading without losing legibility on either palette.
    final bodyStyle = TextStyle(
      color: context.colors.onSurface.withValues(alpha: 0.85),
      fontSize: 14,
      height: 1.5,
    );
    final split = _split(context, text);
    final sections = split
        .where((section) => !(skipIngredientBlock && section.isIngredients))
        .toList(growable: false);
    // A recipe whose only section was the ingredient block, already
    // rendered above. Falling through to the unstructured branch would
    // print the whole blob and show the list twice.
    if (sections.isEmpty && split.isNotEmpty) return const SizedBox.shrink();
    if (sections.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
              label: AppLocalizations.of(context).recipeInstructions),
          const SizedBox(height: 10),
          Text(text, style: bodyStyle),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          _SectionHeading(label: sections[i].heading),
          const SizedBox(height: 10),
          Text(sections[i].body, style: bodyStyle),
          if (i != sections.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Splits the instruction blob on each recognised section header.
  /// Header tokens ("MALZEMELER:", "HAZIRLANIŞI:") are stripped from
  /// the body, and lowercase title-cased versions are used for the
  /// rendered heading. Returns an empty list when no recognised header
  /// is present — the caller then falls back to a plain single-block
  /// render so unstructured legacy instructions still work.
  List<_InstructionBlock> _split(BuildContext context, String source) {
    final matches = <({int index, String header})>[];
    for (final header in _sectionHeaders) {
      final idx = source.indexOf(header);
      if (idx != -1) matches.add((index: idx, header: header));
    }
    if (matches.isEmpty) return const [];
    matches.sort((a, b) => a.index.compareTo(b.index));

    final blocks = <_InstructionBlock>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].index + matches[i].header.length;
      final end = i + 1 < matches.length ? matches[i + 1].index : source.length;
      final body = source.substring(start, end).trim();
      blocks.add(_InstructionBlock(
        heading: _headingFor(context, matches[i].header),
        body: body,
        isIngredients: _ingredientHeaders.contains(matches[i].header),
      ));
    }
    return blocks;
  }

  String _headingFor(BuildContext context, String raw) {
    switch (raw) {
      case 'MALZEMELER:': // i18n-ignore
      case 'INGREDIENTS:': // i18n-ignore
        return AppLocalizations.of(context).recipeIngredients;
      case 'HAZIRLANIŞI:': // i18n-ignore
      case 'YAPILIŞ:': // i18n-ignore
      case 'METHOD:': // i18n-ignore
        return AppLocalizations.of(context).recipeInstructions;
      default:
        return raw;
    }
  }
}

class _InstructionBlock {
  const _InstructionBlock({
    required this.heading,
    required this.body,
    this.isIngredients = false,
  });
  final String heading;
  final String body;

  /// True for the `MALZEMELER:` block, which Phase 7 renders from
  /// structured rows instead whenever the recipe carries them.
  final bool isIngredients;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    // Phase 53D · "Malzemeler" / "Hazırlanışı" headings — onSurface so
    // they stay legible on both palettes.
    return Text(
      label,
      style: TextStyle(
        color: context.colors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Sticky bottom CTA. Wired in phase 23.1 to actually append the recipe
/// to the daily plan via [DailyMenuNotifier.addRecipeToPlan]; the slot
/// is inferred from `recipe.mealType` so a breakfast recipe lands in
/// the breakfast row, a main lands in dinner, etc.
class _AddToPlanButton extends ConsumerWidget {
  const _AddToPlanButton({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B12),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _handleAddToPlan(context, ref, recipe),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(AppLocalizations.of(context).recipeAddToPlan),
            style: FilledButton.styleFrom(
              backgroundColor: _neon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the slot picker, waits for a selection, then dispatches the
/// add-to-plan and toasts + pops on success. Separated out so the
/// button's `onPressed` stays readable.
Future<void> _handleAddToPlan(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
) async {
  // Freemium · viewing the recipe is free; adding it to the daily plan is
  // meal tracking (Pro). A non-pro tap opens the cinematic upsell.
  if (!ref.read(isProProvider)) {
    ref.read(premiumGateProvider).handleLockedTap(
          context,
          LockedFeatureType.nutritionTab,
        );
    return;
  }
  final slot = await _showSlotPicker(context);
  if (slot == null) return;
  HapticFeedback.mediumImpact();
  ref.read(dailyMenuProvider.notifier).addRecipeToPlan(recipe, slot.name);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).recipeAddedToSlot(
          recipe.title,
          _slotLabel(AppLocalizations.of(context), slot),
        )),
        backgroundColor: _neonGreen.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  if (context.canPop()) context.pop();
}

Future<DailyMealSlot?> _showSlotPicker(BuildContext context) {
  return showModalBottomSheet<DailyMealSlot>(
    context: context,
    // Phase 53C · pull the sheet bg from the active theme so the
    // bottom-sheet picker doesn't punch a dark hole through a
    // light-mode scaffold.
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _SlotPickerSheet(),
  );
}

class _SlotPickerSheet extends StatelessWidget {
  const _SlotPickerSheet();

  static const List<DailyMealSlot> _slots = [
    DailyMealSlot.breakfast,
    DailyMealSlot.lunch,
    DailyMealSlot.dinner,
    DailyMealSlot.snack,
  ];

  @override
  Widget build(BuildContext context) {
    // Phase 53F · the meal-swap bottom sheet (the "Hangi öğüne
    // eklemek istersin?" picker triggered by the recipe-detail "Plana
    // Ekle" button) was painting Kahvaltı / Öğle / Akşam labels in
    // hardcoded white. Pull every text + chrome through onSurface so
    // the sheet reads correctly on both palettes.
    final scheme = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).recipeAddToWhichMeal,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 14),
            for (final slot in _slots) ...[
              _SlotOption(
                slot: slot,
                onTap: () => Navigator.of(context).pop(slot),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotOption extends StatelessWidget {
  const _SlotOption({required this.slot, required this.onTap});
  final DailyMealSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final (icon, color) = _iconFor(slot);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : scheme.surfaceContainer,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _slotLabel(AppLocalizations.of(context), slot),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(DailyMealSlot slot) {
    switch (slot) {
      case DailyMealSlot.breakfast:
        return (Icons.free_breakfast, _neon);
      case DailyMealSlot.lunch:
        return (Icons.lunch_dining, _proteinColor);
      case DailyMealSlot.dinner:
        return (Icons.dinner_dining, _carbsColor);
      case DailyMealSlot.snack:
        return (Icons.cookie, _fatColor);
    }
  }
}

String _slotLabel(AppLocalizations l10n, DailyMealSlot slot) {
  switch (slot) {
    case DailyMealSlot.breakfast:
      return l10n.mealBreakfast;
    case DailyMealSlot.lunch:
      return l10n.mealLunch;
    case DailyMealSlot.dinner:
      return l10n.mealDinner;
    case DailyMealSlot.snack:
      return l10n.mealSnack;
  }
}
