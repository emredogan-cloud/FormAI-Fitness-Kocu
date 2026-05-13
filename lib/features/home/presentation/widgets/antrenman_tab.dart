import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/placeholder_images.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/error_card.dart';
import '../../../monetization/models/locked_feature_type.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/premium_gate_service.dart';
import '../../../monetization/widgets/locked_overlay.dart';
import '../../../workout/models/exercise_model.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/models/workout_plan_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'challenge_hero_card.dart';
import 'equipment_strip.dart';
import 'weekly_goal_card.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);

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
  static const List<({String label, ExerciseCategory category})> _chipDefs = [
    (label: 'Core', category: ExerciseCategory.core),
    (label: 'Göğüs', category: ExerciseCategory.chest),
    (label: 'Sırt', category: ExerciseCategory.back),
    (label: 'Omuz', category: ExerciseCategory.shoulders),
    (label: 'Kol', category: ExerciseCategory.arms),
    (label: 'Bacak', category: ExerciseCategory.legs),
    (label: 'Kardiyo', category: ExerciseCategory.fullBody),
  ];

  static const List<String> _precacheAssets = [
    'photos/günlükmeydanokumayenifoto.webp',
    'photos/sınırlarınızorlabelirginkarınkarınkaslarıHIITnewfoto.webp',
    'photos/sınırlarınızorlademiraltıpaketgücünewfoto.webp',
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
          'antrenman workoutSession error',
          err,
          stackTrace: st,
          category: 'workout',
        );
        return ErrorCard(
          message: 'Programın yüklenirken bir sorun oluştu.',
          onRetry: () => ref.invalidate(workoutSessionProvider),
        );
      },
      data: (session) => _buildContent(context, session),
    );
  }

  Widget _buildContent(BuildContext context, WorkoutSessionState session) {
    final completed = session.days.where((d) => d.isCompleted).length;
    final streak = _streakOf(session.days);
    final nextDay = _firstIncomplete(session.days);
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekDates = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: WeeklyGoalCard(
            weekDates: weekDates,
            today: today,
            weeklyCompleted: completed.clamp(0, 3),
            weeklyTarget: 3,
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle(
          title: 'Kişisel Antrenman Programın',
          trailingIcon: Icons.tune,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ChallengeHeroCard(
            title: _challengeTitleFor(nextDay),
            dayNumber: nextDay?.dayNumber ?? 1,
            completed: completed,
            total: 30,
            onTap: () => context.push(AppRoutes.planDetail),
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: 'Ekipmanlı Egzersizler'),
        const SizedBox(height: 12),
        const EquipmentStrip(),
        const SizedBox(height: 28),
        const _SectionTitle(
          title: 'Bölgeler',
          trailingIcon: Icons.search_rounded,
        ),
        const SizedBox(height: 12),
        _CategoryChipsRow(
          chips: _chipDefs,
          selected: _selectedCategory,
          onSelect: (c) => setState(() => _selectedCategory = c),
        ),
        const SizedBox(height: 14),
        _RegionalPlansList(plans: filteredPlans),
        // Phase 134 · "Yeni Egzersizler" teaser strip per region. For
        // non-pro users this surfaces the Phase 96 expansion set as
        // visible-but-locked previews — the curiosity / aspiration
        // beat the emotional-monetization spec asks for. Pro users
        // see the same strip without lock chrome so the "yeni"
        // tagging still reads as a freshness signal.
        _YeniExercisesStrip(category: _selectedCategory),
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
    if (day == null) return 'Kişisel Antrenman';
    if (day.isRestDay) return 'Dinlenme Günü';

    final counts = <String, int>{};
    for (final exercise in day.exercises) {
      counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Kişisel Antrenman';

    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case 'core':
        return 'Sert Karın Kasları';
      case 'upper_body':
        return 'Üst Vücut Gücü';
      case 'lower_body':
        return 'Bacak ve Kalça Ateşi';
      case 'cardio':
      case 'full_body':
        return 'Tüm Vücut Kondisyon';
      default:
        return 'Kişisel Antrenman';
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
                  'Bu bölge için plan bulunmuyor — diğer kategorileri '
                  'keşfedebilirsin.',
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
              'FormAI',
              style: TextStyle(
                color: _neon,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [Shadow(blurRadius: 14, color: _neon)],
              ),
            ),
          ),
          _ProButton(),
          const SizedBox(width: 8),
          _FlameStreakBadge(streak: streak),
        ],
      ),
    );
  }
}

