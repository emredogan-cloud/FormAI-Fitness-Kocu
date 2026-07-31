import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Phase 49 · shimmer-driven skeleton placeholders.
///
/// Drop-in replacements for `CircularProgressIndicator` while a future
/// is in flight. The shimmer sweep matches the dark surface palette
/// (`AppColors.surface` base, slightly lighter highlight) so the
/// placeholder reads as "loading content" rather than "loading icon",
/// and the layout slot stays the right shape so the page doesn't jump
/// when real data lands.
///
/// Two primitives:
///
///   • [SkeletonBox] — rectangular block with rounded corners. Use for
///     thumbnails, card bodies, or any chunk of content that will
///     resolve to a coloured surface.
///   • [SkeletonLine] — single-line text placeholder (slightly shorter
///     by default to mimic the ragged right edge of typeset prose).
///
/// Both honour the `width` / `height` / `borderRadius` overrides so
/// callers can size them to match the eventual content. A central
/// `Shimmer.fromColors` ancestor isn't required — each leaf wraps its
/// own shimmer so callers can drop the widgets anywhere without
/// thinking about ancestry.

const Color _kShimmerBase = AppColors.surface;
const Color _kShimmerHighlight = Color(0xFF22222B);

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _kShimmerBase,
      highlightColor: _kShimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kShimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.widthFactor = 0.7,
    this.height = 12,
  });

  /// Fraction of the parent's max-width the line should occupy. 0.7
  /// (the default) leaves a 30 % gap at the end so a column of skeleton
  /// lines feels like ragged-right body copy rather than a justified
  /// block.
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: SkeletonBox(height: height, borderRadius: 6),
    );
  }
}

/// 2-column recipe-grid skeleton used by `discover_recipes_screen` and
/// any future "tarif keşfet" surface. Renders [count] placeholder
/// cards (default 6 — fills a 360-px viewport without scrolling).
class RecipeGridSkeleton extends StatelessWidget {
  const RecipeGridSkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 252,
      ),
      itemBuilder: (_, __) => const _RecipeCardSkeleton(),
    );
  }
}

class _RecipeCardSkeleton extends StatelessWidget {
  const _RecipeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image slot — flex 3 mirrors the live card's split.
          Expanded(flex: 3, child: SkeletonBox(borderRadius: 0)),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLine(widthFactor: 0.85, height: 12),
                  SkeletonLine(widthFactor: 0.55, height: 10),
                  SkeletonLine(widthFactor: 0.4, height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5×6 grid of muted square placeholders sized to match the Gelişim
/// tab's day-grid. Used while `workoutSessionProvider` is still
/// resolving on cold start so the screen lays out its full chrome
/// instead of jumping when the data lands.
class DayGridSkeleton extends StatelessWidget {
  const DayGridSkeleton({super.key, this.count = 30});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, __) => const SkeletonBox(borderRadius: 12),
    );
  }
}

/// Stack of placeholder rows that mimics the plan-detail exercise
/// list while the program loads. Each row is a 64-px tall block so
/// the count + spacing matches the live list's rhythm.
class ExerciseListSkeleton extends StatelessWidget {
  const ExerciseListSkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _ExerciseRowSkeleton(),
    );
  }
}

class _ExerciseRowSkeleton extends StatelessWidget {
  const _ExerciseRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonLine(widthFactor: 0.7, height: 13),
                SizedBox(height: 8),
                SkeletonLine(widthFactor: 0.45, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
