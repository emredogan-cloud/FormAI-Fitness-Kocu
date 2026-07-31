import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 134 · the cinematic "Unlock Pro" CTA.
///
/// Reused inside cinematic AI conversion scenes (Phase 135) and the
/// post-3rd-workout rating scene's secondary action (Phase 136). Visual
/// language mirrors `today_task_card`'s `_PrimaryCta`: neonDeep → neon
/// gradient with a 50%-alpha neon halo. The lock-open glyph is the one
/// concession to discoverability — the same gradient does double duty
/// for "Antrenmana Başla" elsewhere, and we don't want premium CTAs
/// reading as workout CTAs at a glance.
///
/// Default label is [AppLocalizations.ctaUnlockTransformation] — the Phase 134-/135-/136-
/// spec wording. Override per scene where the framing benefits (e.g.
/// `'Tam Potansiyelini Aç'` for the post-first-workout invitation).
class PremiumCtaButton extends StatelessWidget {
  const PremiumCtaButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon = Icons.lock_open_rounded,
    this.fullWidth = true,
  });

  final VoidCallback onTap;

  /// Null falls back to [AppLocalizations.ctaUnlockTransformation] at
  /// build time — a default cannot be a localized string in a const
  /// constructor.
  final String? label;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final core = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.50),
            blurRadius: 24,
            spreadRadius: 0.6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [AppColors.neonDeep, AppColors.neon],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 22,
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      (label ??
                              AppLocalizations.of(context)
                                  .ctaUnlockTransformation)
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!fullWidth) return core;
    return SizedBox(width: double.infinity, child: core);
  }
}
