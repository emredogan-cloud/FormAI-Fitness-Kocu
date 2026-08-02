import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The neon-on-black surface, in one place.
///
/// Roadmap Phase 12 · extracted when the third screen wanted it. "Your
/// body" (pre-Phase-10 polish), the outcome report and the photo
/// gallery each carried their own private copy of these seven colours,
/// and the community screens would have been a fourth. Three copies is
/// a coincidence; four is a decision, and this is the decision.
///
/// # Why these screens are hardcoded dark at all
///
/// Light mode ships and a user can pick it. These particular surfaces do
/// not follow it, and each says why in its own class doc — briefly:
///
///   * they are the founder's approved comps, which are neon on pure
///     black, and there is no light rendering of them that is not an
///     approximation;
///   * the report and the profile card exist to be **screenshotted**,
///     and the one thing a screenshot must not do is arrive in whichever
///     theme the reader happened to have on;
///   * hardcoding the canvas retires the defect class that has bitten
///     this app three times — `Colors.white` over a tint fill that is
///     dark in one theme and pastel in the other — because the backdrop
///     no longer changes.
///
/// This is deliberately NOT a `ThemeExtension`. An extension would make
/// these colours resolve off the ambient theme, which is exactly what
/// these screens have decided not to do; a plain set of constants says
/// "this surface is fixed" in a way a theme lookup cannot.
///
/// # The lime is the comp's, not the app's
///
/// [neonLime] is `#B8FF33`. [AppColors.neonGreen] is `#39FF14` and is
/// used everywhere else in the app. Every green sampled off the
/// founder's "Your body" comp is the yellow-green; they are different
/// colours and both are correct in their own place.
abstract final class NeonSurface {
  /// Pure black. The comps are pure black and a near-black reads as a
  /// mistake beside them.
  static const Color bg = Color(0xFF000000);

  /// The standard card fill.
  static const Color card = Color(0xFF0B0B10);

  /// A slightly deeper fill for a card that sits *inside* another one,
  /// so the nesting reads without a second border.
  static const Color cardDeep = Color(0xFF08070E);

  static const Color hairline = Color(0x17FFFFFF);

  /// Secondary text. ~55 % white.
  static const Color muted = Color(0x8CFFFFFF);

  /// Tertiary text and disabled glyphs. ~36 % white.
  static const Color faint = Color(0x5CFFFFFF);

  static const Color lime = Color(0xFFB8FF33);
  static const Color purple = AppColors.neon;

  /// Oldest-to-newest, then-to-now, start-to-finish. Used for card rims,
  /// the selected range segment and the chart stroke. Purple first
  /// everywhere, so the direction means the same thing on every surface.
  static const List<Color> brandSweep = [purple, lime];

  /// 16 dp each side of a 360 dp phone leaves a card 91 % of the width,
  /// which is what the founder's reference measures.
  static const double gutter = 16;

  static const double radius = 20;
}

/// A card on the neon surface: a hairline outline, or a 1.4 dp gradient
/// rim with a soft bloom behind it.
///
/// The rim is a filled box with an inset child rather than a `Border`,
/// because Flutter cannot stroke a border with a shader. That is the
/// only reason this widget exists rather than a `BoxDecoration` helper.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.gradient = false,
    this.padding = const EdgeInsets.all(16),
    this.fill = NeonSurface.card,
    this.radius = NeonSurface.radius,
  });

  final Widget child;

  /// True for the one card on a screen that should draw the eye. More
  /// than one gradient rim in a scroll and none of them is emphasis.
  final bool gradient;

  /// `EdgeInsetsGeometry`, not `EdgeInsets`: a card with asymmetric
  /// horizontal padding — a row whose trailing control needs less room
  /// than its leading text — has to be able to pass
  /// `EdgeInsetsDirectional`, or the directional-layout gate rejects the
  /// call site.
  final EdgeInsetsGeometry padding;
  final Color fill;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!gradient) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: NeonSurface.hairline),
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: NeonSurface.purple.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            colors: NeonSurface.brandSweep,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        padding: const EdgeInsets.all(1.4),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius - 1.4),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The small secondary action on a neon surface — a label and a chevron
/// in the accent, on an outlined pill or bare.
///
/// **Wrap it in a `Flexible` inside a `Row`.** An inflexible child lays
/// out at its full intrinsic width, and the pseudo-locale sweep has
/// already put one of these 42 px off a 320 px card.
class NeonPill extends StatelessWidget {
  const NeonPill({
    super.key,
    required this.label,
    required this.onTap,
    this.bordered = true,
    this.color = NeonSurface.lime,
  });

  final String label;
  final VoidCallback onTap;
  final bool bordered;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: bordered ? 14 : 4,
              vertical: bordered ? 9 : 4,
            ),
            decoration: bordered
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.65)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.16),
                        blurRadius: 14,
                        spreadRadius: -3,
                      ),
                    ],
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
