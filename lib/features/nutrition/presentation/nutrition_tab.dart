import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  /// Total expanded height of the hero sliver. Tuned to fit calorie
  /// ring + AI insight + next-best preview + CTA on a 6.1" phone
  /// without clipping.
  static const double _expandedHeight = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    return CustomScrollView(
      slivers: [
        _DecisionPanelSliver(expandedHeight: _expandedHeight),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(title: 'Günün Menüsü'),
          ),
        ),
        const MealPlanSliver(),
        SliverToBoxAdapter(
          child: _DiscoverySectionHeader(
            onSeeAll: () => _showComingSoon(context),
          ),
        ),
        SliverToBoxAdapter(
          child: recipesAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: _neon),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (recipes) => _DiscoveryStrip(recipes: recipes),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tüm tarif keşfi yakında!'),
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: const Color(0xFF0B0B12),
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
          return Stack(
            children: [
              // Always-present dark panel background so the status bar
              // stays dark through the collapse transition.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF14061F), Color(0xFF0B0B12)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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

class _ExpandedDecisionPanel extends ConsumerWidget {
  const _ExpandedDecisionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final score = ref.watch(dailyScoreProvider);
    final streak = ref.watch(nutritionStreakProvider);
    final recommendation = ref.watch(nextBestMealProvider);
    final overCalories =
        target.calories > 0 && consumed.calories >= target.calories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DecisionHeaderRow(score: score, streak: streak),
          const SizedBox(height: 8),
          _CalorieRing(target: target, consumed: consumed),
          const SizedBox(height: 10),
          _AiInsightRow(
            target: target,
            consumed: consumed,
            suggestion: recommendation,
          ),
          const Spacer(),
          if (recommendation != null)
            _NextMealPreview(
              recommendation: recommendation,
              overCalories: overCalories,
            ),
        ],
      ),
    );
  }
}

class _DecisionHeaderRow extends StatelessWidget {
  const _DecisionHeaderRow({required this.score, required this.streak});
  final int score;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final tint = _scoreTint(score);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bugün',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              Text(
                _formatTurkishDate(DateTime.now()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
            style: const TextStyle(
              color: Colors.white,
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

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.target, required this.consumed});
  final MacroTarget target;
  final MacroTarget consumed;

  @override
  Widget build(BuildContext context) {
    final progress =
        target.calories <= 0 ? 0.0 : consumed.calories / target.calories;
    final color = _colorForProgress(progress);
    final clamped = progress.clamp(0.0, 1.0);
    final remaining = target.calories - consumed.calories;
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${consumed.calories}',
                style: TextStyle(
                  color: Colors.white,
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
                '/ ${target.calories} kcal',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _remainingLabel(remaining),
                style: TextStyle(
                  color: color,
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

class _AiInsightRow extends StatelessWidget {
  const _AiInsightRow({
    required this.target,
    required this.consumed,
    required this.suggestion,
  });

  final MacroTarget target;
  final MacroTarget consumed;
  final NextMealRecommendation? suggestion;

  @override
  Widget build(BuildContext context) {
    final copy = _buildCopy(target, consumed, suggestion);
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
                style: const TextStyle(
                  color: Colors.white,
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
                      style: const TextStyle(
                        color: Colors.white70,
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
class _NextMealPreview extends ConsumerWidget {
  const _NextMealPreview({
    required this.recommendation,
    required this.overCalories,
  });

  final NextMealRecommendation recommendation;
  final bool overCalories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = recommendation.recipe;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
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
                  style: const TextStyle(
                    color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white70,
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
    HapticFeedback.mediumImpact();
    ref
        .read(dailyMenuProvider.notifier)
        .addRecipeToPlan(recipe, recipe.mealType);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${recipe.title} plana eklendi!'),
          backgroundColor: _neonGreen.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
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
        HapticFeedback.lightImpact();
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
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: Colors.white10),
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
    final target = ref.watch(macroTargetProvider);
    final consumed = ref.watch(consumedMacrosProvider);
    final remaining = target.calories - consumed.calories;
    final remainingLabel =
        remaining >= 0 ? '$remaining kcal kaldı' : '${-remaining} kcal aşıldı';
    final proteinRatio = target.protein > 0
        ? (consumed.protein / target.protein).clamp(0.0, 1.0)
        : 0.0;
    final proteinPct = (proteinRatio * 100).round();

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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 14, color: Colors.white24),
          const SizedBox(width: 12),
          Text(
            'P %$proteinPct',
            style: const TextStyle(
              color: Colors.white70,
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
                tween: Tween(begin: 0, end: proteinRatio),
                duration: const Duration(milliseconds: 500),
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
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
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
  const _DiscoverySectionHeader({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 8),
      child: Row(
        children: [
          const _SectionTitle(title: 'Tarif Keşfet'),
          const Spacer(),
          TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Tümünü Gör'),
            style: TextButton.styleFrom(
              foregroundColor: _neon,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryStrip extends StatelessWidget {
  const _DiscoveryStrip({required this.recipes});
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    // Prioritise recipes with explicit curated tags first; fall back to
    // any recipe so the strip is never empty once the catalogue loads.
    final items = recipes.toList()
      ..sort((a, b) => b.tags.length.compareTo(a.tags.length));
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(message: 'Keşfedilecek tarif yok — yakında.'),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _CompactDiscoveryCard(
          recipe: items[index],
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
