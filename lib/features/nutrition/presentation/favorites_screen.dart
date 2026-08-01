import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/models/recipe.dart';
import '../domain/recipe_ingredient_lines.dart';
import 'widgets/recipe_image.dart';
import '../providers/favorite_recipes_provider.dart';
import '../providers/nutrition_provider.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _heartRed = Color(0xFFFF4D6D);

/// Phase 56 Lite · "Favorilerim" — the user's saved recipes hub.
///
/// Two responsibilities:
///   1. Render the list of recipes the user has hearted from the
///      detail screen, with quick links back into each.
///   2. Generate a deduplicated shopping list across every favourite
///      and hand it to the OS share sheet via share_plus.
///
/// We don't yet have a structured `ingredients` column on the
/// `recipes` table — Phase 56 Lite is explicitly avoiding that
/// schema lift. Instead the export aggregates each favourite's
/// title + macro line + (when present) the free-text instructions
/// preamble so the user gets a usable list. When the catalogue grows
/// an `ingredients` column we can swap the body builder without
/// touching call sites.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRecipesProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).favoritesTitle),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: recipesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _neon),
        ),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (allRecipes) {
          final saved = allRecipes
              .where((r) => favorites.contains(r.id))
              .toList(growable: false);
          if (saved.isEmpty) {
            // Roadmap Phase 2 (C37) · adds the CTA the old state lacked:
            // a user with no favourites needs a route to recipes, not
            // just a description of emptiness.
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: AppLocalizations.of(context).favoritesEmptyTitle,
              body: AppLocalizations.of(context).favoritesEmptyBody,
              ctaLabel: AppLocalizations.of(context).favoritesDiscoverCta,
              onCta: () => context.push(AppRoutes.nutritionDiscover),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _FavoriteRow(recipe: saved[i]),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _exportShoppingList(context, saved),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                      label: Text(AppLocalizations.of(context)
                          .favoritesBuildShoppingList),
                      style: FilledButton.styleFrom(
                        backgroundColor: _neon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportShoppingList(
    BuildContext context,
    List<Recipe> recipes,
  ) async {
    AppHaptics.primaryCta();
    final body = _buildShoppingListBody(AppLocalizations.of(context), recipes);
    AnalyticsService.instance.shoppingListExported(recipeCount: recipes.length);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: body,
          subject: AppLocalizations.of(context).shoppingListTitle,
        ),
      );
    } catch (e, st) {
      AppLogger.warning(
        'shopping list share failed: $e',
        category: 'favorites',
        data: {'stack': st.toString()},
      );
    }
  }

  /// Phase 57 · shopping-list body formatted to the PM's exact spec:
  ///
  ///     FormAI Öğün Malzemeleri
  ///     1) <Meal 1 Name>
  ///     Malzemeler:
  ///     - <Ingredient 1>
  ///     - <Ingredient 2>
  ///     2) <Meal 2 Name>
  ///     ...
  ///
  /// Per-recipe ingredients are sourced in priority order:
  /// Phase 7 · the per-recipe list comes from
  /// [recipeIngredientLines], which prefers the structured
  /// `recipe_ingredients` rows and falls back to the legacy blob. The
  /// local copy of that scan lived here and in `ShareService`, with a
  /// comment on both promising a refactor when a third caller appeared.
  /// It did. A placeholder still covers the genuinely-empty case so the
  /// recipient sees the title rather than a bare heading.
  String _buildShoppingListBody(AppLocalizations l10n, List<Recipe> recipes) {
    if (recipes.isEmpty) return l10n.favoritesShoppingListEmpty;
    final buf = StringBuffer()..writeln(l10n.favoritesIngredientsHeading);
    for (var i = 0; i < recipes.length; i++) {
      final r = recipes[i];
      buf
        ..writeln('${i + 1}) ${r.title}')
        ..writeln(l10n.shoppingListRecipeIngredients);
      final items = recipeIngredientLines(r);
      if (items.isEmpty) {
        buf.writeln(l10n.shoppingListPlaceholder);
      } else {
        for (final ing in items) {
          buf.writeln('- $ing');
        }
      }
    }
    return buf.toString().trimRight();
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/recipe', extra: recipe),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _Thumb(
                      imageUrl: recipe.imageUrl, mealType: recipe.mealType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).recipeMacroTimeLine(
                          recipe.calories,
                          recipe.protein,
                          recipe.prepTimeMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: _heartRed, size: 22),
                tooltip: AppLocalizations.of(context).favoritesRemove,
                onPressed: () async {
                  AppHaptics.secondaryTap();
                  await ref
                      .read(favoriteRecipesProvider.notifier)
                      .toggle(recipe.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
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
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 22),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return RecipeImage(
      url: src,
      // Phase 7 · lets the tile fall back to its meal type's cover
      // photograph rather than a gradient when the recipe's own image
      // has not been generated yet. See RecipeImageRegistry.
      mealType: mealType,
      fit: BoxFit.cover,
      memCacheHeight: 200,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context).recipesCatalogueLoadError,
            style: TextStyle(color: context.colors.onSurface),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).commonTryAgain)),
        ],
      ),
    );
  }
}
