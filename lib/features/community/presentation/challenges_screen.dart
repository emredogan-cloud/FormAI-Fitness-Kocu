import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import '../domain/league.dart';
import '../domain/models/leaderboard_models.dart';

/// Roadmap Phase 13 (C25) · time-boxed challenges.
///
/// # The content is data, not code
///
/// The roadmap requires that content ops ship a new challenge "without a
/// release", so a challenge is a row in `challenges` and its copy is
/// jsonb keyed by locale — the shape migration 011 chose for content
/// localisation. ARB would have tied a content edit to the release
/// train, which is exactly backwards.
///
/// That has a consequence this screen has to handle: **the server can be
/// newer than the client.** A challenge whose `kind` this build does not
/// recognise, or whose copy has no usable locale, is dropped rather than
/// rendered as a slug. `Challenge.fromJson` and [Challenge.title] both
/// return null instead of guessing, and the same rule governs the feed's
/// badge rows and the milestone timeline.
///
/// # Nothing here is a ranking
///
/// A challenge board is ordered by progress, but it is a *shared* board
/// — everybody who joined is working on the same target, and finishing
/// is the outcome rather than placing. There is no promotion, no tier
/// and no percentile. Ranking lives on the leaderboard, and putting a
/// second one here would make the two mean less.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _busy = false;

  Future<void> _join(Challenge challenge) async {
    setState(() => _busy = true);
    final ok =
        await ref.read(communityRepositoryProvider).joinChallenge(challenge);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      unawaited(
          AnalyticsService.instance.challengeJoined(slug: challenge.slug));
      ref.invalidate(myChallengeEntriesProvider);
    }
  }

  Future<void> _leave(Challenge challenge) async {
    setState(() => _busy = true);
    await ref.read(communityRepositoryProvider).leaveChallenge(challenge.id);
    if (!mounted) return;
    setState(() => _busy = false);
    unawaited(
      AnalyticsService.instance.challengeAbandoned(slug: challenge.slug),
    );
    ref.invalidate(myChallengeEntriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final challenges = ref.watch(openChallengesProvider);
    final mine = ref.watch(myChallengeEntriesProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.challengesTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: challenges.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
        error: (_, __) => _Message(text: l10n.communityUnavailableBody),
        data: (rows) {
          // A challenge whose copy cannot be built in any locale is
          // dropped here rather than rendered with a slug in it.
          final showable = [
            for (final c in rows)
              if (c.title(locale) != null) c,
          ];
          if (showable.isEmpty) return _Message(text: l10n.challengesEmpty);
          final entries = mine.value ?? const <String, ChallengeEntry>{};
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              NeonSurface.gutter,
              8,
              NeonSurface.gutter,
              40,
            ),
            itemCount: showable.length,
            itemBuilder: (context, index) {
              final challenge = showable[index];
              return _ChallengeCard(
                challenge: challenge,
                entry: entries[challenge.id],
                locale: locale,
                busy: _busy,
                onJoin: () => _join(challenge),
                onLeave: () => _leave(challenge),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.entry,
    required this.locale,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
  });

  final Challenge challenge;
  final ChallengeEntry? entry;
  final String locale;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final joined = entry != null;
    final open = challenge.isOpen(now);
    final fraction = challengeFraction(
      progress: entry?.progress ?? 0,
      target: challenge.target,
    );
    final daysLeft = challenge.endsAt.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        gradient: joined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    challenge.title(locale)!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  // A window that has closed says so instead of counting
                  // down to a negative number.
                  open
                      ? l10n.challengeDaysLeft(daysLeft < 0 ? 0 : daysLeft)
                      : l10n.challengeEnded,
                  style: TextStyle(
                    color: open ? NeonSurface.lime : NeonSurface.faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (challenge.body(locale) != null) ...[
              const SizedBox(height: 8),
              Text(
                challenge.body(locale)!,
                style: const TextStyle(
                  color: NeonSurface.muted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
            if (joined) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    NeonSurface.lime,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry!.isComplete
                    ? l10n.challengeComplete
                    : l10n.challengeProgress(entry!.progress, challenge.target),
                style: TextStyle(
                  color:
                      entry!.isComplete ? NeonSurface.lime : NeonSurface.faint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: joined
                  ? NeonPill(
                      label: l10n.challengeLeave,
                      color: NeonSurface.muted,
                      onTap: busy ? () {} : onLeave,
                    )
                  // A closed challenge offers nothing rather than a
                  // button that would join something already over.
                  : open
                      ? NeonPill(
                          label: l10n.challengeJoin,
                          onTap: busy ? () {} : onJoin,
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeonSurface.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
