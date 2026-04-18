import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../models/workout_day_model.dart';
import '../providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _success = Color(0xFF39FF14);

const String _heroImageUrl =
    'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&w=600&q=80';

const int _programLength = 30;

/// Full 30-day plan view, opened from the dashboard's "Günlük Meydan Okuma"
/// hero card. Mirrors the reference design (hero header → sticky "X gün
/// kaldı" → list of day tiles with the current day expanded into a CTA
/// card and weekly rest days swapped for a coffee-cup tile) but tinted
/// into our dark/neon-purple FormAI palette.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(workoutSessionProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: sessionAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _neon)),
        error: (err, _) => Center(
          child: Text(
            'Plan yüklenemedi: $err',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (session) => _buildContent(context, ref, session),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionState session,
  ) {
    final realDays = session.days;
    final activeDayNumber =
        _firstIncomplete(realDays)?.dayNumber ?? realDays.length + 1;
    final completed = realDays.where((d) => d.isCompleted).length;
    final remaining = (_programLength - completed).clamp(0, _programLength);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF1A0B3D),
          elevation: 0,
          leading: const _BackButton(),
          flexibleSpace: const FlexibleSpaceBar(
            background: _HeroHeader(),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyRemainingHeader(remaining: remaining),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverList.builder(
            itemCount: _programLength,
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final realDay = _findDay(realDays, dayNumber);
              final isActive = dayNumber == activeDayNumber;
              final isRest = _isRestDay(dayNumber);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayTile(
                  dayNumber: dayNumber,
                  realDay: realDay,
                  isActive: isActive,
                  isRest: isRest,
                  onTap: () => _onDayTap(context, ref, dayNumber, realDay),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Mark every 7th day as rest (4, 11, 18, 25). Visual-only heuristic until
  /// the data model carries an explicit rest-day flag.
  bool _isRestDay(int dayNumber) => dayNumber % 7 == 4;

  Future<void> _onDayTap(
    BuildContext context,
    WidgetRef ref,
    int dayNumber,
    WorkoutDay? realDay,
  ) async {
    if (realDay == null || realDay.exercises.isEmpty) return;
    await ref.read(workoutSessionProvider.notifier).startDay(dayNumber);
    if (!context.mounted) return;
    context.push(AppRoutes.workout);
  }

  WorkoutDay? _findDay(List<WorkoutDay> days, int dayNumber) {
    for (final d in days) {
      if (d.dayNumber == dayNumber) return d;
    }
    return null;
  }

  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final d in days) {
      if (!d.isCompleted) return d;
    }
    return null;
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -10,
            top: 50,
            bottom: 0,
            width: 220,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                _neon.withValues(alpha: 0.55),
                BlendMode.softLight,
              ),
              child: Image.network(
                _heroImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Soft vignette so the bottom of the hero blends into the dark list.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bolt, color: Colors.white, size: 18),
                    Icon(Icons.bolt, color: Colors.white, size: 18),
                    Icon(Icons.bolt, color: Colors.white70, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Orta düzey',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Taş Gibi Sert\nKarın Kasları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(blurRadius: 18, color: Colors.black45),
                    ],
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

class _StickyRemainingHeader extends SliverPersistentHeaderDelegate {
  _StickyRemainingHeader({required this.remaining});
  final int remaining;

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _StickyRemainingHeader ||
        oldDelegate.remaining != remaining;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$remaining',
            style: const TextStyle(
              color: _neon,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: [Shadow(blurRadius: 20, color: _neon)],
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              'gün kaldı',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.dayNumber,
    required this.realDay,
    required this.isActive,
    required this.isRest,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? realDay;
  final bool isActive;
  final bool isRest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return _ActiveDayCard(
        dayNumber: dayNumber,
        realDay: realDay,
        onTap: onTap,
      );
    }
    return _StandardDayCard(
      dayNumber: dayNumber,
      realDay: realDay,
      isRest: isRest,
      onTap: onTap,
    );
  }
}

class _ActiveDayCard extends StatelessWidget {
  const _ActiveDayCard({
    required this.dayNumber,
    required this.realDay,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? realDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Stub progress until per-set tracking lands; matches the screenshot's
    // "14% Tamamlandı" hint without lying about state we don't track yet.
    final percent = realDay == null ? 0 : 14;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.5),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayNumber. gün',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent% Tamamlandı',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Text(
                  'DEVAM ET',
                  style: TextStyle(
                    color: _neon,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardDayCard extends StatelessWidget {
  const _StandardDayCard({
    required this.dayNumber,
    required this.realDay,
    required this.isRest,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? realDay;
  final bool isRest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = realDay?.isCompleted ?? false;
    final tappable = !isRest && (realDay?.exercises.isNotEmpty ?? false);
    final exerciseCount = realDay?.exercises.length ?? 0;

    final subtitle = isRest
        ? 'İst.'
        : (realDay == null ? 'Yakında' : '$exerciseCount Egzersiz');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tappable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color:
                  completed ? _success.withValues(alpha: 0.45) : Colors.white12,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayNumber. gün',
                      style: TextStyle(
                        color: isRest || realDay == null
                            ? Colors.white60
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRest)
                const Icon(Icons.local_cafe, color: Colors.white54, size: 22)
              else if (completed)
                const Icon(Icons.check_circle, color: _success, size: 22)
              else if (tappable)
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                  size: 22,
                )
              else
                const Icon(Icons.lock_outline, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
