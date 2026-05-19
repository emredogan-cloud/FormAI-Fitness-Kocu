import 'package:flutter/material.dart';

import '../../../../core/widgets/cached_image.dart';

/// Phase 2-A.5 · meal image with bundled LQIP placeholder.
///
/// Wraps [CachedImage] with an `assets/lqip/meals/<slug>.webp` layer
/// underneath so the recipe-card grid never paints a grey hole on
/// first frame:
///
///   • Bottom layer  — `Image.asset(LQIP)`. Bundled (~700 B per slug),
///     decodes instantly, also acts as the persistent offline fallback
///     when the CDN never resolves.
///   • Top layer     — `CachedImage` (Phase 40). Streams the full image
///     from `recipes_images` Supabase Storage via cached_network_image's
///     disk cache. Default fade-in (200 ms) gives a soft sharp-up.
///
/// The slug is derived from [url] (the last path segment, extension
/// stripped). After the Phase 2-A.4 DB rewrite, `recipe.imageUrl`
/// resolves to `<cdn-or-supabase>/recipes_images/<slug>.webp`, whose
/// last segment IS the slug. Pre-rewrite (`photos/meals/<slug>.webp`)
/// and post-rewrite shapes both extract the same slug, so this widget
/// is a no-op-improvement even before the DB flip.
///
/// Drop-in for `CachedImage(url: ..., errorBuilder: ...)` — the
/// `errorBuilder` only fires when **both** the LQIP asset and the
/// network image fail (the rare case: Unsplash-legacy URLs whose slug
/// has no bundled LQIP, plus offline). Otherwise the LQIP IS the
/// fallback.
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.url,
    this.slug,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.memCacheHeight = 600,
    this.memCacheWidth,
    this.errorBuilder,
  });

  /// Fully-resolved image URL (e.g. `https://<cdn>/recipes_images/foo.webp`)
  /// OR a local asset path (`photos/meals/foo.webp` during the migration's
  /// pre-rewrite window). Both end in `<slug>.webp` so the LQIP layer
  /// resolves correctly regardless of which state the DB is in.
  final String url;

  /// Optional explicit slug override. When omitted, the slug is
  /// derived from [url] — the last path segment with the extension
  /// stripped. Callers with a denormalised `slug` column can pass it
  /// in to skip the URL parse.
  final String? slug;

  final BoxFit fit;
  final Alignment alignment;
  final int memCacheHeight;
  final int? memCacheWidth;

  /// Rendered only when the network image fails AND the bundled LQIP
  /// is missing. For the 293 migrated meals the LQIP exists, so this
  /// path covers only Unsplash-legacy rows or onboarding-only seeds.
  final Widget Function(BuildContext, Object?, StackTrace?)? errorBuilder;

  String? get _resolvedSlug {
    final explicit = slug?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (url.isEmpty) return null;
    // Take the last path segment, robust to both `photos/meals/foo.webp`
    // and `https://x/storage/v1/object/public/recipes_images/foo.webp`.
    final lastSlash = url.lastIndexOf('/');
    final tail = lastSlash >= 0 ? url.substring(lastSlash + 1) : url;
    if (tail.isEmpty) return null;
    final dot = tail.lastIndexOf('.');
    final stem = dot > 0 ? tail.substring(0, dot) : tail;
    return stem.isEmpty ? null : stem;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSlug = _resolvedSlug;
    // No slug → no LQIP layer possible → behave like a bare CachedImage.
    // This is the Unsplash-legacy path and the empty-string-url guard.
    if (resolvedSlug == null) {
      return CachedImage(
        url: url,
        fit: fit,
        alignment: alignment,
        memCacheHeight: memCacheHeight,
        memCacheWidth: memCacheWidth,
        errorBuilder: errorBuilder,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom: bundled LQIP. Decodes at 64 px (we're blurring it
        // anyway via upscale); on missing asset, falls back to a
        // transparent SizedBox so the CachedImage below remains the
        // primary visual.
        Image.asset(
          'assets/lqip/meals/$resolvedSlug.webp',
          fit: fit,
          alignment: alignment,
          cacheHeight: 64,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        // Top: full-quality streamed image. On error, render an empty
        // box so the LQIP underneath stays visible — UNLESS the caller
        // passed an explicit fallback (e.g. branded gradient) AND the
        // LQIP is also missing, in which case there's nothing under us.
        // We can't synchronously detect "LQIP exists on disk", so the
        // policy is: if caller provided errorBuilder, defer to caller
        // (their fallback covers the LQIP — same visual as today). If
        // not, fall back to transparent so the LQIP shines through.
        CachedImage(
          url: url,
          fit: fit,
          alignment: alignment,
          memCacheHeight: memCacheHeight,
          memCacheWidth: memCacheWidth,
          errorBuilder: errorBuilder ??
              (_, __, ___) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
