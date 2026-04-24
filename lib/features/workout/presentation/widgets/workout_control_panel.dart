import 'package:flutter/material.dart';

import '../../services/crunch_analyzer.dart';

const Color _neon = Color(0xFF00F0FF);
const Color _panel = Color(0xFF101010);

class WorkoutControlPanel extends StatelessWidget {
  const WorkoutControlPanel({
    super.key,
    required this.currentSet,
    required this.totalSets,
    required this.metric,
    required this.exerciseName,
    required this.detectorState,
    required this.isPaused,
    required this.onTogglePlay,
    required this.onNext,
    this.onPrev,
  });

  final int currentSet;
  final int totalSets;
  final String metric;
  final String exerciseName;
  final CrunchState detectorState;
  final bool isPaused;
  // Phase 40: now nullable — backwards-nav isn't implemented so the
  // parent passes `null` and the prev button is replaced by an equal-
  // width `SizedBox` to preserve the Row's symmetric layout.
  final VoidCallback? onPrev;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        children: [
          _SetIndicator(
            currentSet: currentSet,
            totalSets: totalSets,
            detectorLabel: detectorState.name.toUpperCase(),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              metric,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 1,
                shadows: [Shadow(blurRadius: 14, color: _neon)],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            exerciseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // When `onPrev` is null we render an invisible puck of
              // matching diameter so the center play button stays
              // horizontally centered inside the panel.
              if (onPrev != null)
                _ControlIconButton(
                  icon: Icons.skip_previous_rounded,
                  onTap: onPrev,
                )
              else
                const SizedBox(width: 40, height: 40),
              _CenterPlayButton(
                isPaused: isPaused,
                onTap: onTogglePlay,
              ),
              _ControlIconButton(
                icon: Icons.skip_next_rounded,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetIndicator extends StatelessWidget {
  const _SetIndicator({
    required this.currentSet,
    required this.totalSets,
    required this.detectorLabel,
  });

  final int currentSet;
  final int totalSets;
  final String detectorLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _neon.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _neon.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Text(
            totalSets > 0 ? 'SET $currentSet / $totalSets' : 'SET —',
            style: const TextStyle(
              color: _neon,
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          detectorLabel,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.isPaused, required this.onTap});

  final bool isPaused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: _neon,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.black,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
