import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../workout/data/session_log_repository.dart';
import '../../../workout/models/session_log_model.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 52 · weekly retrospective card. Surfaces every Sunday on the
/// Gelişim tab to bookend the user's training week with a snapshot of
/// what they actually did. The intent is loss-aversion-via-celebration:
/// even a partial week (1-2 workouts) reads as progress when the card
/// names it explicitly, which keeps the user engaged into the next
/// 7-day cycle instead of treating Sunday as "the streak's natural
/// end".
///
/// Render gate: caller passes a [today] (defaults to `DateTime.now()`)
/// so widget tests can simulate any day of the week. The card returns
/// `SizedBox.shrink()` on non-Sundays so the parent doesn't need to
/// guard the visibility itself.
///
/// Numbers (all measured — the honesty pass removed the estimated
/// kcal constant and the always-zero nutrition-adherence proxy):
///   • X — workouts completed THIS WEEK (the 7-day bucket containing
///     the user's first incomplete day, matching the rest of Gelişim's
///     weekly slicing).
///   • Y — minutes actually trained, summed from the week's
///     session-log `durationSeconds`.
///   • Z — reps actually completed, summed from the week's
///     session-log exercise entries.
class WeeklyRetrospectiveCard extends ConsumerWidget {
  const WeeklyRetrospectiveCard({super.key, this.today});

  /// Injected for testability. Production callers leave it null and
  /// the card resolves the current date itself.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = today ?? DateTime.now();
    if (now.weekday != DateTime.sunday) return const SizedBox.shrink();

    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final activeDayNumber = _firstActiveDayNumber(days);
    final weekIndex = ((activeDayNumber - 1) ~/ 7).clamp(0, 4);
    final weekStart = weekIndex * 7 + 1;
    final weeklyDays = days
        .where(
          (d) => d.dayNumber >= weekStart && d.dayNumber < weekStart + 7,
        )
        .toList(growable: false);
    final weeklyCompleted = weeklyDays.where((d) => d.isCompleted).length;
    // Honesty pass · the retrospective used to claim "X kcal yaktın"
    // from a flat completions × 250 constant and a "%N beslenme"
    // adherence derived from a streak counter that is structurally
    // always 0. Both replaced with MEASURED session-log numbers.
    final logs =
        ref.watch(sessionLogsProvider).value ?? const <int, SessionLog>{};
    var weeklyMinutes = 0;
    var weeklyReps = 0;
    for (var dn = weekStart; dn < weekStart + 7; dn++) {
      final log = logs[dn];
      if (log != null) {
        weeklyMinutes += (log.durationSeconds / 60).round();
        weeklyReps += log.totalReps;
      }
    }

    return Container(
      // Self-padding on the bottom so the parent ListView in `gelisim_tab`
      // can drop its own SizedBox under us. When the card is hidden
      // (non-Sundays) the parent's spacing collapses too, instead of
      // leaving a tall gap where the retrospective would otherwise sit.
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.neonDeep.withValues(alpha: 0.65),
            AppColors.neon.withValues(alpha: 0.30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).retrospectiveEyebrow,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Roadmap Phase 5 · one parameterised sentence rather than
          // seven concatenated spans.
          //
          // The old form hardcoded Turkish clause order into the widget
          // tree, so no translator could have reordered it — and several
          // languages must. The bold emphasis on the three numbers is
          // preserved by splitting the rendered sentence around the
          // substituted fragments, which keeps the visual design while
          // letting the sentence be rewritten freely around them.
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
              children: _emphasised(
                AppLocalizations.of(context).retrospectiveSummary(
                  AppLocalizations.of(context)
                      .retrospectiveWorkoutsValue(weeklyCompleted),
                  AppLocalizations.of(context)
                      .retrospectiveMinutesValue(weeklyMinutes),
                  AppLocalizations.of(context)
                      .retrospectiveRepsValue(weeklyReps),
                ),
                [
                  AppLocalizations.of(context)
                      .retrospectiveWorkoutsValue(weeklyCompleted),
                  AppLocalizations.of(context)
                      .retrospectiveMinutesValue(weeklyMinutes),
                  AppLocalizations.of(context)
                      .retrospectiveRepsValue(weeklyReps),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                icon: Icons.fitness_center,
                label: '$weeklyCompleted',
                hint: AppLocalizations.of(context).progressUnitWorkouts,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.timer_outlined,
                label: '$weeklyMinutes',
                hint: AppLocalizations.of(context).progressUnitMinutes,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.repeat_rounded,
                label: '$weeklyReps',
                hint: AppLocalizations.of(context).progressUnitReps,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns the day number of the first incomplete non-rest day, or 1
  /// when no such day exists (program complete or empty list). Mirrors
  /// the slicing logic the Gelişim tab already uses for its weekly
  /// stats cards so the retrospective and the bars-chart agree on
  /// "this week".
  int _firstActiveDayNumber(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day.dayNumber;
    }
    return 1;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splits [sentence] around each of [emphasise] and returns spans with
/// those fragments bolded.
///
/// A fragment the translator dropped simply isn't found and isn't
/// bolded — the sentence still renders correctly, which is the right
/// failure mode for a cosmetic concern.
List<TextSpan> _emphasised(String sentence, List<String> emphasise) {
  var spans = <TextSpan>[TextSpan(text: sentence)];
  for (final fragment in emphasise) {
    if (fragment.isEmpty) continue;
    final next = <TextSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || span.style != null || !text.contains(fragment)) {
        next.add(span);
        continue;
      }
      final index = text.indexOf(fragment);
      if (index > 0) next.add(TextSpan(text: text.substring(0, index)));
      next.add(_bold(fragment));
      final rest = text.substring(index + fragment.length);
      if (rest.isNotEmpty) next.add(TextSpan(text: rest));
    }
    spans = next;
  }
  return spans;
}

TextSpan _bold(String text) {
  return TextSpan(
    text: text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
    ),
  );
}
