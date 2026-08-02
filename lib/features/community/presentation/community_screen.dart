import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import 'profile_editor_screen.dart';

/// Roadmap Phase 12 (R6, C24) · the way in to community.
///
/// Three states, and the order they are checked in is the feature:
///
///   1. **The schema is not applied** — `019` is deliberately unapplied,
///      so this is the state most users are in today. It says
///      "isn't switched on yet" and, crucially, that nothing else has
///      changed. An error tile here would tell somebody their app is
///      broken when it is working exactly as intended.
///   2. **No profile** — the default, and not a gap. The roadmap's rule
///      is that a user who never touches community sees no change, so
///      the empty state leads with what a profile is *for* and with the
///      fact that nothing on it is visible until they say so.
///   3. **A profile exists** — the identity, and the way to edit it.
///
/// Dark-only on the shared [NeonSurface], like the outcome report and
/// the photo screens. A profile card is an artifact that gets shared,
/// and the reasoning is in `neon_surface.dart`.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(communityAvailableProvider);
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.communityTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: available.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
        // A failure to even ask is treated as unavailable rather than as
        // an error: the honest thing to tell somebody offline is that
        // this part is not reachable, not that something broke.
        error: (_, __) => const _Unavailable(),
        data: (isAvailable) {
          if (!isAvailable) return const _Unavailable();
          return profile.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: NeonSurface.purple),
            ),
            error: (_, __) => const _Unavailable(),
            data: (row) =>
                row == null ? const _NoProfile() : _Profile(profile: row),
          );
        },
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 44, color: NeonSurface.faint),
            const SizedBox(height: 18),
            Text(
              l10n.communityUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.communityUnavailableBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProfile extends ConsumerWidget {
  const _NoProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileNoneTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.profileNoneBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NeonSurface.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => _openEditor(context, ref, null),
              child: Text(l10n.profileCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.profile});

  final CommunityProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NeonSurface.gutter,
        8,
        NeonSurface.gutter,
        40,
      ),
      children: [
        NeonCard(
          gradient: true,
          fill: NeonSurface.cardDeep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // A handle is an address, not copy: the '@' is part of
                // how one is written in every language this app ships.
                '@${profile.handle}', // i18n-ignore — a handle
                style: const TextStyle(
                  color: NeonSurface.lime,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Moderation is a gate, not a delay: while a name is pending it
        // is visible to its owner and nobody else, and saying so is what
        // stops somebody wondering why their friend cannot find them.
        if (!profile.moderationApproved) ...[
          const SizedBox(height: 12),
          NeonCard(
            child: Text(
              l10n.profilePendingReview,
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        NeonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileVisibilityTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _VisibilityLine(
                label: l10n.profileVisibilityPublic,
                on: profile.visibility.isPublic,
              ),
              _VisibilityLine(
                label: l10n.profileVisibilityBadges,
                on: profile.visibility.showBadges,
              ),
              _VisibilityLine(
                label: l10n.profileVisibilityStats,
                on: profile.visibility.showStats,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: NeonPill(
            label: l10n.profileEdit,
            onTap: () => _openEditor(context, ref, profile),
          ),
        ),
      ],
    );
  }
}

/// One visibility flag, read-only. A tick or a dash rather than a
/// disabled switch: a switch that cannot be moved invites somebody to
/// try, and the place to change these is the editor.
class _VisibilityLine extends StatelessWidget {
  const _VisibilityLine({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            on ? Icons.check_circle_outline_rounded : Icons.remove_rounded,
            size: 18,
            color: on ? NeonSurface.lime : NeonSurface.faint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: on ? Colors.white : NeonSurface.faint,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref,
  CommunityProfile? existing,
) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ProfileEditorScreen(existing: existing),
    ),
  );
  if (saved == true) ref.invalidate(myProfileProvider);
}
