import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/placeholder_images.dart';
import '../../../../core/widgets/error_card.dart';
import '../../../workout/models/exercise_model.dart';
import '../../../workout/models/workout_day_model.dart';
import '../../../workout/models/workout_plan_model.dart';
import '../../../workout/providers/workout_provider.dart';
import 'challenge_hero_card.dart';
import 'push_limits_strip.dart';
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
    return Image.network(
      image,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.white10,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        );
      },
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
    precacheImage(const NetworkImage(defaultMuscularPhotoUrl), context)
        .catchError((_) => null);
    precacheImage(const NetworkImage(defaultLeanPhotoUrl), context)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(workoutSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _neon)),
      error: (err, st) {
        debugPrint('antrenman workoutSession error: $err\n$st');
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

    final allPlans = ref.watch(workoutPlansProvider);
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
          title: 'Günlük Meydan Okuma',
          trailingIcon: Icons.tune,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ChallengeHeroCard(
            dayNumber: nextDay?.dayNumber ?? 1,
            completed: completed,
            total: 30,
            onTap: () => context.push(AppRoutes.planDetail),
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: 'Sınırlarını Zorla'),
        const SizedBox(height: 12),
        const PushLimitsStrip(),
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
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? _neonAccent : Colors.white60,
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            'Bu bölge için plan yakında eklenecek.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
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
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white54,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.summary,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.black,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white24, width: 1),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _open(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
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
