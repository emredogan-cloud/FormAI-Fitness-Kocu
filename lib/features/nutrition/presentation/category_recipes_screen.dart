import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/error_card.dart';
import 'widgets/recipe_image.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Dedicated "all recipes in this meal category" screen pushed via
/// `/nutrition/category/:type`. Reads the dedicated
/// [categoryRecipesProvider] family, which asks Postgres to filter by
/// `meal_type` (or by the `'Pratik & Ekonomik'` tag for the Phase 83
/// `budget` sentinel) and returns the complete result in one round-trip.
///
/// Phase 83 hotfix · was previously stateful with a `ScrollController`
/// driving paginated `loadMore()` calls against the global
/// [recipesProvider], filtering the loaded page client-side. That
/// flow silently broke once the catalogue grew past the 20-row first
/// page (UUID ordering scattered budget rows past page 1, the screen
/// rendered an empty state, the empty state didn't scroll, so
/// `_onScroll` never triggered the next page). Server-side filtering
/// makes the page-1 question moot: every match comes back at once.
class CategoryRecipesScreen extends ConsumerWidget {
  const CategoryRecipesScreen({
    super.key,
    required this.categoryType,
    this.mealTypeSubFilter,
  });

  /// Route path parameter. One of: `breakfast`, `lunch`, `dinner`,
  /// `snack`, `dessert`, `budget`. Unknown values render an empty
  /// state rather than crashing — the server-side filter just returns
  /// an empty list for any unrecognised `meal_type`.
  final String categoryType;

  /// Phase 83 dashboard expansion · optional `?meal=<token>` query
  /// parameter. Only consulted when [categoryType] is `'budget'`; the
  /// repository chains an `eq('meal_type', mealTypeSubFilter)` onto the
  /// existing `contains('tags', ['Pratik & Ekonomik'])` so the
  /// dashboard strip's five sub-cards each route to the intersection
  /// (e.g. budget AND breakfast).
  final String? mealTypeSubFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(categoryRecipesProvider(
      (token: categoryType, mealType: mealTypeSubFilter),
    ));
    // Phase 53E · drop the hardcoded `0xFF0B0B12` Scaffold + AppBar
    // backgrounds. The screen now inherits whatever
    // `scaffoldBackgroundColor` the active theme ships, and the AppBar
    // surface + foreground both pull from the live ColorScheme so they
    // flip with the theme toggle.
    final scheme = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          _titleFor(
              AppLocalizations.of(context), categoryType, mealTypeSubFilter),
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: recipesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        error: (err, st) {
          AppLogger.error(
            'CategoryRecipesScreen error',
            err,
            stackTrace: st,
            category: 'nutrition',
            data: {
              'category': categoryType,
              'mealTypeSubFilter': mealTypeSubFilter,
            },
          );
          return ErrorCard(
            message: AppLocalizations.of(context).recipesLoadError,
            onRetry: () => ref.invalidate(
              categoryRecipesProvider(
                (token: categoryType, mealType: mealTypeSubFilter),
              ),
            ),
          );
        },
        data: (recipes) {
          if (recipes.isEmpty) {
            return _EmptyCategoryState(category: categoryType);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _CategoryRecipeCard(recipe: recipes[index]),
          );
        },
      ),
    );
  }

  /// Maps the route param to the Turkish AppBar title. Unknown values
  /// fall back to a generic "Tarifler" so a malformed deeplink still
  /// renders a sensible header.
  ///
  /// Phase 83 dashboard expansion · when [type] is `'budget'` AND
  /// [subFilter] resolves to a known meal_type, the title combines
  /// both (e.g. "Pratik & Ekonomik · Kahvaltı") so the user sees what
  /// they actually filtered on instead of a generic "Pratik & Ekonomik"
  /// that hides the sub-bucket.
  static String _titleFor(
    AppLocalizations l10n,
    String type,
    String? subFilter,
  ) {
    // The switch keys are English route tokens, not stored content —
    // unlike `recipe_tags.dart`, where the cases match database values.
    // So the tokens stay and only the labels are localised.
    final base = switch (type.toLowerCase()) {
      'breakfast' => l10n.recipeCategoryBreakfastTitle,
      'lunch' => l10n.recipeCategoryLunchTitle,
      'dinner' => l10n.recipeCategoryDinnerTitle,
      'snack' => l10n.recipeCategorySnackTitle,
      'dessert' => l10n.recipeCategoryDessertTitle,
      'budget' => l10n.recipeCategoryPracticalTitle,
      _ => l10n.recipeCategoryGenericTitle,
    };
    if (type.toLowerCase() != 'budget' ||
        subFilter == null ||
        subFilter.isEmpty) {
      return base;
    }
    final subLabel = switch (subFilter.toLowerCase()) {
      'breakfast' => l10n.mealBreakfast,
      'lunch' => l10n.mealLunch,
      'dinner' => l10n.mealDinner,
      'snack' => l10n.mealSnacks,
      'dessert' => l10n.mealDesserts,
      _ => null,
    };
    return subLabel == null ? base : '$base · $subLabel';
  }
}

class _CategoryRecipeCard extends StatelessWidget {
  const _CategoryRecipeCard({required this.recipe});
  final Recipe recipe;

  /// Phase 33 bump: cards are now 140 px tall with a 120×120 thumb.
  /// Phase 32's 120/100 pairing overflowed by ~17 px on rows with two
  /// tag chips because the title (maxLines: 2) + tag Wrap + macro row
  /// together exceed 100 px of inner height on compact devices. The
  /// extra 20 px absorbs that while keeping the layout tight; the
  /// title+tags block now lives in an `Expanded` so any residual slack
  /// is distributed gracefully instead of overflowing.
  static const double _cardHeight = 140;
  static const double _thumbSize = 120;

  @override
  Widget build(BuildContext context) {
    // Phase 53E · the recipe card was the dominant ghost — entire
    // list scrolled white-on-white. Card surface, border, recipe
    // title, kcal value, and protein value all flip via onSurface.
    // Brand-coloured icons (neon flame, blue dumbbell) stay because
    // they're the macro identifiers users learn.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return SizedBox(
      height: _cardHeight,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/recipe', extra: recipe),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : scheme.surface,
              border: Border.all(
                color: isDark ? Colors.white12 : scheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fixed 100×100 thumbnail. `BoxFit.cover` + a strict box
                // guarantees no stretching regardless of the source
                // aspect ratio, and ClipRRect rounds the corners
                // independently of the card's own rounded border.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: _thumbSize,
                    height: _thumbSize,
                    child: _Thumb(imageUrl: recipe.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + tags share the flexible top region.
                      // Wrapping them in `Expanded` lets the tag Wrap
                      // grow to two rows (which was the phase 32
                      // overflow trigger) without blowing past the
                      // fixed card height; the macro row below stays
                      // pinned as the fixed bottom anchor.
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RecipeTagsStrip(
                              recipe: recipe,
                              maxTags: 2,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: _neon,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)
                                .macroKcal(recipe.calories),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.fitness_center,
                            color: _proteinColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)
                                .macroProtein(recipe.protein),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Phase 53E · thumb fallback flips with the active theme so a
    // missing image lands on a soft surface tone instead of a black
    // square in light mode.
    final scheme = context.colors;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant,
        color: scheme.onSurface.withValues(alpha: 0.55),
        size: 28,
      ),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return RecipeImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 300,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    // Phase 53E · empty-state copy + secondary explainer flip with the
    // active theme.
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neon.withValues(alpha: 0.12),
              border: Border.all(color: _neon.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: _neon,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).recipeCategoryEmpty,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).categoryNoRecipes(category),
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.55),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
