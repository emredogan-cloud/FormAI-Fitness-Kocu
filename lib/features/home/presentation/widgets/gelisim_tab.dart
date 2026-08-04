import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/audio_feedback.dart';
import '../../../../core/widgets/error_card.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../referral/providers/referral_provider.dart';
import '../../../nutrition/domain/models/planned_meal.dart';
import '../../../nutrition/providers/daily_menu_provider.dart';
import '../../../nutrition/providers/nutrition_provider.dart';
import '../../../progress/presentation/widgets/body_metrics_summary_card.dart';
import '../../../progress/presentation/widgets/outcome_report_card.dart';
import '../../../progress/presentation/widgets/weekly_retrospective_card.dart';
import '../../../progress/providers/xp_provider.dart';
import '../../../workout/data/session_log_repository.dart';
import '../../../workout/models/session_log_model.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'today_task_card.dart';
import '../../../progress/providers/streak_provider.dart';
import '../../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8B5CF6);
const Color _neonDeep = Color(0xFF6A3DFF);
const Color _success = Color(0xFF22C55E);
const Color _orange = Color(0xFFF97316);
const Color _restAmber = Color(0xFFFFB84D);
const Color _surface = Color(0xFF0F0F14);
const Color _surfaceBorder = Color(0xFF1E1E26);
const Color _inactive = Color(0xFF1C1C24);

