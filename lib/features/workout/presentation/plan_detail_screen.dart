import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/placeholder_images.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/error_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../monetization/models/locked_feature_type.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../monetization/services/premium_gate_service.dart';
import '../../monetization/widgets/locked_overlay.dart';
import '../models/exercise_model.dart';
import '../models/workout_day_model.dart';
import '../models/workout_plan_model.dart';
import '../providers/workout_provider.dart';
import '../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _success = Color(0xFF39FF14);

// Phase 48 · centralised in `app_constants.dart`.
const int _programLength = AppConstants.programLength;

/// Phase 35: the hero at the top of the program view now reflects the
/// muscle focus of the next incomplete day — title + image both. The
/// photo URLs mirror the neon-lit Unsplash shots used by the Bölgeler
/// strip so the two surfaces feel like the same product.
class _HeroCopy {
  const _HeroCopy({required this.title, required this.imageUrl});

  /// A lookup, not text — every hero below is a `const`.
  final String Function(AppLocalizations) title;
  final String imageUrl;
}

String _heroDefaultTitle(AppLocalizations l) => l.planHeroDefault;
String _heroCoreTitle(AppLocalizations l) => l.planHeroCore;
String _heroUpperTitle(AppLocalizations l) => l.planHeroUpper;
String _heroLowerTitle(AppLocalizations l) => l.planHeroLower;
String _heroFullBodyTitle(AppLocalizations l) => l.planHeroFullBody;

const _HeroCopy _heroCopyDefault = _HeroCopy(
  title: _heroDefaultTitle,
  imageUrl: defaultMuscularPhotoUrl,
);

const _HeroCopy _heroCopyRest = _HeroCopy(
  title: _restDayTitle,
  imageUrl: defaultLeanPhotoUrl,
);

String _restDayTitle(AppLocalizations l) => l.planRestDay;

/// Picks the hero strings for the active day by tallying its exercises'
/// `targetMuscle` and handing back the dominant region's copy. Mirrors
/// `_challengeTitleFor` on the antrenman tab so both surfaces stay in
/// lockstep; diverging would mean a user's dashboard says "Üst Vücut
/// Gücü" while the program detail still reads "Karın Kasları".
_HeroCopy _heroCopyFor(WorkoutDay? day) {
  if (day == null) return _heroCopyDefault;
  if (day.isRestDay) return _heroCopyRest;

  final counts = <String, int>{};
  for (final exercise in day.exercises) {
    counts[exercise.targetMuscle] = (counts[exercise.targetMuscle] ?? 0) + 1;
  }
  if (counts.isEmpty) return _heroCopyDefault;

  final dominant =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  switch (dominant) {
    case 'core':
      return const _HeroCopy(
        title: _heroCoreTitle,
        imageUrl: defaultLeanPhotoUrl,
      );
    case 'upper_body':
      return const _HeroCopy(
        title: _heroUpperTitle,
        imageUrl: defaultMuscularPhotoUrl,
      );
    case 'lower_body':
      return const _HeroCopy(
        title: _heroLowerTitle,
        imageUrl:
            'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=800&q=80',
      );
    case 'cardio':
    case 'full_body':
      return const _HeroCopy(
        title: _heroFullBodyTitle,
        imageUrl:
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80',
      );
    default:
      return _heroCopyDefault;
  }
}

/// Display strings for the onboarding `GoalPhysique` enum values.
/// Mirrors the map in `profile_tab.dart`; duplicated rather than shared
/// because the profile-tab copy is private and this is the second UI
/// surface that needs to render the same labels.
const Map<String, String Function(AppLocalizations)> _goalLabels = {
  'tone': _goalTone,
  'bulk': _goalBulk,
  'sixpack': _goalSixpack,
};

String _goalTone(AppLocalizations l) => l.goalToneLabel;
String _goalBulk(AppLocalizations l) => l.goalBulkLabel;
String _goalSixpack(AppLocalizations l) => l.goalSixpackLabel;

