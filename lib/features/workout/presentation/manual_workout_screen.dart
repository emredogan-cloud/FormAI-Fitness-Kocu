import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/workout_background_registry.dart';
import '../domain/workout_mode.dart';
import '../models/exercise_model.dart';
import '../providers/workout_provider.dart';
import 'widgets/session_complete_overlay.dart';
import '../../../l10n/app_localizations.dart';

/// Roadmap Phase 3 (C21) · the camera-free workout.
///
/// The camera requirement is an exclusion, not just a feature. Users who
/// decline the permission, train in a shared space, can't prop a phone
/// at two metres, or simply don't want to be filmed had no path through
/// a FormAI workout at all.
///
/// **This is a different UI over the identical session state machine**,
/// not a parallel implementation. It drives the same
/// `workoutSessionProvider` — `setCurrentReps` and
/// `completeCurrentExercise` — so rest timers, set progression, day
/// completion, session logs, XP, streaks and badges all behave exactly
/// as they do in camera mode. The only thing missing is form analysis,
/// and the UI says so plainly rather than pretending otherwise.
///
/// That equivalence is the point: a camera-free user is not on a
/// degraded track, they are on the same track with one instrument off.
///
/// ---
///
/// **Phase 6 polish · rebuilt to the reference designs.** The screen was
/// a centred column on a flat background with most of the display unused.
/// It is now a full-bleed exercise photograph carrying the set counter,
/// with the mode banner above it and the set track and action below —
/// the layout fills the display rather than floating in the middle of it.
///
/// Two structural notes:
///
/// * **The photograph comes from [WorkoutBackgroundRegistry]**, which
///   resolves an exercise's own background if one is bundled and
///   otherwise its category's. Every exercise therefore has real art
///   today, and adding `photos/workout_backgrounds/<PascalCase>.webp`
///   upgrades one with no code change.
/// * **Nothing here is fixed-height except the chrome.** The card takes
///   the remaining space and its contents scale down inside it, so a
///   320 px phone at a 1.3 text scale loses size rather than overflowing.
class ManualWorkoutScreen extends ConsumerStatefulWidget {
  const ManualWorkoutScreen({super.key});

  @override
  ConsumerState<ManualWorkoutScreen> createState() =>
      _ManualWorkoutScreenState();
}