// Phase 48 · single source of truth for these two values lives in
// `lib/core/constants/app_constants.dart`. Aliased here so the rest of
// this file's heavy use-sites stay terse.
const int _programLength = AppConstants.programLength;
const int _kcalPerDay = AppConstants.kcalPerCompletedDay;

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
    // Phase 48.1 · the unlock listener moved to `DashboardScreen` so
    // it can gate dialogs on the dashboard route being current. Showing
    // celebrations from inside this tab fired them on top of the
    // workout summary overlay, which the PM flagged as a clash.
    final sessionAsync = ref.watch(workoutSessionProvider);
    final session = sessionAsync.value;
    // Phase 49 · treat the first frame after cold-start as "loading"
    // when the session hasn't materialised yet. The day-grid section
    // swaps in a shimmer placeholder instead of rendering 30 locked
    // cells, which was the pre-Phase-49 look and read as "empty".
    final isSessionLoading = sessionAsync.isLoading && session == null;
    final days = session?.days ?? const <WorkoutDay>[];
    final completedCount = days.where((d) => d.isCompleted).length;
    final streak = ref.watch(currentStreakProvider);
    final activeDay = _firstIncomplete(days);
    final activeDayNumber = activeDay?.dayNumber ?? 1;
    final percent = (completedCount / _programLength).clamp(0.0, 1.0);
    // isStub = the repository's offline fallback (30 rest days). Its
    // `_firstIncomplete` is null exactly like a FINISHED program, so
    // without this exclusion the tab congratulated an offline
    // onboarding with the "program complete" celebration card — the
    // "Senkronize ediliyor" banner the repo comment promised was never
    // built (review REV-C1).
    final isStub = session?.isStub ?? false;
    final isProgramComplete = days.isNotEmpty && activeDay == null && !isStub;

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
    // Badge predicate only ("Kalori Avcısı" is DEFINED as LIFETIME
    // completions × kcalPerCompletedDay ≥ 1500 — unified with
    // unlockedBadgesProvider/badges_screen; this tab used to compute a
    // program-week variant, so the same badge read locked here while
    // unlocked in the gallery). The stat charts below no longer present
    // this constant as a measurement — they draw real session-log data.
    final badgeKcal = completedCount * _kcalPerDay;

    // Honest chart series: measured duration + reps from the week's
    // session logs (keyed by program-day number). Days without a log
    // render as zero — a true empty state, not a decorative baseline.
    final sessionLogs =
        ref.watch(sessionLogsProvider).value ?? const <int, SessionLog>{};
    final weeklyMinutes = List<double>.generate(7, (i) {
      final log = sessionLogs[weekStart + i];
      return log == null ? 0.0 : log.durationSeconds / 60.0;
    });
    final weeklyReps = List<double>.generate(7, (i) {
      final log = sessionLogs[weekStart + i];
      return log == null ? 0.0 : log.totalReps.toDouble();
    });

    // Section spacing normalized to the 20–24 px system. 14 stays on
    // the top-row → today-task seam because those two blocks are a
    // single logical "status + next action" unit.
    //
    // Phase 38: a radial neon glow wraps the whole tab — dark purple
    // halo at the top fading to pure black at the edges/bottom, so the
    // surface feels branded instead of flat-black. The gradient lives
    // on the outer `Container` (not per-card) to keep the effect cheap
    // and consistent while cards scroll past.
    // Phase 49 · pull-to-refresh on the Gelişim tab. Invalidates the
    // workout-session notifier so a swipe-down re-runs `_loadProgram`
    // (which re-pulls completion rows from Supabase + replays any
    // queued offline syncs). Awaiting the future on the next read
    // keeps the spinner visible until the new data lands.
    Future<void> handleRefresh() async {
      ref.invalidate(workoutSessionProvider);
      await ref.read(workoutSessionProvider.future);
    }

    // Phase 53B · the dark-purple radial halo is signature dark-mode
    // chrome. In light mode we deliberately let the Scaffold's
    // `scaffoldBackgroundColor` (lightBg, off-white) show through —
    // a `Container` with no decoration just means cards painted on
    // pure `surface` (#FFFFFF) get a subtle gray seam to sit on,
    // exactly the contrast the PM screenshot was missing.
    final isDark = context.isDarkMode;
    return Container(
      decoration: isDark
          ? const BoxDecoration(
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
            )
          : null,
      child: RefreshIndicator(
        onRefresh: handleRefresh,
        color: _neon,
        backgroundColor: const Color(0xFF14141B),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _TopHeader(
              streak: streak,
              percent: percent,
              completedCount: completedCount,
            ),
            const SizedBox(height: 22),
            _ProgramStatsColumn(
              percent: percent,
              completedCount: completedCount,
              streak: streak,
            ),
            const SizedBox(height: 14),
            if (isStub)
              ErrorCard(
                compact: true,
                message: AppLocalizations.of(context).programSyncing,
                icon: Icons.cloud_sync_rounded,
                onRetry: () => ref.invalidate(workoutSessionProvider),
              )
            else if (isProgramComplete)
              ProgramCompleteCard(
                // Roadmap Phase 14 (C40) · the day-31 problem. This card
                // is where the app used to run out of things to say.
                onChooseNext: () => context.push(AppRoutes.programContinuation),
              )
            else if (activeDay != null)
              TodayTaskCard(activeDay: activeDay),
            const SizedBox(height: 24),
            _DayGridSection(
              days: days,
              activeDayNumber: activeDayNumber,
              isLoading: isSessionLoading,
            ),
            const SizedBox(height: 24),
            _StatsCardsColumn(
              weeklyDays: weeklyDays,
              weeklyCompleted: weeklyCompleted,
              weeklyMinutes: weeklyMinutes,
              weeklyReps: weeklyReps,
            ),
            const SizedBox(height: 22),
            // Roadmap Phase 9 (C1) · above the coach card, below the
            // session stats. The stats above it are what the user did;
            // this is what changed because of it, which is the question
            // the testers named first and the app could not answer.
            const BodyMetricsSummaryCard(),
            const SizedBox(height: 22),
            // Roadmap Phase 10 (C4, C39) · the outcome report, directly
            // under what changed. It renders nothing until there are two
            // sessions to report on, and pads its own bottom margin so
            // the gap collapses with it.
            const OutcomeReportCard(),
            // Phase 52 · weekly retrospective. The card returns
            // SizedBox.shrink on non-Sundays AND self-pads its own
            // bottom margin on Sundays, so we don't need a second
            // SizedBox before the AI Coach card — that would produce
            // a 44 px void on weekdays when the retrospective is
            // collapsed.
            const WeeklyRetrospectiveCard(),
            _AiCoachCard(streak: streak, percent: percent),
            const SizedBox(height: 22),
            _BadgesSection(
              completedCount: completedCount,
              streak: streak,
              totalKcal: badgeKcal,
            ),
            const SizedBox(height: 22),
            const _CommunityRow(),
          ],
        ),
      ),
    );
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

