import 'package:flutter/material.dart';

import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';

/// Act 2 · AI companion bonding.
///
/// The named coach (Form) introduces itself with a typewriter line over
/// a layered, breathing avatar halo. Designed so the user feels they
/// have *met* a presence in the first 4 seconds — not "watched a button
/// fade in."
///
/// Cinematic atmosphere layered on top of the existing structure:
///
///   • 15-second background parallax (gentle vertical translate +
///     scale, easeInOutCubic). Slightly different rhythm from Act 1's
///     16 s pan so two consecutive screens don't feel mechanically
///     synced.
///   • Coach avatar: outer radial halo wrapped in [BreathingBox]
///     (3.6 s cycle) + inner photo wrapped in [GlowPulse] (2.4 s
///     cycle). The two cycles deliberately drift in and out of phase
///     so the avatar feels *alive* instead of pulsing on a metronome.
///   • Chat bubble wrapped in a barely-perceptible [BreathingBox]
///     (0.95 → 1.0 over 5 s). Says "the coach is exhaling between
///     sentences."
///   • Typewriter via [KineticTextReveal] with a [RevealController] so
///     a tap anywhere inside the gesture region short-circuits the
///     reveal. On completion: [AppHaptics.success] confirms the line
///     landed, then the CTA gets its own [GlowPulse] ambient.
///
/// Three audit-§2.3 beats stay in the line: identity, 12-week promise,
/// 90-second effort transparency.

class CoachIntroStep extends StatefulWidget {
  const CoachIntroStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<CoachIntroStep> createState() => _CoachIntroStepState();
}

class _CoachIntroStepState extends State<CoachIntroStep>
    with SingleTickerProviderStateMixin {
  // Cinematic rebuild · the coach now has a name (Form) and the line is
  // structured as three beats per the audit (§2.3): identity, promise,
  // effort-transparency. The "90 saniye" line sets a time-budget
  // expectation so the user mentally commits before the wizard starts —
  // norm-of-reciprocity + time-boxing psychology.
  static const String _coachLine =
      'Merhaba, ben Form. '
      '12 haftada vücudunu nasıl değiştireceğini sana göstereceğim. '
      'Önce seni tanıyalım — bu 90 saniye sürüyor.';

  final RevealController _reveal = RevealController();
  late final AnimationController _bgPan;
  bool _typingDone = false;

  @override
  void initState() {
    super.initState();
    _bgPan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
    // Soft completion confirmation — Form has finished introducing
    // itself. Reads as "the AI nodded at you" rather than "a button
    // unlocked."
    AppHaptics.success();
  }

  void _skipTyping() {
    if (_typingDone) return;
    _reveal.skip();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background hero with slow ambient parallax. Translates up to
        // 8 px and scales 1.04 → 1.06 over the 15 s loop. The
        // RepaintBoundary keeps the rest of the screen out of the
        // composite-region whenever only the bg transforms.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _bgPan,
            builder: (context, child) {
              final t = MotionTokens.reassuranceEase.transform(_bgPan.value);
              return Transform.translate(
                offset: Offset(0, -8.0 * t),
                child: Transform.scale(
                  scale: 1.04 + (0.02 * t),
                  alignment: Alignment.center,
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'photos/merhababenseninkişiselyapayzekakoçunumyeniarkaplan.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF0E0729)),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                Expanded(
                  // GestureDetector wraps only the avatar + bubble area
                  // so taps here skip the typewriter; the CTA owns its
                  // own onPressed.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skipTyping,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _LivingCoachAvatar(),
                        const SizedBox(height: 28),
                        BreathingBox(
                          minAlpha: 0.95,
                          maxAlpha: 1.0,
                          duration: const Duration(milliseconds: 5000),
                          child: _CoachBubble(
                            controller: _reveal,
                            text: _coachLine,
                            onComplete: _onTypingComplete,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: _typingDone ? 0.0 : 1.0,
                          child: const Text(
                            'Geçmek için ekrana dokun',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: _typingDone ? 1.0 : 0.45,
                  child: GlowPulse(
                    enabled: _typingDone,
                    color: AppColors.neon,
                    minAlpha: 0.40,
                    maxAlpha: 0.65,
                    minBlur: 22,
                    maxBlur: 32,
                    spread: 1,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(18),
                    duration: const Duration(milliseconds: 2800),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _typingDone
                            ? () {
                                AppHaptics.secondaryTap();
                                widget.onContinue();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('DEVAM ET'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.neon,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.neon.withValues(alpha: 0.45),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Chat-bubble container that hosts the typewriter reveal.
///
/// Visually identical to the previous _TerminalBubble (same neon outline,
/// blurred glow, asymmetric corner radii) but the reveal itself is now
/// powered by [KineticTextReveal] from the motion library, so a single
/// API governs every character-by-character moment in the wizard.
class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.controller,
    required this.text,
    required this.onComplete,
  });

  final RevealController controller;
  final String text;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: AppColors.neon.withValues(alpha: 0.4),
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
      child: KineticTextReveal(
        text: text,
        controller: controller,
        onComplete: onComplete,
        caret: true,
        caretColor: AppColors.neon,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// The coach avatar — outer radial halo + inner circular photo.
///
/// Two breathing layers, intentionally out of phase:
///   • Outer halo: 3.6-second cycle via [BreathingBox] (radial gradient
///     fades 0.55 → 1.0 alpha).
///   • Inner photo: 2.4-second cycle via [GlowPulse] (boxshadow alpha
///     0.30 → 0.55, blur 22 → 30).
///
/// The differing periods drift the layers in and out of phase, so the
/// avatar reads as *alive* rather than *blinking on a metronome*. Each
/// primitive is `RepaintBoundary`-isolated internally so the parent
/// rebuild on `_typingDone` doesn't trigger a full repaint of the
/// avatar.
///
/// Stays a static webp until the artist delivers the Rive-driven
/// living-coach .riv asset; the cinematic primitives carry the
/// "presence" feel in the meantime.
class _LivingCoachAvatar extends StatelessWidget {
  const _LivingCoachAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          BreathingBox(
            minAlpha: 0.55,
            maxAlpha: 1.0,
            duration: const Duration(milliseconds: 3600),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neon.withValues(alpha: 0.55),
                    AppColors.neonAccent.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          GlowPulse(
            color: AppColors.neon,
            minAlpha: 0.30,
            maxAlpha: 0.55,
            minBlur: 22,
            maxBlur: 30,
            spread: -2,
            duration: const Duration(milliseconds: 2400),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'photos/kişiselyapayzekakoçfoto.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [AppColors.neon, AppColors.neonAccent],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 56,
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
