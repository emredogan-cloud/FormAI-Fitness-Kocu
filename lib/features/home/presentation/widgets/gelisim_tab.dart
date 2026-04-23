import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _success = Color(0xFF39FF14);
const Color _restAmber = Color(0xFFFFB84D);
const Color _inactive = Color(0xFF1C1C24);

const int _programLength = 30;
const int _freeDayLimit = 3;
const int _kcalPerDay = 250;

/// Phase 36 Gelişim rebuild. The tab shifted from a passive tracker to
/// an active loop: streak + percent hero, a glowing "Bugünkü Görev"
/// card with a one-tap CTA into today's workout, a 4-state 30-day grid
/// (current / completed / rest / locked), a weekly stats row, and a
/// container-based calorie chart.
class GelisimTab extends ConsumerWidget {
  const GelisimTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final completedCount = days.where((d) => d.isCompleted).length;
    final streak = _streakOf(days);
    final activeDay = _firstIncomplete(days);
    // Fall back to "1" pre-load so the grid doesn't mark day 31 as
    // current on first paint while the cache is still resolving.
    final activeDayNumber = activeDay?.dayNumber ?? 1;
    final percent = (completedCount / _programLength).clamp(0.0, 1.0);
    final isProgramComplete = days.isNotEmpty && activeDay == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        const Text(
          'Gelişim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'İlerlemen bir bakışta.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 22),
        _HeroSection(
          streak: streak,
          percent: percent,
        ),
        const SizedBox(height: 18),
        if (isProgramComplete)
          const _ProgramCompleteCard()
        else if (activeDay != null)
          _NextActionCard(activeDay: activeDay),
        const SizedBox(height: 24),
        const _SectionLabel(title: '30 GÜNLÜK PROGRAM'),
        const SizedBox(height: 12),
        _DayGrid(days: days, activeDayNumber: activeDayNumber),
        const SizedBox(height: 24),
        const _SectionLabel(title: 'BU HAFTA'),
        const SizedBox(height: 12),
        _WeeklyStatsRow(days: days, activeDayNumber: activeDayNumber),
        const SizedBox(height: 24),
        const _SectionLabel(title: 'HAFTALIK KALORİ'),
        const SizedBox(height: 12),
        _CalorieBarChart(days: days, activeDayNumber: activeDayNumber),
      ],
    );
  }

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

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day;
    }
    return null;
  }
}

// =============================================================================
// Hero — streak badge + percent bar + adaptive motivational line.
// =============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.streak, required this.percent});
  final int streak;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.22),
            _neonAccent.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                '$streak günlük seri',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('📈', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '%${(percent * 100).round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'program tamamlandı',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(_neon),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _motivationalCopy(streak, percent),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String _motivationalCopy(int streak, double percent) {
    if (percent >= 1.0) return 'Başardın — 30 günlük yolculuk tamam!';
    if (streak >= 7) return 'İnanılmaz! Momentum tamamen seninle.';
    if (streak >= 3) return 'Harika gidiyorsun, devam et!';
    if (streak >= 1) return 'İyi başlangıç — bugün seriyi uzat.';
    return 'Hadi başlayalım — bugünkü görevin hazır.';
  }
}

// =============================================================================
// Next Action — glowing neon card. Tap starts today's workout directly,
// short-circuiting to /paywall if the day is beyond the free-tier window
// and the user isn't PRO.
// =============================================================================

