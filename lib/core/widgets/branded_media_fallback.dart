import 'package:flutter/material.dart';

/// Phase 57 · branded fallback used everywhere a network image, video,
/// or other media asset fails to load.
///
/// Renders a subtle purple-blue gradient with the FormAI wordmark so a
/// missing recipe photo or broken workout-guide thumbnail reads as
/// "intentional empty state" rather than "Flutter rendered the
/// broken-image icon". Sized to fill the parent so it's a drop-in for
/// any `Image.network` / `CachedImage.errorBuilder` / video-error
/// widget — the parent's `BoxFit` controls the perceived dimensions.
///
/// `compact: true` swaps the wordmark for an "F" mark; useful for
/// thumbnail-sized slots (≤ 80 dp) where the full wordmark would
/// crowd out everything else.
class BrandedMediaFallback extends StatelessWidget {
  const BrandedMediaFallback({
    super.key,
    this.compact = false,
    this.icon,
  });

  final bool compact;

  /// Optional contextual icon stamped above the wordmark — for example
  /// `Icons.restaurant` on a recipe thumbnail or `Icons.fitness_center`
  /// on a plan card. Falls back to no icon (just the wordmark) when
  /// omitted, which keeps the fallback uncluttered for hero shots.
  final IconData? icon;

  static const Color _bgTop = Color(0xFF221145);
  static const Color _bgBottom = Color(0xFF0D0622);
  static const Color _accent = Color(0xFF8E5BFF);
  static const Color _accentSecondary = Color(0xFF4DA6FF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tiny =
                  constraints.maxHeight < 60 || constraints.maxWidth < 60;
              final showCompact = compact || tiny;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null && !tiny) ...[
                    Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: showCompact ? 22 : 28,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (showCompact)
                    const _BrandMark()
                  else
                    const _BrandWordmark(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [
            BrandedMediaFallback._accent,
            BrandedMediaFallback._accentSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'F',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [
                BrandedMediaFallback._accent,
                BrandedMediaFallback._accentSecondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'F',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'FormAI', // i18n-ignore — brand wordmark
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
