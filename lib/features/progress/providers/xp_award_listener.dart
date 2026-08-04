import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/analytics_service.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/league.dart';
import '../../community/domain/models/community_models.dart';
import '../../workout/data/session_log_repository.dart';
import '../../workout/models/session_log_model.dart';
import '../domain/level_curve.dart';
import '../domain/xp_calculator.dart';
import 'badge_unlocks_provider.dart';
import 'xp_provider.dart';

/// Progress redesign Phase 3.C · multi-source XP awarding hook.
///
/// Fed by three signals (badge unlocks, session logs, max-streak
/// transitions) and credits XP idempotently against the persistence
/// ledgers in [AppPreferences]. Mounted from `dashboard_screen.dart`
/// alongside the existing `celebratedBadgesProvider` listener so the
/// route-aware queueing for level-up celebrations naturally falls out
/// of the same lifecycle.
///
/// **Backfill semantics:** the persistence ledgers default to empty
/// sets. On a Phase-3 boot for an existing user (any number of
/// completed days, badges, or max-streak) the first `_evaluate()` call
/// finds every legacy signal "uncredited" and walks the full XP backlog
/// in one pass. The ledger updates lock the credit in place so a
/// subsequent rebuild (or an app restart) sees the same set as
/// "already credited" and does nothing.
final xpAwardListenerProvider = NotifierProvider<XpAwardListener, void>(
  XpAwardListener.new,
);

/// How long after the listener mounts squad-feed publishing stays off.
///
/// Everything credited before this has elapsed is treated as history —
/// see `XpAwardListener._publish`. A workout finishes many minutes into
/// a session, so no live event is ever lost to it.
const Duration kFeedPublishAfterMount = Duration(seconds: 3);

class XpAwardListener extends Notifier<void> {
  /// False for [kFeedPublishAfterMount] after mount. Nothing reaches the
  /// squad feed before it flips — see [_publish].
  bool _live = false;

  @override
  void build() {
    final timer = Timer(kFeedPublishAfterMount, () => _live = true);
    ref.onDispose(timer.cancel);
    // React to the three signals. Each `listen` fires both on first
    // attach and on every subsequent change — `_evaluate` is idempotent
    // so we don't have to debounce.
    ref.listen<Set<String>>(
      unlockedBadgesProvider,
      (_, __) => _evaluate(),
      fireImmediately: true,
    );
    // Session logs are async; only react once data lands. We swallow
    // loading/error states — the next emission with data will trigger
    // a clean evaluate.
    ref.listen<AsyncValue<Map<int, SessionLog>>>(
      sessionLogsProvider,
      (_, next) {
        if (next.hasValue) _evaluate();
      },
      fireImmediately: true,
    );
    // The max-streak watermark lives on AppPreferences and the streak
    // UI bumps it via `bumpMaxStreakIfHigher`. We can't `listen` to a
    // raw Provider field easily, so we re-watch the whole preferences
    // provider and read the field defensively. AppPreferences is a
    // value type (no built-in change notifications), so the listener
    // fires whenever the provider rebuilds — which is whenever any
    // pref-backed signal changes.
    ref.listen<AppPreferences>(
      appPreferencesProvider,
      (_, __) => _evaluate(),
      fireImmediately: true,
    );
  }

  void _evaluate() {
    final prefs = ref.read(appPreferencesProvider);
    final xpNotifier = ref.read(lifetimeXpProvider.notifier);

    // What this pass newly credits. Collected rather than acted on
    // immediately, because the squad feed only wants the ones that
    // happened while we were watching — see `_publish`.
    var creditedDays = 0;
    final creditedBadges = <String>[];
    var creditedMilestone = 0;
    final levelBefore = levelForXp(ref.read(lifetimeXpProvider));

    // ─── 1. Workout XP from session logs ────────────────────────────
    final logsAsync = ref.read(sessionLogsProvider);
    final logs = logsAsync.value;
    if (logs != null) {
      final awarded = prefs.awardedSessionDays;
      for (final entry in logs.entries) {
        final dayNumber = entry.key;
        if (awarded.contains(dayNumber)) continue;
        final delta = xpForWorkout(entry.value);
        if (delta > 0) {
          xpNotifier.add(delta);
          prefs.markSessionDayAwarded(dayNumber);
          creditedDays++;
        }
      }
    }

    // ─── 2. Badge XP ────────────────────────────────────────────────
    final unlocked = ref.read(unlockedBadgesProvider);
    final awardedBadges = prefs.awardedBadgeIds;
    for (final id in unlocked) {
      if (awardedBadges.contains(id)) continue;
      final delta = xpForBadge(id);
      if (delta > 0) {
        xpNotifier.add(delta);
        prefs.markBadgeAwarded(id);
        creditedBadges.add(id);
      }
    }

    // ─── 3. Streak milestone XP ─────────────────────────────────────
    // We pay milestones based on `maxStreak` (the watermark), not the
    // live streak. That way the user gets credit even if their streak
    // breaks afterwards — we only ever credit each milestone once.
    final maxStreak = prefs.maxStreak;
    final awardedMilestones = prefs.awardedStreakMilestones;
    for (final milestone in kStreakXpMilestones) {
      if (milestone > maxStreak) break;
      if (awardedMilestones.contains(milestone)) continue;
      final delta = xpForStreakMilestone(milestone);
      if (delta > 0) {
        xpNotifier.add(delta);
        prefs.markStreakMilestoneAwarded(milestone);
        creditedMilestone = milestone;
      }
    }

    _publish(
      days: creditedDays,
      badges: creditedBadges,
      milestone: creditedMilestone,
      levelBefore: levelBefore,
      levelAfter: levelForXp(ref.read(lifetimeXpProvider)),
    );
  }

