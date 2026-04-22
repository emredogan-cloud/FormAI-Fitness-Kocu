import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/placeholder_images.dart';
import '../../../core/widgets/error_card.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';
import '../providers/workout_provider.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _success = Color(0xFF39FF14);

const int _programLength = 30;

/// Freemium split — the first three days of the 30-day program are free
/// for everyone, so a non-paying user can experience the coaching loop end
/// to end before hitting the paywall. Bumping this also updates the lock
/// visuals and the paywall redirect in `_onDayTap`.
const int _freeDayLimit = 3;

/// Renders [src] as either a network image (when it starts with `http`) or
/// a bundled asset. Local copy of the dashboard helper so plan-detail can
/// honour the same mixed-source pattern (Unsplash placeholders + local
/// docs/ reference shots) without leaking dashboard internals.
Widget _resolveImage(String src) {
  final fallback = Container(
    color: Colors.white10,
    alignment: Alignment.center,
    child: const Icon(Icons.fitness_center, color: Colors.white54),
  );
  if (src.startsWith('http')) {
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
  return Image.asset(
    src,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => fallback,
  );
}

/// Two faces:
///   • [plan] non-null  → renders that plan's hero + exercise list.
///   • [plan] null      → renders the legacy 30-day program view (the
///                        dashboard's "Günlük Meydan Okuma" hero card
///                        opens this mode).
/// The router decides which mode based on whether `state.extra` carries
/// a [WorkoutPlan].
class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, this.plan});

  final WorkoutPlan? plan;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    // Warm the hero image for this screen BEFORE it appears so the
    // SliverAppBar doesn't decode a ~200 KB webp during the push
    // transition. Works for both faces: plan.image when present, or
    // the default muscular URL when we fall back to the program view.
    final heroSrc = widget.plan?.image ?? defaultMuscularPhotoUrl;
    _precache(heroSrc);
  }

  void _precache(String src) {
    final ImageProvider provider =
        src.startsWith('http') ? NetworkImage(src) : AssetImage(src);
    precacheImage(provider, context).catchError((_) {
      // Best-effort: failures are fine — the widget's own errorBuilder
      // will still swap in a fallback at render time.
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    if (p != null) {
      return _PlanView(plan: p);
    }
    final sessionAsync = ref.watch(workoutSessionProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: sessionAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _neon)),
        error: (err, st) {
          debugPrint('plan detail workoutSession error: $err\n$st');
          return ErrorCard(
            message: 'Plan yüklenirken bir sorun oluştu.',
            onRetry: () => ref.invalidate(workoutSessionProvider),
          );
        },
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
    final isPro = ref.watch(isProProvider);

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
              final isLocked = !isPro && dayNumber > _freeDayLimit;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayTile(
                  dayNumber: dayNumber,
                  realDay: realDay,
                  isActive: isActive,
                  isRest: isRest,
                  isLocked: isLocked,
                  onTap: () =>
                      _onDayTap(context, ref, dayNumber, realDay, isLocked),
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
    bool isLocked,
  ) async {
    // Premium gate short-circuits BEFORE we touch the session — don't want
    // to "start" a day the user can't actually run, or the 30-day ledger
    // would record a bogus in-progress day the next time they open the
    // plan detail screen.
    if (isLocked) {
      context.push(AppRoutes.paywall);
      return;
    }
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
                defaultMuscularPhotoUrl,
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
    required this.isLocked,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? realDay;
  final bool isActive;
  final bool isRest;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Lock takes precedence over the active-day gradient: a locked day
    // isn't actually runnable, so it shouldn't look like "continue here".
    if (isActive && !isLocked) {
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
      isLocked: isLocked,
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
    required this.isLocked,
    required this.onTap,
  });

  final int dayNumber;
  final WorkoutDay? realDay;
  final bool isRest;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = realDay?.isCompleted ?? false;
    final exerciseCount = realDay?.exercises.length ?? 0;

    // Rest days ignore the lock (they don't gate value behind payment),
    // so locked-but-rest keeps the coffee styling. For workout days, the
    // lock makes the tile tappable — tap routes to /paywall in the
    // parent's _onDayTap handler.
    final lockedWorkoutDay = isLocked && !isRest;
    final tappable = !isRest &&
        (lockedWorkoutDay || (realDay?.exercises.isNotEmpty ?? false));

    final String subtitle;
    if (isRest) {
      subtitle = 'İst.';
    } else if (lockedWorkoutDay) {
      subtitle = 'Premium ile aç';
    } else {
      subtitle = realDay == null ? 'Yakında' : '$exerciseCount Egzersiz';
    }

    final dimmed = isRest || realDay == null || lockedWorkoutDay;
    final borderColor = lockedWorkoutDay
        ? _neon.withValues(alpha: 0.35)
        : (completed ? _success.withValues(alpha: 0.45) : Colors.white12);
    final fillColor = lockedWorkoutDay
        ? _neon.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.04);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tappable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: fillColor,
            border: Border.all(color: borderColor, width: 1),
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
                        color: dimmed ? Colors.white60 : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: lockedWorkoutDay
                            ? _neon.withValues(alpha: 0.85)
                            : Colors.white54,
                        fontSize: 13,
                        fontWeight: lockedWorkoutDay
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRest)
                const Icon(Icons.local_cafe, color: Colors.white54, size: 22)
              else if (lockedWorkoutDay)
                Icon(Icons.lock, color: _neon.withValues(alpha: 0.9), size: 22)
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

