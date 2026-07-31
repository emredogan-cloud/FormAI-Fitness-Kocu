import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workout/data/session_log_repository.dart';
import 'app_preferences.dart';
import 'feature_flags.dart';
import 'progressive_disclosure.dart';

/// Roadmap Phase 4 (R1.3) · wiring between the pure disclosure rules and
/// the app's live state.
///
/// The rules themselves live in `progressive_disclosure.dart` and take a
/// plain value object, which is what makes them exhaustively testable.
/// This file is the only place that knows where those values come from.

/// Completed sessions, from the session-log ledger.
///
/// Session logs rather than the day-completion flags: a log is written
/// per finished day and is the same substrate the stats surfaces plot,
/// so "sessions" here means exactly what the user would count.
final completedSessionCountProvider = Provider<int>((ref) {
  return ref.watch(sessionLogsProvider).maybeWhen(
        data: (logs) => logs.length,
        orElse: () => 0,
      );
});

/// The live disclosure inputs.
final disclosureStateProvider = Provider<DisclosureState>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final flags = ref.watch(featureFlagsProvider);
  return DisclosureState(
    daysSinceInstall: prefs.daysSinceInstall,
    completedSessions: ref.watch(completedSessionCountProvider),
    manuallyUnlocked: prefs.manualUnlocks,
    enabled: flags.isEnabled(FeatureFlag.progressiveDisclosure),
    grandfathered: prefs.disclosureGrandfathered,
  );
});

/// Whether a given capability is open right now.
final capabilityUnlockedProvider =
    Provider.family<bool, Capability>((ref, capability) {
  return isUnlocked(capability, ref.watch(disclosureStateProvider));
});

/// Decides, once, whether this install predates staged disclosure.
///
/// A user who is already on day 40 with 12 sessions when this ships must
/// not suddenly find capabilities "locked" — that would be taking away
/// surfaces they already use, which is the one thing disclosure must
/// never do. The check is deliberately generous: any prior evidence of
/// real use grandfathers the install.
///
/// Idempotent: it only ever sets the flag, never clears it.
///
/// Takes plain values rather than a `Ref` so the decision itself is
/// directly testable without a container.
Future<void> applyDisclosureGrandfathering({
  required AppPreferences prefs,
  required int completedSessions,
}) async {
  if (prefs.disclosureGrandfathered) return;

  // A fresh install has 0 days and 0 sessions, and must NOT be
  // grandfathered — it is the cohort the schedule exists for.
  final established = prefs.daysSinceInstall >= 1 || completedSessions >= 1;
  if (established) {
    await prefs.setDisclosureGrandfathered(true);
  }
}

/// Called once from app start.
Future<void> ensureDisclosureGrandfathering(WidgetRef ref) {
  return applyDisclosureGrandfathering(
    prefs: ref.read(appPreferencesProvider),
    completedSessions: ref.read(completedSessionCountProvider),
  );
}
