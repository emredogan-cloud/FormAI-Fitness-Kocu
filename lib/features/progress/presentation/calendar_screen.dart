import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_extension.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _success = Color(0xFF22C55E);
const Color _restAmber = Color(0xFFFFB84D);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);
const Color _inactive = Color(0xFF1C1C24);

/// Phase 47A · monthly calendar view of the user's 30-day program.
///
/// Anchors program day 1 at `today − (activeDayNumber − 1) days`, so
/// the currently-active program day lines up with today's calendar
/// date. Each calendar cell shows:
///
///   • COMPLETED → green tile with a check glyph.
///   • ACTIVE → pulsing neon ring on today's cell.
///   • REST → amber coffee glyph for program rest days.
///   • UPCOMING → dim tile with the date number.
///   • OUT OF PROGRAM → minimal grey date label.
///
/// The user can swipe between adjacent months with the arrow controls
/// in the header; swipes past the program window just show empty
/// cells so the calendar never lies about program activity.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const List<String> _weekdayLabels = [
    'Pt',
    'Sa',
    'Ça',
    'Pe',
    'Cu',
    'Ct',
    'Pa',
  ];
  static const List<String> _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _visibleMonth = DateTime(today.year, today.month);
  }

  void _stepMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  /// Maps a program day number → the calendar date that day occurs on.
  /// Program day 1 sits at `today − (activeDayNumber − 1)` days; so
  /// a user on Day 5 sees days 1-4 in the recent past and days 5-30
  /// starting from today.
  DateTime _programDayToDate({
    required int dayNumber,
    required int activeDayNumber,
    required DateTime today,
  }) {
    final offset = dayNumber - activeDayNumber;
    return DateTime(today.year, today.month, today.day + offset);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final activeDayNumber = session?.activeDay?.dayNumber ??
        (days.isEmpty ? 1 : _firstIncompleteDayNumber(days));
    final today = DateTime.now();
    final todayStripped = DateTime(today.year, today.month, today.day);

    // Build a date → WorkoutDay lookup so each cell can find its state
    // in O(1). `yyyy-MM-dd` string keys sidestep DateTime equality
    // quirks (where the same day expressed in two zones would hash
    // differently).
    final dayByDate = <String, WorkoutDay>{};
    for (final day in days) {
      final date = _programDayToDate(
        dayNumber: day.dayNumber,
        activeDayNumber: activeDayNumber,
        today: todayStripped,
      );
      dayByDate[_dateKey(date)] = day;
    }

    // Phase 53D · scaffold + AppBar use the active theme; gradient halo
    // is dark-mode-only.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        title: Text(
          'Takvimim',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [Color(0xFF1E0A40), Color(0xFF0A0612), Colors.black],
                  stops: [0.0, 0.55, 1.0],
                ),
              )
            : null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _MonthNavigator(
              label: '${_monthNames[_visibleMonth.month - 1]} '
                  '${_visibleMonth.year}',
              onBack: () => _stepMonth(-1),
              onForward: () => _stepMonth(1),
            ),
            const SizedBox(height: 18),
            _WeekdayRow(labels: _weekdayLabels),
            const SizedBox(height: 10),
            _MonthGrid(
              visibleMonth: _visibleMonth,
              today: todayStripped,
              dayByDate: dayByDate,
              dateKey: _dateKey,
            ),
            const SizedBox(height: 22),
            const _Legend(),
            const SizedBox(height: 18),
            _MonthSummaryCard(
              dayByDate: dayByDate,
              visibleMonth: _visibleMonth,
              dateKey: _dateKey,
            ),
          ],
        ),
      ),
    );
  }

  int _firstIncompleteDayNumber(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day.dayNumber;
    }
    return days.last.dayNumber;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavButton(icon: Icons.chevron_left_rounded, onTap: onBack),
        Text(
          label,
          style: TextStyle(
            color: context.colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        _NavButton(icon: Icons.chevron_right_rounded, onTap: onForward),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.onSurface.withValues(alpha: 0.04),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(
            icon,
            color: scheme.onSurface.withValues(alpha: 0.70),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final secondary = context.colors.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondary,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.today,
    required this.dayByDate,
    required this.dateKey,
  });

  final DateTime visibleMonth;
  final DateTime today;
  final Map<String, WorkoutDay> dayByDate;
  final String Function(DateTime date) dateKey;

  /// Days in the current month that precede the 1st (to fill the first
  /// row) + every day of the month + trailing blanks to make the grid
  /// a clean multiple of 7.
  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
    // Monday-indexed leading blanks — DateTime.weekday returns 1..7 where
    // 1 is Monday. `_weekdayLabels[0] == 'Pt'` aligns with Monday, so
    // `firstOfMonth.weekday - 1` is the count of leading empty cells.
    final leading = firstOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final dayOfMonth = index - leading + 1;
        if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
          return const SizedBox.shrink();
        }
        final cellDate =
            DateTime(visibleMonth.year, visibleMonth.month, dayOfMonth);
        final workoutDay = dayByDate[dateKey(cellDate)];
        final isToday = cellDate == today;
        return _DayCell(
          date: cellDate,
          isToday: isToday,
          workoutDay: workoutDay,
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.workoutDay,
  });

  final DateTime date;
  final bool isToday;
  final WorkoutDay? workoutDay;

  @override
  Widget build(BuildContext context) {
    final completed = workoutDay?.isCompleted ?? false;
    final isRest = workoutDay?.isRestDay ?? false;

    // Phase 53D · text colour, neutral fill, and outline ALL flip with
    // the active theme. Completed / today cells pin onSurface so the
    // day number reads on either palette; the upcoming "in-program but
    // not yet" cell now lands on surfaceContainer in light mode.
    final scheme = context.colors;
    final isDark = context.isDarkMode;

    Color bg;
    Color border;
    Color textColor;
    Widget? overlay;
    List<BoxShadow>? shadow;

    if (completed) {
      bg = _success.withValues(alpha: 0.15);
      border = _success.withValues(alpha: 0.6);
      textColor = scheme.onSurface;
      shadow = [
        BoxShadow(color: _success.withValues(alpha: 0.35), blurRadius: 8),
      ];
      overlay = const Positioned(
        top: 4,
        right: 4,
        child: Icon(Icons.check_circle, color: _success, size: 12),
      );
    } else if (isToday) {
      bg = _neon.withValues(alpha: 0.18);
      border = _neon;
      textColor = scheme.onSurface;
      shadow = [
        BoxShadow(color: _neon.withValues(alpha: 0.5), blurRadius: 12),
      ];
    } else if (isRest) {
      bg = _restAmber.withValues(alpha: 0.08);
      border = _restAmber.withValues(alpha: 0.35);
      textColor = scheme.onSurface.withValues(alpha: 0.70);
      overlay = Positioned(
        top: 4,
        right: 4,
        child: Icon(
          Icons.local_cafe,
          color: _restAmber.withValues(alpha: 0.8),
          size: 11,
        ),
      );
    } else if (workoutDay != null) {
      // Upcoming program day — in program but not completed and not today.
      bg = isDark ? _inactive : scheme.surfaceContainer;
      border = isDark ? Colors.white12 : scheme.outlineVariant;
      textColor = scheme.onSurface.withValues(alpha: 0.55);
    } else {
      // Outside the 30-day program window entirely.
      bg = Colors.transparent;
      border = Colors.transparent;
      textColor = scheme.onSurface.withValues(alpha: 0.35);
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: isToday ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: shadow,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight:
                    completed || isToday ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? _surface : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? _surfaceBorder : scheme.outlineVariant,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: const [
          _LegendItem(color: _success, label: 'Tamamlanan'),
          _LegendItem(color: _neon, label: 'Bugün'),
          _LegendItem(color: _restAmber, label: 'Dinlenme'),
          _LegendItem(color: Color(0xFF2A2A36), label: 'Bekleyen'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.colors.onSurface.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.dayByDate,
    required this.visibleMonth,
    required this.dateKey,
  });

  final Map<String, WorkoutDay> dayByDate;
  final DateTime visibleMonth;
  final String Function(DateTime date) dateKey;

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    var completed = 0;
    var rest = 0;
    var planned = 0;
    for (var i = 1; i <= daysInMonth; i++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, i);
      final day = dayByDate[dateKey(date)];
      if (day == null) continue;
      planned += 1;
      if (day.isCompleted) completed += 1;
      if (day.isRestDay) rest += 1;
    }

    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? _surface : scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? _surfaceBorder : scheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 16,
            spreadRadius: 0.4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BU AY ÖZET',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.70),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryTile(
                label: 'Tamamlanan',
                value: '$completed',
                accent: _success,
              ),
              _SummaryTile(
                label: 'Planlanan',
                value: '$planned',
                accent: _neon,
              ),
              _SummaryTile(
                label: 'Dinlenme',
                value: '$rest',
                accent: _restAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: context.colors.onSurface.withValues(alpha: 0.70),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
