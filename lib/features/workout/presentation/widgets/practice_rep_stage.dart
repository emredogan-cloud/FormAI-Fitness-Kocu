import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../services/crunch_analyzer.dart' show CrunchState;
import '../pose_painter.dart';

/// Roadmap Phase 3 feature 3 (R1.2) · one repetition, with zero stakes.
///
/// The user has just been told the app can see them. This is where they
/// find out what that *buys* them: they squat once, watch their own
/// joints get named on screen, and see the counter tick from 0 to 1 off
/// their own movement. Everything is driven by the production
/// `SquatAnalyzer` over real landmarks, so the rehearsal is the real
/// thing with the pressure taken out — which is the only version of it
/// worth showing. A scripted animation here would teach the user to
/// trust something that hasn't actually been demonstrated.
///
/// The widget itself is pure presentation: it owns no camera, no
/// detector and no timers. Every value it renders is passed in, which is
/// what lets the whole stage be exercised in widget tests without a
/// camera platform channel.
class PracticeRepStage extends StatelessWidget {
  const PracticeRepStage({
    super.key,
    required this.controller,
    required this.pose,
    required this.imageSize,
    required this.lensDirection,
    required this.reps,
    required this.state,
    required this.cue,
    required this.onSkip,
  });

  final CameraController? controller;
  final Pose? pose;
  final Size? imageSize;
  final CameraLensDirection? lensDirection;
  final int reps;
  final CrunchState state;
  final String? cue;
  final VoidCallback onSkip;

  /// The joints the `SquatAnalyzer` actually reads: hip-knee-ankle for
  /// the rep cycle, shoulder for the torso-lean form check. Labelling
  /// anything else would be theatre — and the kind that is invisible in
  /// review because it looks equally convincing on screen.
  static const List<PoseLandmarkType> trackedJoints = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.leftAnkle,
  ];

  /// Roadmap Phase 5 · the joint SET stays const; only the labels are
  /// localised.
  ///
  /// Splitting them keeps the thing that must match the analyzer — which
  /// landmarks are read — as a compile-time constant that a test can
  /// assert against `SquatAnalyzer`'s geometry, while the words shown on
  /// the body move to ARB. Storing localized strings in the map would
  /// have coupled a correctness invariant to a translation.
  static Map<PoseLandmarkType, String> jointLabels(AppLocalizations l10n) => {
        PoseLandmarkType.leftShoulder: l10n.practiceJointShoulder,
        PoseLandmarkType.leftHip: l10n.practiceJointHip,
        PoseLandmarkType.leftKnee: l10n.practiceJointKnee,
        PoseLandmarkType.leftAnkle: l10n.practiceJointAnkle,
      };

  @override
  Widget build(BuildContext context) {
    final ready = controller != null && controller!.value.isInitialized;
    final currentPose = pose;
    final size = imageSize;
    final lens = lensDirection;

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.previewSize?.height ?? 720,
                    height: controller!.value.previewSize?.width ?? 1280,
                    // The painter lives INSIDE the same box the preview
                    // fills, so one FittedBox scales both and the labels
                    // stay welded to the body as it moves.
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller!),
                        if (currentPose != null && size != null && lens != null)
                          CustomPaint(
                            painter: TutorialPosePainter(
                              pose: currentPose,
                              imageSize: size,
                              // Landmarks are already in the rotated
                              // frame that `imageSize` describes, so no
                              // further rotation is applied here.
                              rotation: InputImageRotation.rotation0deg,
                              cameraLensDirection: lens,
                              trackedJoints:
                                  jointLabels(AppLocalizations.of(context)),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: AppColors.neon),
                ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: _PracticeHeader(reps: reps, state: state),
              ),
              if (cue != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: _PracticeCue(text: cue!),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Text(
            AppLocalizations.of(context).practiceSquatOnce,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            AppLocalizations.of(context).practiceExplainer,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ),
        // Skipping is a first-class exit, not a failure. A user with a
        // mobility limitation, in a crowded room, or simply not dressed
        // to squat must not be blocked from their workout by a demo.
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            minimumSize: const Size(120, 48),
          ),
          child: Text(
            AppLocalizations.of(context).practiceSkipStep,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// The live rep readout. Deliberately the largest thing on screen: the
/// number moving is the proof.
class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({required this.reps, required this.state});

  final int reps;
  final CrunchState state;

  @override
  Widget build(BuildContext context) {
    final tracking = state != CrunchState.unknown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // The count is announced as a live region so a screen-reader
          // user gets the same "it counted me" moment a sighted user
          // gets from the digit changing.
          Semantics(
            liveRegion: true,
            label: AppLocalizations.of(context).countedRepsLabel(reps),
            child: ExcludeSemantics(
              child: Text(
                '$reps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [Shadow(blurRadius: 14, color: AppColors.neon)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).practiceRepsLabel,
                  style: TextStyle(
                    color: AppColors.neon,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tracking
                      ? AppLocalizations.of(context).practiceTrackingYou
                      : AppLocalizations.of(context).practiceGetInFrame,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

class _PracticeCue extends StatelessWidget {
  const _PracticeCue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF39FF14).withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
