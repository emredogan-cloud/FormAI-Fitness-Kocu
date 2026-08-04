import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/content_sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/content_freshness.dart';

/// Roadmap Phase 14 (C6) · "Yenilikler" — what landed since you last
/// looked.
///
/// # Why this is a section and not a screen
///
/// The roadmap asks that new-content discovery "must not feel like
/// advertising inside a paid product". A screen you can open is a
/// destination; a screen the app opens *for* you is a promotion. So
/// this is a section at the top of a hub the user already chose to
/// visit, it disappears entirely when there is nothing new, and nothing
/// anywhere pushes the user to it.
///
/// # The badge is per-drop and lives on the device
///
/// `AppPreferences.seenContentDrops` holds slugs, not timestamps, so a
/// drop republished with the same slug does not re-badge. Marking
/// happens when the section is BUILT rather than when a card is tapped:
/// having the list in front of you is what "seen" means, and requiring
/// a tap would keep a permanent "New" dot beside content somebody has
/// decided they do not want.
class NewContentSection extends ConsumerStatefulWidget {
  const NewContentSection({super.key});

  @override
  ConsumerState<NewContentSection> createState() => _NewContentSectionState();
}

class _NewContentSectionState extends ConsumerState<NewContentSection> {
  /// Slugs that were unseen when this section first built.
  ///
  /// Captured once, because [AppPreferences.markContentDropsSeen] runs
  /// on the same frame — reading the preference on every rebuild would
  /// clear every badge before the first paint finished.
  Set<String>? _unseenAtOpen;

  @override
  void initState() {
    super.initState();
    // The sync is what makes this section able to show anything the
    // app was not launched with. It is allowed to fail silently: the
    // cache still answers, and an empty catalogue renders as nothing.
    unawaited(ref.read(contentSyncServiceProvider).refreshIfStale());
  }

  ContentAudience _audience(BuildContext context) {
    final prefs = ref.read(appPreferencesProvider);
    final metrics = prefs.userMetrics ?? const <String, dynamic>{};
    return ContentAudience(
      goal: (metrics['targetPhysique'] as String?) ?? prefs.goal,
      level: metrics['activityLevel'] as String?,
      locale: Localizations.localeOf(context).toLanguageTag(),
      hasEquipment: prefs.hasEquipment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final audience = _audience(context);

    final drops = [
      for (final drop in ref.watch(contentSyncServiceProvider).drops())
        if (drop.isLive(now) &&
            drop.matches(audience) &&
            // A drop whose copy did not survive the locale fallback is
            // dropped rather than rendered as its slug — the same rule
            // the challenge screen follows.
            drop.title(locale) != null)
          drop,
    ];

    // Nothing new is not an empty state here. This section sits inside a
    // hub that has its own content, and an "there is nothing new" card
    // on every visit is noise.
    if (drops.isEmpty) return const SizedBox.shrink();

    final prefs = ref.read(appPreferencesProvider);
    final seen = prefs.seenContentDrops;
    _unseenAtOpen ??= {
      for (final d in drops)
        if (!seen.contains(d.slug)) d.slug,
    };
    if (_unseenAtOpen!.isNotEmpty) {
      unawaited(prefs.markContentDropsSeen(_unseenAtOpen!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(
            l10n.discoveryNewContentTitle.toUpperCase(),
            style: TextStyle(
              color: AppColors.neon.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
        for (final drop in drops)
          _DropCard(
            drop: drop,
            locale: locale,
            isNew: _unseenAtOpen!.contains(drop.slug),
            newLabel: l10n.discoveryNewBadge,
            onTap: () {
              unawaited(
                AnalyticsService.instance.newContentDiscovered(
                  slug: drop.slug,
                  kind: drop.kind.name,
                ),
              );
              final route = drop.route;
              if (route != null && route.startsWith('/')) {
                context.push(route);
              }
            },
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _DropCard extends StatelessWidget {
  const _DropCard({
    required this.drop,
    required this.locale,
    required this.isNew,
    required this.newLabel,
    required this.onTap,
  });

  final ContentDrop drop;
  final String locale;
  final bool isNew;
  final String newLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A drop with no route is a announcement rather than a destination.
    // Rendering it with a tap target that goes nowhere is worse than
    // rendering it flat.
    final tappable = drop.route != null && drop.route!.startsWith('/');
    final body = drop.body(locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tappable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              drop.title(locale)!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.neon,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                newLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (body != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (tappable)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