class _TopHeader extends ConsumerWidget {
  const _TopHeader({
    required this.streak,
    required this.percent,
    required this.completedCount,
  });
  final int streak;
  final double percent;
  final int completedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 53C · "Gelişim" headline + streak pill text were
    // hardcoded white. Pull onSurface for the title block + the pill
    // copy so the page header reads in light mode.
    final scheme = context.colors;
    // Phase 54 · share affordance lives top-right of the Gelişim tab.
    // We pass `referralCode` through to the rendered template so the
    // exported PNG carries a deep-link the friend can tap to install
    // (`formai://r/<code>`). Code may still be loading on a fresh
    // install — the share path tolerates a null code.
    final referralCode = ref.watch(referralCodeProvider).value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).progressTabTitle,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              // P1-3 · surface the (previously invisible) identity
              // system: level + title + lifetime XP were computed and
              // persisted with zero UI consumers.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // XP gem glyph — a premium accent on the (otherwise plain)
                  // level · title · lifetime-XP identity line.
                  Image.asset(
                    'assets/illustrations/xp_gem.webp',
                    width: 9,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).progressIdentityLine(
                        ref.watch(levelProgressProvider).level,
                        ref
                            .watch(currentTitleProvider)
                            .title(AppLocalizations.of(context)),
                        ref.watch(lifetimeXpProvider),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                AppLocalizations.of(context).streakDailyLabel(streak),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ShareProgressButton(
          percent: (percent * 100).round(),
          completedCount: completedCount,
          streak: streak,
          referralCode: referralCode,
        ),
      ],
    );
  }
}

class _ShareProgressButton extends StatelessWidget {
  const _ShareProgressButton({
    required this.percent,
    required this.completedCount,
    required this.streak,
    required this.referralCode,
  });

