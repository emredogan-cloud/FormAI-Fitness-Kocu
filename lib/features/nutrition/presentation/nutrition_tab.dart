import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/cached_image.dart';
import '../domain/models/macro_target.dart';
import '../domain/models/recipe.dart';
import '../domain/services/next_best_meal_service.dart';
import '../providers/daily_menu_provider.dart';
import '../providers/nutrition_provider.dart';
import 'widgets/meal_plan_timeline.dart';
import 'widgets/recipe_tags.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonGreen = Color(0xFF39FF14);
const Color _warningColor = Color(0xFFFF5577);
const Color _proteinColor = Color(0xFF4DA6FF);
const Color _carbsColor = Color(0xFFFF4DDB);
const Color _fatColor = Color(0xFFEAFF00);

// Traffic-light palette for the calorie ring.
const Color _statusOnTrack = Color(0xFF39FF14);
const Color _statusLow = Color(0xFFEAFF00);
const Color _statusOver = Color(0xFFFF5577);

/// Phase 26 decision-first dashboard. Everything the user needs to act
/// on their day (calorie ring + AI prescription + next best meal with
/// a single green CTA) is packed into a `SliverAppBar` hero that
/// collapses to a persistent "1200 kcal kaldı | P %70" toolbar as the
/// user scrolls. Below the hero: the accordion meal timeline, then a
/// compact discovery strip.
///
/// Structural deltas from the pre-26 layout:
///   • No more `SingleChildScrollView` + `Column`. The tab is a
///     `CustomScrollView` with slivers so we can pin the hero.
///   • `_DailyDashboardHeader` / `_DailyScoreCard` / `_MacroStatusCard`
///     / the standalone `AiInsightBanner` / `NextBestMealCard` are all
///     gone — their content is absorbed into the one hero panel so
///     the user doesn't have to scroll past five separate cards to
///     make one decision.
class NutritionTab extends ConsumerWidget {
  const NutritionTab({super.key});

  /// Total expanded height of the hero sliver. Bumped in phase 27 to
  /// accommodate the restored Protein/Carbs/Fat macro bars between the
  /// calorie ring and the AI insight block.
  static const double _expandedHeight = 450;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    // Phase 49 · pull-to-refresh. Invalidates the recipe catalogue +
    // the daily-menu so a swipe-down on the Beslenme tab pulls fresh
    // rows from Supabase. Awaiting the recipe future keeps the
    // RefreshIndicator spinner visible until the first page actually
    // lands instead of dismissing instantly.
    Future<void> handleRefresh() async {
      ref.invalidate(recipesProvider);
      ref.invalidate(dailyMenuProvider);
      await ref.read(recipesProvider.future);
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      color: _neon,
      // Phase 53 hotfix · refresh chrome flips with the active theme.
      backgroundColor: context.colors.surface,
      child: CustomScrollView(
        slivers: [
          _DecisionPanelSliver(expandedHeight: _expandedHeight),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(title: 'Günün Menüsü'),
            ),
          ),
          const MealPlanSliver(),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(title: 'Öğün Kategorileri'),
            ),
          ),
          const SliverToBoxAdapter(child: _MealCategoriesSection()),
          const SliverToBoxAdapter(child: _DiscoverySectionHeader()),
          SliverToBoxAdapter(
            child: recipesAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: _neon),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (recipes) => _DiscoverySection(recipes: recipes),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

// ============================================================================
// Decision Panel Sliver — the hero. LayoutBuilder fades between the full
// expanded panel (calorie ring + AI insight + next-best preview + single
// green CTA) and the compact collapsed header ("1200 kcal kaldı | P %70")
// as the user scrolls.
// ============================================================================

