import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

class _ProButton extends StatelessWidget {
  const _ProButton();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD166);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(AppRoutes.paywall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: gold, width: 1),
            gradient: LinearGradient(
              colors: [
                gold.withValues(alpha: 0.25),
                gold.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👑', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'PRO',
                style: TextStyle(
                  color: gold,
                  fontSize: 12,
                  letterSpacing: 2,
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const Color _neon = Color(0xFF00F0FF);
  static const Color _done = Color(0xFF39FF14);
  static const int _totalDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(workoutSessionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _neon),
          ),
          error: (err, _) => Center(
            child: Text(
              'Program yüklenemedi: $err',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (session) => _buildContent(context, ref, session),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionState session,
  ) {
    final completedCount = session.days.where((d) => d.isCompleted).length;
    final streak = _computeStreak(session.days);
    final nextDay = _nextAvailableDay(session.days);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            streak: streak,
            completed: completedCount,
            total: _totalDays,
          ),
        ),
        SliverToBoxAdapter(
          child: _NextDayCard(
            nextDay: nextDay,
            onStart: nextDay == null
                ? null
                : () => _startDay(context, ref, nextDay.dayNumber),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              '30 GÜNLÜK PROGRAM',
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 3,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dayNumber = index + 1;
                return _DayTile(
                  dayNumber: dayNumber,
                  day: _findDay(session.days, dayNumber),
                  isNext: nextDay?.dayNumber == dayNumber,
                  onTap: () => _startDay(context, ref, dayNumber),
                );
              },
              childCount: _totalDays,
            ),
          ),
        ),
      ],
    );
  }

  void _startDay(BuildContext context, WidgetRef ref, int dayNumber) async {
    final day = _findDay(
      ref.read(workoutSessionProvider).value?.days ?? const [],
      dayNumber,
    );
    if (day == null) return; // Locked day: not yet in program.
    await ref.read(workoutSessionProvider.notifier).startDay(dayNumber);
    if (!context.mounted) return;
    context.push(AppRoutes.workout);
  }

  WorkoutDay? _findDay(List<WorkoutDay> days, int dayNumber) {
    for (final day in days) {
      if (day.dayNumber == dayNumber) return day;
    }
    return null;
  }

  WorkoutDay? _nextAvailableDay(List<WorkoutDay> days) {
    for (final day in days) {
      if (!day.isCompleted) return day;
    }
    return null;
  }

  int _computeStreak(List<WorkoutDay> days) {
    var streak = 0;
    for (final day in days) {
      if (day.isCompleted) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak == 0 ? 1 : streak;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.streak,
    required this.completed,
    required this.total,
  });

  final int streak;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SixPack AI',
                  style: TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(blurRadius: 14, color: Color(0xFF00F0FF)),
                    ],
                  ),
                ),
              ),
              const _ProButton(),
              const SizedBox(width: 8),
              _StreakBadge(streak: streak),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '30 Günde Karın Kası',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          _ProgressBar(completed: completed, total: total),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orangeAccent, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'gün',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'İLERLEME',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$completed / $total',
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF00F0FF)),
          ),
        ),
      ],
    );
  }
}

class _NextDayCard extends StatelessWidget {
  const _NextDayCard({required this.nextDay, required this.onStart});

  final WorkoutDay? nextDay;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final day = nextDay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1F2B), Color(0xFF001018)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4400F0FF),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUGÜNÜN ANTRENMANI',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              day == null ? 'Program tamamlandı!' : 'Gün ${day.dayNumber}',
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day == null
                  ? 'Tebrikler — 30 günü bitirdin.'
                  : day.exercises.map((e) => e.name).join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(day == null ? 'Programı gözden geçir' : 'BAŞLA'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.dayNumber,
    required this.day,
    required this.isNext,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? day;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInProgram = day != null;
    final isCompleted = day?.isCompleted ?? false;
    final isLocked = !isInProgram;

    Color borderColor;
    Color textColor;
    Color bgColor = Colors.transparent;
    Widget? overlay;

    if (isCompleted) {
      borderColor = DashboardScreen._done;
      textColor = DashboardScreen._done;
      bgColor = DashboardScreen._done.withValues(alpha: 0.08);
      overlay = const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.check_circle,
            color: DashboardScreen._done,
            size: 16,
          ),
        ),
      );
    } else if (isNext) {
      borderColor = DashboardScreen._neon;
      textColor = DashboardScreen._neon;
      bgColor = DashboardScreen._neon.withValues(alpha: 0.10);
    } else if (isLocked) {
      borderColor = Colors.white12;
      textColor = Colors.white30;
      overlay = const Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.lock_outline, color: Colors.white24, size: 14),
        ),
      );
    } else {
      borderColor = Colors.white24;
      textColor = Colors.white70;
    }

    final decoration = BoxDecoration(
      color: bgColor,
      border: Border.all(color: borderColor, width: isNext ? 2 : 1),
      borderRadius: BorderRadius.circular(12),
      boxShadow: isNext
          ? [
              BoxShadow(
                color: DashboardScreen._neon.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : null,
    );

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: decoration,
        child: Stack(
          children: [
            Center(
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (overlay != null) overlay,
          ],
        ),
      ),
    );
  }
}
