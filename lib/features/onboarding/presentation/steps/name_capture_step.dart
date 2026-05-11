import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_chat_bubble.dart';
import '../widgets/coach_mood.dart';
import '../widgets/composing_dots.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.5 · Name capture + 2-beat bonding micro-conversation
/// (chat-format).
///
/// Phase 109 first version: chat-thread asking the user's name, Form
/// acknowledged it, auto-advanced.
///
/// Phase 131 evolution: the chat continued one beat further with a
/// coaching-tone question + chip ack.
///
/// Phase 132 evolution: the chat continues ONE MORE beat — a
/// motivation-style question after the tone ack. Three chips,
/// persisted via `wizardProvider.motivationStyle`. Per the user's
/// explicit cap ("only add 2 additional questions"), this is the
/// final beat — name + tone + motivation = exactly 2 questions after
/// the name, which is the bonding-without-fatigue target.
///
/// Phase 132 also adds:
///
///  • **AI-thinking cadence beat** — after every user chip tap, a
///    short composing-dots bubble appears for ~750 ms before Form's
///    typewriter ack starts. Reads as "Form is composing a reply",
///    matches the cinematic-AI-presence chat-bar illusion across
///    the rest of the product.
///
///  • **Deeper chat atmosphere** — a second radial gradient layer
///    pulses bottom-right with `neonDeep`, out of phase from the
///    primary breath. Bumped particle count + slightly raised alpha
///    range. Still well below the cinematic-presence scenes' depth
///    so the chat surface remains the focal point.
///
/// Atmosphere upgrade: the scene now layers a slow breathing radial
/// gradient + a soft edge vignette on top of the existing ambient-
/// particle field. Pulls the chat closer to the cinematic depth of
/// the CinematicAiPresence scenes while staying readable — the chat
/// surface itself is unchanged so the bubble copy remains the focal
/// point.
///
/// Mood progression:
///
///   • Phase A (asking name)        → CoachMood.listening
///   • Phase B (name acknowledged)  → CoachMood.proud (briefly)
///   • Phase C (asking tone)        → CoachMood.listening again
///   • Phase D (tone chosen, ack)   → CoachMood.proud
///
/// Re-entry: when both `name` and `coachingTone` already exist
/// (back-nav), the cascade collapses to its final state — both
/// Form bubbles + both user responses pre-rendered, input/chips
/// hidden, ready for `onContinue`.

class NameCaptureStep extends ConsumerStatefulWidget {
  const NameCaptureStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<NameCaptureStep> createState() => _NameCaptureStepState();
}

