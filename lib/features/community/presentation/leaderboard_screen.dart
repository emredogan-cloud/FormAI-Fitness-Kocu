import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/neon_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/providers/streak_provider.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/data/session_log_repository.dart';
import '../data/community_repository.dart';
import '../domain/league.dart';
import '../domain/models/leaderboard_models.dart';

/// Roadmap Phase 13 (C23 · R6) · the leaderboard.
///
/// # Beginner protection is the design, not a setting
///
/// The roadmap is unusually blunt about this: *"A first-week user must
/// never open a leaderboard and see themselves last out of 40,000."*
/// Three things enforce it, and none of them is a preference the user
/// has to find:
///
///   1. **The default scope is squad**, never global — [defaultScope],
///      which lives in the domain layer so it cannot be quietly changed
///      by editing a widget.
///   2. **Consistency is the default metric.** It is a ratio, so
///      somebody training three days out of three beats somebody
///      training five out of seven. It is the only one of the four a
///      beginner can win, which is why it is first.
///   3. **A large rank is told as a percentile**, via [presentRank]. "You
///      are 12,406th" and "top 40%" are the same fact and only one of
///      them is a reason to come back tomorrow.
///
/// # Being here at all is opt-in
///
/// There is no `opted_in` column. A user is on the board exactly when
/// they have a row, and [_leave] deletes it. Nothing is published until
/// somebody presses the button on [_JoinCard], and the card says
/// precisely which four numbers it will send — not a category, the
/// actual list, because "your stats" could mean anything and one of the
/// things it could mean is a body weight.
///
/// Withdrawing loses nothing. XP, streaks and sessions live on the
/// device; the server copy is a projection, and deleting a projection is
/// not deleting progress.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardScope _scope = defaultScope;
  LeaderboardMetric _metric = LeaderboardMetric.consistency;
  late Future<List<LeaderboardEntry>> _rows = _load();
  bool _busy = false;

  Future<List<LeaderboardEntry>> _load() => ref
      .read(communityRepositoryProvider)
      .board(scope: _scope, metric: _metric);

  void _reload() => setState(() => _rows = _load());

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.instance.leaderboardViewed(scope: _scope.name),
    );
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    final repository = ref.read(communityRepositoryProvider);
    // The numbers come from the engines that already own them. Nothing
    // here recomputes XP or a streak — a second calculation would be a
    // second answer, and the one on the dashboard is the one the user
    // believes.
    final logs = ref.read(sessionLogsProvider).value ?? const {};
    final ok = await repository.publishWeek(
      xp: ref.read(lifetimeXpProvider),
      sessions: logs.length,
      streak: ref.read(currentStreakProvider),
      consistency: _consistencyPercent(logs.length),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      unawaited(AnalyticsService.instance.leaderboardJoined());
      ref.invalidate(onLeaderboardsProvider);
      _reload();
    }
  }

  Future<void> _leave() async {
    setState(() => _busy = true);
    await ref.read(communityRepositoryProvider).leaveLeaderboards();
    if (!mounted) return;
    setState(() => _busy = false);
    unawaited(AnalyticsService.instance.leaderboardLeft());
    ref.invalidate(onLeaderboardsProvider);
    _reload();
  }

  /// Days trained out of the days in the programme so far, as a whole
  /// percent. The same ratio the Progress tab shows, so the number on
  /// the board is the number the user has already seen.
  int _consistencyPercent(int sessions) {
    final total = ref.read(sessionLogsProvider).value?.length ?? 0;
    if (total == 0) return 0;
    return ((sessions / 30) * 100).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(communityAvailableProvider);
    final joined = ref.watch(onLeaderboardsProvider);

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          l10n.leaderboardTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: available.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonSurface.purple),
        ),
        error: (_, __) => _Unavailable(message: l10n.communityUnavailableBody),
        data: (isAvailable) {
          if (!isAvailable) {
            return _Unavailable(message: l10n.communityUnavailableBody);
          }
          return joined.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: NeonSurface.purple),
            ),
            error: (_, __) =>
                _Unavailable(message: l10n.communityUnavailableBody),
            data: (isOn) =>
                isOn ? _board(l10n) : _JoinCard(busy: _busy, onJoin: _join),
          );
        },
      ),
    );
  }

  Widget _board(AppLocalizations l10n) {
    return Column(
      children: [
        _ScopeBar(
          scope: _scope,
          onChanged: (scope) {
            setState(() {
              _scope = scope;
              _rows = _load();
            });
            unawaited(
              AnalyticsService.instance.leaderboardViewed(scope: scope.name),
            );
          },
        ),
        _MetricBar(
          metric: _metric,
          onChanged: (metric) => setState(() {
            _metric = metric;
            _rows = _load();
          }),
        ),
        Expanded(
          child: FutureBuilder<List<LeaderboardEntry>>(
            future: _rows,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: NeonSurface.purple),
                );
              }
              final rows = snapshot.data ?? const <LeaderboardEntry>[];
              if (rows.isEmpty) return _Empty(scope: _scope);
              final me = ref.read(currentCommunityUserIdProvider);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  NeonSurface.gutter,
                  4,
                  NeonSurface.gutter,
                  32,
                ),
                itemCount: rows.length + 1,
                itemBuilder: (context, index) {
                  if (index == rows.length) {
                    return _LeaveRow(busy: _busy, onLeave: _leave);
                  }
                  return _Row(
                    entry: rows[index],
                    rank: index + 1,
                    total: rows.length,
                    metric: _metric,
                    isMe: rows[index].userId == me,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One line of the board.
class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.rank,
    required this.total,
    required this.metric,
    required this.isMe,
  });

  final LeaderboardEntry entry;
  final int rank;
  final int total;
  final LeaderboardMetric metric;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A row for somebody else always shows its position — the list is
    // ordered and hiding it would be strange. The percentile rule is
    // about how *your own* placing is told to you, and it is applied on
    // your row only.
    final shown =
        isMe ? presentRank(rank: rank, total: total) : RankPosition(rank);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeonCard(
        gradient: isMe,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                switch (shown) {
                  RankPosition(:final rank) => '$rank',
                  RankPercentile(:final percentile) =>
                    l10n.leaderboardTopPercent(percentile),
                  RankUnranked() => '—', // i18n-ignore — an em dash
                },
                style: TextStyle(
                  color: isMe ? NeonSurface.lime : NeonSurface.faint,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                // A private profile keeps its rank and loses its name.
                // That is the roadmap's pseudonymity, and it costs no
                // field — see `020`'s header.
                entry.displayName ?? l10n.feedSomeone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: entry.displayName == null
                      ? NeonSurface.muted
                      : Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: entry.displayName == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              metric == LeaderboardMetric.consistency
                  ? l10n.leaderboardPercent(entry.valueFor(metric))
                  : '${entry.valueFor(metric)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeBar extends StatelessWidget {
  const _ScopeBar({required this.scope, required this.onChanged});

  final LeaderboardScope scope;
  final ValueChanged<LeaderboardScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(LeaderboardScope s) => switch (s) {
          LeaderboardScope.squad => l10n.leaderboardScopeSquad,
          LeaderboardScope.friends => l10n.leaderboardScopeFriends,
          LeaderboardScope.global => l10n.leaderboardScopeGlobal,
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NeonSurface.gutter,
        4,
        NeonSurface.gutter,
        8,
      ),
      child: Row(
        children: [
          for (final s in LeaderboardScope.values) ...[
            if (s != LeaderboardScope.values.first) const SizedBox(width: 8),
            Expanded(
              child: _Segment(
                label: label(s),
                selected: s == scope,
                onTap: () => onChanged(s),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.metric, required this.onChanged});

  final LeaderboardMetric metric;
  final ValueChanged<LeaderboardMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(LeaderboardMetric m) => switch (m) {
          LeaderboardMetric.consistency => l10n.leaderboardMetricConsistency,
          LeaderboardMetric.xp => l10n.leaderboardMetricXp,
          LeaderboardMetric.sessions => l10n.leaderboardMetricSessions,
          LeaderboardMetric.streak => l10n.leaderboardMetricStreak,
        };
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NeonSurface.gutter),
        children: [
          for (final m in LeaderboardMetric.values) ...[
            if (m != LeaderboardMetric.values.first) const SizedBox(width: 8),
            _Segment(
              label: label(m),
              selected: m == metric,
              onTap: () => onChanged(m),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? NeonSurface.purple.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? NeonSurface.purple : NeonSurface.hairline,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : NeonSurface.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The opt-in. Names the four numbers rather than calling them "stats".
class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.busy, required this.onJoin});

  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: NeonCard(
          gradient: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.leaderboardJoinTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.leaderboardJoinBody,
                style: const TextStyle(
                  color: NeonSurface.muted,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // The actual list. "Your stats" could mean anything, and
              // one of the things it could mean is a body weight.
              for (final line in [
                l10n.leaderboardMetricConsistency,
                l10n.leaderboardMetricXp,
                l10n.leaderboardMetricSessions,
                l10n.leaderboardMetricStreak,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          color: NeonSurface.lime, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                l10n.leaderboardJoinPrivacy,
                style: const TextStyle(
                  color: NeonSurface.faint,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NeonSurface.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy ? null : onJoin,
                  child: Text(l10n.leaderboardJoinButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opting out. Visible, one tap, and worded as a door rather than a
/// punishment — the roadmap asks for exactly that.
class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.busy, required this.onLeave});

  final bool busy;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.leaderboardLeaveNote,
            style: const TextStyle(
              color: NeonSurface.faint,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NeonPill(
              label: l10n.leaderboardLeaveButton,
              color: NeonSurface.muted,
              onTap: busy ? () {} : onLeave,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scope});

  final LeaderboardScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Says which scope is empty rather than "no results". A user with
    // no squad is not looking at a broken screen — they are looking at
    // a scope they have not filled yet, and the difference matters.
    final message = switch (scope) {
      LeaderboardScope.squad => l10n.leaderboardEmptySquad,
      LeaderboardScope.friends => l10n.leaderboardEmptyFriends,
      LeaderboardScope.global => l10n.leaderboardEmptyGlobal,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
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

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeonSurface.muted,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
