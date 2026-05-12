import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Phase 134 · the reusable visual treatment for premium-locked content.
///
/// Wraps any child widget with:
///   • a soft Gaussian blur over the child (the "tantalising preview"
///     beat — content is *visible* but unreachable, NOT removed),
///   • a faint neon wash so the locked state reads as premium /
///     aspirational rather than disabled / errored,
///   • an optional top-right lock badge,
///   • an optional bottom hint banner ("Premium ile aç" or similar),
///   • a full-area tap intercept that routes the call to [onTap]
///     (typically `PremiumGateService.handleLockedTap`).
///
/// When [locked] is false the overlay renders nothing — pass-through.
/// This lets callers do `LockedOverlay(locked: !isPro, ...)` without an
/// extra `if`.
///
/// Visual reference: matches `_StandardDayCard`'s locked-day styling
/// (`plan_detail_screen.dart` line 770-845) — same neon-35% border, same
/// `Icons.lock` glyph at 90% alpha, same "Premium ile aç" w700 hint —
/// so locked equipment exercises and locked days read as one system.
class LockedOverlay extends StatelessWidget {
  const LockedOverlay({
    super.key,
    required this.child,
    required this.locked,
    this.onTap,
    this.blurSigma = 5,
    this.showLockBadge = true,
    this.hint,
    this.cornerRadius = 16,
    this.neonAlpha = 0.10,
  });

  /// The preview content — fully rendered underneath, then blurred.
  /// MUST be tappable on its own when unlocked; this widget only adds
  /// the lock-state behaviour.
  final Widget child;

  /// When false, the overlay short-circuits to a plain `child`. When
  /// true, blur + badge + tap intercept all engage.
  final bool locked;

  /// Tapped only when [locked] is true. Conventionally a wrapper around
  /// `ref.read(premiumGateProvider).handleLockedTap(context, type)`.
  final VoidCallback? onTap;

  /// Gaussian blur sigma. 5 is the default — strong enough that text
  /// is unreadable but composition stays legible. Bump to ~8 for
  /// dense surfaces (recipe cards), drop to ~3 for already-minimal
  /// surfaces (plain exercise tiles).
  final double blurSigma;

  /// Top-right lock chip with the brand neon glyph. Drop to false on
  /// surfaces that already carry their own lock affordance (the
  /// "Yeni" chip used in the regions menu).
  final bool showLockBadge;

  /// Optional bottom-banner text. Pass `'Premium ile aç'` for plan-detail
  /// equipment exercises; pass null for grid tiles where space is
  /// already tight.
  final String? hint;

  /// Border radius for the overlay's clip + outline. Should match the
  /// child's own corner radius so the blur doesn't bleed outside the
  /// container.
  final double cornerRadius;

  /// Tint strength of the neon wash on top of the blur. Default 0.10
  /// matches the locked-day card; bump to ~0.15 for tighter "this
  /// IS premium" cues, drop to ~0.06 for already-saturated surfaces.
  final double neonAlpha;

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
          // Blur + neon tint layer. BackdropFilter samples whatever's
          // beneath, so it picks up the child's pixels rendered above.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: AppColors.neon.withValues(alpha: neonAlpha),
                  border: Border.all(
                    color: AppColors.neon.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          if (showLockBadge)
            Positioned(
              top: 10,
              right: 10,
              child: _LockBadge(),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkBg.withValues(alpha: 0.65),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 0.4,
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_rounded,
        color: AppColors.neon,
        size: 16,
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.darkBg.withValues(alpha: 0.78),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.neon, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.neon,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
