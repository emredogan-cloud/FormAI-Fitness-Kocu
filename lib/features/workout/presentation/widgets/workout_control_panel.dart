import 'package:flutter/material.dart';

import '../../services/crunch_analyzer.dart';
import '../../../../l10n/app_localizations.dart';

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
    this.repCounterKey,
    this.formIndicatorKey,
    this.pauseControlKey,
    this.nextControlKey,
  });

  final int currentSet;
  final int totalSets;
  final String metric;
  final String exerciseName;
  final CrunchState detectorState;
  final bool isPaused;
  // Phase 47B: onPrev is passed in when the session has at least one
  // exercise behind the active index; the parent still passes `null`
  // on the first exercise so the Row renders an equal-width invisible
  // puck in place of the button and keeps the play control centered.
  final VoidCallback? onPrev;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;

  // Roadmap Phase 3b · spotlight anchors for the first-workout coach-mark
  // layer. Passed in rather than read from the tour registry here so this
  // widget stays a plain StatelessWidget with no provider dependency —
  // it is rendered by three tests that never build a ProviderScope.
  // Null everywhere except the live workout screen.
  final GlobalKey? repCounterKey;
  final GlobalKey? formIndicatorKey;
  final GlobalKey? pauseControlKey;
  final GlobalKey? nextControlKey;

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
            detectorLabel: _detectorLabel(context, detectorState),
            detectorKey: formIndicatorKey,
          ),
          const Spacer(),
          FittedBox(
            key: repCounterKey,
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
                  semanticLabel:
                      AppLocalizations.of(context).workoutPrevExercise,
                  onTap: onPrev,
                )
              else
                const SizedBox(width: 48, height: 48),
              _CenterPlayButton(
                key: pauseControlKey,
                isPaused: isPaused,
                onTap: onTogglePlay,
              ),
              _ControlIconButton(
                key: nextControlKey,
                icon: Icons.skip_next_rounded,
                semanticLabel: AppLocalizations.of(context).workoutNextExercise,
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
    this.detectorKey,
  });

  final int currentSet;
  final int totalSets;
  final String detectorLabel;
  final GlobalKey? detectorKey;

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
            totalSets > 0
                ? AppLocalizations.of(context)
                    .setProgressUpper(currentSet, totalSets)
                : AppLocalizations.of(context).setProgressUnknown,
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
          key: detectorKey,
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
  const _ControlIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  final IconData icon;
  // U4 · icon-only control — TalkBack/VoiceOver otherwise announce
  // nothing actionable here.
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 1),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            // U4 · 13px pad + 22px icon = 48dp minimum touch target.
            padding: const EdgeInsets.all(13),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({
    super.key,
    required this.isPaused,
    required this.onTap,
  });

  final bool isPaused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isPaused
          ? AppLocalizations.of(context).workoutResume
          : AppLocalizations.of(context).workoutPause,
      child: DecoratedBox(
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
      ),
    );
  }
}

/// The rep detector's state, in the user's language.
///
/// This used to render `detectorState.name.toUpperCase()` — so a
/// Turkish user watched "UNKNOWN" sit beside their rep counter until
/// the analyser locked on. An enum name is an identifier, not copy.
String _detectorLabel(BuildContext context, CrunchState state) {
  final l10n = AppLocalizations.of(context);
  return switch (state) {
    CrunchState.unknown => l10n.detectorStateWaiting,
    CrunchState.down => l10n.detectorStateDown,
    CrunchState.up => l10n.detectorStateUp,
  };
}
