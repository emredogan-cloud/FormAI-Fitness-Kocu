import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../widgets/composing_dots.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.7 · Form's thinking moment (Phase 110).
///
/// Reference video timestamp: ~0:28–0:35. Unrot's clipboard scene —
/// Brain visibly *preparing* before the question phase begins.
/// Adapted for FormAI: Form in `thinking` mood (cool accent halo,
/// faster pulse) + a centered composing-dot bubble that morphs into
/// a typewritten setup line + auto-advance.
///
/// Sits between name capture and gender. Header-less (`interlude_`
/// prefix in [_stepNames]) so the bonding-zone visual continuity
/// holds: the user reads it as Form's voice, not a wizard step.
///
/// Behavioural differentiation from idle/listening Form:
///
///   • Mood = `thinking`. The character system already shifts halo
///     to neonAccent (cool blue), bumps pulse to 2.0 s, and runs a
///     faster glow — visibly different posture from the listening
///     mood we just left in name capture.
///   • A subtle ±1.1 ° head wobble (3.6 s cycle, easeInOutSine)
///     layered on top — reads as "thoughtfully tilting", a small
///     human-cue that nothing in the mood system alone provides.
///   • [ComposingDots] inside a centered Form-bubble for ~2.2 s.
///     Three dots ripple left-to-right on staggered phases — the
///     universal "the other side is composing" signal.
///   • After the dwell, dots cross-fade to a [KineticTextReveal] of
///     Form's setup line. The bubble container stays mounted; only
///     the inner content swaps, so the bubble visibly *grows* with
///     the text (as it would in any chat app).
///
/// Copy: name-aware. With name set, "Emre, senden birkaç şey
/// öğrenmem gerekiyor. Plan tamamen sana özel olacak." Without name,
/// the un-vocative variant. Soft success haptic on typewriter
/// completion; 1.5 s dwell; auto-advance.

class SetupThinkingStep extends ConsumerStatefulWidget {
  const SetupThinkingStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<SetupThinkingStep> createState() =>
      _SetupThinkingStepState();
}

class _SetupThinkingStepState extends ConsumerState<SetupThinkingStep>
    with TickerProviderStateMixin {
  /// Atmospheric radial breath — same language as the analysis
  /// illusion screen so the two "Form is computing" surfaces feel
  /// like one motion family.
  late final AnimationController _atmosphere;

  /// Subtle head-wobble on the avatar — adds a *human cue* that the
  /// mood system alone doesn't provide. Range ±0.020 rad (~1.1°)
  /// over a 3.6 s cycle. Slow enough to be subliminal.
  late final AnimationController _wobble;
  late final Animation<double> _wobbleAngle;

  /// Composing → text state. Dots show first; after [_composingDwell]
  /// the bubble cross-fades to the typewritten line.
  bool _composing = true;
  bool _typingDone = false;

  static const Duration _composingDwell = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _atmosphere = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);

    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _wobbleAngle = Tween<double>(begin: -0.020, end: 0.020).animate(
      CurvedAnimation(
        parent: _wobble,
        curve: MotionTokens.breathEase,
      ),
    );

    Future<void>.delayed(_composingDwell, () {
      if (mounted) setState(() => _composing = false);
    });
  }

  @override
  void dispose() {
    _atmosphere.dispose();
    _wobble.dispose();
    super.dispose();
  }

  void _onTypingComplete() {
    if (!mounted || _typingDone) return;
    setState(() => _typingDone = true);
    AppHaptics.success();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onContinue();
    });
  }

  String _composeText(WizardState s) {
    final name = _capitaliseFirst(s.name);
    if (name != null) {
      return '$name, senden birkaç şey öğrenmem gerekiyor.\n'
          'Plan tamamen sana özel olacak.';
    }
    return 'Senden birkaç şey öğrenmem gerekiyor.\n'
        'Plan tamamen sana özel olacak.';
  }

  String? _capitaliseFirst(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(wizardProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Atmospheric radial breath — slightly cooler tone than the
        // post-goal interlude (which uses warm neon for reassurance);
        // the thinking moment leans on neonAccent so the *air* of
        // the screen reads as "computing", not "comforting."
        AnimatedBuilder(
          animation: _atmosphere,
          builder: (context, _) {
            final t =
                MotionTokens.breathEase.transform(_atmosphere.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 1.0,
                  colors: [
                    AppColors.neonAccent.withValues(alpha: 0.10 + 0.05 * t),
                    const Color(0xFF0A0814),
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            );
          },
        ),
        const AmbientParticles(
          count: 10,
          color: AppColors.neonAccent,
          minAlpha: 0.07,
          maxAlpha: 0.26,
          minRadius: 1.0,
          maxRadius: 2.4,
          driftDuration: Duration(seconds: 22),
          seed: 88,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _wobbleAngle,
                  builder: (context, child) => Transform.rotate(
                    angle: _wobbleAngle.value,
                    alignment: Alignment.center,
                    child: child,
                  ),
                  child: const LivingCoachAvatar(
                    size: 156,
                    innerSize: 100,
                    mood: CoachMood.thinking,
                  ),
                ),
                const SizedBox(height: 32),
                _ThinkingBubble(
                  composing: _composing,
                  text: _composeText(wizard),
                  onTypingComplete: _onTypingComplete,
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

/// Centered Form-style bubble that holds the composing-then-text
/// transition. Shape mirrors the chat-bubble Form-side language
/// (dark surface, neon outline, soft outer glow) but symmetric
/// corners — no tail — because this scene is a focal moment, not a
/// chat thread.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({
    required this.composing,
    required this.text,
    required this.onTypingComplete,
  });

  final bool composing;
  final String text;
  final VoidCallback onTypingComplete;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.neon.withValues(alpha: 0.42),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: -2,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: composing
                ? const Padding(
                    key: ValueKey('composing'),
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Center(child: ComposingDots()),
                  )
                : KineticTextReveal(
                    key: const ValueKey('text'),
                    text: text,
                    charDuration: const Duration(milliseconds: 30),
                    onComplete: onTypingComplete,
                    caret: true,
                    caretColor: AppColors.neon,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