class _ProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                'PRO',
                style: TextStyle(
                  color: Colors.white,
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

/// Phase 134 · "Yeni Egzersizler" strip rendered below the regional plan
/// list, filtered to the currently-selected region.
///
/// Visual model: horizontal scrollable strip of compact exercise cards
/// (gradient swatch + exercise name + "Yeni" chip). Non-pro users see
/// the same cards through [LockedOverlay], so the chip + lock badge
/// stack to read as "premium-tier movement freshly added". Tapping a
/// locked tile routes through [PremiumGateService] so the cinematic
/// conversion scene (Phase 135) lights up once C4 ships — Phase 134's
/// gate-service stub for now routes straight to /paywall, keeping the
/// behaviour identical to other locked surfaces in this commit.
///
/// Source data: [exercisesProvider] (Supabase-backed via Phase 50A).
/// Tagging lives in [PremiumExerciseTags.newSlugs] and is applied at
/// hydration time in `WorkoutRepository._exerciseFromRow`.
class _YeniExercisesStrip extends ConsumerWidget {
  const _YeniExercisesStrip({required this.category});

  final ExerciseCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);
    return exercisesAsync.maybeWhen(
      data: (all) => _buildStrip(context, ref, all),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildStrip(
    BuildContext context,
    WidgetRef ref,
    List<Exercise> all,
  ) {
    final yeniForRegion = all
        .where((e) => e.isNew && e.category == category)
        .take(8)
        .toList(growable: false);
    if (yeniForRegion.isEmpty) return const SizedBox.shrink();

    final isPro = ref.watch(isProProvider);
    final gate = ref.read(premiumGateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const _SectionTitle(title: 'Yeni Egzersizler'),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'FormAI tarafından seçildi',
            style: TextStyle(
              color: Color(0xFFB58CFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: yeniForRegion.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final exercise = yeniForRegion[index];
              final card = _YeniExerciseCard(
                exercise: exercise,
                onTap: isPro
                    ? () => _showYeniExerciseDetail(context, exercise)
                    : null,
              );
              return LockedOverlay(
                locked: !isPro,
                cornerRadius: 18,
                showLockBadge: true,
                showProBadge: true,
                onTap: () => gate.handleLockedTap(
                  context,
                  LockedFeatureType.regionNewExercise,
                ),
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact preview tile for [_YeniExercisesStrip].
///
/// 137-polish revision: dropped from 152 → 138 wide so a 5-card rail
/// fits within a single horizontal sweep on mid-range Androids
/// (denser feels Netflix-style instead of decorative). Gradient
/// dropped 10 luminance steps so it reads as a *backdrop* rather than
/// the whole card — the cinematic feel comes from the LockedOverlay
/// glass treatment that lands on top for non-pro users, not from
/// brute saturation here. The "YENİ" chip becomes an outline-style
/// "NEW" pill (soft-purple, tiny) consistent with the new LockedOverlay
/// indicator language.
class _YeniExerciseCard extends StatelessWidget {
  const _YeniExerciseCard({required this.exercise, this.onTap});

  static const Color _softPurple = Color(0xFFB58CFF);

  final Exercise exercise;
  final VoidCallback? onTap;

  /// Rough minute estimate used in the metadata footer. Mirrors
  /// `TodayTaskCard._estimateMinutes` shape but coarser — we only need
  /// a single-card hint, not an accurate plan duration.
  int _estimateMinutes() {
    if (exercise.isTimeBased) {
      final duration = (exercise.targetDurationInSeconds ?? 30) * exercise.sets;
      return (duration / 60).clamp(1, 30).round();
    }
    final repsTime = (exercise.targetReps ?? 10) * 3 * exercise.sets;
    return (repsTime / 60).clamp(1, 30).round();
  }

  String get _difficultyLabel {
    switch (exercise.difficulty) {
      case 'advanced':
        return 'İleri';
      case 'intermediate':
        return 'Orta';
      default:
        return 'Başlangıç';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 138,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                _neon.withValues(alpha: 0.32),
                _neonAccent.withValues(alpha: 0.16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.18),
                blurRadius: 12,
                spreadRadius: 0.2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NewPill(softPurple: _softPurple),
                const Spacer(),
                Text(
                  exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_estimateMinutes()} dk · $_difficultyLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 137-polish · tiny outlined "NEW" pill rendered in the top-left
/// corner of [_YeniExerciseCard]. Outline-only style (no solid fill)
/// matches the LockedOverlay's premium-pill language so the locked +
/// unlocked states feel consistent.
class _NewPill extends StatelessWidget {
  const _NewPill({required this.softPurple});

  final Color softPurple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.30),
        border: Border.all(
          color: softPurple.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: softPurple.withValues(alpha: 0.95),
          fontSize: 8.5,
          height: 1.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

void _showYeniExerciseDetail(BuildContext context, Exercise exercise) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _YeniExerciseDetailSheet(exercise: exercise),
  );
}

class _YeniExerciseDetailSheet extends StatelessWidget {
  const _YeniExerciseDetailSheet({required this.exercise});

  final Exercise exercise;

  static const Color _softPurple = Color(0xFFB58CFF);

  int _estimateMinutes() {
    if (exercise.isTimeBased) {
      final duration = (exercise.targetDurationInSeconds ?? 30) * exercise.sets;
      return (duration / 60).clamp(1, 30).round();
    }
    final repsTime = (exercise.targetReps ?? 10) * 3 * exercise.sets;
    return (repsTime / 60).clamp(1, 30).round();
  }

  String get _difficultyLabel {
    switch (exercise.difficulty) {
      case 'advanced':
        return 'İleri';
      case 'intermediate':
        return 'Orta';
      default:
        return 'Başlangıç';
    }
  }

  String get _setsRepsLabel {
    return exercise.isTimeBased
        ? '${exercise.sets} × ${exercise.targetDurationInSeconds ?? 0} sn'
        : '${exercise.sets} set · ${exercise.targetReps ?? 0} tekrar';
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = exercise.description.isNotEmpty;
    final hasTip = exercise.shortTip.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF100920),
        border: Border.all(
          color: _softPurple.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.black.withValues(alpha: 0.30),
              border: Border.all(
                color: _softPurple.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: Text(
              'YENİ',
              style: TextStyle(
                color: _softPurple.withValues(alpha: 0.95),
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            exercise.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ExerciseMetaChip(
                icon: Icons.timer_outlined,
                label: '${_estimateMinutes()} dk',
              ),
              _ExerciseMetaChip(
                icon: Icons.fitness_center,
                label: _difficultyLabel,
              ),
              _ExerciseMetaChip(
                icon: exercise.isTimeBased
                    ? Icons.timer_rounded
                    : Icons.repeat_rounded,
                label: _setsRepsLabel,
              ),
            ],
          ),
          if (hasDescription) ...[
            const SizedBox(height: 16),
            Text(
              exercise.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (hasTip) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _softPurple.withValues(alpha: 0.10),
                border: Border.all(
                  color: _softPurple.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: _softPurple.withValues(alpha: 0.80),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.shortTip,
                      style: TextStyle(
                        color: _softPurple.withValues(alpha: 0.90),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseMetaChip extends StatelessWidget {
  const _ExerciseMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
