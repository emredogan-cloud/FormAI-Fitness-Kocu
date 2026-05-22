import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../workout/data/session_log_repository.dart';
import '../../workout/models/session_log_model.dart';
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

class XpAwardListener extends Notifier<void> {
  @override
  void build() {
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
      }
    }
  }
}