class _NameCaptureStepState extends ConsumerState<NameCaptureStep>
    with SingleTickerProviderStateMixin {
  static const String _prompt1 = 'Bu yolculukta sana nasıl sesleneyim?';
  static const String _prompt2 =
      'Bu plan boyunca seninle bu isimle konuşacağım.';
  static const String _tonePrompt =
      'Bir şey daha. Yanında nasıl olmamı istersin?';
  static const String _motivationPrompt =
      'Son bir şey. Seni en çok ne motive eder?';

  /// 750 ms composing-dots beat between every user chip tap and
  /// Form's reply — the "Form is thinking" cadence Phase 132 added.
  static const Duration _composingBeat = Duration(milliseconds: 750);

  /// The three coaching-tone tokens persisted to `wizardProvider`.
  static const List<_ChipChoice> _tones = [
    _ChipChoice(
      token: 'cesaretlendirici',
      label: 'Cesaret veren',
      userBubble: 'Cesaret veren',
    ),
    _ChipChoice(
      token: 'direkt',
      label: 'Net ve direkt',
      userBubble: 'Net ve direkt',
    ),
    _ChipChoice(
      token: 'sakin',
      label: 'Sakin, hatırlatan',
      userBubble: 'Sakin, hatırlatan',
    ),
  ];

  /// The three motivation-style tokens persisted to `wizardProvider`.
  /// Captures *why* the user is here so Form's downstream copy can
  /// echo their internal driver — outcome / process / identity.
  static const List<_ChipChoice> _motivations = [
    _ChipChoice(
      token: 'sonuc',
      label: 'Sonuçları görmek',
      userBubble: 'Sonuçları görmek',
    ),
    _ChipChoice(
      token: 'disiplin',
      label: 'Disiplin kurmak',
      userBubble: 'Disiplin kurmak',
    ),
    _ChipChoice(
      token: 'guc',
      label: 'Daha güçlü hissetmek',
      userBubble: 'Daha güçlü hissetmek',
    ),
  ];

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  late final ScrollController _scrollCtrl;

  /// Breathing radial atmosphere behind the chat. Slow (6.4 s)
  /// reverse-loop so the scene feels alive without ever competing
  /// with the bubbles for attention.
  late final AnimationController _atmosphereCtrl;

  /// True when name + tone were already captured on a prior visit.
  /// Collapses the whole cascade to its final state.
  late final bool _isReturning;

  bool _msg1Done = false;
  bool _msg2Done = false;
  bool _userNamePosted = false;
  bool _ackNameDone = false;
  bool _toneAskDone = false;
  bool _toneChosen = false;
  /// Gates the composing-dots beat between user tone-tap and Form's
  /// reply. Flips true after `_composingBeat` elapses; the tone-ack
  /// bubble doesn't render until then.
  bool _toneAckReady = false;
  bool _ackToneDone = false;
  bool _motivationAskDone = false;
  bool _motivationChosen = false;
  /// Same composing gate as `_toneAckReady`, for the motivation beat.
  bool _motivationAckReady = false;
  bool _ackMotivationDone = false;

  String _capturedName = '';
  String? _capturedToneToken;
  String _capturedToneBubble = '';
  String? _capturedMotivationToken;
  String _capturedMotivationBubble = '';

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(wizardProvider);
    final existingName = wizard.name ?? '';
    final existingTone = wizard.coachingTone;
    final existingMotivation = wizard.motivationStyle;
    _isReturning = existingName.isNotEmpty &&
        existingTone != null &&
        existingMotivation != null;

    _textCtrl = TextEditingController(text: existingName);
    _focusNode = FocusNode();
    _scrollCtrl = ScrollController();
    _atmosphereCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat(reverse: true);

    _textCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (_isReturning) {
      // Returning user with everything captured — collapse to "all
      // done" so we're ready to auto-advance. Pre-fill captured
      // fields in case the user backs out and re-enters.
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _ackNameDone = true;
      _toneAskDone = true;
      _toneChosen = true;
      _toneAckReady = true;
      _ackToneDone = true;
      _motivationAskDone = true;
      _motivationChosen = true;
      _motivationAckReady = true;
      _ackMotivationDone = true;
      _capturedName = existingName;
      _capturedToneToken = existingTone;
      _capturedToneBubble = _tones
          .firstWhere(
            (t) => t.token == existingTone,
            orElse: () => _tones.first,
          )
          .userBubble;
      _capturedMotivationToken = existingMotivation;
      _capturedMotivationBubble = _motivations
          .firstWhere(
            (m) => m.token == existingMotivation,
            orElse: () => _motivations.first,
          )
          .userBubble;
      // Returning users with the full cascade already captured see
      // their pre-filled answers briefly, then auto-advance —
      // typewriters are skipped (`!_isReturning`), so no
      // `onTypingComplete` callback fires to trigger the normal exit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !_ackMotivationDone) {
            // _ackMotivationDone is already true here from the
            // collapse above; flip it once via setState so the auto-
            // advance bookkeeping stays explicit and trace-able.
            setState(() => _ackMotivationDone = true);
            widget.onContinue();
          } else if (mounted) {
            widget.onContinue();
          }
        });
      });
    } else if (existingName.isNotEmpty && existingTone != null) {
      // Partial returning state: name + tone set, motivation not.
      // Jump to motivation-asking.
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _ackNameDone = true;
      _toneAskDone = true;
      _toneChosen = true;
      _toneAckReady = true;
      _ackToneDone = true;
      _capturedName = existingName;
      _capturedToneToken = existingTone;
      _capturedToneBubble = _tones
          .firstWhere(
            (t) => t.token == existingTone,
            orElse: () => _tones.first,
          )
          .userBubble;
    } else if (existingName.isNotEmpty) {
      // Earliest partial state: only name set. Jump to tone-asking.
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _ackNameDone = true;
      _capturedName = existingName;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _atmosphereCtrl.dispose();
    super.dispose();
  }

  void _onMsg1Done() {
    if (!mounted || _msg1Done) return;
    setState(() => _msg1Done = true);
    _scrollToEnd();
  }

  void _onMsg2Done() {
    if (!mounted || _msg2Done) return;
    setState(() => _msg2Done = true);
    _focusNode.requestFocus();
    _scrollToEnd();
  }

  void _submitName() {
    final name = _textCtrl.text.trim();
    if (name.isEmpty) return;
    AppHaptics.success();
    _focusNode.unfocus();
    ref.read(wizardProvider.notifier).setName(name);
    setState(() {
      _capturedName = name;
      _userNamePosted = true;
    });
    _scrollToEnd();
  }

  void _onAckNameDone() {
    if (!mounted || _ackNameDone) return;
    setState(() => _ackNameDone = true);
    _scrollToEnd();
  }

  void _onToneAskDone() {
    if (!mounted || _toneAskDone) return;
    setState(() => _toneAskDone = true);
    _scrollToEnd();
  }

  void _onToneTap(_ChipChoice choice) {
    if (!mounted || _toneChosen) return;
    AppHaptics.success();
    ref.read(wizardProvider.notifier).setCoachingTone(choice.token);
    setState(() {
      _capturedToneToken = choice.token;
      _capturedToneBubble = choice.userBubble;
      _toneChosen = true;
    });
    _scrollToEnd();
    // Composing-dots beat — Form "thinks" briefly before replying.
    // Skipped on returning users (they already saw the cascade).
    if (_isReturning) {
      setState(() => _toneAckReady = true);
      return;
    }
    Future<void>.delayed(_composingBeat, () {
      if (!mounted || _toneAckReady) return;
      setState(() => _toneAckReady = true);
      _scrollToEnd();
    });
  }

  void _onAckToneDone() {
    if (!mounted || _ackToneDone) return;
    setState(() => _ackToneDone = true);
    _scrollToEnd();
  }

  void _onMotivationAskDone() {
    if (!mounted || _motivationAskDone) return;
    setState(() => _motivationAskDone = true);
    _scrollToEnd();
  }

  void _onMotivationTap(_ChipChoice choice) {
    if (!mounted || _motivationChosen) return;
    AppHaptics.success();
    ref.read(wizardProvider.notifier).setMotivationStyle(choice.token);
    setState(() {
      _capturedMotivationToken = choice.token;
      _capturedMotivationBubble = choice.userBubble;
      _motivationChosen = true;
    });
    _scrollToEnd();
    if (_isReturning) {
      setState(() => _motivationAckReady = true);
      return;
    }
    Future<void>.delayed(_composingBeat, () {
      if (!mounted || _motivationAckReady) return;
      setState(() => _motivationAckReady = true);
      _scrollToEnd();
    });
  }

  void _onAckMotivationDone() {
    if (!mounted || _ackMotivationDone) return;
    setState(() => _ackMotivationDone = true);
    AppHaptics.success();
    // Closing dwell — let the user read the personalized line, then
    // advance.
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onContinue();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _normalizeForGreeting(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _toneAckText(String token, String name) {
    final n = _normalizeForGreeting(name);
    final prefix = n.isEmpty ? '' : '$n, ';
    return switch (token) {
      'cesaretlendirici' =>
        '${prefix}o zaman cesaret vererek yanında olacağım.',
      'direkt' => '${prefix}sana net ve direkt konuşacağım.',
      'sakin' => '${prefix}sakin sakin hatırlatacağım.',
      _ => '$prefix' 'öyle olsun.',
    };
  }

  String _motivationAckText(String token, String name) {
    final n = _normalizeForGreeting(name);
    final prefix = n.isEmpty ? '' : '$n, ';
    return switch (token) {
      'sonuc' => '${prefix}o zaman sonuçlar seninle olsun.',
      'disiplin' => '${prefix}birlikte güzel bir ritim kuracağız.',
      'guc' => '${prefix}her gün biraz daha güçlü hissedeceksin.',
      _ => '${prefix}anladım, seni bu yolda taşıyacağım.',
    };
  }

  CoachMood _currentMood() {
    if (!_userNamePosted) return CoachMood.listening;
    if (!_ackNameDone) return CoachMood.proud;
    if (!_toneChosen) return CoachMood.listening;
    if (!_ackToneDone) return CoachMood.proud;
    if (!_motivationChosen) return CoachMood.listening;
    return CoachMood.proud;
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050410)),
        // Phase 131 atmosphere · slow radial breath behind the chat,
        // anchored top-center. Same language as CinematicAiPresence
        // but lighter so the chat bubbles remain the focal point.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _atmosphereCtrl,
            builder: (context, _) {
              final t = Curves.easeInOutSine.transform(_atmosphereCtrl.value);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.15,
                    colors: [
                      AppColors.neon.withValues(alpha: 0.16 + 0.07 * t),
                      AppColors.neonAccent.withValues(alpha: 0.05 + 0.03 * t),
                      const Color(0xFF050410),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
        // Phase 132 atmosphere depth · second radial bloom anchored
        // bottom-right with `neonDeep`, breathing out of phase with
        // the primary. Adds layered depth + subtle asymmetry; tuned
        // very low (alpha ≤ 0.13) so it reads as ambient depth, not
        // as a competing light source.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _atmosphereCtrl,
            builder: (context, _) {
              final t = Curves.easeInOutSine.transform(
                1.0 - _atmosphereCtrl.value,
              );
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.35, 0.6),
                    radius: 0.85,
                    colors: [
                      AppColors.neonDeep.withValues(alpha: 0.07 + 0.06 * t),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
        const AmbientParticles(
          count: 12,
          color: AppColors.neon,
          minAlpha: 0.06,
          maxAlpha: 0.22,
          minRadius: 1.0,
          maxRadius: 2.2,
          driftDuration: Duration(seconds: 26),
          seed: 17,
        ),
        // Soft edge vignette — pulls the eye toward the centered
        // chat thread without darkening the chat surface itself.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.35,
                colors: [
                  Colors.transparent,
                  const Color(0xFF050410).withValues(alpha: 0.55),
                ],
                stops: const [0.60, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              CoachChatHeader(
                avatar: LivingCoachAvatar(
                  size: 44,
                  innerSize: 32,
                  mood: _currentMood(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CoachChatBubble(
                        text: _prompt1,
                        side: ChatBubbleSide.form,
                        typewriter: !_isReturning,
                        startDelay: const Duration(milliseconds: 250),
                        onTypingComplete: _onMsg1Done,
                      ),
                      if (_msg1Done) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _prompt2,
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          startDelay: const Duration(milliseconds: 250),
                          onTypingComplete: _onMsg2Done,
                        ),
                      ],
                      if (_userNamePosted) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _capturedName,
                          side: ChatBubbleSide.user,
                        ),
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: 'Tamam, '
                              '${_normalizeForGreeting(_capturedName)}.',
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          startDelay: const Duration(milliseconds: 400),
                          onTypingComplete: _onAckNameDone,
                        ),
                      ],
                      if (_ackNameDone) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _tonePrompt,
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          // Longer beat — Form is shifting topics.
                          startDelay: const Duration(milliseconds: 650),
                          onTypingComplete: _onToneAskDone,
                        ),
                      ],
                      if (_toneChosen) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _capturedToneBubble,
                          side: ChatBubbleSide.user,
                        ),
                        const SizedBox(height: 8),
                        if (!_toneAckReady)
                          const _ComposingBubble()
                        else
                          CoachChatBubble(
                            text: _toneAckText(
                              _capturedToneToken ?? '',
                              _capturedName,
                            ),
                            side: ChatBubbleSide.form,
                            typewriter: !_isReturning,
                            startDelay: const Duration(milliseconds: 200),
                            onTypingComplete: _onAckToneDone,
                          ),
                      ],
                      if (_ackToneDone) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _motivationPrompt,
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          // Slightly longer beat than the tone shift —
                          // the user is being asked to share something
                          // a touch more personal.
                          startDelay: const Duration(milliseconds: 700),
                          onTypingComplete: _onMotivationAskDone,
                        ),
                      ],
                      if (_motivationChosen) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _capturedMotivationBubble,
                          side: ChatBubbleSide.user,
                        ),
                        const SizedBox(height: 8),
                        if (!_motivationAckReady)
                          const _ComposingBubble()
                        else
                          CoachChatBubble(
                            text: _motivationAckText(
                              _capturedMotivationToken ?? '',
                              _capturedName,
                            ),
                            side: ChatBubbleSide.form,
                            typewriter: !_isReturning,
                            startDelay: const Duration(milliseconds: 200),
                            onTypingComplete: _onAckMotivationDone,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              _BottomComposer(
                showInput: !_userNamePosted,
                showChips: (_toneAskDone && !_toneChosen) ||
                    (_motivationAskDone && !_motivationChosen),
                textCtrl: _textCtrl,
                focusNode: _focusNode,
                inputEnabled: _msg2Done && !_userNamePosted,
                canSubmit: ctaEnabled,
                onSubmit: _submitName,
                chips: _motivationAskDone && !_motivationChosen
                    ? _motivations
                    : _tones,
                onChipTap: _motivationAskDone && !_motivationChosen
                    ? _onMotivationTap
                    : _onToneTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom anchor for the chat — either the name-input pill, or the
/// coaching-tone chip selector, or nothing (during the final ack
/// dwell before auto-advance). AnimatedSwitcher cross-fades between
/// them so the bottom never visually pops.
class _BottomComposer extends StatelessWidget {
  const _BottomComposer({
    required this.showInput,
    required this.showChips,
    required this.textCtrl,
    required this.focusNode,
    required this.inputEnabled,
    required this.canSubmit,
    required this.onSubmit,
    required this.chips,
    required this.onChipTap,
  });

  final bool showInput;
  final bool showChips;
  final TextEditingController textCtrl;
  final FocusNode focusNode;
  final bool inputEnabled;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final List<_ChipChoice> chips;
  final void Function(_ChipChoice) onChipTap;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (showInput) {
      child = _ChatInputPill(
        key: const ValueKey('input'),
        controller: textCtrl,
        focusNode: focusNode,
        enabled: inputEnabled,
        canSubmit: canSubmit,
        onSubmit: onSubmit,
      );
    } else if (showChips) {
      child = _ChipSelector(
        key: ValueKey('chips-${chips.first.token}'),
        chips: chips,
        onTap: onChipTap,
      );
    } else {
      child = const SizedBox(key: ValueKey('empty'), height: 0);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class _ChipChoice {
  const _ChipChoice({
    required this.token,
    required this.label,
    required this.userBubble,
  });
  final String token;
  final String label;
  final String userBubble;
}

/// Small left-aligned chat bubble holding three pulsing dots — the
/// "Form is composing a reply" beat between a user chip tap and
/// Form's typewritten ack. Same shape language as a Form-side
/// [CoachChatBubble] so the bubble silhouette doesn't pop when the
/// real ack bubble swaps in.
class _ComposingBubble extends StatelessWidget {
  const _ComposingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: AppColors.neon.withValues(alpha: 0.42),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neon.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: const ComposingDots(),
      ),
    );
  }
}

/// Three-row chip selector. Each chip is a soft neon-bordered pill
/// with a subtle glow — same visual language as the input pill so
/// the bottom of the chat reads as one consistent surface that just
/// changes contents. Used for both the coaching-tone beat and the
/// motivation-style beat; behaviour identical, parent decides which
/// chip set to pass in.
class _ChipSelector extends StatelessWidget {
  const _ChipSelector({
    super.key,
    required this.chips,
    required this.onTap,
  });

  final List<_ChipChoice> chips;
  final void Function(_ChipChoice) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ToneChipButton(choice: chips[i], onTap: () => onTap(chips[i])),
          ],
        ],
      ),
    );
  }
}

