import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/neon_surface.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/program_progression.dart';
import '../providers/workout_provider.dart';

/// Roadmap Phase 14 (C40, P5, R5) · day 31.
///
/// # Every path is offered; exactly one is marked
///
/// `recommend()` reads what the user actually did — completed days over
/// total — and marks the path that fits it. It does not choose. The
/// roadmap's requirement for the difficulty tiers is that they are
/// "explained honestly so users self-select correctly", and a program
/// that silently got harder is indistinguishable, from the inside, from
/// a body that got weaker.
///
/// # The card copy changes with the reading
///
/// Somebody who finished 11 of 30 days sees "Run the program again" —
/// same load, and the honest reason underneath it. Somebody who
/// finished 28 sees "Repeat with more volume". They are the same
/// [ContinuationPath]; what differs is the overload the recommendation
/// carries, and pretending otherwise would put the same sentence in
/// front of two people in opposite situations.
///
/// # What choosing actually does
///
/// Every path ends in `WorkoutRepository.resetProgress()`, which drops
/// the completion ledger, the plan cache and its fingerprint. What
/// differs is the state written *before* the reset:
///
///   * repeat  → the cycle overload moves up by the recommended step;
///   * tier    → `userMetrics['activityLevel']`, and the overload RESETS
///               to 1.0 because the tier change is the increase;
///   * focus   → `userMetrics['targetPhysique']`;
///   * hold    → the maintenance flag, which halves the rest cadence.
///
/// The plan cache is keyed by a fingerprint over all of those, so the
/// next program load regenerates rather than serving the old plan back.
class ProgramContinuationScreen extends ConsumerStatefulWidget {
  const ProgramContinuationScreen({super.key});

  @override
  ConsumerState<ProgramContinuationScreen> createState() =>
      _ProgramContinuationScreenState();
}

