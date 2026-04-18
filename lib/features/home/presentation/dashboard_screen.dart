import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/audio_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/models/exercise_model.dart';
import '../../workout/models/workout_day_model.dart';
import '../../workout/models/workout_plan_model.dart';
import '../../workout/providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _neonAccent = Color(0xFF4DA6FF);
const Color _surface = Color(0xFF111118);

// Aesthetic Unsplash placeholders. The first one matches the muscular
// reference in the docs/ screenshots; the second one is the lean
// alternative used on lighter cards.
const String _muscularPhotoUrl =
    'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&w=600&q=80';
const String _leanPhotoUrl =
    'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=600&q=80';

const List<String> _trDayLabels = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];

/// Renders [image] as either a network image (when it starts with `http`)
/// or a bundled asset. Shared by dashboard tiles so one attribute can
/// mix Unsplash placeholders and local reference shots.
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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            _AntrenmanTab(),
            _GelisimTab(),
            _ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: index,
        onTap: onChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: _neon,
        unselectedItemColor: Colors.white54,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Antrenman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Gelişim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 1 — Antrenman (Dashboard)
// ============================================================================

class _AntrenmanTab extends ConsumerStatefulWidget {
  const _AntrenmanTab();

  @override
  ConsumerState<_AntrenmanTab> createState() => _AntrenmanTabState();
}

class _AntrenmanTabState extends ConsumerState<_AntrenmanTab> {
  // Order matches the spec's chip order with Sırt added between Göğüs and
  // Kol so the new Phase 21 plans are visible from the dashboard.
  static const List<({String label, ExerciseCategory category})> _chipDefs = [
    (label: 'Core', category: ExerciseCategory.core),
    (label: 'Göğüs', category: ExerciseCategory.chest),
    (label: 'Sırt', category: ExerciseCategory.back),
    (label: 'Kol', category: ExerciseCategory.arms),
    (label: 'Bacak', category: ExerciseCategory.legs),
    (label: 'Tüm Vücut', category: ExerciseCategory.fullBody),
  ];

  ExerciseCategory _selectedCategory = ExerciseCategory.core;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(workoutSessionProvider);