  /// Roadmap Phase 14 · advances every challenge the user has joined.
  ///
  /// Called from the same place as the feed write, for the same reason:
  /// the ledger above has already decided that a session is new, and a
  /// separate component asking that question would answer it slightly
  /// differently. Once per completed workout is also the right cadence —
  /// a challenge measured in sessions cannot advance more often than a
  /// session happens.
  ///
  /// # Progress is derived, never accumulated
  ///
  /// Each kind is recomputed from the engine that owns it — session
  /// logs, the streak provider, lifetime XP — rather than incremented.
  /// An increment can be applied twice and is then wrong forever; a
  /// derived value is self-correcting, so a missed write costs one
  /// stale reading rather than a permanently wrong total.
  ///
  /// # It is as fabricable as the leaderboard, and bounded the same way
  ///
  /// The client reports the number because the client is where the
  /// number lives (see `020_leaderboards.sql`'s header). What stops a
  /// runaway value here is `target`: progress is only meaningful
  /// relative to it, and `challengeFraction` clamps the rendering at
  /// 1.0. Closing the gap properly needs server-side session recording,
  /// which is Phase 15's.
  Future<void> _reportChallengeProgress() async {
    final repository = ref.read(communityRepositoryProvider);
    final joined = await repository.myChallengeEntries();
    if (joined.isEmpty) return;

    final open = await repository.challenges();
    if (open.isEmpty) return;

    final logs = ref.read(sessionLogsProvider).value ?? const {};
    final prefs = ref.read(appPreferencesProvider);
    final xp = ref.read(lifetimeXpProvider);

    for (final challenge in open) {
      final entry = joined[challenge.id];
      // Not joined, or already finished — completion is a moment and a
      // later write must not reopen it.
      if (entry == null || entry.isComplete) continue;
      final progress = switch (challenge.kind) {
        ChallengeKind.sessions => logs.length,
        ChallengeKind.streak => prefs.maxStreak,
        ChallengeKind.xp => xp,
        ChallengeKind.consistency =>
          ((logs.length / kProgrammeDays) * 100).round().clamp(0, 100),
      };
      // Nothing changed: skip the write rather than spend a round trip
      // saying so.
      if (progress <= entry.progress) continue;
      await repository.reportChallengeProgress(
        challenge: challenge,
        progress: progress,
      );
      if (progress >= challenge.target) {
        unawaited(
          AnalyticsService.instance.challengeCompleted(slug: challenge.slug),
        );
      }
    }
  }

  /// Roadmap Phase 12 (C22) · mirrors what this pass credited into the
  /// squad feed.
  ///
  /// This lives here rather than in a listener of its own because the
  /// ledgers above are already the answer to "is this new?", and a
  /// second component asking that question would be a second, subtly
  /// different answer. `CommunityRepository.recordActivity` is a no-op
  /// for a user in no squad, which is the common case.
  ///
  /// # Why a backfill publishes nothing
  ///
  /// The ledgers default to empty, so a reinstall whose session logs
  /// come back from the cloud finds the entire history uncredited and
  /// walks it. Posting forty "trained today" lines into a squad because
  /// somebody changed phones is the worst thing this feature could do.
  ///
  /// Guarding one *pass* is not enough, and the test suite is where that
  /// showed up twice. `markSessionDayAwarded` is async and is not
  /// awaited, so crediting XP re-enters `_evaluate` before the ledger
  /// writes land and a long backlog arrives as several small passes,
  /// each of which looks live on its own. Settling on the first pass
  /// that credits nothing does not fix it either: badges are derived
  /// from session logs and unlock a microtask *after* the workouts they
  /// came from are credited, so the quiet pass lands in the gap and the
  /// badge publishes anyway.
  ///
  /// What actually distinguishes a live signal is that **the app was
  /// already running when it happened**, so that is what is measured:
  /// publishing turns on [kFeedPublishAfterMount] after mount and
  /// everything before it is history. A crude clock beats a clever
  /// predicate here — the two predicates above were both wrong, and
  /// this one cannot be, because a workout takes minutes.
  ///
  /// # Why nothing is retried
  ///
  /// The ledger is marked before the write is attempted, so a failed
  /// write loses the event permanently. That is the intended trade: a
  /// retry queue for feed lines would eventually post "trained today"
  /// about a Tuesday, and a missing line is a smaller wrong than a
  /// false one. Nothing downstream reads the feed, so nothing else
  /// drifts.
  void _publish({
    required int days,
    required List<String> badges,
    required int milestone,
    required int levelBefore,
    required int levelAfter,
  }) {
    if (!_live) return;
    if (days > 1) return; // a live pass can only ever credit one day
    if (days == 0 && badges.isEmpty && milestone == 0) return;

    final community = ref.read(communityRepositoryProvider);
    void send(ActivityKind kind, {int? value, String? token}) {
      // Fire and forget: a feed write must never be able to delay or
      // fail an XP award, which is the thing the user actually sees.
      unawaited(
          community.recordActivity(kind: kind, value: value, token: token));
    }

    if (days == 1) send(ActivityKind.workoutCompleted);
    if (days == 1) unawaited(_reportChallengeProgress());
    for (final id in badges) {
      send(ActivityKind.badgeEarned, token: id);
    }
    if (milestone > 0) {
      send(ActivityKind.streakMilestone, value: milestone);
    }
    // One line for the level reached, not one per level crossed. A
    // single workout can cross two on the early curve, and "reached
    // level 4" then "reached level 5" reads as a bug.
    if (levelAfter > levelBefore) {
      send(ActivityKind.levelUp, value: levelAfter);
    }
  }
}