class _NextActionCard extends ConsumerWidget {
  const _NextActionCard({required this.activeDay});
  final WorkoutDay activeDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = _focusLabel(activeDay);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _launch(context, ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🎯', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'Bugünkü Görev',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gün ${activeDay.dayNumber} · $focus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0.2,
                      shadows: [Shadow(blurRadius: 14, color: Colors.black45)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${activeDay.exercises.length} egzersiz bekliyor',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'ANTRENMANA BAŞLA',
                      style: TextStyle(
                        color: _neon,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    if (activeDay.exercises.isEmpty) return;
    final isPro = ref.read(isProProvider);
    if (!isPro && activeDay.dayNumber > _freeDayLimit) {
      HapticFeedback.lightImpact();
      context.push(AppRoutes.paywall);
      return;
    }
    HapticFeedback.mediumImpact();
    await ref
        .read(workoutSessionProvider.notifier)
        .startDay(activeDay.dayNumber);
    if (!context.mounted) return;
    context.push(AppRoutes.workout);
  }

  /// Maps the day's dominant `targetMuscle` to a short Turkish focus
  /// label. Parallels the helpers on the antrenman and plan-detail
  /// surfaces so the same day renders the same sub-title everywhere.
  String _focusLabel(WorkoutDay day) {
    if (day.isRestDay) return 'Aktif Dinlenme';
    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Antrenman';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return 'Karın & Core';
      case 'upper_body':
        return 'Göğüs & Kol';
      case 'lower_body':
        return 'Bacak Gücü';
      case 'cardio':
        return 'Yağ Yakıcı Kardiyo';
      case 'full_body':
        return 'Tüm Vücut HIIT';
      default:
        return 'Antrenman';
    }
  }
}

/// Rendered in place of the next-action card once every workout day is
/// marked complete. Keeps the section height stable so the subsequent
/// stats / chart don't jump up.
class _ProgramCompleteCard extends StatelessWidget {
  const _ProgramCompleteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: _success.withValues(alpha: 0.12),
        border: Border.all(color: _success.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: _success.withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tebrikler!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '30 günlük programı tamamladın.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

// =============================================================================
// Section label (shared, same style as pre-phase-36).
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// =============================================================================
// 30-day grid. Cells pick one of four states: CURRENT (pulsing neon),
// COMPLETED (green glow + check + tap SnackBar), REST (amber coffee),
// LOCKED (dimmed + IgnorePointer).
// =============================================================================

enum _CellState { completed, current, rest, locked }

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days, required this.activeDayNumber});
  final List<WorkoutDay> days;
  final int activeDayNumber;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _programLength,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index + 1;
        final realDay = _findDay(dayNumber);
        final state = _stateFor(dayNumber, realDay);
        return _DayCell(dayNumber: dayNumber, state: state);
      },
    );
  }

  WorkoutDay? _findDay(int dayNumber) {
    for (final d in days) {
      if (d.dayNumber == dayNumber) return d;
    }
    return null;
  }

  _CellState _stateFor(int dayNumber, WorkoutDay? real) {
    if (real?.isCompleted ?? false) return _CellState.completed;
    if (real?.isRestDay ?? false) return _CellState.rest;
    if (dayNumber == activeDayNumber) return _CellState.current;
    return _CellState.locked;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.dayNumber, required this.state});
  final int dayNumber;
  final _CellState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _CellState.current:
        return _PulsingCurrentCell(dayNumber: dayNumber);
      case _CellState.completed:
        return _CompletedCell(dayNumber: dayNumber);
      case _CellState.rest:
        return _RestCell(dayNumber: dayNumber);
      case _CellState.locked:
        return _LockedCell(dayNumber: dayNumber);
    }
  }
}

class _PulsingCurrentCell extends StatefulWidget {
  const _PulsingCurrentCell({required this.dayNumber});
  final int dayNumber;

  @override
  State<_PulsingCurrentCell> createState() => _PulsingCurrentCellState();
}

