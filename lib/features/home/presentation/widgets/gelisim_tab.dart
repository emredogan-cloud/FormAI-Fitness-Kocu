import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../progress/presentation/widgets/badge_unlock_dialog.dart';
import '../../../progress/providers/badge_unlocks_provider.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'today_task_card.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _neonDeep = Color(0xFF6A3DFF);
const Color _success = Color(0xFF22C55E);
const Color _orange = Color(0xFFF97316);
const Color _restAmber = Color(0xFFFFB84D);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);
const Color _inactive = Color(0xFF1C1C24);

const int _programLength = 30;
const int _kcalPerDay = 250;

/// Phase 36b: the Gelişim tab now mirrors the "gelişim_sekmesi_referans"
/// mock — 2-card top row (program progress + streak), full-width today-
/// task CTA, 4-state 30-day grid, a row of three rich stats cards with
/// mini charts (bars / area line / waveform), an AI coach card, and a
/// hex-shaped badges strip. Bottom nav is owned by `dashboard_screen`,
/// not this file.
class GelisimTab extends ConsumerWidget {
  const GelisimTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 48 · celebrate brand-new badge unlocks. The Gelisim tab is
    // the canonical home of badge progress, so this is where we observe
    // the unlock set. The `previous == null` guard skips the very first
    // build (a fresh app open shouldn't celebrate yesterday's wins);
    // subsequent transitions diff and chain a dialog per newly-unlocked
    // badge so a multi-unlock day doesn't drop celebrations on the floor.
    ref.listen<Set<String>>(unlockedBadgesProvider, (previous, next) async {
      if (previous == null) return;
      final newOnes = next.difference(previous).toList();
      if (newOnes.isEmpty) return;
      for (final id in newOnes) {
        final badge = badgeById(id);
        if (badge == null) continue;
        if (!context.mounted) return;
        await showBadgeUnlockedDialog(context, badge);
      }
    });

    final session = ref.watch(workoutSessionProvider).value;
    final days = session?.days ?? const <WorkoutDay>[];
    final completedCount = days.where((d) => d.isCompleted).length;
    final streak = _streakOf(days);
    final activeDay = _firstIncomplete(days);
    final activeDayNumber = activeDay?.dayNumber ?? 1;
    final percent = (completedCount / _programLength).clamp(0.0, 1.0);
    final isProgramComplete = days.isNotEmpty && activeDay == null;

    // Per-week slice — stats + charts all snap to the 7-day bucket that
    // contains the active day so the three cards show "this week", not
    // "the first week of the program".
    final weekIndex = ((activeDayNumber - 1) ~/ 7).clamp(0, 4);
    final weekStart = weekIndex * 7 + 1;
    final weeklyDays = List<WorkoutDay?>.generate(7, (i) {
      final dn = weekStart + i;
      if (dn > _programLength) return null;
      for (final d in days) {
        if (d.dayNumber == dn) return d;
      }
      return null;
    });
    final weeklyCompleted =
        weeklyDays.where((d) => d?.isCompleted ?? false).length;
    final weeklyKcal = weeklyCompleted * _kcalPerDay;

    // Section spacing normalized to the 20–24 px system. 14 stays on
    // the top-row → today-task seam because those two blocks are a
    // single logical "status + next action" unit.
    //
    // Phase 38: a radial neon glow wraps the whole tab — dark purple
    // halo at the top fading to pure black at the edges/bottom, so the
    // surface feels branded instead of flat-black. The gradient lives
    // on the outer `Container` (not per-card) to keep the effect cheap
    // and consistent while cards scroll past.
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.85),
          radius: 1.1,
          colors: [
            Color(0xFF1E0A40),
            Color(0xFF0A0612),
            Colors.black,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _TopHeader(streak: streak),
          const SizedBox(height: 22),
          _ProgramStatsColumn(
            percent: percent,
            completedCount: completedCount,
            streak: streak,
          ),
          const SizedBox(height: 14),
          if (isProgramComplete)
            const ProgramCompleteCard()
          else if (activeDay != null)
            TodayTaskCard(activeDay: activeDay),
          const SizedBox(height: 24),
          _DayGridSection(days: days, activeDayNumber: activeDayNumber),
          const SizedBox(height: 24),
          _StatsCardsColumn(
            weeklyDays: weeklyDays,
            weeklyCompleted: weeklyCompleted,
            weeklyKcal: weeklyKcal,
          ),
          const SizedBox(height: 22),
          _AiCoachCard(streak: streak, percent: percent),
          const SizedBox(height: 22),
          _BadgesSection(
            completedCount: completedCount,
            streak: streak,
            weeklyKcal: weeklyKcal,
          ),
        ],
      ),
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
// Top header — title/subtitle block with a streak pill anchored top-right.
// =============================================================================

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gelişim',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'İlerlemen bir bakışta.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: _orange.withValues(alpha: 0.15),
            border: Border.all(color: _orange.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                '$streak Günlük Seri',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Program-progress card (left) + streak card (right).
// =============================================================================

/// Phase 38: was `_ProgramStatsRow` — the two square half-width tiles
/// split into full-width horizontal stacks (text on the left, visual on
/// the right) so each card can breathe instead of cramping the type.
class _ProgramStatsColumn extends StatelessWidget {
  const _ProgramStatsColumn({
    required this.percent,
    required this.completedCount,
    required this.streak,
  });
  final double percent;
  final int completedCount;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgramProgressCard(
          percent: percent,
          completedCount: completedCount,
        ),
        const SizedBox(height: 12),
        _StreakCard(streak: streak),
      ],
    );
  }
}