class _DecisionPanelSliver extends ConsumerWidget {
  const _DecisionPanelSliver({required this.expandedHeight});
  final double expandedHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      // Phase 53 hotfix · was hardcoded `0xFF0B0B12`, leaving the
      // collapsed app-bar pinned to dark even after the theme flipped.
      // ColorScheme.surface is the right anchor for both modes.
      backgroundColor: context.colors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minH = topPadding + kToolbarHeight;
          final range = expandedHeight - minH;
          final t = range <= 0
              ? 1.0
              : ((constraints.maxHeight - minH) / range).clamp(0.0, 1.0);
          // Phase 53E · the dark gradient panel under the calorie ring +
          // macro bars was the real hero in dark mode but pinned the
          // entire top of the nutrition tab to black-purple in light
          // mode regardless of the SliverAppBar's `backgroundColor`.
          // Gate the gradient on `isDarkMode`; light mode falls through
          // to `surface` so the hero blends into the rest of the
          // scaffolded white surface.
          final isDark = context.isDarkMode;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? null : context.colors.surface,
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF14061F), Color(0xFF0B0B12)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                ),
              ),
              // Expanded panel fades out as the sliver collapses.
              Positioned(
                top: topPadding,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: t < 0.3,
                  child: Opacity(
                    opacity: t,
                    child: const _ExpandedDecisionPanel(),
                  ),
                ),
              ),
              // Compact header fades in as the sliver collapses.
              Positioned(
                top: topPadding,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: IgnorePointer(
                  ignoring: t > 0.7,
                  child: Opacity(
                    opacity: 1.0 - t,
                    child: const _CompactDecisionHeader(),
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

// ============================================================================
// Expanded panel content.
// ============================================================================

class _ExpandedDecisionPanel extends StatelessWidget {
  const _ExpandedDecisionPanel();

  /// Phase 48 · the panel itself is now stateless — each child block
  /// is a `Consumer` that subscribes to only the providers it actually
  /// reads. Previously `ref.watch(macroTargetProvider)` +
  /// `consumedMacrosProvider` + 3 others all rebuilt the entire panel
  /// (5 widgets, ~250 lines of build) every time any single field
  /// flipped. With per-block consumers + `.select()` slicing the
  /// header row only rebuilds when score/streak change, the macro
  /// bars only when the protein/carbs/fat ints change, etc.
  ///
  /// ClipRect + NeverScrollableScrollPhysics keeps the panel from
  /// throwing a RenderFlex overflow when the SliverAppBar shrinks
  /// toward its toolbar height during collapse — the scroll view
  /// absorbs the squeeze, the clip rect hides the lower content
  /// instead of painting it into the toolbar area.
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _DecisionHeaderRow(),
            SizedBox(height: 8),
            Center(child: _CalorieRing()),
            SizedBox(height: 10),
            _MacroBarsRow(),
            SizedBox(height: 10),
            _AiInsightRow(),
            SizedBox(height: 10),
            _NextMealPreview(),
          ],
        ),
      ),
    );
  }
}

