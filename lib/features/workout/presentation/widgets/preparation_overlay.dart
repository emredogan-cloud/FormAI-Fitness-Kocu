import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import 'workout_back_button.dart';
import '../../../../l10n/app_localizations.dart';

const Color _neon = Color(0xFF00F0FF);

class PreparationOverlay extends StatelessWidget {
  const PreparationOverlay({
    super.key,
    required this.exercise,
    required this.secondsRemaining,
    required this.onExit,
  });

  final Exercise exercise;
  final int secondsRemaining;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final countdownText = secondsRemaining > 0 ? '$secondsRemaining' : 'BAŞLA';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF00111A), Colors.black],
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _neon.withValues(alpha: 0.65),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).prepGetReady,
                      style: TextStyle(
                        color: _neon,
                        fontSize: 12,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    exercise.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      shadows: [Shadow(blurRadius: 18, color: _neon)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    exercise.description.isNotEmpty
                        ? exercise.description
                        : AppLocalizations.of(context).prepTakePosition,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    countdownText,
                    style: TextStyle(
                      color: secondsRemaining > 0
                          ? _neon
                          : const Color(0xFF39FF14),
                      fontSize: secondsRemaining > 0 ? 140 : 80,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 32,
                          color: secondsRemaining > 0
                              ? _neon
                              : const Color(0xFF39FF14),
                        ),
                        Shadow(
                          blurRadius: 64,
                          color: secondsRemaining > 0
                              ? _neon
                              : const Color(0xFF39FF14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
