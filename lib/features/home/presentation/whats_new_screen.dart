import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/content_sync_service.dart';
import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/content_freshness.dart';

/// Roadmap Phase 14 (C5, R5) · the in-app changelog.
///
/// # Why the copy comes from the server
///
/// A changelog authored in ARB ships with the release it describes,
/// which sounds right until the first time a note needs correcting —
/// then a typo in a release note costs a release. `content_releases` is
/// a table, so the note for a build can be written before the build
/// ships and fixed after it does.
///
/// # Why it is three items and celebratory
///
/// The roadmap is specific: "celebratory and brief — 3 items maximum,
/// each one line, never a wall of release notes". [ContentRelease.items]
/// enforces the cap so this screen cannot be the place it leaks, and
/// there is no "see full release notes" link — a user who wants a
/// changelog has the store listing.
///
/// # Why it marks itself seen on open, not on dismiss
///
/// A user who opens this and swipes back has seen it. Marking on the
/// dismiss button would show it again to everybody who left any other
/// way, which over a staged rollout means showing the same three lines
/// to the same person repeatedly — the precise failure that makes an
/// in-app changelog feel like an ad.
class WhatsNewScreen extends ConsumerStatefulWidget {
  const WhatsNewScreen({super.key, this.release});

  /// Null when the screen is opened directly and there is no unread
  /// note. That is a real state rather than a programming error: the
  /// route is reachable from Profile so somebody can go and look, and
  /// "nothing new right now" is the honest thing to show them.
  final ContentRelease? release;

  @override
  ConsumerState<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends ConsumerState<WhatsNewScreen> {
  @override
  void initState() {
    super.initState();
    final release = widget.release;
    if (release == null) return;
    // Both are fire-and-forget: neither the analytics call nor the
    // preference write is something the user should wait for a frame on.
    unawaited(
      ref.read(appPreferencesProvider).markWhatsNewSeen(release.buildNumber),
    );
    unawaited(
      AnalyticsService.instance.whatsNewViewed(
        version: release.version,
        build: release.buildNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final release = widget.release;
    final items = release?.items(locale) ?? const <ReleaseItem>[];
    final headline = release?.headline(locale) ?? l10n.whatsNewDefaultHeadline;

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.whatsNewTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NeonSurface.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (release != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.whatsNewVersion(release.version),
                        style: const TextStyle(
                          color: NeonSurface.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (items.isEmpty)
                      Text(
                        l10n.whatsNewEmpty,
                        style: const TextStyle(color: NeonSurface.muted),
                      ),
                    for (final item in items) _ReleaseRow(item: item),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NeonSurface.lime,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.whatsNewDismiss),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.item});

  final ReleaseItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonSurface.card,
        borderRadius: BorderRadius.circular(NeonSurface.radius),
        border: Border.all(color: NeonSurface.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: NeonSurface.lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.body!,
                    style: const TextStyle(
                      color: NeonSurface.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The release this device should show, or null.
///
/// A [Provider] rather than a call site so the dashboard can watch it
/// without knowing how the decision is made — and so a test can override
/// the sync service without building a screen.
final pendingReleaseNoteProvider =
    Provider.family<ContentRelease?, ({int build, String locale})>(
  (ref, args) {
    final prefs = ref.watch(appPreferencesProvider);
    return ContentRelease.newestFor(
      ref.watch(contentSyncServiceProvider).releases(),
      build: args.build,
      lastSeenBuild: prefs.whatsNewSeenBuild,
      locale: args.locale,
    );
  },
);
