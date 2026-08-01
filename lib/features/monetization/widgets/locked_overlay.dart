import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 134 / 137-polish · the reusable visual treatment for premium-
/// locked content.
///
/// Wraps any child widget with:
///   • a soft Gaussian blur over the child (the "tantalising preview"
///     beat — content is *visible* but unreachable, NOT removed),
///   • a dark-glass premium gradient (purple-10% top → black-28% bottom)
///     so the locked state reads as elegant / mysterious rather than
///     errored,
///   • an optional top-right [_LockIndicator] (outline lock glyph +
///     tiny outlined "PRO" pill),
///   • an optional bottom hint banner with the same soft-purple voice,
///   • a full-area tap intercept that routes to [onTap] (typically
///     `PremiumGateService.handleLockedTap`).
///
/// When [locked] is false the overlay short-circuits to the bare child
/// so callers can do `LockedOverlay(locked: !isPro, ...)` without an
/// extra `if`.
///
/// 137-polish revision: lock badge dropped from 32 → 28 px, fill switched
/// from the brand neon (`AppColors.neon` 0xFF8E5BFF) to the softer
/// `0xFFB58CFF` at 50 % opacity, glyph swapped to the outline
/// (`Icons.lock_outline`), and the loud neon-35% border + 35%-alpha
/// box-shadow were dropped for a low-opacity outline. The wash is now a
/// vertical gradient instead of a solid neon tint. Combined effect:
/// elegant "premium category" cue instead of "blocked content" alarm.
class LockedOverlay extends StatelessWidget {
  const LockedOverlay({
    super.key,
    required this.child,
    required this.locked,
    this.onTap,
    this.blurSigma = 4.5,
    this.showLockBadge = true,
    this.showProBadge = true,
    this.hint,
    this.cornerRadius = 16,
  });

  /// The preview content — fully rendered underneath, then blurred.
  /// MUST be tappable on its own when unlocked; this widget only adds
  /// the lock-state behaviour.
  final Widget child;

  /// When false, the overlay short-circuits to a plain `child`. When
  /// true, blur + indicator + tap intercept all engage.
  final bool locked;

  /// Tapped only when [locked] is true. Conventionally a wrapper around
  /// `ref.read(premiumGateProvider).handleLockedTap(context, type)`.
  final VoidCallback? onTap;

  /// Gaussian blur sigma. 4.5 is the default — strong enough that text
  /// loses precision but composition stays legible. Pre-polish default
  /// was 5; the new lighter wash lets us drop a notch and the overall
  /// surface still reads as locked.
  final double blurSigma;

  /// Top-right outline lock glyph. Drop to false on surfaces that
  /// already carry their own lock affordance.
  final bool showLockBadge;

  /// Tiny outlined "PRO" pill rendered next to the lock glyph. Drop
  /// to false in extremely tight surfaces (mini-thumbnail grids); the
  /// lock alone still reads correctly.
  final bool showProBadge;

  /// Optional bottom-banner text. Pass `'Premium ile aç'` for plan-detail
  /// equipment exercises; pass null for grid tiles where space is
  /// already tight.
  final String? hint;

  /// Border radius for the overlay's clip + outline. Should match the
  /// child's own corner radius so the blur doesn't bleed outside the
  /// container.
  final double cornerRadius;

  /// Soft-purple accent used by every locked surface. Sits 30 luminance
  /// steps lighter than `AppColors.neon` (0xFF8E5BFF) so the lock glyph
  /// reads as elegant rather than alarming. Internal: callers do not
  /// pick the colour, the overlay does.
  static const Color _softPurple = Color(0xFFB58CFF);

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    final radius = BorderRadius.circular(cornerRadius);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // Tantalising preview underneath. ExcludeFocus so screen readers
          // and keyboard navigation don't try to interact with content
          // that's about to be intercepted — the lock surface is the only
          // interactive target.
          ExcludeFocus(
            child: AbsorbPointer(child: child),
          ),
          // Blur + dark-glass gradient wash. The vertical gradient gives
          // the surface depth — slightly purple-tinted at the top, fading
          // toward a darker bottom so the lock indicator + hint pill in
          // the lower half land on a calm anchor instead of fighting a
          // bright wash.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _softPurple.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  ),
                  border: Border.all(
                    color: _softPurple.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          if (showLockBadge || showProBadge)
            Positioned(
              top: 9,
              right: 9,
              child: _LockIndicator(
                showLock: showLockBadge,
                showPro: showProBadge,
              ),
            ),
          if (hint != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _HintBanner(text: hint!),
            ),
          // Tap surface on top of everything — must be last so it wins
          // hit-testing against the blur layer.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                splashColor: _softPurple.withValues(alpha: 0.10),
                highlightColor: _softPurple.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline lock glyph + optional "PRO" pill, rendered side by side in
/// the overlay's top-right corner. The composition reads as
/// "premium category" rather than "blocked" — the outline (vs filled)
/// lock + the typographic PRO tag both lean on premium UI conventions
/// (Apple, WHOOP, Strava) instead of casino / mobile-game alarm cues.
class _LockIndicator extends StatelessWidget {
  const _LockIndicator({required this.showLock, required this.showPro});

  final bool showLock;
  final bool showPro;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLock) _LockGlyph(),
        if (showLock && showPro) const SizedBox(width: 6),
        if (showPro) const PremiumProPill(),
      ],
    );
  }
}

class _LockGlyph extends StatelessWidget {
  static const Color _softPurple = LockedOverlay._softPurple;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(
          color: _softPurple.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.lock_outline,
        color: _softPurple.withValues(alpha: 0.80),
        size: 12,
      ),
    );
  }
}

/// Tiny outlined "PRO" capsule badge. Used inside [LockedOverlay] and as a
/// secondary premium indicator on dimmed exercise tiles.
class PremiumProPill extends StatelessWidget {
  const PremiumProPill({super.key});

  static const Color _softPurple = LockedOverlay._softPurple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(
          color: _softPurple.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        AppLocalizations.of(context).premiumBadge,
        style: TextStyle(
          color: _softPurple.withValues(alpha: 0.90),
          fontSize: 9,
          height: 1.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});

  final String text;

  static const Color _softPurple = LockedOverlay._softPurple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(
          color: _softPurple.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            color: _softPurple.withValues(alpha: 0.85),
            size: 11,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _softPurple.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
