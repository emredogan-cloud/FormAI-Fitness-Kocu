import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_extension.dart';

/// Roadmap Phase 2 (C37 · F-0.3) · the one empty state.
///
/// Before this, four screens each had their own private `_EmptyState`
/// with different anatomy and different quality bars: favourites and
/// discover had icon + title + body; the nutrition tab and category
/// screens had a bare sentence in a box. None of them had a CTA, which
/// is the part that matters — an empty state that only says "nothing
/// here" leaves the user with nowhere to go, and the Testers Community
/// report was explicitly about users not knowing what the app can do.
///
/// Anatomy, in the order the eye reads it:
///   1. **Haloed icon** — signals "this is a designed state", not a
///      loading failure.
///   2. **Title** — what is empty, in the user's words.
///   3. **Body** — *why* it's empty and what fills it.
///   4. **CTA (optional)** — the action that fills it, one tap away.
///
/// Every field except [title] is optional so a caller can be as terse or
/// as complete as the surface deserves, and no call site has to invent
/// layout.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.ctaLabel,
    this.onCta,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? body;

  /// Renders a filled button when both [ctaLabel] and [onCta] are given.
  final String? ctaLabel;
  final VoidCallback? onCta;

  /// Tighter padding + smaller halo, for an empty state that sits inside
  /// a card rather than owning a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final hasCta = ctaLabel != null && onCta != null;
    final haloSize = compact ? 56.0 : 88.0;
    final iconSize = compact ? 24.0 : 38.0;

    return Semantics(
      container: true,
      label: body == null ? title : '$title. $body',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 32,
          vertical: compact ? 18 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: haloSize,
              height: haloSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neon.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.38),
                ),
              ),
              child: Icon(icon, color: AppColors.neon, size: iconSize),
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: compact ? 14.5 : 16,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.60),
                  fontSize: compact ? 12.5 : 13.5,
                  height: 1.42,
                ),
              ),
            ],
            if (hasCta) ...[
              SizedBox(height: compact ? 14 : 20),
              FilledButton(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  foregroundColor: Colors.white,
                  // 48dp minimum target.
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  ctaLabel!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
