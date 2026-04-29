import 'package:flutter/material.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// Phase 60G · the unified onboarding image surface.
///
/// Used by every visual that renders a bundled `photos/...` asset
/// inside the onboarding flow — gender / goal / activity option tiles
/// (via `_OptionImageTile`) and the pre-paywall plan-card hero.
/// Centralising the chrome means:
///
///   • a single placeholder layer (neon→accent gradient + optional
///     fallback icon) is painted **before** [Image.asset] starts
///     decoding, so a slow-decode or replaced asset never flashes a
///     blank tile;
///   • [Image.asset]'s `frameBuilder` fades the real image in over
///     240 ms once the first frame lands, keeping the transition
///     calm rather than popping;
///   • [Image.asset]'s `errorBuilder` collapses to `SizedBox.shrink`
///     so the placeholder layer underneath stays visible — this is
///     what lets the PM drop higher-res replacement assets into
///     `photos/` later without us touching this file;
///   • a subtle bottom-half dark gradient overlay (`dimOverlay: true`,
///     default) gives every photo the same "sealed-into-the-product"
///     feel regardless of the source asset's lighting.
///
/// Consistent BorderRadius, BoxFit.cover, and the dim-overlay are the
/// three knobs the PM called out in the Phase-60G brief.
class OnboardingImage extends StatelessWidget {
  const OnboardingImage({
    super.key,
    required this.asset,
    this.fallbackIcon,
    this.borderRadius = 14,
    this.dimOverlay = true,
  });

  /// Bundled asset path. The placeholder layer renders even when this
  /// path is missing, so it's safe to point at not-yet-shipped photos.
  final String asset;

  /// Icon painted on the placeholder layer when [Image.asset] fails or
  /// hasn't decoded yet. `null` leaves the gradient bare.
  final IconData? fallbackIcon;

  /// Outer corner radius. Defaults to 14 — the Phase-60E option-tile
  /// radius — so smaller tiles look right without overrides.
  final double borderRadius;

  /// When true, paints a transparent → 25%-black gradient over the
  /// bottom half so trailing overlays (selection check / hero text)
  /// always have legible contrast against the photo.
  final bool dimOverlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder layer — always rendered, sits behind the
          // image. If the image errors or is yet to decode, this
          // layer is what the user sees.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _neon.withValues(alpha: 0.4),
                  _neonAccent.withValues(alpha: 0.32),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: fallbackIcon == null
                ? null
                : Center(
                    child: Icon(
                      fallbackIcon,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 28,
                    ),
                  ),
          ),
          Image.asset(
            asset,
            fit: BoxFit.cover,
            // Fade the real image in once the first frame lands so the
            // transition from placeholder feels intentional rather
            // than a pop.
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          if (dimOverlay)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x40000000)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
