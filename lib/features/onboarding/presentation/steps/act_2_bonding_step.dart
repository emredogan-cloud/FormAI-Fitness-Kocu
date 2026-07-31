import 'package:flutter/material.dart';

import '../../../../core/motion/arrival_pulse.dart';
import '../../../../core/motion/breathing_box.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/motion/kinetic_text_reveal.dart';
import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';
import '../../../../l10n/app_localizations.dart';

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
    with TickerProviderStateMixin {
  // Cinematic rebuild · the coach now has a name (Form) and the line is
  // structured as three beats per the audit (§2.3): identity, promise,
  // effort-transparency. The "90 saniye" line sets a time-budget
  // expectation so the user mentally commits before the wizard starts —
  // norm-of-reciprocity + time-boxing psychology.
  static const String _coachLine = 'Merhaba, ben Form. '
      '12 haftada vücudunu nasıl değiştireceğini sana göstereceğim. '
      'Önce seni tanıyalım — bu 90 saniye sürüyor.';

  // Phase 108 · Form arrival choreography.
  //
  // The screen used to mount with the avatar already present — felt
  // like "Form was always here." Reference video (~0:00–0:06) shows
  // the character arriving as a deliberate moment. Adapted for
  // FormAI's premium aesthetic: avatar fades + scales 0.88 → 1.0
  // (easeOutBack overshoot), an [ArrivalPulse] ring radiates outward
  // (scanning gesture), and a light haptic lands at the ring's peak.
  // The user feels "the AI noticed me" — calm AI acknowledgment, not
  // cartoon hand-wave.
  static const Duration _entryDuration = Duration(milliseconds: 1100);

  final RevealController _reveal = RevealController();
  late final AnimationController _bgPan;
  late final AnimationController _entry;
  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;
  bool _typingDone = false;
  bool _arrivalHapticFired = false;

  @override
  void initState() {
    super.initState();
    _bgPan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _entry = AnimationController(
      vsync: this,
      duration: _entryDuration,
    );
    // Avatar fades in on the first 40 % of the entry window —
    // settles before the scale overshoot lands so the user reads
    // "Form materialised, then arrived." Scale runs longer (70 %)
    // with easeOutBack, giving a slight overshoot on landing.
    _entryFade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );
    _entryScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    // Light haptic at the ring's peak (~halfway through the entry)
    // so the felt impact lands at the moment the user perceives
    // the scanning ring at full radius. Only fires once.
    _entry.addListener(() {
      if (!_arrivalHapticFired && _entry.value >= 0.55) {
        _arrivalHapticFired = true;
        AppHaptics.secondaryTap();
      }
    });
    _entry.forward();
  }

  @override
  void dispose() {
    _bgPan.dispose();
    _entry.dispose();
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
              'photos/Second_screen.png',
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
                        // Phase 108 · Form's arrival. ArrivalPulse
                        // ring radiates outward starting 200 ms in,
                        // while the avatar itself fades + scales up
                        // with a slight overshoot (easeOutBack).
                        // Mood progresses idle → listening once the
                        // typewriter completes, same as before.
                        ArrivalPulse(
                          color: AppColors.neon,
                          maxRadius: 240,
                          duration: const Duration(milliseconds: 1100),
                          startDelay: const Duration(milliseconds: 200),
                          child: FadeTransition(
                            opacity: _entryFade,
                            child: ScaleTransition(
                              scale: _entryScale,
                              child: LivingCoachAvatar(
                                mood: _typingDone
                                    ? CoachMood.listening
                                    : CoachMood.idle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        BreathingBox(
                          minAlpha: 0.95,
                          maxAlpha: 1.0,
                          duration: const Duration(milliseconds: 5000),
                          child: _CoachBubble(
                            controller: _reveal,
                            text: _coachLine,
                            onComplete: _onTypingComplete,
                            // Phase 108 · hold the typewriter until
                            // Form's arrival has settled, so the user
                            // reads "Form arrived → Form began
                            // speaking", not both at once. Delay
                            // matches the entry duration plus a
                            // small grace beat.
                            startDelay: const Duration(milliseconds: 1200),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: _typingDone ? 0.0 : 1.0,
                          child: Text(
                            AppLocalizations.of(context).tapToSkip,
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
    this.startDelay = Duration.zero,
  });

  final RevealController controller;
  final String text;
  final VoidCallback onComplete;

  /// Delay before the typewriter inside this bubble begins. Lets the
  /// caller (CoachIntroStep · Phase 108) hold the speech until Form's
  /// arrival choreography settles.
  final Duration startDelay;

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
        startDelay: startDelay,
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

// _LivingCoachAvatar moved to widgets/living_coach_avatar.dart so the
// name-capture step (and any future Form-speaks moment) can re-use the
// same two-layer breathing identity.
