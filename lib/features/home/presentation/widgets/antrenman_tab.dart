import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/tour_targets.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/placeholder_images.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/error_card.dart';
import '../../../workout/data/session_log_repository.dart';
import '../../../workout/models/exercise_model.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/models/session_log_model.dart';
import '../../../workout/models/workout_plan_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'challenge_hero_card.dart';
import 'equipment_strip.dart';
import 'weekly_goal_card.dart';
import '../../../progress/providers/streak_provider.dart';
import '../../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

/// The light-mode counterpart to [_neon]. Translucent neon fills go
/// almost white on a light scaffold, so anything drawn *on* one needs a
/// darker ink than the neon itself.
const Color _neonDeep = Color(0xFF6A3DFF);

Widget _resolveImage(String image) {
  final fallback = Container(
    color: Colors.white10,
    alignment: Alignment.center,
    child: const Icon(Icons.fitness_center, color: Colors.white54),
  );
  if (image.startsWith('http')) {
    return CachedImage(
      url: image,
      fit: BoxFit.cover,
      memCacheHeight: 500,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  return Image.asset(
    image,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => fallback,
  );
}

class AntrenmanTab extends ConsumerStatefulWidget {
  const AntrenmanTab({super.key});

  @override
  ConsumerState<AntrenmanTab> createState() => _AntrenmanTabState();
}

class _AntrenmanTabState extends ConsumerState<AntrenmanTab> {
  /// Body-area chips. A function rather than a `const` table because
  /// the labels are copy; the [ExerciseCategory] is the identity.
  static List<({String label, ExerciseCategory category})> _chipDefs(
    AppLocalizations l10n,
  ) =>
      [
        (label: l10n.muscleCore, category: ExerciseCategory.core),
        (label: l10n.muscleChest, category: ExerciseCategory.chest),
        (label: l10n.muscleBack, category: ExerciseCategory.back),
        (label: l10n.muscleShoulders, category: ExerciseCategory.shoulders),
        (label: l10n.muscleArms, category: ExerciseCategory.arms),
        (label: l10n.muscleLegs, category: ExerciseCategory.legs),
        (label: l10n.muscleCardio, category: ExerciseCategory.fullBody),
      ];

  // Asset paths, not copy — the Turkish characters are in the FILENAMES
  // on disk, which is why the gate's heuristic flags them.
  static const List<String> _precacheAssets = [
    'photos/günlükmeydanokumayenifoto.webp', // i18n-ignore
    'photos/sınırlarınızorlabelirginkarınkarınkaslarıHIITnewfoto.webp', // i18n-ignore
    'photos/sınırlarınızorlademiraltıpaketgücünewfoto.webp', // i18n-ignore
  ];

  ExerciseCategory _selectedCategory = ExerciseCategory.core;
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    for (final asset in _precacheAssets) {
      precacheImage(AssetImage(asset), context).catchError((_) {
        return;
      });
    }
    // Phase 51 · warm `flutter_cache_manager` (the same disk cache
    // `CachedNetworkImage` reads from) so the regional plan cards
    // displaying these defaults skip the network on first render.
    // The previous `precacheImage(NetworkImage(...))` populated the
    // framework's in-memory ImageCache, which `CachedNetworkImage`
    // never consults — meaning every "precached" URL was downloaded
    // twice, once for the framework cache and again for the disk
    // cache the cards actually read from.
    unawaited(_warmDefaults());
  }

  Future<void> _warmDefaults() async {
    final cacheManager = DefaultCacheManager();
    for (final url in const [defaultMuscularPhotoUrl, defaultLeanPhotoUrl]) {
      try {
        await cacheManager.downloadFile(url);
      } catch (_) {
        // Best-effort. If the prefetch fails, CachedNetworkImage will
        // run the download itself the first time the URL renders.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(workoutSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _neon)),
      error: (err, st) {
        AppLogger.error(
          'antrenman workoutSession error', // i18n-ignore — log line
          err,
          stackTrace: st,
          category: 'workout',
        );
        return ErrorCard(
          message: AppLocalizations.of(context).workoutProgramLoadFailed,
          onRetry: () => ref.invalidate(workoutSessionProvider),
        );
      },
      data: (session) => _buildContent(context, session),
    );
  }

  Widget _buildContent(BuildContext context, WorkoutSessionState session) {
    final completed = session.days.where((d) => d.isCompleted).length;
    final streak = ref.watch(currentStreakProvider);
    final nextDay = _firstIncomplete(session.days);
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekDates = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
    // P1-4 · "weekly goal" used the LIFETIME completion count, so once
    // a user passed 3 total workouts the card read 3/3 forever and the
    // Monday reset never happened. Count distinct active days inside
    // THIS calendar week from session-log timestamps (+ lastWorkoutAt,
    // which also covers ad-hoc plan workouts).
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final logs =
        ref.watch(sessionLogsProvider).value ?? const <int, SessionLog>{};
    final weeklyActiveDays = <DateTime>{};
    void addIfThisWeek(DateTime? instant) {
      if (instant == null) return;
      final local = instant.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final offset = day.difference(weekStartDate).inDays;
      if (offset >= 0 && offset < 7) weeklyActiveDays.add(day);
    }

    for (final log in logs.values) {
      addIfThisWeek(DateTime.tryParse(log.completedAtIso));
    }
    addIfThisWeek(ref.watch(appPreferencesProvider).lastWorkoutAt);
    final weeklyGoalCompleted = weeklyActiveDays.length;

    final plansAsync = ref.watch(workoutPlansProvider);
    // Phase 50A · the plans list is now async (Supabase-backed). Falling
    // back to an empty list during loading / error keeps the regional
    // strip's empty-state copy in charge of the UX rather than chaining
    // a second loading spinner.
    final allPlans = plansAsync.value ?? const <WorkoutPlan>[];
    final filteredPlans =
        allPlans.where((p) => p.category == _selectedCategory).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      children: [
        _AntrenmanHeader(streak: streak),
        const SizedBox(height: 14),
        // REV-C1 · offline-fallback stub (30 rest days) must announce
        // itself instead of rendering as a silent all-rest program.
        if (session.isStub)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: ErrorCard(
              compact: true,
              message: AppLocalizations.of(context).programSyncing,
              icon: Icons.cloud_sync_rounded,
              onRetry: () => ref.invalidate(workoutSessionProvider),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: WeeklyGoalCard(
            weekDates: weekDates,
            today: today,
            weeklyCompleted: weeklyGoalCompleted.clamp(0, 3),
            weeklyTarget: 3,
          ),
        ),
        const SizedBox(height: 16),
        // Roadmap Phase 2 (C27) · tour target. KeyedSubtree rather than a
        // key on the Padding so the resolved rect hugs the card itself.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: KeyedSubtree(
            key: ref.read(tourTargetsProvider).coachCard,
            child: const _CoachEntryCard(),
          ),
        ),
        const SizedBox(height: 26),
        _SectionTitle(
          title: AppLocalizations.of(context).workoutTabHeading,
          trailingIcon: Icons.tune,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Roadmap Phase 2 (C27) · tour step 1 points here: "today's
          // workout lives here".
          child: KeyedSubtree(
            key: ref.read(tourTargetsProvider).planCard,
            child: ChallengeHeroCard(
              // The offline stub is thirty EMPTY days and `isRestDay` is
              // `exercises.isEmpty`, so an unloaded program and a
              // genuine rest day are the same value to this card — it
              // read "Rest day" to a user whose program had simply not
              // downloaded. The banner above already says what is
              // happening; the card must not contradict it with a
              // schedule it does not have.
              title: session.isStub
                  ? AppLocalizations.of(context).workoutProgramPreparing
                  : _challengeTitleFor(nextDay),
              dayNumber: nextDay?.dayNumber ?? 1,
              completed: completed,
              total: 30,
              onTap: () => context.push(AppRoutes.planDetail),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _SectionTitle(
            title: AppLocalizations.of(context).workoutEquipmentHeading),
        const SizedBox(height: 12),
        const EquipmentStrip(),
        const SizedBox(height: 28),
        _SectionTitle(
          title: AppLocalizations.of(context).workoutAreasHeading,
          trailingIcon: Icons.search_rounded,
        ),
        const SizedBox(height: 12),
        _CategoryChipsRow(
          chips: _chipDefs(AppLocalizations.of(context)),
          selected: _selectedCategory,
          onSelect: (c) => setState(() => _selectedCategory = c),
        ),
        const SizedBox(height: 14),
        _RegionalPlansList(plans: filteredPlans),
      ],
    );
  }

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final day in days) {
      if (!day.isCompleted) return day;
    }
    return null;
  }

  /// Builds a human title for the next-up day on the dashboard card.
  /// Rest days short-circuit to "Dinlenme Günü"; active days pick a
  /// title from the dominant `targetMuscle` of that day's exercises so
  /// a core-heavy day and a cardio-heavy day don't both read as
  /// "Karın Kasları".
  String _challengeTitleFor(WorkoutDay? day) {
    if (day == null) return AppLocalizations.of(context).workoutPersonalSession;
    if (day.isRestDay) return AppLocalizations.of(context).workoutRestDay;

    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return AppLocalizations.of(context).workoutPersonalSession;
    }

    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return AppLocalizations.of(context).workoutDayCoreTitle;
      case 'upper_body':
        return AppLocalizations.of(context).workoutDayUpperTitle;
      case 'lower_body':
        return AppLocalizations.of(context).workoutDayLowerTitle;
      case 'cardio':
      case 'full_body':
        return AppLocalizations.of(context).workoutDayFullBodyTitle;
      default:
        return AppLocalizations.of(context).workoutPersonalSession;
    }
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.chips,
    required this.selected,
    required this.onSelect,
  });

  final List<({String label, ExerciseCategory category})> chips;
  final ExerciseCategory selected;
  final ValueChanged<ExerciseCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return _CategoryChip(
            label: chip.label,
            selected: chip.category == selected,
            onTap: () => onSelect(chip.category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · unselected chip label was `Colors.white60` —
    // legible on dark, invisible on light. Pull from onSurface so
    // the strip flips with the active theme; selected stays neonAccent
    // because it's the brand-coloured emphasis.
    final scheme = context.colors;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? _neonAccent
                  : scheme.onSurface.withValues(alpha: 0.6),
              fontSize: selected ? 17 : 16,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: selected ? 36 : 0,
            decoration: BoxDecoration(
              color: _neonAccent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _neonAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionalPlansList extends StatelessWidget {
  const _RegionalPlansList({required this.plans});
  final List<WorkoutPlan> plans;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      // Phase 47B · polished empty state. Icon + two-line copy nudges
      // the user toward other regional categories instead of leaving
      // them on a dead-end neutral note. No CTA here on purpose —
      // the user already sees the category filter strip above; the
      // message is the nudge.
      // Phase 53B · pull surfaces + text from the active ColorScheme
      // so the empty card flips correctly under both palettes.
      final scheme = context.colors;
      final isDark = context.isDarkMode;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
            border: Border.all(
              color: isDark ? Colors.white12 : scheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _neonAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _neonAccent.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.explore,
                  color: _neonAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).workoutNoPlansForArea,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const Divider(
        color: Colors.white12,
        height: 18,
        thickness: 1,
      ),
      itemBuilder: (context, index) => _PlanTile(plan: plans[index]),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · plan tile sits on the scaffold (transparent), so
    // text colour has to flip with the active theme. The trailing
    // chevron pill also picks up the theme so it doesn't stay a
    // black puck on a white surface.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 64,
                height: 64,
                child: plan.image == null
                    ? Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.fitness_center,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      )
                    : _resolveImage(plan.image!),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.summary,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: isDark ? Colors.black : scheme.surface,
              shape: CircleBorder(
                side: BorderSide(
                  color: scheme.onSurface.withValues(alpha: 0.24),
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _open(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onSurface,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    context.push(AppRoutes.planDetail, extra: plan);
  }
}

class _AntrenmanHeader extends StatelessWidget {
  const _AntrenmanHeader({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'FormAI', // i18n-ignore — brand wordmark
              style: TextStyle(
                color: _neon,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [Shadow(blurRadius: 14, color: _neon)],
              ),
            ),
          ),
          _CoachButton(),
          const SizedBox(width: 8),
          _ProButton(),
          const SizedBox(width: 8),
          _FlameStreakBadge(streak: streak),
        ],
      ),
    );
  }
}