// ============================================================================
// Plan-specific view (used when PlanDetailScreen is opened with a non-null
// WorkoutPlan in state.extra). Mirrors the program view's hero + sticky
// summary + list shape so the two share the same scroll feel.
// ============================================================================

class _PlanView extends ConsumerWidget {
  const _PlanView({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = plan.exercises;
    // Regional / ad-hoc plans are a premium feature — non-PRO users see
    // the card header + exercise list but every meaningful interaction
    // routes to /paywall. The list below the CTA is dimmed so the lock
    // framing carries visually even when a user scrolls past the button.
    final isPro = ref.watch(isProProvider);
    final locked = !isPro;
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1A0B3D),
            elevation: 0,
            leading: const _BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: _PlanHeroHeader(plan: plan),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTextHeader(
              text: '${exercises.length} egzersiz · '
                  '${plan.durationMinutes} Dk · ${plan.level}',
            ),
          ),
          if (exercises.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              sliver: SliverToBoxAdapter(
                child: _ComingSoonNote(plan: plan),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _PlanStartCta(plan: plan, locked: locked),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList.builder(
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final tile = _ExerciseTile(exercise: exercises[index]);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: locked ? Opacity(opacity: 0.35, child: tile) : tile,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanHeroHeader extends StatelessWidget {
  const _PlanHeroHeader({required this.plan});
  final WorkoutPlan plan;

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
          if (plan.image != null)
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
                child: _resolveImage(plan.image!),
              ),
            ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    plan.level.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  plan.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: 0.2,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black45)],
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

class _StickyTextHeader extends SliverPersistentHeaderDelegate {
  _StickyTextHeader({required this.text});
  final String text;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _StickyTextHeader || oldDelegate.text != text;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanStartCta extends ConsumerWidget {
  const _PlanStartCta({required this.plan, required this.locked});
  final WorkoutPlan plan;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (locked) {
                context.push(AppRoutes.paywall);
                return;
              }
              // Seed the session with this plan's exercises (ad-hoc
              // day, won't persist to the 30-day ledger) then hand off to
              // the camera screen so the user drops straight into the
              // first rep.
              ref
                  .read(workoutSessionProvider.notifier)
                  .initializeWorkout(plan.exercises);
              context.push(AppRoutes.workout);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locked) ...[
                    const Icon(Icons.lock, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    locked ? 'PRO İLE KİLİDİ AÇ' : 'PLANI BAŞLAT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final subtitle = exercise.isTimeBased
        ? '${exercise.sets} × ${exercise.targetDurationInSeconds ?? 0} sn'
        : '${exercise.sets} set · ${exercise.targetReps ?? 0} tekrar';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _neon.withValues(alpha: 0.18),
            ),
            child: Icon(
              exercise.isTimeBased
                  ? Icons.timer_outlined
                  : Icons.repeat_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top, color: _neon, size: 28),
          const SizedBox(height: 10),
          Text(
            '${plan.title} — yakında',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bu bölge için bespoke egzersiz seti yolda. Şimdilik diğer '
            'planları deneyebilirsin.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