  final int percent;
  final int completedCount;
  final int streak;
  final String? referralCode;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          AppHaptics.secondaryTap();
          ShareService.instance.shareProgress(
            context: context,
            percent: percent,
            completedDays: completedCount,
            totalDays: _programLength,
            streak: streak,
            referralCode: referralCode,
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _neon.withValues(alpha: 0.12),
            border: Border.all(color: _neon.withValues(alpha: 0.55)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.ios_share_rounded,
            color: scheme.onSurface,
            size: 18,
          ),
        ),
      ),
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
                _CardLabel(
                    text: AppLocalizations.of(context).progressCompletionLabel),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).percentValue(pctInt),
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)
                      .daysCompletedOf(completedCount, _programLength),
                  style: TextStyle(
                    color: context.colors.onSurface.withValues(alpha: 0.55),
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
                        Container(
                          height: 7,
                          color:
                              context.colors.onSurface.withValues(alpha: 0.10),
                        ),
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
                Text(
                  AppLocalizations.of(context).progressKeepGoing,
                  style: TextStyle(
                    color: context.colors.onSurface.withValues(alpha: 0.70),
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
                _CardLabel(
                    text: AppLocalizations.of(context).progressStreakLabel),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).streakDaysLower(streak),
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).progressDontBreakStreak,
                  style: TextStyle(
                    color: context.colors.onSurface.withValues(alpha: 0.55),
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
                      padding: const EdgeInsetsDirectional.only(end: 6),
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
    this.isLoading = false,
  });
  final List<WorkoutDay> days;
  final int activeDayNumber;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Phase 47A · "Takvimi Gör →" restored. The Phase 40 concern was
    // a placeholder SnackBar; the real `/progress/calendar` screen
    // ships in Phase 47A and maps program days onto calendar dates
    // relative to today, so the pill can finally route somewhere real.
    //
    // Phase 49 · while the session is loading we render a 5×6 shimmer
    // grid in the same slot so the page reserves its real height
    // (no jump when data lands) and the user sees motion instead of
    // 30 locked-state cells.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SectionLabel(
                title: AppLocalizations.of(context).progressProgramHeading),
            _SectionLinkPill(
              label: AppLocalizations.of(context).progressSeeCalendar,
              onTap: () => context.push(AppRoutes.progressCalendar),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const DayGridSkeleton()
        else
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
    // Phase 53C · day-number ink read as white-on-light-green in
    // light mode, which has poor contrast. Pull from onSurface so it
    // stays charcoal in light, white in dark.
    final scheme = context.colors;
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
                content: Text(
                    AppLocalizations.of(context).dayCompletedBang(dayNumber)),
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
                style: TextStyle(
                  color: scheme.onSurface,
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
    // Phase 53C · locked cell was painted with the dark-mode `_inactive`
    // (#1C1C24) regardless of theme — looked like a black square on
    // an otherwise off-white grid. Switch to surfaceContainer so light
    // mode lands on a soft gray and dark mode on the legacy tone.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return IgnorePointer(
      child: Opacity(
        opacity: 0.55,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? _inactive : scheme.surfaceContainer,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                color: scheme.onSurface.withValues(alpha: 0.45),
                size: 12,
              ),
              const SizedBox(height: 2),
              Text(
                '$dayNumber',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.55),
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
// Three stats cards — weekly completion (bars), measured workout minutes
// (area line), measured reps (bars). All three draw from the same 7-day
// bucket; the last two read REAL session-log data.
//
// Honesty pass · the old cards fabricated their series: the "kcal" line
// was `completed ? 1.0 : 0.2`, the value a flat completions × 250, and
// the "ANTRENMAN" waveform alternated even/odd baselines purely for
// shape. Progress charts are the reward for coming back — decorating
// them with invented data broke exactly that trust.
// =============================================================================

/// Phase 38: was `_StatsCardsRow`. The three tight squares that lived
/// side-by-side are now full-width horizontal cards stacked vertically,
/// so the charts on the right side have room to elongate instead of
/// getting crushed into a 110-px column.
class _StatsCardsColumn extends StatelessWidget {
  const _StatsCardsColumn({
    required this.weeklyDays,
    required this.weeklyCompleted,
    required this.weeklyMinutes,
    required this.weeklyReps,
  });
  final List<WorkoutDay?> weeklyDays;
  final int weeklyCompleted;

  /// Measured workout minutes per weekday slot (0 = no session logged).
  final List<double> weeklyMinutes;

  /// Measured completed reps per weekday slot (0 = no session logged).
  final List<double> weeklyReps;

  static List<String> dayLabels(AppLocalizations l10n) => [
        l10n.weekdayShortMon,
        l10n.weekdayShortTue,
        l10n.weekdayShortWed,
        l10n.weekdayShortThu,
        l10n.weekdayShortFri,
        l10n.weekdayShortSat,
        l10n.weekdayShortSun,
      ];

  /// Normalizes a measured series into 0..1 bar heights. Zero stays a
  /// hairline (0.03) so an empty day *looks* empty; non-zero values get
  /// a visibility floor so a 5-minute day doesn't vanish next to a
  /// 40-minute day.
  static List<double> _normalize(List<double> values) {
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxV <= 0) return List<double>.filled(values.length, 0.03);
    return [
      for (final v in values) v <= 0 ? 0.03 : 0.15 + 0.85 * (v / maxV),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final completionBars =
        weeklyDays.map((d) => (d?.isCompleted ?? false) ? 1.0 : 0.12).toList();
    final totalMinutes = weeklyMinutes.fold<double>(0, (a, b) => a + b).round();
    final totalReps = weeklyReps.fold<double>(0, (a, b) => a + b).round();

    return Column(
      children: [
        _StatChartCard(
          label: AppLocalizations.of(context).progressThisWeek,
          value: AppLocalizations.of(context)
              .progressWeeklyCompleted(weeklyCompleted, 7),
          accent: _neon,
          chart: _MiniBars(
            values: completionBars,
            labels: dayLabels(AppLocalizations.of(context)),
            gradientColors: const [_neonDeep, _neon],
          ),
        ),
        const SizedBox(height: 12),
        _StatChartCard(
          label: AppLocalizations.of(context).progressWorkoutDuration,
          value: '$totalMinutes',
          unit: AppLocalizations.of(context).progressUnitMinutes,
          accent: _orange,
          chart: _MiniAreaLine(
            values: _normalize(weeklyMinutes),
            color: _orange,
          ),
        ),
        const SizedBox(height: 12),
        _StatChartCard(
          label: AppLocalizations.of(context).progressReps,
          value: '$totalReps',
          unit: AppLocalizations.of(context).progressUnitReps,
          accent: _success,
          chart: _MiniBars(
            values: _normalize(weeklyReps),
            labels: dayLabels(AppLocalizations.of(context)),
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
                        style: TextStyle(
                          color: context.colors.onSurface,
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

/// Phase 52 · context-aware coach card. The greeting branches on the
/// live streak vs. the persisted `maxStreak` watermark so the card can
/// distinguish three states the PM specifically called out:
///
///   • Champion (`streak >= 7`) — celebrate the run.
///   • Comeback (`streak == 0 && maxStreak > 0`) — soft re-entry copy
///     that names how short the bar is. Without `maxStreak` we couldn't
///     tell a comeback user from a brand-new install.
///   • Default (everyone else) — generic forward motion copy.
///
/// Also hosts the "Günlük Özet Dinle" audio button: tapping fires a
/// flutter_tts phrase composed from the live macro target, the active
/// day's dominant target muscle, and the first meal in today's plan.
class _AiCoachCard extends ConsumerWidget {
  const _AiCoachCard({required this.streak, required this.percent});
  final int streak;
  final double percent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxStreak = ref.watch(appPreferencesProvider).maxStreak;
    final copy = _copyFor(AppLocalizations.of(context),
        streak: streak, maxStreak: maxStreak);
    return _SoftCard(
      accent: _neon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CoachAvatar(),
              const SizedBox(width: 12),
              _CardLabel(
                  text: AppLocalizations.of(context).progressAiCoachHeading),
              const Spacer(),
              _DailySummaryButton(streak: streak),
            ],
          ),
          const SizedBox(height: 12),
          // Phase 53 · defensive text scaling. The greeting is hero
          // copy that has to read at any TextScaler the user picks; an
          // unbounded Text with the OS scaler at 1.7x (the maximum
          // setting on iOS Accessibility) would push it past 4 lines
          // and overlap the Önerilere pill below. Cap to 4 lines with
          // ellipsis so the layout stays stable while assistive tech
          // gets the full string via Semantics.
          Text(
            copy,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textScaler: _clampedScaler(context),
            // Phase 53C · greeting copy was hardcoded white, leaving
            // it invisible on a light AI Coach card. Pull onSurface so
            // the contextual copy stays readable in both palettes.
            style: TextStyle(
              color: context.colors.onSurface,
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
            alignment: AlignmentDirectional.centerStart,
            child: _SectionLinkPill(
              label: AppLocalizations.of(context).progressGoToSuggestions,
              onTap: () => context.push(AppRoutes.progressSuggestions),
            ),
          ),
        ],
      ),
    );
  }

  String _copyFor(
    AppLocalizations l10n, {
    required int streak,
    required int maxStreak,
  }) {
    if (streak >= 7) {
      return l10n.progressCoachStreakStrong;
    }
    if (streak == 0 && maxStreak > 0) {
      return l10n.progressCoachComeback;
    }
    return l10n.progressCoachSteady;
  }

  /// Phase 53 · accessibility text scaling. The OS-level scaler can
  /// hit 1.7x on iOS / 2.0x on Android; layouts in this card are
  /// designed for ~1.0–1.3x, beyond which they overflow. Clamp at
  /// 1.3 so the user still gets larger-than-default text but the
  /// hero card doesn't need a redesign per scaler step.
  TextScaler _clampedScaler(BuildContext context) {
    final inherited = MediaQuery.textScalerOf(context);
    return inherited.clamp(maxScaleFactor: 1.3);
  }
}

/// Phase 52 · "Günlük Özet Dinle" button anchored top-right of the AI
/// Coach card. Builds the dynamic phrase off live providers so the
/// summary always reflects whatever the user is actually looking at:
///
///   • Calorie target → `macroTargetProvider`.
///   • Today's dominant target muscle → most-frequent `targetMuscle`
///     across the active day's exercises (matches the Bölgeler strip's
///     mapping).
///   • Suggested meal → first item in today's `dailyMenuProvider` plan.
///
/// On tap: spinner replaces the icon while the TTS engine warms up so
/// the user gets visual confirmation that the press registered (the
/// platform channel can take ~200 ms on cold first-tap before audio
/// actually starts).
class _DailySummaryButton extends ConsumerStatefulWidget {
  const _DailySummaryButton({required this.streak});

  final int streak;

  @override
  ConsumerState<_DailySummaryButton> createState() =>
      _DailySummaryButtonState();
}

class _DailySummaryButtonState extends ConsumerState<_DailySummaryButton> {
  bool _isSpeaking = false;

  @override
  Widget build(BuildContext context) {
    // Phase 53 · explicit Semantics so VoiceOver / TalkBack announce
    // the icon-only button as "Günlük özetimi dinle, düğme" rather
    // than just "düğme". `enabled: !_isSpeaking` mirrors the visual
    // disabled state for assistive tech.
    return Semantics(
      button: true,
      enabled: !_isSpeaking,
      label: _isSpeaking
          ? AppLocalizations.of(context).progressSummaryReading
          : AppLocalizations.of(context).progressSummaryListen,
      child: ExcludeSemantics(
        child: Material(
          color: _neon.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isSpeaking ? null : _onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: _isSpeaking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _neon,
                        ),
                      )
                    : const Icon(Icons.graphic_eq, color: _neon, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    AppHaptics.secondaryTap();
    setState(() => _isSpeaking = true);
    try {
      final phrase = _composeSummary(AppLocalizations.of(context), ref);
      final audio = AudioFeedback();
      await audio.init();
      // `speak` blocks until the platform reports completion (the
      // engine is configured with `awaitSpeakCompletion(true)` in
      // AudioFeedback.init), so the spinner stays visible for the
      // duration of the utterance.
      await audio.speak(phrase, cooldown: Duration.zero);
    } catch (e, st) {
      AppLogger.error(
        'Daily summary TTS failed',
        e,
        stackTrace: st,
        category: 'tts',
      );
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  String _composeSummary(AppLocalizations l10n, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final prefs = ref.read(appPreferencesProvider);
    final metrics = prefs.userMetrics ?? const <String, dynamic>{};
    final name = _resolveName(l10n, user?.email, metrics);

    final macroTarget = ref.read(macroTargetProvider);
    final session = ref.read(workoutSessionProvider).value;
    final activeDay = session == null ? null : _firstActiveDay(session.days);
    final muscleLabel = _muscleLabel(l10n, activeDay);

    final mealAsync = ref.read(dailyMenuProvider);
    final mealName = _firstMealName(l10n, mealAsync.value);

    return l10n.coachMorningBrief(
      name,
      macroTarget.calories,
      muscleLabel,
      mealName,
    );
  }

  /// Falls back through every signal we have, in priority order, to
  /// produce a friendly first name. The wizard never asks for a name,
  /// so this is intentionally lossy — if nothing usable exists we use
  /// "Şampiyon" so the phrase still reads like a coach greeting.
  String _resolveName(
    AppLocalizations l10n,
    String? email,
    Map<String, dynamic> metrics,
  ) {
    final fromMetrics = metrics['firstName'] as String?;
    if (fromMetrics != null && fromMetrics.trim().isNotEmpty) {
      return fromMetrics.trim();
    }
    if (email != null && email.contains('@')) {
      final localPart = email.substring(0, email.indexOf('@'));
      // Strip common email punctuation so "ali.veli" reads as "Ali"
      // when we capitalise the first segment.
      final cleaned = localPart.split(RegExp(r'[._+]')).first;
      if (cleaned.isNotEmpty) {
        return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
      }
    }
    return l10n.progressDefaultChampion;
  }

  WorkoutDay? _firstActiveDay(List<WorkoutDay> days) {
    for (final day in days) {
      if (day.isRestDay) continue;
      if (!day.isCompleted) return day;
    }
    return null;
  }

  String _muscleLabel(AppLocalizations l10n, WorkoutDay? day) {
    if (day == null || day.exercises.isEmpty) return l10n.muscleGroupFullBody;
    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return l10n.muscleGroupCore;
      case 'upper_body':
        return l10n.muscleGroupUpperBody;
      case 'lower_body':
        return l10n.muscleGroupLowerBody;
      case 'cardio':
        return l10n.muscleGroupCardio;
      case 'full_body':
        return l10n.muscleGroupFullBody;
      default:
        return l10n.muscleGroupFullBody;
    }
  }

  String _firstMealName(AppLocalizations l10n, List<PlannedMeal>? meals) {
    if (meals == null || meals.isEmpty) {
      return l10n.mealFallbackName;
    }
    final first = meals.first;
    final title = first.recipe.title.trim();
    return title.isEmpty ? l10n.mealFallbackName : title;
  }
}

/// Phase 38: the generic robot icon is replaced by the custom coach
/// photograph (`photos/PT_FORM.png`, already declared
/// under the `photos/` asset root in pubspec.yaml). The image is
/// clipped to a 45-px circle, surrounded by a 2-px neon-gradient ring
/// + glow so the avatar reads as "your coach" and not a stock icon.
/// An `errorBuilder` falls back to the old robot glyph if the asset
/// ever fails to decode.
///
/// Phase 49 · slow breathing scale (0.95 → 1.05) so the avatar reads
/// as "alive" / "thinking" instead of a static stamp. 2.4 s per
/// half-cycle keeps it subtle — fast enough to register motion, slow
/// enough not to fight the rest of the page's content.
class _CoachAvatar extends StatefulWidget {
  const _CoachAvatar();

  @override
  State<_CoachAvatar> createState() => _CoachAvatarState();
}

class _CoachAvatarState extends State<_CoachAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.95,
    end: 1.05,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
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
            'photos/PT_FORM.png',
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
    required this.totalKcal,
  });

  final int completedCount;
  final int streak;

  /// Lifetime completions × kcalPerCompletedDay — the ONE "Kalori
  /// Avcısı" definition, shared with unlockedBadgesProvider and
  /// badges_screen.
  final int totalKcal;

  @override
  Widget build(BuildContext context) {
    final badges = <_BadgeData>[
      _BadgeData(
        label: AppLocalizations.of(context).badgeStripFirstWeek,
        icon: Icons.flag_rounded,
        accent: _orange,
        unlocked: completedCount >= 1,
        progress: (completedCount / 7).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: AppLocalizations.of(context).badgeStripDisciplined,
        icon: Icons.shield_rounded,
        accent: _neon,
        unlocked: streak >= 3,
        progress: (streak / 3).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: AppLocalizations.of(context).badgeStripCalorieHunter,
        icon: Icons.local_fire_department,
        accent: _success,
        unlocked: totalKcal >= 1500,
        progress: (totalKcal / 1500).clamp(0.0, 1.0),
      ),
      _BadgeData(
        label: AppLocalizations.of(context).badgeStripThirtyDayChampion,
        icon: Icons.emoji_events_rounded,
        accent: _neon,
        unlocked: false,
        progress: 0,
      ),
      _BadgeData(
        label: AppLocalizations.of(context).badgeStripHiitMaster,
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
            _SectionLabel(
                title: AppLocalizations.of(context).badgeGalleryHeading),
            Builder(
              builder: (context) => _SectionLinkPill(
                label: AppLocalizations.of(context).badgeGallerySeeAll,
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

/// Roadmap Phase 12 (C21) · the way into community.
///
/// One row at the foot of the Progress tab, under the badges, rather
/// than a fifth item in the bottom navigation. The phase's rule is that
/// a user who never touches community sees no change, and a new tab is
/// a change to everybody's app the moment it ships. A row under the
/// badges is not — and it is the right neighbour, because a profile is
/// mostly the badges plus a name.
///
/// It is shown unconditionally, including when the schema is not
/// applied. The destination reports that state in a sentence, which is
/// a better answer than a row that silently is not there.
class _CommunityRow extends StatelessWidget {
  const _CommunityRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.community),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: _neon, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.communityTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.communityEntrySubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
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
    // 100, not 82. The longest badge label — "30 Gün Şampiyonu" — needs
    // 100 px to wrap onto two lines; at 82 it needed three, which is why
    // it rendered clipped mid-word on a device. The hex itself stays 72
    // and simply sits centred in the wider column.
    return SizedBox(
      width: 100,
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
          // Wraps rather than scales. `FittedBox` lays its child out
          // unbounded, so the text never wrapped and never shrank —
          // "30 Gün Şampiyonu" simply rendered as "30 Gün Şampiy",
          // clipped mid-word under the hex. Found on a device.
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            // Phase 53C · badge labels under the hex were hardcoded
            // white / white38, leaving them invisible on a light
            // scaffold. Pull onSurface so unlocked = primary, locked
            // = dimmed primary.
            style: TextStyle(
              color: data.unlocked
                  ? context.colors.onSurface
                  : context.colors.onSurface.withValues(alpha: 0.45),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!data.unlocked && data.progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppLocalizations.of(context)
                      .percentValue((data.progress * 100).round()),
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
    // Phase 53B · cards now sit on pure `surface` (#FFFFFF in light
    // mode) above the Scaffold's `scaffoldBackgroundColor` (#F7F8FA).
    // The natural surface-vs-scaffold delta gives the contrast the
    // previous hotfix lost when it pinned both surfaces to ~white. A
    // 1.5-px outlineVariant border + soft black-tinted shadow handle
    // visual elevation in light mode; dark mode keeps its accent
    // glow.
    final isDark = context.isDarkMode;
    final scheme = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? _surface : scheme.surface,
        border: Border.all(
          color: isDark ? _surfaceBorder : scheme.outlineVariant,
          width: isDark ? 1 : 1.5,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: 0.5,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
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
    // Phase 53C · the `color` override path is used for accent-tinted
    // labels (e.g. orange for the kcal card); when null, default to
    // the active onSurface so light mode reads charcoal-on-white.
    final base = color ?? context.colors.onSurface;
    return Text(
      text,
      style: TextStyle(
        color: base.withValues(alpha: 0.75),
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
    // Phase 53C · ROZETLERİN / 30 GÜNLÜK PROGRAM tags read through
    // onSurface so they flip with the active theme.
    return Text(
      title,
      style: TextStyle(
        color: context.colors.onSurface.withValues(alpha: 0.55),
        fontSize: 11,
        letterSpacing: 2.6,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
