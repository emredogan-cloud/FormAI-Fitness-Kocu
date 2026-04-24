import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _success = Color(0xFF22C55E);
const Color _orange = Color(0xFFF97316);
const Color _amber = Color(0xFFFFB84D);
const Color _pink = Color(0xFFFF4DDB);
const Color _proteinBlue = Color(0xFF4DA6FF);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);
const int _kcalPerCompletedDay = 250;

/// Phase 47A · full badges gallery.
///
/// Mirrors and expands the 5-badge strip on the Gelişim tab. Derives
/// every unlock state from the same data sources the strip uses
/// (`workoutSessionProvider` for completion counts + streaks,
/// `AppPreferences.nutritionStreak` for the nutrition-streak badges).
///
/// Locked badges render in low-contrast grayscale with a progress
/// percentage beneath the label; unlocked badges light up with the
/// badge's accent colour, a glow halo, and the tier label
/// ("Açıldı!") pinned under the icon. The pattern comes from the
/// Phase 36b reference mock and keeps the same visual grammar used
/// on the Gelişim strip so users instantly recognise which badges
/// they have and which are still in progress.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final completedCount = days.where((d) => d.isCompleted).length;
    final streak = _streakOf(days);
    final weeklyKcal = completedCount * _kcalPerCompletedDay;
    final cardioDaysCompleted = _cardioDaysCompleted(days);
    final coreDaysCompleted = _daysCompletedByMuscle(days, 'core');
    final strengthDaysCompleted = _daysCompletedByStrength(days);
    final nutritionStreak = ref.watch(appPreferencesProvider).nutritionStreak;

    final badges = <_BadgeData>[
      _BadgeData(
        label: 'İlk Adım',
        subtitle: 'İlk gününü bitir',
        icon: Icons.flag_rounded,
        accent: _amber,
        unlocked: completedCount >= 1,
        progress: (completedCount / 1).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Disiplinli',
        subtitle: '3 günlük seri',
        icon: Icons.shield_rounded,
        accent: _neon,
        unlocked: streak >= 3,
        progress: (streak / 3).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'İlk Hafta',
        subtitle: '7 günü tamamla',
        icon: Icons.calendar_view_week_rounded,
        accent: _success,
        unlocked: completedCount >= 7,
        progress: (completedCount / 7).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Sabit',
        subtitle: '7 günlük seri',
        icon: Icons.verified_rounded,
        accent: _orange,
        unlocked: streak >= 7,
        progress: (streak / 7).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Yarıyol',
        subtitle: '14 günü tamamla',
        icon: Icons.hiking_rounded,
        accent: _neonAccent,
        unlocked: completedCount >= 14,
        progress: (completedCount / 14).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Kalori Avcısı',
        subtitle: 'Haftada 1500 kcal',
        icon: Icons.local_fire_department,
        accent: _orange,
        unlocked: weeklyKcal >= 1500,
        progress: (weeklyKcal / 1500).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'HIIT Ustası',
        subtitle: '5 kardiyo günü',
        icon: Icons.bolt_rounded,
        accent: _pink,
        unlocked: cardioDaysCompleted >= 5,
        progress: (cardioDaysCompleted / 5).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Core Master',
        subtitle: '5 karın odaklı gün',
        icon: Icons.center_focus_strong_rounded,
        accent: _proteinBlue,
        unlocked: coreDaysCompleted >= 5,
        progress: (coreDaysCompleted / 5).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Güç Taşı',
        subtitle: '5 güç günü bitir',
        icon: Icons.fitness_center_rounded,
        accent: _neon,
        unlocked: strengthDaysCompleted >= 5,
        progress: (strengthDaysCompleted / 5).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Beslenme Kahramanı',
        subtitle: '7 günlük beslenme serisi',
        icon: Icons.restaurant_rounded,
        accent: _success,
        unlocked: nutritionStreak >= 7,
        progress: (nutritionStreak / 7).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: '30 Gün Şampiyonu',
        subtitle: 'Tüm programı bitir',
        icon: Icons.emoji_events_rounded,
        accent: _amber,
        unlocked: completedCount >= 30,
        progress: (completedCount / 30).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Formun Efsanesi',
        subtitle: '30 gün + 30 beslenme',
        icon: Icons.workspace_premium_rounded,
        accent: _neon,
        unlocked: completedCount >= 30 && nutritionStreak >= 30,
        progress: (((completedCount / 30) + (nutritionStreak / 30)) / 2)
            .clamp(0.0, 1.0),
      ),
    ];

    final unlockedCount = badges.where((b) => b.unlocked).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Rozetler',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.1,
            colors: [Color(0xFF1E0A40), Color(0xFF0A0612), Colors.black],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: _BadgeSummaryCard(
                  unlocked: unlockedCount,
                  total: badges.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverGrid.builder(
                itemCount: badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) =>
                    _BadgeTile(data: badges[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Derivation helpers — keep them pure so a widget test can feed a
  // synthetic `days: []` list and reproduce the unlock predicates.
  // ==========================================================================

  int _streakOf(List<WorkoutDay> days) {
    var streak = 0;
    for (final day in days) {
      if (day.isCompleted) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  int _cardioDaysCompleted(List<WorkoutDay> days) {
    return days.where((d) {
      if (!d.isCompleted) return false;
      if (d.exercises.isEmpty) return false;
      final cardioHits = d.exercises.where((e) => e.isCardio).length;
      return cardioHits >= (d.exercises.length / 2).ceil();
    }).length;
  }

  int _daysCompletedByMuscle(List<WorkoutDay> days, String muscle) {
    return days.where((d) {
      if (!d.isCompleted) return false;
      if (d.exercises.isEmpty) return false;
      return d.exercises.any((e) => e.targetMuscle == muscle);
    }).length;
  }

  int _daysCompletedByStrength(List<WorkoutDay> days) {
    return days.where((d) {
      if (!d.isCompleted) return false;
      if (d.exercises.isEmpty) return false;
      return d.exercises.any((e) =>
          e.targetMuscle == 'upper_body' || e.targetMuscle == 'lower_body');
    }).length;
  }
}

class _BadgeData {
  const _BadgeData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.unlocked,
    required this.progress,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool unlocked;
  final double progress;
}

class _BadgeSummaryCard extends StatelessWidget {
  const _BadgeSummaryCard({required this.unlocked, required this.total});
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221145), Color(0xFF0D0622)],
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.22),
            blurRadius: 20,
            spreadRadius: 0.4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_neon, _neonAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$unlocked / $total kazanıldı',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(_neon),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked == total
                      ? 'Tüm rozetleri topladın — efsane!'
                      : 'Bir sonraki rozet için çalışmaya devam et.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.data});
  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _surface,
        border: Border.all(
          color: data.unlocked
              ? data.accent.withValues(alpha: 0.6)
              : _surfaceBorder,
          width: data.unlocked ? 1.5 : 1,
        ),
        boxShadow: data.unlocked
            ? [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.3),
                  blurRadius: 18,
                  spreadRadius: 0.4,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BadgeMedallion(data: data),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: data.unlocked ? Colors.white : Colors.white60,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: data.unlocked ? Colors.white70 : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          _BadgeStatusPill(data: data),
        ],
      ),
    );
  }
}

class _BadgeMedallion extends StatelessWidget {
  const _BadgeMedallion({required this.data});
  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    final accent = data.accent;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: data.unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.85),
                  accent.withValues(alpha: 0.35),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF20202A), Color(0xFF14141B)],
              ),
        border: Border.all(
          color: data.unlocked ? accent : Colors.white.withValues(alpha: 0.12),
          width: data.unlocked ? 2 : 1,
        ),
        boxShadow: data.unlocked
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 0.6,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        data.icon,
        size: 32,
        color:
            data.unlocked ? Colors.white : Colors.white.withValues(alpha: 0.28),
      ),
    );
  }
}

class _BadgeStatusPill extends StatelessWidget {
  const _BadgeStatusPill({required this.data});
  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    if (data.unlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: data.accent.withValues(alpha: 0.2),
          border: Border.all(color: data.accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, color: data.accent, size: 12),
            const SizedBox(width: 3),
            Text(
              'Açıldı',
              style: TextStyle(
                color: data.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }
    final pct = (data.progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            '%$pct',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
