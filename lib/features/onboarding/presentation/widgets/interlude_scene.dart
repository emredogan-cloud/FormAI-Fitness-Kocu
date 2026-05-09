import 'package:flutter/material.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import 'coach_mood.dart';
import 'living_coach_avatar.dart';

/// Shared scene for Act 3's two strategic interludes. Form fills the
/// screen, says one observation, and the wizard auto-advances. Reads
/// as a *moment* — not a screen the user has to act on.
///
/// The pattern is deliberately the same for both interludes (after
/// goal + before pain-point) so the audit's "scene continuity" notion
/// holds — every Form-speaking moment in the wizard reads as the same
/// kind of beat: avatar pulses, line types in, soft success haptic on
/// type-complete, brief dwell, auto-advance.
///
/// Background pan period is intentionally different from Acts 1 / 2
/// (14 s vs 15 s vs 16 s) so consecutive screens don't lock into a
/// shared rhythm — the wizard reads as a sequence of distinct
/// moments rather than one metronomic loop.
class InterludeScene extends StatefulWidget {
  const InterludeScene({
    super.key,
    required this.text,
    required this.onContinue,
    this.mood = CoachMood.idle,
    this.dwellAfterTyping = const Duration(milliseconds: 1500),
    this.charDuration = const Duration(milliseconds: 30),
    this.avatarSize = 156,
    this.avatarInnerSize = 100,
  });

  /// Form's line. Pre-formatted by the caller (per-goal, per-state copy).
  final String text;

  /// Fires after the typewriter completes + [dwellAfterTyping].
  final VoidCallback onContinue;

  /// Form's emotional state for this interlude. Lets each interlude
  /// caller specify *how* Form delivers the line — `reassuring` for
  /// post-goal empathy, `reflective` for the pre-pain-point setup.
  final CoachMood mood;

  final Duration dwellAfterTyping;
  final Duration charDuration;
  final double avatarSize;
  final double avatarInnerSize;

  @override
  State<InterludeScene> createState() => _InterludeSceneState();
}

class _InterludeSceneState extends State<InterludeScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgPan;
  bool _typingDone = false;

  @override
  void initState() {
    super.initState();
    _bgPan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgPan.dispose();
    super.dispose();
  }

  void _onTypingComplete() {
    if (!mounted || _typingDone) return;
    setState(() => _typingDone = true);
    // Soft confirmation that Form has finished its observation.
    AppHaptics.success();
    Future<void>.delayed(widget.dwellAfterTyping, () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Slow ambient gradient that subtly drifts — gives the scene
        // depth without adding any moving foreground element.
        AnimatedBuilder(
          animation: _bgPan,
          builder: (context, _) {
            final t = MotionTokens.breathEase.transform(_bgPan.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2 - 0.05 * t),
                  radius: 1.0 + 0.1 * t,
                  colors: [
                    AppColors.neon.withValues(alpha: 0.10 + 0.04 * t),
                    const Color(0xFF0A0814),
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            );
          },
        ),
        const AmbientParticles(
          count: 8,
          color: AppColors.neon,
          minAlpha: 0.06,
          maxAlpha: 0.22,
          minRadius: 1.0,
          maxRadius: 2.2,
          driftDuration: Duration(seconds: 24),
          seed: 41,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                LivingCoachAvatar(
                  size: widget.avatarSize,
                  innerSize: widget.avatarInnerSize,
                  mood: widget.mood,
                ),
                const SizedBox(height: 36),
                KineticTextReveal(
                  text: widget.text,
                  onComplete: _onTypingComplete,
                  caret: false,
                  charDuration: widget.charDuration,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
