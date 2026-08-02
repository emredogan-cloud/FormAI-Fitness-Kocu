import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/presentation/badge_copy.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../data/community_repository.dart';
import '../domain/models/community_models.dart';

/// Roadmap Phase 12 (C22) · a squad's activity feed.
///
/// # Presence, not ranking
///
/// The roadmap is explicit that this phase's feed "shows presence, not
/// ranking", and that ranking arrives deliberately in Phase 13. So there
/// are no positions, no totals compared between people, and no ordering
/// by anything but time. Somebody who trained once this week appears
/// exactly as prominently as somebody who trained five times.
///
/// # Reactions, no comments
///
/// Three reactions and no text field, which is a decision rather than an
/// omission: the roadmap notes it "delivers most of the social
/// reinforcement with a fraction of the moderation risk", and
/// `activity_reactions` has no text column to moderate. Tapping a
/// reaction you already gave takes it back — a lit button is how people
/// expect to undo one, and a separate "remove" beside three small
/// buttons is clutter.
///
/// # A name that cannot be resolved is "Someone"
///
/// A squad member whose profile is private, or who has blocked this
/// reader since, still has events in the feed — the RLS policy scopes
/// events by squad, not by profile visibility. Rendering their row with
/// a blank name would look broken; rendering it as "Someone" is true.
class SquadFeedScreen extends ConsumerStatefulWidget {
  const SquadFeedScreen({super.key, required this.squad});

  final Squad squad;

  @override
  ConsumerState<SquadFeedScreen> createState() => _SquadFeedScreenState();
}

class _SquadFeedScreenState extends ConsumerState<SquadFeedScreen> {
  late Future<List<ActivityEvent>> _events = _load();

  Future<List<ActivityEvent>> _load() =>
      ref.read(communityRepositoryProvider).feed(widget.squad.id);

  Future<void> _react(ActivityEvent event, FeedReaction reaction) async {
    // Tapping the reaction already given takes it back.
    final next = event.myReaction == reaction.token ? null : reaction;
    await ref
        .read(communityRepositoryProvider)
        .react(eventId: event.id, reaction: next);
    if (!mounted) return;
    setState(() => _events = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.squad.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.feedTitle,
                style: const TextStyle(
                  color: NeonSurface.faint,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<ActivityEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: NeonSurface.purple),
            );
          }
          final events = snapshot.data ?? const <ActivityEvent>[];
          if (events.isEmpty) return const _Empty();
          return RefreshIndicator(
            color: NeonSurface.purple,
            backgroundColor: NeonSurface.card,
            onRefresh: () async => setState(() => _events = _load()),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                NeonSurface.gutter,
                8,
                NeonSurface.gutter,
                40,
              ),
              itemCount: events.length,
              itemBuilder: (context, index) => _EventRow(
                event: events[index],
                onReact: _react,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onReact});

  final ActivityEvent event;
  final void Function(ActivityEvent, FeedReaction) onReact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final sentence = _sentence(l10n);
    // A kind whose copy cannot be built — a badge id that has outlived
    // its definition — drops the row rather than rendering a token at
    // somebody. Same rule as the Phase 10 milestone timeline.
    if (sentence == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sentence,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat.MMMd(localeTag).format(event.createdAt),
                  style: const TextStyle(
                    color: NeonSurface.faint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final reaction in FeedReaction.values) ...[
                  if (reaction != FeedReaction.values.first)
                    const SizedBox(width: 8),
                  _ReactionChip(
                    reaction: reaction,
                    count: event.reactions[reaction.token] ?? 0,
                    mine: event.myReaction == reaction.token,
                    onTap: () => onReact(event, reaction),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The line, or null when it cannot honestly be built.
  ///
  /// The actor's name is resolved by the repository at read time; an
  /// unresolvable one becomes "Someone" rather than a blank, because a
  /// squad member who has gone private still has events here and a blank
  /// row looks broken.
  String? _sentence(AppLocalizations l10n) {
    final name = event.actorName ?? l10n.feedSomeone;
    switch (event.kind) {
      case ActivityKind.workoutCompleted:
        return l10n.feedWorkout(name);
      case ActivityKind.levelUp:
        return l10n.feedLevel(name, event.value ?? 0);
      case ActivityKind.streakMilestone:
        return l10n.feedStreak(name, event.value ?? 0);
      case ActivityKind.badgeEarned:
        final id = event.token;
        if (id == null) return null;
        for (final badge in kBadgeCatalog) {
          if (badge.id == id) return l10n.feedBadge(name, badge.title(l10n));
        }
        return null;
    }
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final FeedReaction reaction;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (reaction) {
      FeedReaction.cheer => l10n.feedReactionCheer,
      FeedReaction.strong => l10n.feedReactionStrong,
      FeedReaction.fire => l10n.feedReactionFire,
    };
    return Semantics(
      button: true,
      selected: mine,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: mine
              ? NeonSurface.purple.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: mine ? NeonSurface.purple : NeonSurface.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: mine ? Colors.white : NeonSurface.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // The count is absent at zero rather than shown as
                  // "0" — a row of zeroes reads as nobody caring, which
                  // is exactly the wrong note for a feed whose job is
                  // encouragement.
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: mine ? NeonSurface.lime : NeonSurface.faint,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.feedEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            // States exactly what the feed carries, which is the privacy
            // position: "Nothing else does."
            Text(
              l10n.feedEmptyBody,
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