/// Phase 27 restoration of the Protein/Carbs/Fat progress bars that
/// Phase 26 accidentally dropped. Three thin `LinearProgressIndicator`s
/// stacked tightly — each with its label + "{consumed}g / {target}g"
/// readout on the right side.
///
/// Phase 48 · each `_MacroBar` is its own `Consumer` that selects only
/// the two ints (target + consumed for that macro) it needs. Tapping
/// a "Yedim" on a high-protein meal therefore only rebuilds the
/// Protein bar, not Karb/Yağ, and never the calorie ring above.
///
/// Phase 52 · the whole strip is now an `InkWell` that routes to the
/// recipe-discovery screen so a user staring at a half-empty protein
/// bar gets a one-tap path to "find a recipe that fills this gap".
/// The inner bars stay non-interactive — wrapping each one separately
/// would clash with the Riverpod `select`s that already optimise their
/// rebuilds, and the whole-strip target is a bigger hit area anyway.
class _MacroBarsRow extends StatelessWidget {
  const _MacroBarsRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          AppHaptics.secondaryTap();
          context.push(AppRoutes.nutritionDiscover);
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MacroBar(
                label: 'Protein',
                color: _proteinColor,
                macro: _MacroField.protein,
              ),
              SizedBox(height: 6),
              _MacroBar(
                label: 'Karb',
                color: _carbsColor,
                macro: _MacroField.carbs,
              ),
              SizedBox(height: 6),
              _MacroBar(
                label: 'Yağ',
                color: _fatColor,
                macro: _MacroField.fat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MacroField { protein, carbs, fat }

class _MacroBar extends ConsumerWidget {
  const _MacroBar({
    required this.label,
    required this.color,
    required this.macro,
  });

  final String label;
  final Color color;
  final _MacroField macro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.select` so this bar only rebuilds when its specific macro int
    // changes — adding a high-protein meal won't invalidate the carb
    // or fat bars.
    final target = ref.watch(macroTargetProvider.select(_pick));
    final consumed = ref.watch(consumedMacrosProvider.select(_pick));
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    // Phase 53E · macro labels ("Protein", "Karb", "Yağ") + the
    // " / Ng" target tail flip with the active theme; the live
    // consumed value (`{N}g`) keeps the macro brand tint because it's
    // the live readout the user is watching.
    final scheme = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${consumed}g',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '/ ${target}g',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            // Phase 49 · 500 → 800 ms easeOutCubic so the macro bar
            // glides into its new value instead of snapping. Pairs
            // with the calorie ring's tween so the whole hero moves
            // as one.
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  int _pick(MacroTarget m) {
    switch (macro) {
      case _MacroField.protein:
        return m.protein;
      case _MacroField.carbs:
        return m.carbs;
      case _MacroField.fat:
        return m.fat;
    }
  }
}

class _DecisionHeaderRow extends ConsumerWidget {
  const _DecisionHeaderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.select` so this row only rebuilds when score or streak flips,
    // not on every macro update.
    final score = ref.watch(dailyScoreProvider);
    final streak = ref.watch(nutritionStreakProvider);
    final tint = _scoreTint(score);
    // Phase 53C · "Bugün" header + date were hardcoded white, leaving
    // them invisible on the light-mode panel. onSurface flips both.
    final scheme = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bugün',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              Text(
                _formatTurkishDate(DateTime.now()),
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _InlinePill(
          label: '$score / 100',
          icon: Icons.emoji_events,
          tint: tint,
        ),
        const SizedBox(width: 6),
        _InlinePill(
          label: '$streak Gün',
          leadingEmoji: '🔥',
          tint: const Color(0xFFFF8A00),
        ),
      ],
    );
  }

  static Color _scoreTint(int score) {
    if (score >= 80) return _statusOnTrack;
    if (score >= 50) return _statusLow;
    return _statusOver;
  }
}

class _InlinePill extends StatelessWidget {
  const _InlinePill({
    required this.label,
    required this.tint,
    this.icon,
    this.leadingEmoji,
  });