class _ProgramContinuationScreenState
    extends ConsumerState<ProgramContinuationScreen> {
  bool _busy = false;

  /// Builds the outcome from the program the user just finished.
  ///
  /// `isStub` matters here more than anywhere else in the app: a
  /// 30-rest-day placeholder has zero completed days out of thirty,
  /// which reads as a total failure and would recommend repeating at
  /// the same load. The caller never opens this screen on a stub, and
  /// this guard is the second line.
  ProgramOutcome? _outcome() {
    final session = ref.read(workoutSessionProvider).value;
    if (session == null || session.isStub) return null;
    final days = session.days;
    if (days.isEmpty) return null;
    final metrics = ref.read(appPreferencesProvider).userMetrics ??
        const <String, dynamic>{};
    return ProgramOutcome(
      completedDays: days.where((d) => d.isCompleted).length,
      totalDays: days.length,
      tier: DifficultyTier.fromToken(metrics['activityLevel'] as String?),
    );
  }

  Future<void> _choose(
    ContinuationPath path,
    ContinuationRecommendation recommended,
    ProgramOutcome outcome, {
    String? goal,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final prefs = ref.read(appPreferencesProvider);
    try {
      final metrics = Map<String, dynamic>.from(prefs.userMetrics ?? const {});
      var tier = recommended.tier;

      switch (path) {
        case ContinuationPath.repeatWithProgression:
          tier = DifficultyTier.fromToken(metrics['activityLevel'] as String?);
          // `repeatOverloadFor`, NOT `recommended.overload`. They differ
          // for exactly one outcome — a strong finisher, whose
          // recommendation is a tier at 1.0 volume — and reading the
          // recommendation there would hand them the same program back
          // under a card that promised more.
          await prefs.setProgramCycleOverload(
            nextCycleOverload(
              prefs.programCycleOverload,
              repeatOverloadFor(outcome),
            ),
          );
          await prefs.setMaintenanceMode(false);
        case ContinuationPath.advanceTier:
          metrics['activityLevel'] = tier.token;
          await prefs.saveUserMetrics(metrics);
          // The tier IS the increase. Carrying the old cycle overload
          // into a harder tier is two increases at once, which is the
          // thing `recommend()` refuses to do in one step.
          await prefs.setProgramCycleOverload(1.0);
          await prefs.setMaintenanceMode(false);
        case ContinuationPath.switchFocus:
          if (goal != null) {
            metrics['targetPhysique'] = goal;
            await prefs.saveUserMetrics(metrics);
          }
          tier = DifficultyTier.fromToken(metrics['activityLevel'] as String?);
          await prefs.setMaintenanceMode(false);
        case ContinuationPath.maintenance:
          tier = DifficultyTier.fromToken(metrics['activityLevel'] as String?);
          await prefs.setMaintenanceMode(true);
          // Holding what you built is not the moment to add volume.
          await prefs.setProgramCycleOverload(1.0);
      }

      await ref.read(workoutRepositoryProvider).resetProgress();
      ref.invalidate(workoutSessionProvider);

      unawaited(
        AnalyticsService.instance.programContinuationChosen(
          path: path.name,
          tier: tier.token,
          wasRecommended: path == recommended.path,
        ),
      );
      if (mounted) navigator.pop(true);
    } catch (e, st) {
      AppLogger.error('continuation choice failed', e,
          stackTrace: st, category: 'workout');
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The focus picker. Three goals, minus the one they are already on —
  /// "switch focus" to the focus you already have is not a choice.
  Future<void> _pickFocus(
    ContinuationRecommendation recommended,
    ProgramOutcome outcome,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = (ref.read(appPreferencesProvider).userMetrics ??
        const {})['targetPhysique'] as String?;
    final options = <String, String>{
      'sixpack': l10n.goalSixpackLabel, // i18n-ignore — stored goal token
      'bulk': l10n.goalBulkLabel, // i18n-ignore — stored goal token
      'tone': l10n.goalToneLabel, // i18n-ignore — stored goal token
    }..removeWhere((token, _) => token == current);

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeonSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              l10n.continueSwitchTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in options.entries)
              ListTile(
                title: Text(
                  entry.value,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: NeonSurface.muted),
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _choose(ContinuationPath.switchFocus, recommended, outcome,
        goal: picked);
  }

  String _tierName(AppLocalizations l10n, DifficultyTier tier) =>
      switch (tier) {
        DifficultyTier.beginner => l10n.tierBeginner,
        DifficultyTier.intermediate => l10n.tierIntermediate,
        DifficultyTier.advanced => l10n.tierAdvanced,
      };

  String _fitLine(AppLocalizations l10n, ProgramFit fit) => switch (fit) {
        ProgramFit.tooHard => l10n.fitTooHard,
        ProgramFit.tooEasy => l10n.fitTooEasy,
        ProgramFit.wellMatched => l10n.fitWellMatched,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outcome = _outcome();

    if (outcome == null) {
      // Nothing to reason from. Closing is better than guessing an
      // outcome and recommending off it.
      return Scaffold(
        backgroundColor: NeonSurface.bg,
        appBar: AppBar(
          backgroundColor: NeonSurface.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.programCompleteTitle),
        ),
        body: const SizedBox.shrink(),
      );
    }

    final recommended = recommend(outcome);
    final nextTier = outcome.tier.next;
    // What a repeat would actually carry — see `repeatOverloadFor`.
    final repeatOverload = repeatOverloadFor(outcome);

    return Scaffold(
      backgroundColor: NeonSurface.bg,
      appBar: AppBar(
        backgroundColor: NeonSurface.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.programCompleteTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NeonSurface.gutter),
          children: [
            Text(
              l10n.programCompleteBody(
                outcome.totalDays,
                outcome.completedDays,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fitLine(l10n, recommended.fit),
              style: const TextStyle(
                color: NeonSurface.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),

            // Repeat. The copy splits on whether the recommendation
            // carries any overload — the same path means two different
            // things to somebody who finished 28 days and somebody who
            // finished 11, and one sentence for both would be false to
            // one of them.
            _PathCard(
              title: repeatOverload > 1.0
                  ? l10n.continueRepeatTitle
                  : l10n.continueRepeatSameTitle,
              body: repeatOverload > 1.0
                  ? l10n.continueRepeatBody
                  : l10n.continueRepeatSameBody,
              recommended:
                  recommended.path == ContinuationPath.repeatWithProgression,
              recommendedLabel: l10n.continueRecommended,
              enabled: !_busy,
              onTap: () => _choose(
                ContinuationPath.repeatWithProgression,
                recommended,
                outcome,
              ),
            ),

            // Only when there is a tier above. An advanced user is
            // offered a change of focus instead, which is the dead end
            // this phase exists to remove.
            if (nextTier != null)
              _PathCard(
                title: l10n.continueAdvanceTitle(_tierName(l10n, nextTier)),
                body: l10n.continueAdvanceBody,
                recommended: recommended.path == ContinuationPath.advanceTier,
                recommendedLabel: l10n.continueRecommended,
                enabled: !_busy,
                onTap: () =>
                    _choose(ContinuationPath.advanceTier, recommended, outcome),
              ),

            _PathCard(
              title: l10n.continueSwitchTitle,
              body: l10n.continueSwitchBody,
              recommended: recommended.path == ContinuationPath.switchFocus,
              recommendedLabel: l10n.continueRecommended,
              enabled: !_busy,
              onTap: () => _pickFocus(recommended, outcome),
            ),

            _PathCard(
              title: l10n.continueMaintenanceTitle,
              body: l10n.continueMaintenanceBody,
              // Never marked. Recommending that somebody stop
              // progressing is not a call an algorithm gets to make
              // from a completion count — `recommend()` never returns
              // it and a test pins that.
              recommended: false,
              recommendedLabel: l10n.continueRecommended,
              enabled: !_busy,
              onTap: () =>
                  _choose(ContinuationPath.maintenance, recommended, outcome),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.title,
    required this.body,
    required this.recommended,
    required this.recommendedLabel,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String body;
  final bool recommended;
  final String recommendedLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: NeonSurface.card,
        borderRadius: BorderRadius.circular(NeonSurface.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(NeonSurface.radius),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NeonSurface.radius),
              border: Border.all(
                color: recommended ? NeonSurface.lime : NeonSurface.hairline,
                width: recommended ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: NeonSurface.lime,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recommendedLabel,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: NeonSurface.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