/// Always-reachable entry to the AI coach — a persistent presence in the
/// dashboard header (the coach is one tap away from anywhere on the home).
class _CoachButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).coachTalkShort,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(AppRoutes.coach),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _neon.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(color: _neon.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'photos/PT_FORM.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.smart_toy, color: _neon, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dashboard's prominent, always-present AI-coach entry. Deliberately a
/// calm, tappable card in the home flow — not a floating bubble — so "talk to
/// Form" reads as a first-class surface (à la WHOOP / Fitbod coach cards).
/// Theme-aware; one tap opens the full coach conversation.
class _CoachEntryCard extends ConsumerWidget {
  const _CoachEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    // The dot and its label used to be a green circle and the word
    // "online", unconditionally. With the radio off the card still said
    // the coach was online — which is the single situation the indicator
    // exists to report, and the coach genuinely cannot answer, because
    // its replies come from a server.
    //
    // `connectivityProvider` assumes online until the first platform
    // event (see its doc comment), so a cold start does not flicker
    // through a false offline state.
    final online = ref.watch(connectivityProvider).value ?? true;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).coachTalkLong,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push(AppRoutes.coach),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isDark ? const Color(0xFF160C26) : scheme.surface,
              border: Border.all(color: _neon.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(color: _neon.withValues(alpha: 0.15), blurRadius: 18),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _neon.withValues(alpha: 0.6)),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'photos/PT_FORM.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.smart_toy, color: _neon, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Form', // i18n-ignore — the coach's name
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: online
                                  ? const Color(0xFF39FF14)
                                  : scheme.onSurface.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            online
                                ? AppLocalizations.of(context).coachOnline
                                : AppLocalizations.of(context).coachOffline,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(context).coachGreeting,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _neon.withValues(alpha: 0.8),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // The fill is a translucent neon gradient, so on a light scaffold it
    // resolves to a near-white lavender — and the label was hardcoded
    // white. Found on the device: "PREMIUM" was white on almost-white,
    // around 1.3:1, in the dashboard header. The deeper purple keeps the
    // brand and is legible on the light fill; dark mode is unchanged.
    final fg = context.isDarkMode ? Colors.white : _neonDeep;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(AppRoutes.paywall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _neon, width: 1),
            gradient: LinearGradient(
              colors: [
                _neon.withValues(alpha: 0.25),
                _neon.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: fg, size: 14),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).premiumBadge,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  letterSpacing: 1.6,
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

class _FlameStreakBadge extends StatelessWidget {
  const _FlameStreakBadge({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFF8A00), Color(0xFFFF3D00)],
          ).createShader(rect),
          child: const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 32,
            shadows: [Shadow(blurRadius: 14, color: Color(0xFFFF6F00))],
          ),
        ),
        if (streak > 0)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF6F00),
                  width: 1,
                ),
              ),
              child: Text(
                '$streak',
                style: const TextStyle(
                  color: Color(0xFFFFB04D),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailingIcon});
  final String title;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · "Ekipmanlı Egzersizler" / "Bölgeler" / etc. titles need
    // to flip with the active theme. Pull the active onSurface tone
    // and let the trailing icon tile match.
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: Colors.white54, size: 22),
        ],
      ),
    );
  }
}
