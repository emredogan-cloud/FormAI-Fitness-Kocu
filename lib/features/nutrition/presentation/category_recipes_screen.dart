import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/error_card.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Dedicated "all recipes in this meal category" screen pushed via
/// `/nutrition/category/:type`. Reads the same `recipesProvider` the
/// nutrition tab uses, filters by category, and renders a scrollable
/// list. Tapping a card opens the existing [RecipeDetailScreen] with
/// `context.push('/recipe', extra: recipe)`.
///
/// Phase 48 · stateful so a `ScrollController` can drive pagination
/// against the paginated `recipesProvider`. When the user scrolls
/// within ~600 px of the bottom, the notifier fetches the next page
/// from Supabase via `.range(from, to)` instead of pulling the whole
/// catalogue eagerly.
class CategoryRecipesScreen extends ConsumerStatefulWidget {
  const CategoryRecipesScreen({super.key, required this.categoryType});

  /// Route path parameter. One of: `breakfast`, `lunch`, `dinner`,
  /// `snack`, `dessert`. Unknown values render an empty state rather
  /// than crashing.
  final String categoryType;

  @override
  ConsumerState<CategoryRecipesScreen> createState() =>
      _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends ConsumerState<CategoryRecipesScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _loadMoreThreshold = 600;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels + _loadMoreThreshold >= position.maxScrollExtent) {
      ref.read(recipesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
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
          _titleFor(widget.categoryType),
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
          );
          return ErrorCard(
            message: 'Tarifler yüklenirken bir sorun oluştu.',
            onRetry: () => ref.invalidate(recipesProvider),
          );
        },
        data: (recipes) {
          final filtered = _filter(recipes, widget.categoryType);
          if (filtered.isEmpty) {
            return _EmptyCategoryState(category: widget.categoryType);
          }
          final hasMore = ref.read(recipesProvider.notifier).hasMore;
          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: filtered.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= filtered.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _neon,
                      ),
                    ),
                  ),
                );
              }
              return _CategoryRecipeCard(recipe: filtered[index]);
            },
          );
        },
      ),
    );
  }

  /// Maps the route param to the Turkish AppBar title. Unknown values
  /// fall back to a generic "Tarifler" so a malformed deeplink still
  /// renders a sensible header.
  static String _titleFor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return 'Kahvaltı Tarifleri';
      case 'lunch':
        return 'Öğle Yemeği Tarifleri';
      case 'dinner':
        return 'Akşam Yemeği Tarifleri';
      case 'snack':
        return 'Ara Öğün Tarifleri';
      case 'dessert':
        return 'Sporcu Tatlıları';
      default:
        return 'Tarifler';
    }
  }

  /// Exact-match filter (phase 30). No more trim/`toLowerCase` —
  /// Dart's case folding on Turkish characters isn't guaranteed to
  /// round-trip (İ / i / I / ı), and the seed + route both use
  /// identical lowercase English tokens (`breakfast`, `lunch`,
  /// `dinner`, `snack`, `dessert`), so a direct `==` compare is
  /// cleaner and can never silently fail on Unicode edge cases.
  static List<Recipe> _filter(List<Recipe> recipes, String type) {
    return recipes.where((r) => r.mealType == type).toList();
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
                            '${recipe.calories} kcal',
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
                            '${recipe.protein}g P',
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
    return CachedImage(
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
            'Bu kategoride henüz tarif yok.',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Bu kategoriye uygun tarif bulunamadı ($category).',
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
