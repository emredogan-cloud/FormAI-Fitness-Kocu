import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'branded_media_fallback.dart';

/// Phase 40: thin wrapper around [CachedNetworkImage] that centralises
/// the three things every call site cared about:
///
///   1. A dark placeholder so the hole while decoding doesn't flash white.
///   2. An `errorWidget` that pipes back to the caller's custom fallback
///      (most sites render a local icon / gradient panel when the URL
///      404s — we preserve that per-site look by taking a builder).
///   3. `memCacheHeight` tuning so thumbnails don't decode at full res
///      (800-px Unsplash photo in a 48-px `_Thumb` was the main cost).
///
/// Defaults aim at the common case (hero cards ~ 600 physical px). Pass
/// `memCacheHeight: 200` for small thumbnails.
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.memCacheHeight = 600,
    this.memCacheWidth,
    this.placeholder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  /// Max decoded bitmap height in **physical** pixels. 600 covers hero
  /// cards on a 3x device (~200 dp); drop to 200 for thumbnail tiles.
  final int memCacheHeight;
  final int? memCacheWidth;

  /// Shown while the image is fetching. Defaults to a flat dark panel
  /// (no shimmer animation — keeps the CPU quiet on scroll).
  final WidgetBuilder? placeholder;

  /// Rendered when the image fails to load. Same signature as
  /// `Image.network`'s `errorBuilder` for easy migration.
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      memCacheHeight: memCacheHeight,
      memCacheWidth: memCacheWidth,
      placeholder: (context, _) =>
          placeholder?.call(context) ?? const _DefaultPlaceholder(),
      errorWidget: (context, _, error) {
        final builder = errorBuilder;
        if (builder != null) return builder(context, error, StackTrace.current);
        return const _DefaultError();
      },
    );
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF14141B));
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError();

  @override
  Widget build(BuildContext context) {
    // Phase 57 · branded gradient + wordmark instead of the generic
    // broken-image icon. Affects every CachedImage call site that
    // doesn't pass its own `errorBuilder`. Sites that pass a custom
    // builder (recipe / plan thumbnails, etc.) keep their contextual
    // restaurant / fitness icons because those read better as
    // "expected empty state" at small sizes.
    return const BrandedMediaFallback();
  }
}