class _ManualWorkoutScreenState extends ConsumerState<ManualWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.manualModeSessionStarted();
    // Cheap, idempotent, and the answer is needed the moment the first
    // exercise renders. Failing leaves the category art in place.
    WorkoutBackgroundRegistry.warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _completeSet() async {
    AppHaptics.primaryCta();
    await ref.read(workoutSessionProvider.notifier).completeCurrentExercise();
  }

  void _adjustReps(int delta) {
    final state = ref.read(workoutSessionProvider).value;
    if (state == null) return;
    final next = (state.currentReps + delta).clamp(0, 999);
    if (next == state.currentReps) return;
    AppHaptics.secondaryTap();
    ref.read(workoutSessionProvider.notifier).setCurrentReps(next);
  }

  void _skipRest() {
    AppHaptics.primaryCta();
    ref.read(workoutSessionProvider.notifier).skipRest();
  }

  /// Roadmap Phase 3 feature 6 · reopens the setup guide as a reference.
  /// Pushed, so the user lands back on their in-progress session.
  Future<void> _showSetupGuide() async {
    AnalyticsService.instance.tutorialReplayed();
    await context.push(AppRoutes.cameraTutorialReplay);
  }

  /// Offers the camera back. A user who picked manual once shouldn't
  /// have to reinstall to change their mind.
  Future<void> _switchToCamera() async {
    await ref
        .read(appPreferencesProvider)
        .setPreferredWorkoutMode(WorkoutMode.camera);
    AnalyticsService.instance.workoutModeSwitched(to: WorkoutMode.camera.token);
    if (!mounted) return;
    context.pushReplacement(AppRoutes.workout);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workoutSessionProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  title: l10n.workoutTitle,
                  onBack: () => context.pop(),
                  onSetupGuide: _showSetupGuide,
                  onCamera: _switchToCamera,
                ),
                Expanded(
                  child: async.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.neon),
                    ),
                    error: (_, __) => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.workoutLoadFailed,
                      body: l10n.workoutLoadFailedBody,
                      ctaLabel: l10n.commonTryAgain,
                      onCta: () => ref.invalidate(workoutSessionProvider),
                    ),
                    data: (state) {
                      final exercise = state.activeExercise;
                      if (exercise == null) {
                        return EmptyState(
                          icon: Icons.done_all_rounded,
                          title: l10n.workoutDayDone,
                          body: l10n.workoutDayDoneBody,
                        );
                      }
                      if (state.isResting) {
                        return _RestView(
                          seconds: state.restSecondsRemaining,
                          totalSeconds: (state.upcomingExercise ?? exercise)
                              .restDurationInSeconds,
                          currentSet: state.currentSet,
                          totalSets: exercise.sets,
                          onContinue: _skipRest,
                        );
                      }
                      return _ActiveView(
                        exercise: exercise,
                        currentSet: state.currentSet,
                        currentReps: state.currentReps,
                        onAdjust: _adjustReps,
                        onComplete: _completeSet,
                      );
                    },
                  ),
                ),
              ],
            ),
            // Same overlay + acknowledge contract as the camera screen,
            // so day completion celebrates identically in both modes.
            if (async.value?.isSessionComplete ?? false)
              SessionCompleteOverlay(
                day: async.value!.activeDay,
                onAcknowledge: () {
                  ref
                      .read(workoutSessionProvider.notifier)
                      .acknowledgeSessionComplete();
                  if (context.mounted) context.pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

const Color _kBackground = Color(0xFF0A0612);
const List<Color> _kBrandGradient = [AppColors.neon, AppColors.neonGreen];

/// Back, title, and the two ways out of camera-free mode — all as the
/// reference's rounded tiles rather than a stock [AppBar], which had a
/// larger vertical footprint than the design allows for.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onSetupGuide,
    required this.onCamera,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSetupGuide;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          _TileButton(
            icon: Icons.arrow_back_rounded,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            color: AppColors.neon,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Roadmap Phase 3 feature 6 · the setup guide stays reachable
          // from the camera-free surface too. Someone who chose manual
          // because the camera felt daunting is exactly who benefits
          // from being able to re-read the placement guidance without
          // committing to a camera session first.
          _TileButton(
            icon: Icons.center_focus_strong_outlined,
            label: l10n.workoutShowCameraSetup,
            color: AppColors.neon,
            onTap: onSetupGuide,
          ),
          const SizedBox(width: 8),
          _TileButton(
            icon: Icons.videocam_outlined,
            label: l10n.workoutOpenCamera,
            color: Colors.white,
            onTap: onCamera,
          ),
        ],
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: color, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active set
// ---------------------------------------------------------------------------

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.exercise,
    required this.currentSet,
    required this.currentReps,
    required this.onAdjust,
    required this.onComplete,
  });

  final Exercise exercise;
  final int currentSet;
  final int currentReps;
  final ValueChanged<int> onAdjust;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The card is a fixed share of the viewport rather than "whatever
        // the chrome leaves", and the column scrolls when the two together
        // do not fit.
        //
        // `Expanded` was the obvious shape and is wrong at the edges: it
        // can only shrink the card to zero, so once the banner, tip, set
        // track and button alone exceed the screen — a 320 px phone at a
        // 1.3 text scale, which is 41 px over — the column overflows
        // anyway, having first squeezed the rep counter into
        // illegibility. Sizing the card and scrolling gives up the one
        // thing that can be given up, which is seeing all of it at once.
        //
        // 0.56 is what makes the button land at the bottom of a normal
        // phone rather than floating above it.
        final cardHeight = math.max(190.0, constraints.maxHeight * 0.56);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const _ManualModeBanner(),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: cardHeight,
                    child: _ExerciseCard(
                      exercise: exercise,
                      currentSet: currentSet,
                      currentReps: currentReps,
                      onAdjust: onAdjust,
                    ),
                  ),
                  if (exercise.shortTip.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _TipCard(tip: exercise.shortTip),
                  ],
                  const SizedBox(height: 10),
                  _SetTrack(currentSet: currentSet, totalSets: exercise.sets),
                  const SizedBox(height: 12),
                  _GradientCta(
                    label: l10n.workoutCompleteSet,
                    onTap: onComplete,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// States plainly what this mode does and doesn't do. An app that
/// quietly drops its headline feature and says nothing is what erodes
/// trust; naming the trade-off preserves it.
class _ManualModeBanner extends StatelessWidget {
  const _ManualModeBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          colors: [
            AppColors.neon.withValues(alpha: 0.85),
            AppColors.neonGreen.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0716),
          borderRadius: BorderRadius.circular(15.6),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonGreen.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                color: AppColors.neonGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.workoutManualModeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.workoutManualModeBody,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 12.5,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.verified_user_outlined,
              color: AppColors.neonGreen.withValues(alpha: 0.85),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

/// The photograph, the set, the movement, and the counter that is the
/// whole point of camera-free mode.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.currentSet,
    required this.currentReps,
    required this.onAdjust,
  });

  final Exercise exercise;
  final int currentSet;
  final int currentReps;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF120A22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              WorkoutBackgroundRegistry.backgroundFor(exercise),
              fit: BoxFit.cover,
              // A background that fails to decode must leave a dark
              // panel, never an error box over a live workout.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            // Legibility, and it is doing real work: these photographs
            // are bright in the middle, which is exactly where the rep
            // count sits.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE60A0612),
                    Color(0x730A0612),
                    Color(0xF00A0612),
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  // Every band below is elastic. The rep cluster is 280 px
                  // wide at its design size, which does not fit a 320 px
                  // phone's card, and at a 1.3 text scale the whole column
                  // is taller than the card as well. Rather than pick
                  // breakpoints, each band takes a share of the height and
                  // scales down inside it — so the card is always exactly
                  // full and never overflows, on any phone at any scale.
                  _SetPill(
                    label: l10n.setProgressUpper(currentSet, exercise.sets),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              exercise.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1.14,
                              ),
                            ),
                            if (exercise.targetReps != null) ...[
                              const SizedBox(height: 8),
                              _TargetLine(reps: exercise.targetReps!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _RepCounter(reps: currentReps, onAdjust: onAdjust),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetPill extends StatelessWidget {
  const _SetPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.neon,
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// "Target: 10 reps" — the number picked out, the rest quiet. Written as
/// one sentence in ARB and split at render, so a translator controls
/// where the emphasis lands.
class _TargetLine extends StatelessWidget {
  const _TargetLine({required this.reps});

  final int reps;

  @override
  Widget build(BuildContext context) {
    final sentence = AppLocalizations.of(context).targetRepsLabel(reps);
    final index = sentence.indexOf('$reps');
    final base = TextStyle(
      color: Colors.white.withValues(alpha: 0.66),
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    if (index < 0) return Text(sentence, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: sentence.substring(0, index)),
          TextSpan(
            // From the number to the end of the sentence: "10 reps",
            // "10 tekrar". Splitting at the number alone would leave the
            // unit stranded in a different colour in one language and
            // not the other.
            text: sentence.substring(index),
            style: const TextStyle(
              color: AppColors.neon,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

/// Big, unambiguous +/− around the count. Deliberately not a text field:
/// mid-set, with sweaty hands, a numeric keyboard is the wrong
/// affordance.
class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.reps, required this.onAdjust});

  final int reps;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.completedRepsLabel(reps),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            icon: Icons.remove_rounded,
            label: l10n.workoutDecrementRep,
            onTap: () => onAdjust(-1),
          ),
          const SizedBox(width: 14),
          Container(
            width: 152,
            height: 152,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.34),
              border: Border.all(color: AppColors.neon, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neon.withValues(alpha: 0.55),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            // The circle is a fixed 152 so it stays a circle; the count
            // inside it is not, because "888" at a 1.3 text scale is
            // taller than the ring that has to contain it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    l10n.workoutRepsUnit,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.neon,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          _RoundButton(
            icon: Icons.add_rounded,
            label: l10n.workoutIncrementRep,
            onTap: () => onAdjust(1),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // 64dp — comfortably above the 48dp minimum, because this is
          // tapped mid-exercise rather than at rest.
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.neonGreen,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              AppLocalizations.of(context).workoutTipWithText(tip),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where this set sits in the exercise. Reads at a glance mid-set, which
/// a "1 / 3" string does not.
class _SetTrack extends StatelessWidget {
  const _SetTrack({required this.currentSet, required this.totalSets});

  final int currentSet;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          for (var i = 1; i <= totalSets; i++) ...[
            if (i > 1)
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            _SetStep(
              number: i,
              label: l10n.workoutSetShort(i),
              done: i < currentSet,
              active: i == currentSet,
            ),
          ],
        ],
      ),
    );
  }
}

class _SetStep extends StatelessWidget {
  const _SetStep({
    required this.number,
    required this.label,
    required this.done,
    required this.active,
  });

  final int number;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = done
        ? AppColors.neonGreen
        : (active ? AppColors.neon : Colors.white.withValues(alpha: 0.34));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.neon.withValues(alpha: 0.14) : null,
            border: Border.all(color: tint, width: active ? 2 : 1.4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.neon.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded,
                  color: AppColors.neonGreen, size: 20)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: active ? Colors.white : tint,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: tint,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rest
// ---------------------------------------------------------------------------

class _RestView extends StatelessWidget {
  const _RestView({
    required this.seconds,
    required this.totalSeconds,
    required this.currentSet,
    required this.totalSets,
    required this.onContinue,
  });

  final int seconds;
  final int totalSeconds;
  final int currentSet;
  final int totalSets;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(
            Icons.schedule_rounded,
            color: AppColors.neon.withValues(alpha: 0.9),
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.workoutResting,
            style: const TextStyle(
              color: AppColors.neon,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 18),
          Flexible(
            flex: 12,
            child: _RestDial(
              seconds: seconds,
              totalSeconds: totalSeconds,
              unit: l10n.workoutRestSecondsUnit,
            ),
          ),
          const Spacer(flex: 2),
          _RestEncouragement(
            title: l10n.workoutRestCardTitle,
            body: l10n.workoutRestCardBody,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RestStat(
                  icon: Icons.timer_outlined,
                  value: '$totalSeconds',
                  // A unit symbol, not copy.
                  suffix: 's', // i18n-ignore — SI symbol for second
                  label: l10n.workoutRestTimeLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RestStat(
                  icon: Icons.fitness_center_rounded,
                  value: '$currentSet',
                  suffix: ' / $totalSets', // i18n-ignore — a ratio
                  label: l10n.workoutSetProgressLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GradientCta(
            label: l10n.workoutContinueSession,
            onTap: onContinue,
          ),
        ],
      ),
    );
  }
}

/// The countdown. The ring is the remaining fraction, so the number and
/// the arc can never disagree.
class _RestDial extends StatelessWidget {
  const _RestDial({
    required this.seconds,
    required this.totalSeconds,
    required this.unit,
  });

  final int seconds;
  final int totalSeconds;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final fraction = totalSeconds <= 0
        ? 0.0
        : (seconds / totalSeconds).clamp(0.0, 1.0).toDouble();
    return Semantics(
      liveRegion: true,
      label: '$seconds $unit',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _RestDialPainter(fraction: fraction),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$seconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 112,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestDialPainter extends CustomPainter {
  const _RestDialPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(16);
    const start = -math.pi / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = AppColors.neon.withValues(alpha: 0.16);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (fraction <= 0) return;
    final shader = SweepGradient(
      startAngle: start,
      endAngle: start + math.pi * 2,
      colors: [
        AppColors.neon.withValues(alpha: 0.55),
        AppColors.neon,
        const Color(0xFFB79BFF),
        AppColors.neon.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.35, 0.6, 1.0],
      transform: GradientRotation(start),
    ).createShader(rect);

    final sweep = math.pi * 2 * fraction;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RestDialPainter old) =>
      old.fraction != fraction;
}

class _RestEncouragement extends StatelessWidget {
  const _RestEncouragement({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            color: AppColors.neon,
            size: 30,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.32,
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

class _RestStat extends StatelessWidget {
  const _RestStat({
    required this.icon,
    required this.value,
    required this.suffix,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String suffix;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neon.withValues(alpha: 0.13),
            ),
            child: Icon(icon, color: AppColors.neon, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.neon,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        suffix,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
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

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.neon.withValues(alpha: 0.42),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: _kBrandGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