    return sessionAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _neon)),
      error: (err, _) => Center(
        child: Text(
          'Program yüklenemedi: $err',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (session) => _buildContent(context, session),
    );
  }

  Widget _buildContent(BuildContext context, WorkoutSessionState session) {
    final completed = session.days.where((d) => d.isCompleted).length;
    final streak = _streakOf(session.days);
    final nextDay = _firstIncomplete(session.days);
    final today = DateTime.now();
    // Monday-anchored 7-day window so "Haftalık Hedef" shows the current
    // calendar week rather than a sliding 7-day strip.
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
          child: _WeeklyGoalCard(
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
          child: _ChallengeHeroCard(
            dayNumber: nextDay?.dayNumber ?? 1,
            completed: completed,
            total: 30,
            onTap: () => context.push(AppRoutes.planDetail),
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(title: 'Sınırlarını Zorla'),
        const SizedBox(height: 12),
        const _PushLimitsStrip(),
        // ---------- Flattened Bölgeler section (was Tab 2) ----------
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
    // Push the unified plan-detail route with the WorkoutPlan attached as
    // `extra`; the screen renders an empty-state for plans whose exercise
    // list hasn't been populated yet, so coming-soon plans still reach a
    // real screen instead of a snackbar dead-end.
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

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.weekDates,
    required this.today,
    required this.weeklyCompleted,
    required this.weeklyTarget,
  });

  final List<DateTime> weekDates;
  final DateTime today;
  final int weeklyCompleted;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Text(
                      'Haftalık Hedef',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.edit, color: Colors.white38, size: 14),
                  ],
                ),
              ),
              Text(
                '$weeklyCompleted/$weeklyTarget egzersiz',
                style: const TextStyle(
                  color: _neonAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < weekDates.length; i++)
                _DateBubble(
                  date: weekDates[i],
                  label: _trDayLabels[i],
                  isToday: _isSameDay(weekDates[i], today),
                  isPast: weekDates[i]
                      .isBefore(DateTime(today.year, today.month, today.day)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _CoachSpeechBubble(
            text: 'Haftayı tam gaz bitir! Bir antrenman daha yap, '
                'harika başaracaksın!',
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateBubble extends StatelessWidget {
  const _DateBubble({
    required this.date,
    required this.label,
    required this.isToday,
    required this.isPast,
  });

  final DateTime date;
  final String label;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final bg = isToday
        ? _neon
        : (isPast ? Colors.white.withValues(alpha: 0.04) : Colors.transparent);
    final border = isToday ? _neon : Colors.white.withValues(alpha: 0.18);
    final numberColor =
        isToday ? Colors.white : (isPast ? Colors.white60 : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: 1),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: numberColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachSpeechBubble extends StatelessWidget {
  const _CoachSpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_neon, _neonAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeHeroCard extends StatelessWidget {
  const _ChallengeHeroCard({
    required this.dayNumber,
    required this.completed,
    required this.total,
    required this.onTap,
  });

  final int dayNumber;
  final int completed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: 0,
                bottom: 40,
                width: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      _neon.withValues(alpha: 0.35),
                      BlendMode.softLight,
                    ),
                    child: Image.network(
                      _muscularPhotoUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Taş Gibi Sert\nKarın Kasları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.bolt, color: Colors.white, size: 14),
                      Icon(Icons.bolt, color: Colors.white, size: 14),
                      Icon(Icons.bolt, color: Colors.white70, size: 14),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$dayNumber. Gün',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0.3,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black26)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$completed/$total Gün',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: onTap,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'BAŞLA',
                              style: TextStyle(
                                color: _neon,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PushLimitsStrip extends StatelessWidget {
  const _PushLimitsStrip();

  static const List<
      ({
        String title,
        String level,
        int minutes,
        String imageUrl,
        Color tint,
      })> _items = [
    (
      title: 'Belirgin Karın Kasları HIIT',
      level: 'Orta düzey',
      minutes: 19,
      imageUrl: _muscularPhotoUrl,
      tint: _neon,
    ),
    (
      title: 'Daha Güçlü Şekil ve Çekirdek',
      level: 'Orta düzey',
      minutes: 24,
      imageUrl: _muscularPhotoUrl,
      tint: Color(0xFF1FBF8F),
    ),
    (
      title: 'Demir Altı Paket Gücü',
      level: 'İleri',
      minutes: 18,
      imageUrl: _muscularPhotoUrl,
      tint: _neonAccent,
    ),
    (
      title: 'Atletik Core Kontrolü',
      level: 'Başlangıç',
      minutes: 15,
      imageUrl: _leanPhotoUrl,
      tint: Color(0xFFFF6FB5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _PushLimitsCard(
            title: item.title,
            level: item.level,
            minutes: item.minutes,
            imageUrl: item.imageUrl,
            tint: item.tint,
          );
        },
      ),
    );
  }
}

class _PushLimitsCard extends StatelessWidget {
  const _PushLimitsCard({
    required this.title,
    required this.level,
    required this.minutes,
    required this.imageUrl,
    required this.tint,
  });

  final String title;
  final String level;
  final int minutes;
  final String imageUrl;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            tint.withValues(alpha: 0.85),
            tint.withValues(alpha: 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -8,
            bottom: 50,
            width: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.15),
                  BlendMode.darken,
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$level · $minutes Dk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        child: Text(
                          'BAŞLA',
                          style: TextStyle(
                            color: tint,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 2 — Gelişim (Progress / Reports placeholder)
// ============================================================================
//
// We deliberately repurpose this slot rather than mirror the Bölgeler list
// from Tab 1. The category filter now lives on the main dashboard, so this
// tab focuses on long-term progress and acts as the landing pad for future
// graphs / streak history / body-composition charts.

class _GelisimTab extends ConsumerWidget {
  const _GelisimTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = _streakOf(session?.days ?? const []);

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
              child: _StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'TAMAMLANAN',
                value: '$completed / 30',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _ComingSoonCard(
          title: 'Detaylı Raporlar Yakında',
          body: 'Haftalık aktivite grafiği, güç artışı eğrileri ve vücut '
              'değişim takibi yakında bu sekmede açılacak.',
        ),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.18),
            _neonAccent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _neon.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neon.withValues(alpha: 0.25),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
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

// ============================================================================
// Tab 3 — Profil (preserved with TTS test moved into settings)
// ============================================================================

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider).value;
    final metrics = ref.watch(appPreferencesProvider).userMetrics ?? const {};
    final user = ref.watch(currentUserProvider);

    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final streak = _streakOf(session?.days ?? const []);
    final weight = metrics['weightKg'];
    final height = metrics['heightCm'];
    final age = metrics['age'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _ProfileHeader(email: user?.email, isGuest: user?.isAnonymous ?? false),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'KİLO',
                value: weight == null ? '—' : '$weight kg',
                icon: Icons.monitor_weight_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'SERİ',
                value: '$streak gün',
                icon: Icons.local_fire_department,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'BOY',
                value: height == null ? '—' : '$height cm',
                icon: Icons.height,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'TAMAMLANAN',
                value: '$completed / 30',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SettingsHeader(title: 'AYARLAR'),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.workspace_premium,
          title: 'FormAI Premium',
          subtitle: 'Aboneliğini yönet',
          onTap: () => context.push(AppRoutes.paywall),
        ),
        _SettingsTile(
          icon: Icons.volume_up,
          title: 'Sesli Koç Testi',
          subtitle: 'TTS motorunu hızlıca dene',
          onTap: () => _runTtsTest(context),
        ),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Bildirimler',
          subtitle: 'Yakında',
          onTap: () => _toast(context, 'Yakında'),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          title: 'Gizlilik',
          subtitle: 'Veri ve izinler',
          onTap: () => _toast(context, 'Yakında'),
        ),
        _SettingsTile(
          icon: Icons.logout,
          title: 'Çıkış Yap',
          subtitle: age == null ? null : 'Yaş: $age',
          onTap: () => _signOut(context),
        ),
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

  Future<void> _runTtsTest(BuildContext context) async {
    final audio = AudioFeedback();
    await audio.init();
    await audio.testAudio();
    if (!context.mounted) return;
    _toast(context, '🔊 TTS test tetiklendi — logları kontrol et');
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (context.mounted) _toast(context, 'Çıkış başarısız');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2A1B5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email, required this.isGuest});
  final String? email;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final label = isGuest ? 'Misafir Kullanıcı' : (email ?? 'Hoşgeldin');
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_neon, _neonAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _neon.withValues(alpha: 0.5),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: _neon.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _neon, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _neon.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: _neon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
