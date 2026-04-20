import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'stat_tile.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _inactive = Color(0xFF1C1C24);
const double _kcalPerDay = 250;
const double _kcalFloor = 40;

class GelisimTab extends ConsumerWidget {
  const GelisimTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final completed = days.where((d) => d.isCompleted).length;
    final streak = _streakOf(days);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'TAMAMLANAN',
                value: '$completed / 30',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel(title: '30 GÜNLÜK PROGRAM'),
        const SizedBox(height: 12),
        _DayGrid(days: days),
        const SizedBox(height: 24),
        const _SectionLabel(title: 'HAFTALIK KALORİ'),
        const SizedBox(height: 12),
        _CalorieBarChart(days: days),
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
}

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

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days});
  final List<WorkoutDay> days;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 30,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index + 1;
        final completed = days.any(
          (d) => d.dayNumber == dayNumber && d.isCompleted,
        );
        return _DayCell(dayNumber: dayNumber, completed: completed);
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.dayNumber, required this.completed});
  final int dayNumber;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: completed ? _neon : _inactive,
        border: Border.all(
          color: completed ? _neon : Colors.white12,
        ),
        boxShadow: completed
            ? [BoxShadow(color: _neon.withValues(alpha: 0.45), blurRadius: 10)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (completed) const Icon(Icons.check, color: Colors.white, size: 14),
          Text(
            '$dayNumber',
            style: TextStyle(
              color: completed ? Colors.white : Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieBarChart extends StatelessWidget {
  const _CalorieBarChart({required this.days});
  final List<WorkoutDay> days;

  static const List<String> _labels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  @override
  Widget build(BuildContext context) {
    // We don't persist completion timestamps yet, so the "last 7 days" view
    // falls back to the first week of the program: each bar shows 250 kcal
    // when that program day is complete, otherwise a faint floor bar.
    // When timestamped history lands this function swaps to a calendar map
    // without touching the chart chrome.
    final weekly = List<double>.generate(7, (i) {
      final match = days.where((d) => d.dayNumber == i + 1);
      final completed = match.isNotEmpty && match.first.isCompleted;
      return completed ? _kcalPerDay : _kcalFloor;
    });
    final totalKcal =
        weekly.where((v) => v >= _kcalPerDay).fold<double>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
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
                '${totalKcal.toInt()} kcal',
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
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 300,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labels[i],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: [
                  for (var i = 0; i < weekly.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weekly[i],
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          gradient: weekly[i] >= _kcalPerDay
                              ? const LinearGradient(
                                  colors: [_neonAccent, _neon],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : null,
                          color: weekly[i] >= _kcalPerDay ? null : _inactive,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