class _ToneChipButton extends StatelessWidget {
  const _ToneChipButton({required this.choice, required this.onTap});
  final _ChipChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: AppColors.neon.withValues(alpha: 0.20),
        highlightColor: AppColors.neon.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.neon.withValues(alpha: 0.42),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: 0.14),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Center(
              child: Text(
                choice.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-anchored chat input pill. Rounded TextField on the left,
/// a [GlowPulse] send button on the right that lights up when the
/// input is non-empty. Sticky to SafeArea bottom; rises with the
/// keyboard via Scaffold's default behaviour (NameCaptureStep is
/// hosted inside the wizard's Scaffold which has
/// `resizeToAvoidBottomInset: true` by default).
class _ChatInputPill extends StatelessWidget {
  const _ChatInputPill({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.canSubmit,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.neon.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neon.withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: false,
                maxLength: 32,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => canSubmit ? onSubmit() : null,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: AppColors.neon,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Adın',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GlowPulse(
            enabled: canSubmit,
            color: AppColors.neon,
            minAlpha: 0.40,
            maxAlpha: 0.65,
            minBlur: 18,
            maxBlur: 26,
            spread: 0,
            duration: const Duration(milliseconds: 2400),
            child: Material(
              color: canSubmit
                  ? AppColors.neon
                  : AppColors.neon.withValues(alpha: 0.30),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: canSubmit ? onSubmit : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: canSubmit
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    size: 22,
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