class _PulsingCurrentCellState extends State<_PulsingCurrentCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final glowBlur = 12.0 + t * 14;
        final glowAlpha = 0.55 + t * 0.30;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [_neon, _neonAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 1.2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 16,
              ),
              Text(
                '${widget.dayNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompletedCell extends StatelessWidget {
  const _CompletedCell({required this.dayNumber});
  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Gün $dayNumber tamamlandı!'),
                backgroundColor: _success.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _success.withValues(alpha: 0.12),
            border: Border.all(color: _success.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: _success.withValues(alpha: 0.28),
                blurRadius: 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, color: _success, size: 14),
              Text(
                '$dayNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestCell extends StatelessWidget {
  const _RestCell({required this.dayNumber});
  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _restAmber.withValues(alpha: 0.08),
        border: Border.all(color: _restAmber.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_cafe,
            color: _restAmber.withValues(alpha: 0.9),
            size: 14,
          ),
          Text(
            '$dayNumber',
            style: TextStyle(
              color: _restAmber.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCell extends StatelessWidget {
  const _LockedCell({required this.dayNumber});
  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.42,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _inactive,
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 12),
              Text(
                '$dayNumber',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Weekly stats row — snaps to the 7-day bucket the active day falls in
// so mid-program users see this week's numbers, not the first week's.
// =============================================================================

class _WeeklyStatsRow extends StatelessWidget {
  const _WeeklyStatsRow({required this.days, required this.activeDayNumber});
  final List<WorkoutDay> days;
  final int activeDayNumber;

  @override
  Widget build(BuildContext context) {
    final weekIndex = ((activeDayNumber - 1) ~/ 7).clamp(0, 4);
    final weekStart = weekIndex * 7 + 1;
    final weekEnd = (weekStart + 6).clamp(1, _programLength);
    final weekDays = days
        .where((d) => d.dayNumber >= weekStart && d.dayNumber <= weekEnd)
        .toList();
    final completedThisWeek = weekDays.where((d) => d.isCompleted).length;
    final kcal = completedThisWeek * _kcalPerDay;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            emoji: '🔥',
            value: '$completedThisWeek/7',
            label: 'gün',
            accent: _neon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            emoji: '⚡',
            value: '$kcal',
            label: 'kcal',
            accent: _neonAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            emoji: '💪',
            value: '$completedThisWeek',
            label: 'antrenman',
            accent: _success,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accent,
  });

  final String emoji;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Calorie bar chart — Row of vertical gradient containers, one bar per
// day in the active week. Replaces the phase-24 `fl_chart` widget so
// the strip picks up the same neon card language without a chart-lib
// dependency just for this screen.
// =============================================================================

class _CalorieBarChart extends StatelessWidget {
  const _CalorieBarChart({required this.days, required this.activeDayNumber});
  final List<WorkoutDay> days;
  final int activeDayNumber;

  static const List<String> _labels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];
  static const double _maxHeight = 120;
  static const double _floorHeight = 10;

  @override
  Widget build(BuildContext context) {
    final weekIndex = ((activeDayNumber - 1) ~/ 7).clamp(0, 4);
    final weekStart = weekIndex * 7 + 1;
    final bars = List<_BarData>.generate(7, (i) {
      final dayNumber = weekStart + i;
      if (dayNumber > _programLength) {
        return const _BarData(kcal: 0, isCompleted: false, isCurrent: false);
      }
      final match = days.where((d) => d.dayNumber == dayNumber);
      final completed = match.isNotEmpty && match.first.isCompleted;
      return _BarData(
        kcal: completed ? _kcalPerDay : 0,
        isCompleted: completed,
        isCurrent: dayNumber == activeDayNumber,
      );
    });
    final totalKcal = bars.fold<int>(0, (a, b) => a + b.kcal);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: _neonAccent, size: 18),
              const SizedBox(width: 6),
              Text(
                '$totalKcal kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'bu hafta',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _maxHeight + 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  Expanded(child: _Bar(data: bars[i], label: _labels[i])),
                  if (i < bars.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  const _BarData({
    required this.kcal,
    required this.isCompleted,
    required this.isCurrent,
  });
  final int kcal;
  final bool isCompleted;
  final bool isCurrent;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.data, required this.label});
  final _BarData data;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double targetHeight;
    final Gradient? gradient;
    final Color flatColor;
    if (data.isCompleted) {
      targetHeight = _CalorieBarChart._maxHeight;
      gradient = const LinearGradient(
        colors: [_neonAccent, _neon],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
      flatColor = Colors.transparent;
    } else if (data.isCurrent) {
      targetHeight = _CalorieBarChart._maxHeight * 0.40;
      gradient = LinearGradient(
        colors: [
          _neon.withValues(alpha: 0.5),
          _neon.withValues(alpha: 0.18),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
      flatColor = Colors.transparent;
    } else {
      targetHeight = _CalorieBarChart._floorHeight;
      gradient = null;
      flatColor = Colors.white12;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (data.kcal > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${data.kcal}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: _CalorieBarChart._floorHeight,
            end: targetHeight,
          ),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Container(
            height: value,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: gradient,
              color: gradient == null ? flatColor : null,
              boxShadow: data.isCompleted
                  ? [
                      BoxShadow(
                        color: _neon.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: data.isCurrent ? _neon : Colors.white54,
            fontSize: 11,
            fontWeight: data.isCurrent ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
