import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/error_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'widgets/recipe_image.dart';
import '../domain/models/recipe.dart';
import '../domain/recipe_tag_token.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/recipe_tags.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _proteinColor = Color(0xFF4DA6FF);

/// Phase 47A · "Tüm Tarifler" discover screen.
///
/// Reuses the same filter chip catalogue as the Nutrition tab's
/// compact discovery strip ([kRecipeFilterTokens]) so users see a
/// consistent filtering language across the app. Reads from the same `recipesProvider` the tab
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

  /// Phase 7 · exact-match on the selected [kRecipeFilterTokens] token, not
  /// on a Turkish display label. Trim is already done inside
  /// `Recipe._parseTags`, and `toLowerCase` is deliberately avoided —
  /// Turkish İ/I case folding is locale-dependent, which is the class of
  /// bug the token split removes at the root.
  List<Recipe> _apply(List<Recipe> source, String? activeToken) {
    if (activeToken == null) return source;
    return source.where((r) => r.tagTokens.contains(activeToken)).toList();
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
          AppLocalizations.of(context).recipesAll,
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
            message: AppLocalizations.of(context).recipesLoadError,
            onRetry: () => ref.invalidate(recipesProvider),
          );
        },
        data: (recipes) {
          final filtered = _apply(recipes, activeFilter)
            ..sort((a, b) => b.tagTokens.length.compareTo(a.tagTokens.length));
          final hasMore = ref.read(recipesProvider.notifier).hasMore;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _FilterRow(
                  active: activeFilter,
                  onTap: (token) {
                    // Phase 49 · subtle tactile feedback on chip toggles.
                    AppHaptics.secondaryTap();
                    ref.read(filterChipsProvider.notifier).toggle(token);
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  // Roadmap Phase 2 (C37) · the CTA clears the filter that
                  // produced the empty result, which is the action the
                  // user actually wants.
                  child: EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: AppLocalizations.of(context).recipesNoneForFilter,
                    body: AppLocalizations.of(context).recipesTryAnotherTag,
                    ctaLabel: activeFilter == null
                        ? null
                        : AppLocalizations.of(context).recipesClearFilter,
                    // `toggle` on the active chip is already the clear
                    // operation (see FilterChipsNotifier) — no need for a
                    // second method that does the same thing.
                    onCta: activeFilter == null
                        ? null
                        : () => ref
                            .read(filterChipsProvider.notifier)
                            .toggle(activeFilter),
                  ),
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
    required this.active,
    required this.onTap,
  });

  /// The selected [kRecipeFilterTokens] token, or null for "no filter".
  final String? active;

  /// Called with the tapped **token**, never the label — the label is
  /// what the user reads and changes with the language; the token is
  /// what the filter compares.
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: kRecipeFilterTokens.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final token = kRecipeFilterTokens[index];
          return _FilterChip(
            label: recipeTagLabel(l10n, token) ?? token,
            selected: token == active,
            onTap: () => onTap(token),
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

  /// The active [kRecipeFilterTokens] token, or null. Phase 7 · this used
  /// to be the Turkish label and was interpolated straight into the
  /// count line; a raw `high_protein` in that position would be a
  /// database identifier printed at the user.
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final label = filter == null
        ? null
        : recipeTagLabel(AppLocalizations.of(context), filter!);
    final suffix = label == null ? '' : ' · $label';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Text(
        '${AppLocalizations.of(context).recipesFound(count)}$suffix',
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
                            AppLocalizations.of(context)
                                .macroProteinGrams(recipe.protein),
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