  final String label;
  final Color tint;
  final IconData? icon;
  final String? leadingEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: tint.withValues(alpha: 0.18),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingEmoji != null) ...[
            Text(leadingEmoji!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, color: tint, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              // Phase 53E · the score / streak pills sit on a
              // tint-tinted translucent background. White text reads
              // on dark mode (tint × 18 % over darkBg) but vanishes on
              // light mode (tint × 18 % over white). onSurface gives
              // us legible contrast on both.
              color: context.colors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieRing extends ConsumerWidget {
  const _CalorieRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.select` two ints — adding a meal that touches only protein
    // shouldn't repaint the calorie ring's CircularProgressIndicator.
    final targetCalories =
        ref.watch(macroTargetProvider.select((m) => m.calories));
    final consumedCalories =
        ref.watch(consumedMacrosProvider.select((m) => m.calories));
    final progress =
        targetCalories <= 0 ? 0.0 : consumedCalories / targetCalories;
    final color = _colorForProgress(progress);
    final clamped = progress.clamp(0.0, 1.0);
    final remaining = targetCalories - consumedCalories;
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              // Phase 49 · 600 → 800 ms easeOutCubic. The longer arc
              // gives the eye time to track the ring sweep when a
              // user marks a meal complete and the calorie progress
              // jumps by ~10 % in one tick.
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                // Phase 53I · the unfilled ring track was tinted with the
                // status color × 14 % alpha — fine on the dark gradient
                // hero, invisible on the white light-mode surface where
                // a near-zero kcal day collapsed the whole ring out of
                // view. Theme-aware grey gives a visible track on both.
                backgroundColor: context.isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumedCalories',
                style: TextStyle(
                  // Phase 53E · the centre kcal counter inside the
                  // ring was the most prominent ghost — pure white on
                  // a now-light background. onSurface keeps it bright
                  // in dark mode and charcoal in light.
                  color: context.colors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.6), blurRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '/ $targetCalories kcal',
                style: TextStyle(
                  color: context.colors.onSurface.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _remainingLabel(remaining),
                style: TextStyle(
                  // Phase 53I · "X kcal kaldı" was painted in the live
                  // status tint (neon green / yellow / pink). On the
                  // light-mode white scaffold the neon-green/yellow tones
                  // washed out completely. onSurface keeps the readout
                  // legible on both palettes; the ring sweep already
                  // carries the status colour.
                  color: context.colors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _colorForProgress(double progress) {
    if (progress > 1.0) return _statusOver;
    if (progress < 0.5) return _statusLow;
    return _statusOnTrack;
  }

  static String _remainingLabel(int remaining) {
    if (remaining > 0) return '$remaining kcal kaldı';
    if (remaining < 0) return '${-remaining} kcal aşıldı';
    return 'hedef tam';
  }
}

class _AiInsightRow extends ConsumerWidget {
  const _AiInsightRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final suggestion = ref.watch(nextBestMealProvider);
    final copy = _buildCopy(target, consumed, suggestion);
    // Phase 53E · "Protein hedefini kaçırıyorsun" warning + the fix
    // line below it both flip with the active theme.
    final scheme = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome, color: _neon, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                copy.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '→ ',
                    style: TextStyle(
                      color: _neon,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      copy.fix,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mirror of `buildCoachCopy` from the old standalone banner, kept
  /// local to the hero so the panel stays self-contained. Rules match
  /// the phase 25.2 spec verbatim.
  static ({String message, String fix}) _buildCopy(
    MacroTarget target,
    MacroTarget consumed,
    NextMealRecommendation? suggestion,
  ) {
    final overage = consumed.calories - target.calories;
    if (target.calories > 0 && overage > 0) {
      return (
        message: '$overage kcal fazla aldın.',
        fix: 'Akşam karbonhidratı azalt veya 20 dk yürüyüş yap.',
      );
    }
    if (target.protein > 0 && consumed.protein < target.protein * 0.6) {
      return (
        message: 'Protein hedefini kaçırıyorsun.',
        fix: 'Tavuk/Balık bazlı bir ana öğün ekle.',
      );
    }
    final remainingCalories = target.calories - consumed.calories;
    if (remainingCalories > 0 && remainingCalories < 400) {
      return (
        message: 'Az kalorin kaldı, ölçülü devam.',
        fix: suggestion != null
            ? '${suggestion.recipe.title} senin için uygun.'
            : 'Hafif bir ara öğün seç.',
      );
    }
    if (suggestion != null) {
      return (
        message: 'Dengeyi koru.',
        fix: 'Sonraki adım: ${suggestion.recipe.title}.',
      );
    }
    return const (
      message: 'Harika gidiyorsun!',
      fix: 'Hedeflerine sadık kal.',
    );
  }
}

/// Next-best-meal preview strip inside the hero. One neon-bordered
/// row with thumb + title + impact string + the single primary CTA
/// (swapped for a warning outline when the user is already over
/// their daily calorie target).
///
/// Phase 48 · self-watching consumer. Reads `nextBestMealProvider`
/// directly so the surrounding panel doesn't have to thread it
/// through; renders an empty `SizedBox.shrink` while the catalogue is
/// still loading or there's no suggestion to show.
class _NextMealPreview extends ConsumerWidget {
  const _NextMealPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(nextBestMealProvider);
    if (recommendation == null) return const SizedBox.shrink();
    // `.select` two ints — overCalories only flips when the user
    // crosses the target line, not on every protein increment.
    final targetCalories =
        ref.watch(macroTargetProvider.select((m) => m.calories));
    final consumedCalories =
        ref.watch(consumedMacrosProvider.select((m) => m.calories));
    final overCalories =
        targetCalories > 0 && consumedCalories >= targetCalories;
    final recipe = recommendation.recipe;
    // Phase 53E · the next-meal preview strip flips its surface and
    // the recipe title + impact string with the active theme.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        border: Border.all(color: _neonGreen.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _neonGreen.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _Thumb(imageUrl: recipe.imageUrl),
            ),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recommendation.impactString,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.70),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          overCalories
              ? _WarningCta(recipe: recipe)
              : _PrimaryHemenEkleButton(
                  onPressed: () => _addToPlan(context, ref, recipe),
                ),
        ],
      ),
    );
  }

  void _addToPlan(BuildContext context, WidgetRef ref, Recipe recipe) {
    // "Hemen Ekle" — primary CTA on the next-best-meal preview.
    AppHaptics.primaryCta();
    ref
        .read(dailyMenuProvider.notifier)
        .addRecipeToPlan(recipe, recipe.mealType);
    // Phase 49 · the SnackBar inherits the global theme (floating
    // chrome + neon hairline border), so we no longer override
    // backgroundColor / behavior locally — let the theme drive it for
    // visual consistency across the app.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${recipe.title} plana eklendi!')),
      );
  }
}

class _PrimaryHemenEkleButton extends StatelessWidget {
  const _PrimaryHemenEkleButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 14),
      label: const Text('Hemen Ekle'),
      style: FilledButton.styleFrom(
        backgroundColor: _neonGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _WarningCta extends StatelessWidget {
  const _WarningCta({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        AppHaptics.secondaryTap();
        context.push('/recipe', extra: recipe);
      },
      icon: const Icon(Icons.cancel_outlined, size: 14),
      label: const Text('Hafif Alternatif'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _warningColor,
        side: const BorderSide(color: _warningColor, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
    final fallback = Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, color: Colors.white54, size: 22),
    );
    final src = imageUrl;
    if (src == null || src.isEmpty) return fallback;
    return CachedImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 200,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

// ============================================================================
// Collapsed compact header
// ============================================================================

class _CompactDecisionHeader extends ConsumerWidget {
  const _CompactDecisionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 48 · `.select` four ints (target/consumed × calories/protein)
    // so this collapsed header only rebuilds when one of those four
    // numbers actually changes. Adding a meal that touches carbs +
    // fat won't repaint the strip.
    final targetCalories =
        ref.watch(macroTargetProvider.select((m) => m.calories));
    final consumedCalories =
        ref.watch(consumedMacrosProvider.select((m) => m.calories));
    final targetProtein =
        ref.watch(macroTargetProvider.select((m) => m.protein));
    final consumedProtein =
        ref.watch(consumedMacrosProvider.select((m) => m.protein));
    final remaining = targetCalories - consumedCalories;
    final remainingLabel =
        remaining >= 0 ? '$remaining kcal kaldı' : '${-remaining} kcal aşıldı';
    final proteinRatio = targetProtein > 0
        ? (consumedProtein / targetProtein).clamp(0.0, 1.0)
        : 0.0;
    final proteinPct = (proteinRatio * 100).round();

    // Phase 53E · the collapsed app-bar strip — readable in both
    // palettes via onSurface.
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: _statusOnTrack,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            remainingLabel,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 14,
            color: scheme.onSurface.withValues(alpha: 0.24),
          ),
          const SizedBox(width: 12),
          Text(
            'P %$proteinPct',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                // Phase 49 · 500 → 800 ms easeOutCubic to match the
                // expanded panel's bars + ring.
                tween: Tween(begin: 0, end: proteinRatio),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: _proteinColor.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(_proteinColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Section title reused by both timeline + discovery headings.
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Phase 53C · "Günün Menüsü" / "Öğün Kategorileri" / "Tarif Keşfet"
    // headings — pull onSurface so they stay legible in both palettes.
    return Text(
      title,
      style: TextStyle(
        color: context.colors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ============================================================================
// Compact recipe discovery section. Title row shows "Tarif Keşfet" +
// "Tümünü Gör" (phase 26 spec), followed by a short horizontal list.
// Filter chips dropped in phase 26 — full filtering lives on the future
// "Tümünü Gör" screen.
// ============================================================================

class _DiscoverySectionHeader extends StatelessWidget {
  const _DiscoverySectionHeader();

  // Phase 47A · "Tümünü Gör" restored. Routes to
  // /nutrition/discover, a dedicated grid that carries over the same
  // tag-filter chips used by the compact strip below, and renders
  // every thumbnail through `CachedImage` so repeat visits don't
  // re-download.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _SectionTitle(title: 'Tarif Keşfet'),
          _DiscoverAllPill(
            onTap: () => context.push('/nutrition/discover'),
          ),
        ],
      ),
    );
  }
}

class _DiscoverAllPill extends StatelessWidget {
  const _DiscoverAllPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: _neon.withValues(alpha: 0.10),
            border: Border.all(color: _neon.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tümünü Gör',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                color: _neon.withValues(alpha: 0.9),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 48 · the chip-selection state moved out of this widget into
/// `filterChipsProvider`, so this surface and the dedicated
/// /nutrition/discover screen share the same selection. Now a
/// stateless `ConsumerWidget` — no setState, no per-tab cache.
class _DiscoverySection extends ConsumerWidget {
  const _DiscoverySection({required this.recipes});
  final List<Recipe> recipes;

  static const List<String> _filters = [
    'Yüksek Protein',
    'Düşük Kalori',
    'Hacim',
    'Sıkılaşma',
    'Vegan',
  ];

  /// Strict `==` against the raw selected tag — no `trim`, no
  /// `toLowerCase`. Trim already happens inside [Recipe._parseTags],
  /// so both sides of the compare are already clean; adding it here
  /// would only hide a real bug. Dart's Turkish İ/I case folding is
  /// locale-dependent so `toLowerCase` is deliberately avoided; UI
  /// and DB both use identical Title Case.
  List<Recipe> _apply(List<Recipe> source, String? activeTag) {
    if (activeTag == null) return source;
    return source.where((r) => r.tags.any((t) => t == activeTag)).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(filterChipsProvider);
    // Prioritise tagged recipes first so curated content floats to the
    // start of the strip. `filteredRecipes` is what the horizontal
    // strip iterates over — bound explicitly so tapping a chip and
    // re-running [_apply] flows straight through to the ListView.
    final filteredRecipes = _apply(recipes, active)
      ..sort((a, b) => b.tags.length.compareTo(a.tags.length));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _filters[index];
              final selected = label == active;
              return _DiscoveryFilterChip(
                label: label,
                selected: selected,
                onTap: () {
                  // Phase 49 · subtle tactile feedback on chip toggles.
                  AppHaptics.secondaryTap();
                  ref.read(filterChipsProvider.notifier).toggle(label);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (filteredRecipes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyState(
              message: 'Bu filtreye uygun tarif bulunamadı.',
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredRecipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _CompactDiscoveryCard(recipe: filteredRecipes[index]),
            ),
          ),
      ],
    );
  }
}

class _DiscoveryFilterChip extends StatelessWidget {
  const _DiscoveryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53C · filter chip surface + text + border now flip with
    // the active theme. Selected chip stays neon-tinted; the
    // unselected chip uses an onSurface-derived tint that's visible
    // on both palettes.
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

/// Phase 27 — horizontal row of tappable category cards. Each card
/// routes to `/nutrition/category/{type}` where the screen lists all
/// recipes matching that meal-type bucket.
///
/// Rendered as a StatelessWidget because the cards have no local
/// state; each tap goes straight through `context.push`.
class _MealCategoriesSection extends StatelessWidget {
  const _MealCategoriesSection();

  /// Category entries pair each Turkish display label with the
  /// lowercase English `meal_type` the DB stores. The route push uses
  /// the English `type`; [CategoryRecipesScreen] compares it against
  /// `r.mealType == type` with strict equality. URLs are the verbatim
  /// list from the phase 30 spec — one per category, each tested to
  /// resolve against Unsplash.
  static const List<_CategoryEntry> _categories = [
    _CategoryEntry(
      label: 'Kahvaltı',
      type: 'breakfast',
      tint: Color(0xFFFFB84D),
      // Phase 31 reverted to the Phase 29 breakfast URL (the one on the
      // spec in Phase 30 was 404-ing on test devices).
      imageUrl:
          'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=600&q=80',
    ),
    _CategoryEntry(
      label: 'Öğle Yemeği',
      type: 'lunch',
      tint: Color(0xFF4DA6FF),
      imageUrl:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80',
    ),
    _CategoryEntry(
      label: 'Akşam Yemeği',
      type: 'dinner',
      tint: Color(0xFF8E5BFF),
      imageUrl:
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80',
    ),
    _CategoryEntry(
      label: 'Ara Öğün',
      type: 'snack',
      tint: Color(0xFF39FF14),
      imageUrl:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80',
    ),
    _CategoryEntry(
      label: 'Sporcu Tatlısı',
      type: 'dessert',
      tint: Color(0xFFFF4DDB),
      imageUrl:
          'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _MealCategoryCard(
          entry: _categories[index],
        ),
      ),
    );
  }
}

class _CategoryEntry {
  const _CategoryEntry({
    required this.label,
    required this.type,
    required this.tint,
    required this.imageUrl,
  });
  final String label;
  final String type;
  final Color tint;
  final String imageUrl;
}

class _MealCategoryCard extends StatelessWidget {
  const _MealCategoryCard({required this.entry});
  final _CategoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/nutrition/category/${entry.type}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1 — background image. Network fetch with a
              // neutral fallback gradient so an offline user still
              // sees a tappable tinted tile instead of a broken icon.
              CachedImage(
                url: entry.imageUrl,
                fit: BoxFit.cover,
                memCacheHeight: 400,
                errorBuilder: (_, __, ___) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        entry.tint.withValues(alpha: 0.55),
                        entry.tint.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              // Layer 2 — dark gradient overlay for text legibility.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.2, 1.0],
                  ),
                ),
              ),
              // Layer 3 — subtle tinted border that picks up the
              // category's brand colour without fighting the photo.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: entry.tint.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              // Layer 4 — label pinned to the bottom with a shadow so
              // it holds its own against bright photography.
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black87),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDiscoveryCard extends StatelessWidget {
  const _CompactDiscoveryCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/recipe', extra: recipe),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumb(imageUrl: recipe.imageUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.35, 0.65, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: RecipeTagsStrip(
                  recipe: recipe,
                  maxTags: 1,
                  compact: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black87),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${recipe.calories} kcal · ${recipe.protein}g P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }
}

// ============================================================================
// Helpers
// ============================================================================

/// Formats as e.g. "Çar 22 Nisan" — short form to fit in the hero header row.
String _formatTurkishDate(DateTime d) {
  const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final day = days[d.weekday - 1];
  final month = months[d.month - 1];
  return '$day ${d.day} $month';
}
