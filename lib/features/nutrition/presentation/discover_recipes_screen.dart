import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/error_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'widgets/recipe_image.dart';
import '../domain/models/recipe.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Phase 47A · "Tüm Tarifler" discover screen.
///
/// Reuses the same filter chip catalogue as the Nutrition tab's
/// compact discovery strip (`Yüksek Protein / Düşük Kalori / Hacim /
/// Sıkılaşma / Vegan`) so users see a consistent filtering language
/// across the app. Reads from the same `recipesProvider` the tab
/// reads — no extra Supabase round-trip. The list is a 2-column grid
/// of recipe cards; every image goes through [CachedImage] so repeat
/// opens don't re-download.
///
/// Phase 48 · subscribes a `ScrollController` so the grid asks the
/// `recipesProvider` notifier for the next page once the user is
/// within ~600 px of the current bottom. Pages of 20 fit comfortably
/// inside the user's first scroll, so `loadMore` typically fires only
/// once before the catalogue is fully resident.
class DiscoverRecipesScreen extends ConsumerStatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  ConsumerState<DiscoverRecipesScreen> createState() =>
      _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends ConsumerState<DiscoverRecipesScreen> {
  // Phase 48 · selection persisted in `filterChipsProvider` so the
  // compact strip on the Beslenme tab and this dedicated grid stay in
  // lock-step. No more local `_activeFilter` field.
  final ScrollController _scrollController = ScrollController();

  /// Pixels from the bottom at which we kick off the next-page fetch.
  /// 600 px buys ~3 grid rows of head-room, so the user rarely sees a
  /// "loading more" spinner unless their connection is genuinely slow.
  static const double _loadMoreThreshold = 600;

  static const List<String> _filters = [
    'Yüksek Protein',
    'Düşük Kalori',
    'Hacim',
    'Sıkılaşma',
    'Vegan',
  ];

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

  /// Exact-match on the raw selected tag. Trim is already done inside
  /// `Recipe._parseTags`, and `toLowerCase` is deliberately avoided
  /// (Turkish İ/I case folding is locale-dependent, and the UI + DB
  /// both ship identical Title Case labels).
  List<Recipe> _apply(List<Recipe> source, String? activeTag) {
    if (activeTag == null) return source;
    return source.where((r) => r.tags.any((t) => t == activeTag)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final activeFilter = ref.watch(filterChipsProvider);
    // Phase 53F · drop the hardcoded `0xFF0B0B12` Scaffold + AppBar.
    final scheme = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          'Tüm Tarifler',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: recipesAsync.when(
        // Phase 49 · skeleton grid instead of a centred spinner so the
        // user sees the eventual layout shape immediately on cold open.
        loading: () => const RecipeGridSkeleton(),
        error: (err, st) {
          AppLogger.error(
            'DiscoverRecipesScreen error',
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
          final filtered = _apply(recipes, activeFilter)
            ..sort((a, b) => b.tags.length.compareTo(a.tags.length));
          final hasMore = ref.read(recipesProvider.notifier).hasMore;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _FilterRow(
                  filters: _filters,
                  active: activeFilter,
                  onTap: (label) {
                    // Phase 49 · subtle tactile feedback on chip toggles.
                    AppHaptics.secondaryTap();
                    ref.read(filterChipsProvider.notifier).toggle(label);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: _ResultCount(
                  count: filtered.length,
                  filter: activeFilter,
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverGrid.builder(
                    itemCount: filtered.length,
                    // Phase 58 · `mainAxisExtent` (fixed pixel height)
                    // was still throwing "Bottom Overflowed" on devices
                    // with very long titles + tag chips at text scale
                    // 1.3+, because the body section was forced into
                    // 110 dp and the chip strip alone needed 30+. The
                    // PM-spec'd refactor below moves to
                    // `childAspectRatio` (cell flexes with screen
                    // width), pins the image with `AspectRatio(16/9)`
                    // for a predictable thumb height, and lets the body
                    // grow into whatever's left via `Expanded`. Title
                    // is enforced to max 2 lines + ellipsis at the
                    // widget level so a single 60-char recipe name can
                    // never overshoot. 0.72 cell ratio gives ~129 dp
                    // body on a 360 dp screen — plenty for 2-line
                    // title + tags + macro row even at 1.3 text scale.
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) =>
                        _DiscoverRecipeCard(recipe: filtered[index]),
                  ),
                ),
              if (hasMore && filtered.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.active,
    required this.onTap,
  });

  final List<String> filters;
  final String? active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = filters[index];
          final selected = label == active;
          return _FilterChip(
            label: label,
            selected: selected,
            onTap: () => onTap(label),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53F · filter chip surface + border + label all flip with
    // the active theme. Selected chip stays neon-tinted (brand).
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: selected
                ? _neon.withValues(alpha: 0.25)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : scheme.surface),
            border: Border.all(
              color: selected
                  ? _neon
                  : (isDark ? Colors.white24 : scheme.outlineVariant),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.filter});
  final int count;
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final suffix = filter == null ? '' : ' · $filter';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Text(
        '$count tarif bulundu$suffix',
        style: TextStyle(
          color: context.colors.onSurface.withValues(alpha: 0.60),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DiscoverRecipeCard extends StatelessWidget {
  const _DiscoverRecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    // Phase 53F · grid card surface + border + title + macros all
    // route through onSurface so the discover gallery reads in light
    // mode. Brand-coloured kcal flame + protein dumbbell stay.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/recipe', extra: recipe),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
            ),
          ),
          // Phase 58 · the image is now pinned by `AspectRatio(16/9)`
          // — a predictable height that depends only on the cell width,
          // not on the parent's flex math. The body sits inside an
          // `Expanded` so it gets exactly the leftover space and can
          // never push past the cell boundary. With `childAspectRatio`
          // 0.72 on a 360 dp screen this yields ~88 dp image + ~129 dp
          // body, which fits a 2-line title + tag strip + macro row
          // even at 1.3 OS-level text scale.
          //
          // The body column starts content from the top
          // (`MainAxisSize.max` + default start alignment) and uses a
          // `Spacer` to pin the macro row to the bottom; this keeps
          // the visual rhythm consistent across cards regardless of
          // whether a title takes one line or two.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _Thumb(imageUrl: recipe.imageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
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
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: _neon,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.calories}',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.fitness_center,
                            color: _proteinColor,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.protein}g',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    // Phase 53F · thumb fallback flips with the active theme.
    final scheme = context.colors;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant,
        color: scheme.onSurface.withValues(alpha: 0.40),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
              Icons.restaurant_menu_rounded,
              color: _neon,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bu filtreye uygun tarif bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Farklı bir etiket deneyebilir veya filtreyi kaldırabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.onSurface.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
