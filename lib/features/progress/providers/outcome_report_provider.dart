import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../workout/data/session_log_repository.dart';
import '../data/body_metrics_repository.dart';
import '../domain/outcome_report.dart';
import 'adherence_provider.dart';
import 'badge_unlocks_provider.dart';
import 'xp_provider.dart';

/// Roadmap Phase 10 (C4, C39) · the outcome report, wired.
///
/// The whole job of this file is to hand [OutcomeReportBuilder] the six
/// things it needs and get out of the way. The arithmetic lives in the
/// domain, is pure, and is tested without a `ProviderContainer`; keeping
/// this layer to plumbing is what makes that possible.
///
/// **`asOf` is `DateTime.now()` and that is the only impurity.** It is
/// read here, at the edge, rather than inside the builder — which is why
/// the builder can be tested against a fixed calendar and why a report
/// generated at 23:59 and one generated at 00:01 differ by exactly one
/// day rather than unpredictably.
///
/// It watches the session logs and the body metrics, so logging a
/// workout or a weight rebuilds the report without anyone invalidating
/// anything. Badges, XP and adherence are all derived from those two
/// sources anyway.
final outcomeReportProvider = Provider<OutcomeReport?>((ref) {
  final logs = ref.watch(sessionLogsProvider).value;
  final metrics = ref.watch(bodyMetricsProvider).value;
  // Null while either source is still loading. A report assembled from
  // half its inputs would render a smaller number than the truth and
  // then silently correct itself, which is worse than a spinner —
  // somebody would screenshot the wrong one.
  if (logs == null || metrics == null) return null;

  final unlocked = ref.watch(unlockedBadgesProvider);
  return OutcomeReportBuilder.build(
    sessionLogs: logs,
    bodyMetrics: metrics,
    // Catalogue order, not set order: a `Set<String>` has no meaningful
    // order and the timeline would shuffle between builds.
    unlockedBadgeIds: [
      for (final badge in kBadgeCatalog)
        if (unlocked.contains(badge.id)) badge.id,
    ],
    adherence: ref.watch(adherenceProvider),
    lifetimeXp: ref.watch(lifetimeXpProvider),
    level: ref.watch(currentLevelProvider),
    programLength: AppConstants.programLength,
    kcalPerCompletedDay: AppConstants.kcalPerCompletedDay,
    asOf: DateTime.now(),
  );
});
