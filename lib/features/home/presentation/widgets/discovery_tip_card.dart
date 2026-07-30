import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../domain/discovery_tips.dart';

/// Roadmap Phase 2 (C28) · the dashboard tip slot.
///
/// Deliberately **not** a modal, a snackbar, or an overlay:
///
///   * A modal would block the thing the user opened the app to do.
///   * A snackbar auto-dismisses, so a user who glanced away loses it.
///   * An overlay would cover content.
///
/// Instead it takes its own row of layout between the tab content and
/// the bottom nav — so it can never occlude anything, and the user
/// decides when it goes away.
///
/// Every tip is dismissible, and dismissal is permanent (see
/// [DiscoveryTip]). A tip with no `route` renders without a CTA and is
/// pure information.
class DiscoveryTipCard extends StatelessWidget {
  const DiscoveryTipCard({
    super.key,
    required this.tip,
    required this.onDismiss,
    required this.onAction,
  });

  final DiscoveryTip tip;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final hasCta = tip.ctaLabel != null && tip.route != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.neon.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.neon.withValues(alpha: 0.32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.neon,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BİLİYOR MUYDUN?',
                      style: TextStyle(
                        color: AppColors.neon.withValues(alpha: 0.9),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.body,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.86),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    if (hasCta) ...[
                      const SizedBox(height: 6),
                      // Inline text button rather than a filled CTA: a tip
                      // is a suggestion, and styling it like a primary
                      // action would compete with the day's workout CTA
                      // sitting just above it.
                      GestureDetector(
                        onTap: onAction,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tip.ctaLabel!,
                                style: const TextStyle(
                                  color: AppColors.neon,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: AppColors.neon,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'İpucunu kapat',
                child: IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  // 44dp minimum so the dismiss affordance is genuinely
                  // reachable rather than a pixel-hunt.
                  //
                  // NOTE: no `visualDensity: compact` here. Compact
                  // density subtracts from the resolved size *after* the
                  // constraints are applied, which silently rendered a
                  // 40dp target and defeated the minimum — a test caught
                  // it. The constraints only hold at standard density.
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
