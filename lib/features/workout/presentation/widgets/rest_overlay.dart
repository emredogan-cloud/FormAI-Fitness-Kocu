import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import 'workout_back_button.dart';
import '../../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF00F0FF);

class RestOverlay extends StatelessWidget {
  const RestOverlay({
    super.key,
    required this.secondsRemaining,
    required this.upcomingExercise,
    required this.upcomingSet,
    required this.totalSets,
    required this.onSkip,
    required this.onExit,
  });

  final int secondsRemaining;
  final Exercise? upcomingExercise;
  final int upcomingSet;
  final int totalSets;
  final VoidCallback onSkip;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    final exerciseName = upcomingExercise?.name ?? '—';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF001823), Colors.black],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: WorkoutBackButton(onPressed: onExit),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _neon.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).restTitle,
                    style: TextStyle(
                      color: _neon,
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: _neon,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(blurRadius: 32, color: _neon),
                      Shadow(blurRadius: 64, color: _neon),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).restNext,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalSets > 0
                      ? AppLocalizations.of(context)
                          .setProgress(upcomingSet, totalSets)
                      : '',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                _SkipButton(onTap: onSkip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.65),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: _neon,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).restSkip,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.skip_next_rounded, color: Colors.black, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