class _ProgramProgressCard extends StatelessWidget {
  const _ProgramProgressCard({
    required this.percent,
    required this.completedCount,
  });
  final double percent;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final pctInt = (percent * 100).round();
    // Horizontal stack: all the text (label/value/bar/motivation) sits
    // on the left flex side, the trophy ring pins to the right. Keeps
    // the card slim and full-width friendly.
    return _SoftCard(
      accent: _neon,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CardLabel(text: 'PROGRAM TAMAMLAMA'),
                const SizedBox(height: 8),
                Text(
                  '%$pctInt',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedCount / $_programLength gün tamamlandı',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Stack(
                      children: [
                        Container(height: 7, color: Colors.white10),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 7,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_neonDeep, _neon],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Harika gidiyorsun, devam et! 💪',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _TrophyRing(percent: percent),
        ],
      ),
    );
  }
}

class _TrophyRing extends StatelessWidget {
  const _TrophyRing({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    // Scaled up from 54 → 72 px with a proportionally thicker stroke so
    // the ring reads as a focal element next to the big `%N` number,
    // not a decoration.
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 5.5,
                strokeCap: StrokeCap.round,
                backgroundColor: _neon.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(_neon),
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _neon.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.emoji_events, color: _neon, size: 28),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    // Show last 5 days as dots; fill up to `streak` (capped at 5).
    final filled = streak.clamp(0, 5);
    return _SoftCard(
      accent: _orange,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CardLabel(text: 'SERİ'),
                const SizedBox(height: 8),
                Text(
                  '$streak gün',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Serini bozma!',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Phase 37: tiny dot → 22-px check pucks. Completed days
                // get a green-filled circle with a crisp `Icons.check`;
                // upcoming days keep a transparent fill + white24 outline
                // so the row reads as a 5-day checklist, not a stats chip.
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(5, (i) {
                    final isOn = i < filled;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn
                              ? _success.withValues(alpha: 0.20)
                              : Colors.transparent,
                          border: Border.all(
                            color: isOn
                                ? _success
                                : Colors.white.withValues(alpha: 0.22),
                            width: isOn ? 1.4 : 1,
                          ),
                          boxShadow: isOn
                              ? [
                                  BoxShadow(
                                    color: _success.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: isOn
                            ? const Icon(
                                Icons.check,
                                color: _success,
                                size: 13,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right-side flame puck — the focal "streak" visual that
          // mirrors the trophy ring on the Program card above.
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _orange.withValues(alpha: 0.18),
              border: Border.all(color: _orange.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: _orange.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: _orange,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Today task and program-complete cards now live in
// `today_task_card.dart` so they can be widget-tested in isolation.
// =============================================================================

// =============================================================================
// 30-day grid section — header with a "Takvimi Gör" pill link, then the
// 5×6 grid. Cells pick one of four states: CURRENT (pulsing purple fill),
// COMPLETED (green check tile, tap -> SnackBar), REST (amber coffee),
// LOCKED (dim lock tile, non-tappable).
// =============================================================================

class _DayGridSection extends StatelessWidget {
  const _DayGridSection({
    required this.days,
    required this.activeDayNumber,
  });
  final List<WorkoutDay> days;
  final int activeDayNumber;

  @override
  Widget build(BuildContext context) {
    // Phase 47A · "Takvimi Gör →" restored. The Phase 40 concern was
    // a placeholder SnackBar; the real `/progress/calendar` screen
    // ships in Phase 47A and maps program days onto calendar dates
    // relative to today, so the pill can finally route somewhere real.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionLabel(title: '30 GÜNLÜK PROGRAM'),
            _SectionLinkPill(
              label: 'Takvimi Gör',
              onTap: () => context.push(AppRoutes.progressCalendar),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DayGrid(days: days, activeDayNumber: activeDayNumber),
      ],
    );
  }
}

/// Phase 47A · reusable "section link" pill rendered flush-right of
/// a section header. Low-contrast chrome so it sits alongside the
/// bolder `_SectionLabel` without stealing attention.
class _SectionLinkPill extends StatelessWidget {
  const _SectionLinkPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: _neon.withValues(alpha: 0.10),
            border: Border.all(color: _neon.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _neon,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        final glowBlur = 12.0 + t * 12;
        final glowAlpha = 0.45 + t * 0.30;
        // Phase 37: match the reference's "neon purple outline" treatment
        // for the current day — 2-px neon border + a low-alpha purple
        // wash inside, instead of the full gradient fill the prior
        // version shipped. Pulse stays so it still catches the eye.
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _neon.withValues(alpha: 0.18),
            border: Border.all(color: _neon, width: 2),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 1.0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${widget.dayNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
            color: _success.withValues(alpha: 0.12),
            border: Border.all(color: _success.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: _success.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, color: _success, size: 16),
              const SizedBox(height: 2),
              Text(
                '$dayNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
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
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 2),
          Text(
            '$dayNumber',
            style: TextStyle(
              color: _restAmber.withValues(alpha: 0.85),
              fontSize: 12.5,
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
        opacity: 0.55,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _inactive,
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white38, size: 12),
              const SizedBox(height: 2),
              Text(
                '$dayNumber',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12.5,
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
// Three stats cards — weekly completion (bars), calories (area line),
// workouts (green waveform). All three draw from the same 7-day bucket.
// =============================================================================

/// Phase 38: was `_StatsCardsRow`. The three tight squares that lived
/// side-by-side are now full-width horizontal cards stacked vertically,
/// so the charts on the right side have room to elongate instead of
/// getting crushed into a 110-px column.
class _StatsCardsColumn extends StatelessWidget {
  const _StatsCardsColumn({
    required this.weeklyDays,
    required this.weeklyCompleted,
    required this.weeklyKcal,
  });
  final List<WorkoutDay?> weeklyDays;
  final int weeklyCompleted;
  final int weeklyKcal;

  static const List<String> _dayLabels = [
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
    final completionBars =
        weeklyDays.map((d) => (d?.isCompleted ?? false) ? 1.0 : 0.25).toList();
    final kcalValues =
        weeklyDays.map((d) => (d?.isCompleted ?? false) ? 1.0 : 0.2).toList();
    final waveformBars = List<double>.generate(weeklyDays.length, (i) {
      final completed = weeklyDays[i]?.isCompleted ?? false;
      final baseline = i.isEven ? 0.55 : 0.35;
      return completed ? 1.0 : baseline;
    });

    return Column(
      children: [
        _StatChartCard(
          label: 'BU HAFTA',
          value: '$weeklyCompleted / 7',
          accent: _neon,
          chart: _MiniBars(
            values: completionBars,
            labels: _dayLabels,
            gradientColors: const [_neonDeep, _neon],
          ),
        ),
        const SizedBox(height: 12),
        _StatChartCard(
          label: 'YAKILAN KALORİ',
          value: _formatKcal(weeklyKcal),
          unit: 'kcal',
          accent: _orange,
          chart: _MiniAreaLine(values: kcalValues, color: _orange),
        ),
        const SizedBox(height: 12),
        _StatChartCard(
          label: 'ANTRENMAN',
          value: '$weeklyCompleted',
          unit: 'tamamlandı',
          accent: _success,
          chart: _MiniBars(
            values: waveformBars,
            labels: _dayLabels,
            gradientColors: [
              _success.withValues(alpha: 0.9),
              _success.withValues(alpha: 0.35),
            ],
            rounded: true,
          ),
        ),
      ],
    );
  }

  String _formatKcal(int kcal) {
    if (kcal < 1000) return '$kcal';
    final s = kcal.toString();
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    return '$head.$tail';
  }
}

/// Full-width horizontal stat card: fixed-width left column with the
/// label and big value, then an `Expanded` chart block on the right
/// that stretches edge-to-edge so the mini chart can actually read.
class _StatChartCard extends StatelessWidget {
  const _StatChartCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.chart,
    this.unit,
  });

  final String label;
  final String value;
  final Color accent;
  final Widget chart;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CardLabel(text: label, color: accent),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          unit!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              // 60 px lets the elongated bars / area curve breathe while
              // keeping the card slim (~92 px total). `_MiniBars` still
              // does its own deterministic split between chart + label
              // strip inside this box.
              height: 60,
              child: chart,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of small vertical gradient bars. Each value is 0-1, rendered as
/// a height fraction of the chart box. Sits under the label strip in
/// the "BU HAFTA" / "ANTRENMAN" stats cards.
class _MiniBars extends StatelessWidget {
  const _MiniBars({
    required this.values,
    required this.labels,
    required this.gradientColors,
    this.rounded = false,
  });

  final List<double> values;
  final List<String> labels;
  final List<Color> gradientColors;
  final bool rounded;

  // Explicit label strip height + gap so the column math is exact and
  // the chart can't over-subscribe the parent. The prior `maxHeight - 14`
  // formula under-reserved the label row (fontSize 8.5 × default
  // line-height lands at ~11-12 px, plus ascender/descender), which
  // was the deterministic source of the 2-px bottom overflow.
  static const double _labelStripHeight = 14;
  static const double _chartLabelGap = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved = _labelStripHeight + _chartLabelGap;
        final chartHeight =
            (constraints.maxHeight - reserved).clamp(10.0, 80.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++) ...[
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.08, end: values[i].clamp(0, 1)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Container(
                          height: chartHeight * value,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(rounded ? 4 : 2),
                              bottom: const Radius.circular(2),
                            ),
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i < values.length - 1) const SizedBox(width: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: _chartLabelGap),
            SizedBox(
              height: _labelStripHeight,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    Expanded(
                      child: Center(
                        child: Text(
                          labels[i].substring(0, 1),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    if (i < labels.length - 1) const SizedBox(width: 3),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Smooth-curve area chart painted with a cubic-bezier stroke + a
/// bottom-anchored gradient fill. Used by the "YAKILAN KALORİ" card so
/// the middle stat reads as motion, not tally.
class _MiniAreaLine extends StatelessWidget {
  const _MiniAreaLine({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _AreaLinePainter(values: values, color: color),
    );
  }
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final chartHeight = size.height - 4;
    final stepX = size.width / (values.length - 1);

    Offset pt(int i) => Offset(
          i * stepX,
          chartHeight * (1 - values[i].clamp(0, 1)) + 2,
        );

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = pt(i - 1);
      final curr = pt(i);
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, chartHeight + 2)
      ..lineTo(0, chartHeight + 2)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Final dot at the latest point to anchor the gaze.
    final last = pt(values.length - 1);
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(last, 3, dotPaint);
    canvas.drawCircle(
      last,
      5,
      Paint()..color = color.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _AreaLinePainter old) =>
      old.values != values || old.color != color;
}

// =============================================================================
// AI Coach card — glowing avatar + 2-line recommendation + outlined CTA
// to the (placeholder) suggestions view.
// =============================================================================

class _AiCoachCard extends StatelessWidget {
  const _AiCoachCard({required this.streak, required this.percent});
  final int streak;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(streak, percent);
    return _SoftCard(
      accent: _neon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _CoachAvatar(),
              SizedBox(width: 12),
              _CardLabel(text: 'AI KOÇ'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            copy,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          // Phase 47A · "Önerilere Git →" restored. Routes to the new
          // /progress/suggestions screen which surfaces three tailored
          // mikro-aksiyonlar based on the user's current state.
          Align(
            alignment: Alignment.centerLeft,
            child: _SectionLinkPill(
              label: 'Önerilere Git',
              onTap: () => context.push(AppRoutes.progressSuggestions),
            ),
          ),
        ],
      ),
    );
  }

  String _copyFor(int streak, double percent) {
    if (streak >= 7) {
      return 'Disiplin harika gidiyor. Bugün bir mobility '
          'günü eklemen toparlanmayı hızlandırır.';
    }
    if (streak >= 3) {
      return 'Son günlerde tempon çok iyi. Bugün orta yoğunluklu bir '
          'oturumla seriyi sağlam tutalım.';
    }
    if (streak >= 1) {
      return 'İyi başlangıç. Bugün ufak bir antrenmanla seriyi iki '
          'günlük yapalım — momentum burada başlıyor.';
    }
    return 'Son 2 gündür düşük performans gözüküyor. Bugün hafif '
        'bir antrenmanla devam etmeni öneriyorum.';
  }
}

/// Phase 38: the generic robot icon is replaced by the custom coach
/// photograph (`photos/kişiselyapayzekakoçfoto.webp`, already declared
/// under the `photos/` asset root in pubspec.yaml). The image is
/// clipped to a 45-px circle, surrounded by a 2-px neon-gradient ring
/// + glow so the avatar reads as "your coach" and not a stock icon.
/// An `errorBuilder` falls back to the old robot glyph if the asset
/// ever fails to decode.
class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_neonDeep, _neon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'photos/kişiselyapayzekakoçfoto.webp',
          width: 41,
          height: 41,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: _neonDeep,
            alignment: Alignment.center,
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Badges strip — horizontal list of hex-clipped tiles. Active badges pick
// up the neon/green/orange accent based on their tier; locked ones fade
// into the surface.
// =============================================================================

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({
    required this.completedCount,
    required this.streak,
    required this.weeklyKcal,
  });

  final int completedCount;
  final int streak;
  final int weeklyKcal;

  @override
  Widget build(BuildContext context) {
    final badges = <_BadgeData>[
      _BadgeData(
        label: 'İlk 7 Gün',
        icon: Icons.flag_rounded,
        accent: _orange,
        unlocked: completedCount >= 1,
        progress: (completedCount / 7).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Disiplinli',
        icon: Icons.shield_rounded,
        accent: _neon,
        unlocked: streak >= 3,
        progress: (streak / 3).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: 'Kalori Avcısı',
        icon: Icons.local_fire_department,
        accent: _success,
        unlocked: weeklyKcal >= 1500,
        progress: (weeklyKcal / 1500).clamp(0.0, 1.0),
      ),
      const _BadgeData(
        label: '30 Gün Şampiyonu',
        icon: Icons.emoji_events_rounded,
        accent: _neon,
        unlocked: false,
        progress: 0,
      ),
      const _BadgeData(
        label: 'HIIT Ustası',
        icon: Icons.bolt_rounded,
        accent: _orange,
        unlocked: false,
        progress: 0,
      ),
    ];
    // Phase 47A · "Tümünü Gör →" restored. The full gallery now lives
    // at /progress/badges; the strip here stays as a quick preview of
    // the five most-relevant badges for the current progress state.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _SectionLabel(title: 'ROZETLERİN'),
            Builder(
              builder: (context) => _SectionLinkPill(
                label: 'Tümünü Gör',
                onTap: () => context.push(AppRoutes.progressBadges),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          // Bumped from 112 → 128 to absorb the 3-px bottom overflow
          // when a locked badge renders its progress (`%67`) line below
          // the label. Individual text spans are also `FittedBox`-wrapped
          // so a long localization can't reintroduce the issue.
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => _HexBadge(data: badges[index]),
          ),
        ),
      ],
    );
  }
}

class _BadgeData {
  const _BadgeData({
    required this.label,
    required this.icon,
    required this.accent,
    required this.unlocked,
    required this.progress,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final bool unlocked;
  final double progress;
}

class _HexBadge extends StatelessWidget {
  const _HexBadge({required this.data});
  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CustomPaint(
            size: const Size(72, 78),
            painter: _HexBadgePainter(
              unlocked: data.unlocked,
              accent: data.accent,
            ),
            child: SizedBox(
              width: 72,
              height: 78,
              child: Center(
                child: Icon(
                  data.icon,
                  color: data.unlocked
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: data.unlocked ? Colors.white : Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!data.unlocked && data.progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '%${(data.progress * 100).round()}',
                  style: TextStyle(
                    color: data.accent.withValues(alpha: 0.85),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HexBadgePainter extends CustomPainter {
  _HexBadgePainter({required this.unlocked, required this.accent});
  final bool unlocked;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);

    // Fill.
    final Paint fillPaint;
    if (unlocked) {
      fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0.55),
            accent.withValues(alpha: 0.22),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      fillPaint = Paint()..color = const Color(0xFF14141B);
    }
    canvas.drawPath(path, fillPaint);

    // Soft glow for unlocked.
    if (unlocked) {
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, glowPaint);
    }

    // Stroke.
    final strokePaint = Paint()
      ..color = unlocked ? accent : Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unlocked ? 1.6 : 1.0;
    canvas.drawPath(path, strokePaint);
  }

  /// Pointy-top hexagon inscribed in the given box. The two vertical
  /// apex points sit at 0 / size.height so the badge's label below
  /// aligns cleanly with the bottom edge.
  Path _hexPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2;
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexBadgePainter old) =>
      old.unlocked != unlocked || old.accent != accent;
}

// =============================================================================
// Shared surface primitives.
// =============================================================================

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _surface,
        border: Border.all(color: _surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: (color ?? Colors.white70).withValues(alpha: 0.85),
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.w800,
      ),
    );
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
        letterSpacing: 2.6,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
