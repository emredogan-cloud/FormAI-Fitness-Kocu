import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/workout_mode.dart';
import '../providers/workout_provider.dart';
import 'widgets/session_complete_overlay.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Antrenman',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4),
        ),
        actions: [
          // Roadmap Phase 3 feature 6 · the setup guide stays reachable
          // from the camera-free surface too. Someone who chose manual
          // because the camera felt daunting is exactly who benefits
          // from being able to re-read the placement guidance without
          // committing to a camera session first.
          Semantics(
            button: true,
            label: 'Kamera kurulumunu göster',
            child: IconButton(
              onPressed: _showSetupGuide,
              icon: const Icon(Icons.center_focus_strong_outlined),
              tooltip: 'Kamera kurulumunu göster',
            ),
          ),
          Semantics(
            button: true,
            label: 'Kamerayı aç',
            child: IconButton(
              onPressed: _switchToCamera,
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'Kamerayı aç',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.neon),
              ),
              error: (_, __) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Antrenman yüklenemedi',
                body: 'Planın alınırken bir sorun oldu. Tekrar dener misin?',
                ctaLabel: 'Tekrar Dene',
                onCta: () => ref.invalidate(workoutSessionProvider),
              ),
              data: (state) {
                final exercise = state.activeExercise;
                if (exercise == null) {
                  return const EmptyState(
                    icon: Icons.done_all_rounded,
                    title: 'Bugünlük bu kadar',
                    body: 'Bu günün tüm egzersizlerini tamamladın.',
                  );
                }
                if (state.isResting) {
                  return _RestView(seconds: state.restSecondsRemaining);
                }
                return _ActiveView(
                  exerciseName: exercise.name,
                  setLabel: '${state.currentSet} / ${exercise.sets}',
                  targetReps: exercise.targetReps,
                  currentReps: state.currentReps,
                  onAdjust: _adjustReps,
                  onComplete: _completeSet,
                );
              },
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

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.exerciseName,
    required this.setLabel,
    required this.targetReps,
    required this.currentReps,
    required this.onAdjust,
    required this.onComplete,
  });

  final String exerciseName;
  final String setLabel;
  final int? targetReps;
  final int currentReps;
  final ValueChanged<int> onAdjust;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ManualModeBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Column(
              children: [
                Text(
                  'SET $setLabel',
                  style: TextStyle(
                    color: AppColors.neon.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exerciseName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (targetReps != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Hedef: $targetReps tekrar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                _RepCounter(
                  reps: currentReps,
                  onAdjust: onAdjust,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'SETİ TAMAMLA',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
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
    return Semantics(
      container: true,
      label: 'Tamamlanan tekrar: $reps',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundButton(
            icon: Icons.remove_rounded,
            label: 'Bir tekrar çıkar',
            onTap: () => onAdjust(-1),
          ),
          SizedBox(
            width: 132,
            child: Text(
              '$reps',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 62,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            label: 'Bir tekrar ekle',
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
        color: Colors.white.withValues(alpha: 0.07),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // 64dp — comfortably above the 48dp minimum, because this is
          // tapped mid-exercise rather than at rest.
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _RestView extends StatelessWidget {
  const _RestView({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DİNLEN',
            style: TextStyle(
              color: AppColors.neon.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 76,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'saniye',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kamerasız mod — tekrarları sen sayıyorsun. '
              'İlerlemen normal şekilde kaydedilir.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
