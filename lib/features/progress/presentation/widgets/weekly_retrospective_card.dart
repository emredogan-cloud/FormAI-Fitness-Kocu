import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';

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
/// Numbers:
///   • X — workouts completed THIS WEEK (the 7-day bucket containing
///     the user's first incomplete day, matching the rest of Gelişim's
///     weekly slicing).
///   • Y — kcal burned ≈ X * `AppConstants.kcalPerCompletedDay`. We
///     don't track per-workout calorimetry yet; the constant is the
///     same one the Yakılan Kalori card uses so the two surfaces stay
///     consistent.
///   • Z — nutrition adherence as `min(100, nutritionStreak/7 * 100)`.
///     We don't yet persist per-day macro hit/miss history, so the
///     existing daily "Yedim/Atla" streak counter is the best proxy.
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
    final weeklyKcal = weeklyCompleted * AppConstants.kcalPerCompletedDay;

    final nutritionStreak = ref.watch(appPreferencesProvider).nutritionStreak;
    final nutritionAdherence =
        ((nutritionStreak / 7) * 100).clamp(0, 100).round();

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
              const Text(
                'HAFTANIN ÖZETİ',
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
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
              children: [
                const TextSpan(text: 'Bu hafta '),
                _bold('$weeklyCompleted antrenman'),
                const TextSpan(text: ' yaptın, '),
                _bold('${_formatKcal(weeklyKcal)} kcal'),
                const TextSpan(text: ' yaktın. Beslenme hedefine '),
                _bold('%$nutritionAdherence'),
                const TextSpan(text: ' uydun. Gelecek hafta için hazır mısın?'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                icon: Icons.fitness_center,
                label: '$weeklyCompleted',
                hint: 'antrenman',
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.local_fire_department,
                label: _formatKcal(weeklyKcal),
                hint: 'kcal',
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.restaurant_menu,
                label: '%$nutritionAdherence',
                hint: 'beslenme',
              ),
            ],
          ),
        ],
      ),
    );
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

  String _formatKcal(int kcal) {
    if (kcal < 1000) return '$kcal';
    final s = kcal.toString();
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
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
              alignment: Alignment.centerLeft,
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