/// Freemium split — the first N days of the 30-day program are free
/// for everyone, so a non-paying user can experience the coaching loop
/// end to end before hitting the paywall. Bumping this also updates the
/// lock visuals and the paywall redirect in `_onDayTap`. Phase 48 ·
/// the literal lives in `AppConstants.freeDayLimit`.
const int _freeDayLimit = AppConstants.freeDayLimit;

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
    return CachedImage(
      url: src,
      fit: BoxFit.cover,
      memCacheHeight: 600,
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
    // SliverAppBar doesn't decode a ~200 KB asset during the push
    // transition. Plan view warms plan.image; program view best-effort
    // warms the default — the active-day-specific URL isn't known
    // until `workoutSessionProvider` resolves inside `build`.
    final heroSrc = widget.plan?.image ?? defaultMuscularPhotoUrl;
    _precache(heroSrc);
  }

  void _precache(String src) {
    if (src.startsWith('http')) {
      // Phase 51 · warm `flutter_cache_manager` (the disk cache backing
      // `CachedNetworkImage`) instead of the framework's in-memory
      // `ImageCache`. The PIP card later renders through `CachedImage`,
      // which only consults the disk cache — precaching via
      // `NetworkImage` would have downloaded the file a second time.
      unawaited(_precacheRemote(src));
    } else {
      precacheImage(AssetImage(src), context).catchError((_) {
        // Best-effort: failures are fine — the widget's own errorBuilder
        // will still swap in a fallback at render time.
        return;
      });
    }
  }

  Future<void> _precacheRemote(String url) async {
    try {
      await DefaultCacheManager().downloadFile(url);
    } catch (e) {
      // Best-effort. If the prefetch fails, CachedNetworkImage will
      // attempt the download itself when the image actually renders.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    if (p != null) {
      return _PlanView(plan: p);
    }
    final sessionAsync = ref.watch(workoutSessionProvider);
    // Phase 53C · drop the hardcoded `Colors.black` so the scaffold
    // honours the active theme. Hero header retains its purple
    // gradient because that's brand chrome and reads correctly on
    // both palettes.
    return Scaffold(
      body: sessionAsync.when(
        // Phase 49 · skeleton list mirrors the eventual exercise list
        // shape so the user sees a coherent layout instead of a spinner
        // floating on a black canvas.
        loading: () => const ExerciseListSkeleton(),
        error: (err, st) {
          AppLogger.error(
            'plan detail workoutSession error',
            err,
            stackTrace: st,
            category: 'workout',
          );
          return ErrorCard(
            message: AppLocalizations.of(context).planLoadProblem,
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
    final activeDay = _firstIncomplete(realDays);
    final activeDayNumber = activeDay?.dayNumber ?? realDays.length + 1;
    final completed = realDays.where((d) => d.isCompleted).length;
    final remaining = (_programLength - completed).clamp(0, _programLength);
    final isPro = ref.watch(isProProvider);
    final goalKey = ref
        .watch(appPreferencesProvider)
        .userMetrics?['targetPhysique'] as String?;
    final goalLabel = goalKey == null
        ? null
        : _goalLabels[goalKey]?.call(AppLocalizations.of(context));
    final heroCopy = _heroCopyFor(activeDay);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF1A0B3D),
          elevation: 0,
          leading: const _BackButton(),
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(copy: heroCopy),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyRemainingHeader(remaining: remaining),
        ),
        SliverToBoxAdapter(
          child: _PersonalizedSubtitle(goalLabel: goalLabel),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverList.builder(
            itemCount: _programLength,
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final realDay = _findDay(realDays, dayNumber);
              final isActive = dayNumber == activeDayNumber;
              // The generator is the source of truth for rest days; fall
              // back to false for the defensive "no realDay" path — the
              // UI would rather show a workout tile than a resting one
              // we can't confirm.
              final isRest = realDay?.isRestDay ?? false;
              final isLocked = !isPro && dayNumber > _freeDayLimit;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayTile(
                  dayNumber: dayNumber,
                  realDay: realDay,
                  isActive: isActive && !isRest,
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
    // plan detail screen. Phase 135 routes through PremiumGateService so
    // the cinematic futureDay conversion scene fires before the paywall.
    if (isLocked) {
      await ref.read(premiumGateProvider).handleLockedTap(
            context,
            LockedFeatureType.futureDay,
          );
      return;
    }
    if (realDay == null || realDay.exercises.isEmpty) return;
    // P1-5 · workouts are NOT blocked offline anymore. The pose/form
    // engine is fully on-device; only the demo videos stream from
    // Supabase Storage, and their PIP slots already degrade to a
    // graceful "Video yüklenemedi" tile. A heads-up snackbar sets the
    // expectation and the session proceeds — killing the app's
    // differentiator in gyms/planes for the sake of a demo clip was
    // the wrong trade.
    await _warnIfOffline(context, ref);
    if (!context.mounted) return;
    await ref.read(workoutSessionProvider.notifier).startDay(dayNumber);
    if (!context.mounted) return;
    context.push(AppRoutes.workout);
  }

  /// P1-5 · shared offline heads-up for both workout entry points
  /// (`_onDayTap` for the program-day tiles, `_PlanStartCta` for
  /// regional / equipment plans). Informs, never blocks: rep counting
  /// and voice coaching run on-device without a connection.
  Future<void> _warnIfOffline(BuildContext context, WidgetRef ref) async {
    final online = await ref.read(connectivityServiceProvider).isOnline();
    if (online || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).planOfflineNote,
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  WorkoutDay? _findDay(List<WorkoutDay> days, int dayNumber) {
    for (final d in days) {
      if (d.dayNumber == dayNumber) return d;
    }
    return null;
  }

  /// Skips rest days on purpose: the completion flow never marks them
  /// done, so without the filter the "active" highlight would stick on
  /// day 4 (the first rest day) once days 1-3 are complete.
  WorkoutDay? _firstIncomplete(List<WorkoutDay> days) {
    for (final d in days) {
      if (d.isRestDay) continue;
      if (!d.isCompleted) return d;
    }
    return null;
  }
}

/// Personalized banner stating the plan is tailored to the user. Rendered
/// directly under the sticky "N gün kaldı" header, so the affirmation is
/// visible the first time the user lands on the program view without
/// competing with the hero image.
class _PersonalizedSubtitle extends StatelessWidget {
  const _PersonalizedSubtitle({required this.goalLabel});
  final String? goalLabel;

  @override
  Widget build(BuildContext context) {
    // Flows cleanly whether or not a goal label exists — the old
    // "Senin hedefine (sana özel) ve seviyene özel…" doubled "özel" and
    // read awkwardly when the goal was unset.
    final text = goalLabel != null
        ? AppLocalizations.of(context).planBuiltForGoal(goalLabel!)
        : AppLocalizations.of(context).planTailoredNote;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _neon.withValues(alpha: 0.08),
          border: Border.all(color: _neon.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: _neon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  const _HeroHeader({required this.copy});
  final _HeroCopy copy;

  @override
  Widget build(BuildContext context) {
    // Phase 87 · hero rebuilt as a full-bleed image to match the
    // ChallengeHeroCard treatment on the dashboard. The previous
    // `Positioned(right: -10, width: 220)` panel was deliberate but
    // visually inconsistent: the same asset went from full-bleed on the
    // dashboard hero card to a 220-px right strip on the detail screen.
    // Full-bleed + a stronger bottom-weighted dark gradient keeps the
    // title and chip readable while letting the photo carry the visual.
    return DecoratedBox(
      // Fallback gradient — only visible if `_resolveImage` errors out
      // (network failure on the Unsplash URL). Same brand purple→blue
      // the previous design used as the primary background.
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
          Positioned.fill(child: _resolveImage(copy.imageUrl)),
          // Bottom-weighted dark gradient mirroring ChallengeHeroCard so
          // the headline + chip on top of the image stay readable across
          // any photo lighting. 15% at top → 90% at bottom.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                  stops: const [0.25, 0.6, 1.0],
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
                  children: [
                    Icon(Icons.bolt, color: Colors.white, size: 18),
                    Icon(Icons.bolt, color: Colors.white, size: 18),
                    Icon(Icons.bolt, color: Colors.white70, size: 18),
                    SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context).difficultyIntermediateLong,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  copy.title(AppLocalizations.of(context)),
                  style: const TextStyle(
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
      alignment: AlignmentDirectional.centerStart,
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
          Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              AppLocalizations.of(context).planDaysLeftSuffix,
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
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 14, 16),
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
                  AppLocalizations.of(context).dayOrdinalLower(dayNumber),
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
                      AppLocalizations.of(context).percentCompleted(percent),
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
      subtitle = AppLocalizations.of(context).planRequestedAbbrev;
    } else if (lockedWorkoutDay) {
      subtitle = AppLocalizations.of(context).planUnlockWithPremium;
    } else {
      subtitle = realDay == null
          ? AppLocalizations.of(context).planComingSoon
          : AppLocalizations.of(context).exerciseCountTitle(exerciseCount);
    }

    // Phase 53D · the per-day card was painting card surface + day-number
    // text + subtitle + trailing icon all from hardcoded white tones,
    // leaving the entire 30-day list invisible on a light scaffold.
    // Pull each through the active ColorScheme so the cards read in
    // both modes; brand-coloured states (locked → neon, completed →
    // success green, rest → coffee amber) keep their identity.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    final dimmed = isRest || realDay == null || lockedWorkoutDay;
    final borderColor = lockedWorkoutDay
        ? _neon.withValues(alpha: 0.35)
        : (completed
            ? _success.withValues(alpha: 0.45)
            : (isDark ? Colors.white12 : scheme.outlineVariant));
    final fillColor = lockedWorkoutDay
        ? _neon.withValues(alpha: 0.05)
        : (isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface);

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
                      AppLocalizations.of(context).dayOrdinalLower(dayNumber),
                      style: TextStyle(
                        color: dimmed
                            ? scheme.onSurface.withValues(alpha: 0.55)
                            : scheme.onSurface,
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
                            : scheme.onSurface.withValues(alpha: 0.55),
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
                Icon(
                  Icons.local_cafe,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  size: 22,
                )
              else if (lockedWorkoutDay)
                Icon(Icons.lock, color: _neon.withValues(alpha: 0.9), size: 22)
              else if (completed)
                const Icon(Icons.check_circle, color: _success, size: 22)
              else if (tappable)
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.40),
                  size: 22,
                )
              else
                Icon(
                  Icons.lock_outline,
                  color: scheme.onSurface.withValues(alpha: 0.25),
                  size: 18,
                ),
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
    final gate = ref.read(premiumGateProvider);
    // Phase 53C · same scaffold migration as the legacy plan branch
    // above. The hero header keeps its dark purple gradient because
    // it's an intentional brand element regardless of theme.
    return Scaffold(
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
              text: '${AppLocalizations.of(context).exerciseCountLower(
                exercises.length,
              )} · ${AppLocalizations.of(context).planMinutesLevel(
                plan.durationMinutes,
                plan.level,
              )}',
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
                // Phase 98 · plans that ship an advanced tier (the 7
                // equipment programs after the consolidation) render a
                // half-width Standard / half-width Premium pair. Plans
                // without a premium tier (every regional bodyweight
                // card) keep the legacy single-CTA layout untouched.
                child: plan.hasPremiumTier
                    ? _PlanStartCtaPair(plan: plan, locked: locked)
                    : _PlanStartCta(plan: plan, locked: locked),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                plan.hasPremiumTier ? 12 : 24,
              ),
              sliver: SliverList.builder(
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final tile = _ExerciseTile(exercise: exercises[index]);
                  if (!locked) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: tile,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => gate.handleLockedTap(
                        context,
                        LockedFeatureType.equipmentExercise,
                      ),
                      child: Stack(
                        children: [
                          Opacity(opacity: 0.62, child: tile),
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: PremiumProPill(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (plan.hasPremiumTier)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: _PremiumExercisesSection(
                    plan: plan,
                    locked: locked,
                  ),
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
    // Phase 87 · matches the _HeroHeader rewrite — full-bleed image
    // instead of the 220-px right strip, with a strong bottom-weighted
    // gradient for title legibility. Plans without an image fall back
    // to the brand purple→blue gradient (the DecoratedBox below).
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
            Positioned.fill(child: _resolveImage(plan.image!)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                  stops: const [0.25, 0.6, 1.0],
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
      alignment: AlignmentDirectional.centerStart,
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
            onTap: () async {
              if (locked) {
                context.push(AppRoutes.paywall);
                return;
              }
              // Phase 89 · same offline gate as `_onDayTap`. The
              // helper lives on `_PlanDetailScreenState`, so duplicate
              // the inline check here rather than threading a callback
              // — the SnackBar is the only side effect.
              final online =
                  await ref.read(connectivityServiceProvider).isOnline();
              if (!online) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).planNeedsConnection,
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }
              if (!context.mounted) return;
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
                    locked
                        ? AppLocalizations.of(context).planUnlockWithProUpper
                        : AppLocalizations.of(context).planStartUpper,
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
        ? AppLocalizations.of(context)
            .setsBySeconds(exercise.sets, exercise.targetDurationInSeconds ?? 0)
        : AppLocalizations.of(context)
            .setsByReps(exercise.sets, exercise.targetReps ?? 0);

    // Phase 53C · the entire exercise tile (surface, border, name,
    // subtitle, chevron) was hardcoded for dark mode. All five of
    // those tones now route through the active ColorScheme so the
    // 30-day plan list reads in light mode the same way it does in
    // dark.
    final scheme = context.colors;
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
        border: Border.all(
          color: isDark ? Colors.white12 : scheme.outlineVariant,
        ),
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
              // Icon sits on the neon-tinted square, so white-on-neon
              // works in both modes — keep it as the brand emphasis.
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
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurface.withValues(alpha: 0.38),
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// Phase 47B · empty-plan upsell.
///
/// Rendered in place of the exercise list when a regional/ad-hoc plan
/// ships with zero exercises. Instead of the Phase 40 "bu plan şu an
/// boş" neutral note, this card turns the dead-end into a Premium
/// funnel with a neon paywall CTA. Copy is identical to the Phase
/// 47B spec.
class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _neon.withValues(alpha: 0.18),
            _neon.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.28),
            blurRadius: 22,
            spreadRadius: 0.4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neon.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).planAreaComingSoon,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _neon.withValues(alpha: 0.55),
                    blurRadius: 18,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A3DFF), Color(0xFF4DA6FF)],
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(AppRoutes.paywall),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).planUnlockWithProUpper,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ============================================================================
// Phase 98 · Premium tier UI
// ============================================================================
// Renders a half-width Standard ("Lite Seviye") + half-width Premium
// ("Premium Seviye") launcher pair when the resolved plan ships a non-empty
// `premiumExercises` list. The Standard button preserves the original
// purple→blue brand gradient and routes to `plan.exercises`; the Premium
// button uses a gold gradient + subtle neon glow and routes to
// `plan.premiumExercises`. Both respect the existing `locked` flag (non-PRO
// users → paywall) and the Phase 89 offline gate. Plans without a premium
// tier (regional bodyweight cards) still render the legacy single-CTA
// `_PlanStartCta` above and never reach these widgets.

const Color _premiumGold = Color(0xFFFFC75A);
const Color _premiumGoldDeep = Color(0xFFE9A22A);

enum _PlanTier { standard, premium }

class _PlanStartCtaPair extends ConsumerWidget {
  const _PlanStartCtaPair({required this.plan, required this.locked});

  final WorkoutPlan plan;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 98.1 · IntrinsicHeight is load-bearing here.
    //
    // The parent slot is a `SliverToBoxAdapter`, which gives its child an
    // unbounded vertical constraint. A bare `Row` with
    // `CrossAxisAlignment.stretch` propagates that infinite height down to
    // each `Expanded` child, which asserts at layout with:
    //   "BoxConstraints forces an infinite height.
    //    The offending constraints were: BoxConstraints(0.0<=w<=Infinity, h=Infinity)"
    // The assertion blows up the entire CustomScrollView's layout pass, so
    // the body renders as the bare scaffold background — a "black screen".
    //
    // `IntrinsicHeight` measures the tallest child's intrinsic height, sets
    // the Row's height to that, and only THEN does the cross-axis stretch
    // see a finite constraint to propagate. Equal-height buttons survive
    // and the Row lays out cleanly.
    //
    // Removing `CrossAxisAlignment.stretch` would also make the assertion
    // go away, but the buttons would be different heights (the standard
    // button has no crown icon when unlocked; the premium one always
    // does), which is the visual the wrap was solving in the first place.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TierLaunchButton(
              tier: _PlanTier.standard,
              plan: plan,
              locked: locked,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TierLaunchButton(
              tier: _PlanTier.premium,
              plan: plan,
              locked: locked,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single half-width launcher. The two visual variants (standard vs
/// premium) share the offline check + paywall gate + initializeWorkout
/// hand-off so the only thing that diverges is the gradient, glow tint,
/// optional crown icon, and which exercise list is launched.
class _TierLaunchButton extends ConsumerWidget {
  const _TierLaunchButton({
    required this.tier,
    required this.plan,
    required this.locked,
  });

  final _PlanTier tier;
  final WorkoutPlan plan;
  final bool locked;

  bool get _isPremium => tier == _PlanTier.premium;

  List<Color> get _gradient => _isPremium
      ? const [_premiumGold, _premiumGoldDeep]
      : const [Color(0xFF6A3DFF), Color(0xFF4DA6FF)];

  String get _subtitle => _isPremium ? 'Premium Seviye' : 'Lite Seviye';

  IconData? get _icon => locked
      ? Icons.lock
      : (_isPremium ? Icons.workspace_premium_rounded : null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = _isPremium ? plan.premiumExercises : plan.exercises;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: _isPremium ? 0.55 : 0.45),
            blurRadius: _isPremium ? 28 : 24,
            spreadRadius: _isPremium ? 1.2 : 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: _isPremium
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1,
                  )
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _launch(context, ref, exercises),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_icon != null) ...[
                    Icon(_icon, color: Colors.white, size: 18),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    AppLocalizations.of(context).planStartUpper,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked ? 'PRO Gerekli' : _subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
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

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    List<Exercise> exercises,
  ) async {
    if (locked) {
      context.push(AppRoutes.paywall);
      return;
    }
    // P1-5 · informational offline heads-up (was a hard block). The CV
    // engine runs on-device; only demo videos degrade, and their PIP
    // tiles already handle that gracefully.
    final online = await ref.read(connectivityServiceProvider).isOnline();
    if (!online) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).planOfflineNote,
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    if (!context.mounted) return;
    ref.read(workoutSessionProvider.notifier).initializeWorkout(exercises);
    context.push(AppRoutes.workout);
  }
}

/// Premium exercises section rendered below the standard exercise list when
/// `plan.hasPremiumTier` is true. Carries the gold-titled "İleri Seviye X
/// Antrenmanları" header and the premium tile list. Tiles reuse the
/// standard `_ExerciseTile` shape so spacing/tonality stays consistent;
/// the section's gold + neon glow framing is what signals "this is the
/// upgrade" without forking a whole second tile widget.
///
/// Phase 134 · locked users now see the stronger [LockedOverlay] treatment
/// (blur + neon wash + lock badge) per-exercise instead of the
/// Opacity(0.35) dim that pre-dated the cinematic monetization phase.
/// Tap routes through [PremiumGateService] so the conversion-moment
/// scene wiring (Phase 135) lights up automatically once C4 ships.
class _PremiumExercisesSection extends ConsumerWidget {
  const _PremiumExercisesSection({required this.plan, required this.locked});

  final WorkoutPlan plan;
  final bool locked;

  String _categoryLabel(AppLocalizations l10n) {
    switch (plan.category) {
      case ExerciseCategory.core:
        return l10n.muscleCore;
      case ExerciseCategory.chest:
        return l10n.muscleChest;
      case ExerciseCategory.back:
        return l10n.muscleBack;
      case ExerciseCategory.shoulders:
        return l10n.muscleShoulders;
      case ExerciseCategory.arms:
        return l10n.muscleArms;
      case ExerciseCategory.legs:
        return l10n.muscleLegs;
      case ExerciseCategory.fullBody:
        return l10n.muscleFullBody;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.read(premiumGateProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _neon.withValues(alpha: 0.10),
            _premiumGold.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.30),
            blurRadius: 22,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_premiumGold, _premiumGoldDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _premiumGold.withValues(alpha: 0.55),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).advancedCategoryWorkouts(
                    _categoryLabel(AppLocalizations.of(context)),
                  ),
                  style: const TextStyle(
                    color: _premiumGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        blurRadius: 12,
                        color: Color(0x66FFC75A),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...plan.premiumExercises.map((exercise) {
            final tile = _ExerciseTile(exercise: exercise);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LockedOverlay(
                locked: locked,
                hint: AppLocalizations.of(context).planUnlockWithPremium,
                onTap: () => gate.handleLockedTap(
                  context,
                  LockedFeatureType.equipmentExercise,
                ),
                child: tile,
              ),
            );
          }),
        ],
      ),
    );
  }
}
