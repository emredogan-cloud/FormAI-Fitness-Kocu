import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_chat_bubble.dart';
import '../widgets/coach_mood.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.5 · Name capture + coaching-tone bonding (chat-format).
///
/// Phase 109 first version: chat-thread asking the user's name, Form
/// acknowledged it, auto-advanced.
///
/// Phase 131 evolution: the chat continues one beat further so Form
/// actually *gets to know* the user before the data-collection arc.
/// After Form acknowledges the name, it asks one short bonding
/// question — "Yanında nasıl olmamı istersin?" — with three single-tap
/// tone chips ("Cesaret veren" / "Net ve direkt" / "Sakin, hatırlatan").
/// The chip choice persists to `wizardProvider.coachingTone` so the
/// rest of the wizard can speak in that register, and Form
/// acknowledges the choice with a tone-specific closing line before
/// auto-advancing.
///
/// Why one extra question and not two: the user explicitly framed
/// this as "emotional bonding, NOT survey fatigue." One question that
/// shapes how Form speaks afterward earns its place in the flow; a
/// second would start tipping into questionnaire territory.
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

  /// The three coaching-tone tokens persisted to `wizardProvider`.
  static const List<_ToneChoice> _tones = [
    _ToneChoice(
      token: 'cesaretlendirici',
      label: 'Cesaret veren',
      userBubble: 'Cesaret veren',
    ),
    _ToneChoice(
      token: 'direkt',
      label: 'Net ve direkt',
      userBubble: 'Net ve direkt',
    ),
    _ToneChoice(
      token: 'sakin',
      label: 'Sakin, hatırlatan',
      userBubble: 'Sakin, hatırlatan',
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
  bool _ackToneDone = false;

  String _capturedName = '';
  String? _capturedToneToken;
  String _capturedToneBubble = '';

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(wizardProvider);
    final existingName = wizard.name ?? '';
    final existingTone = wizard.coachingTone;
    _isReturning = existingName.isNotEmpty && existingTone != null;

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
      // Returning user — collapse to "all done" so we're ready to
      // auto-advance. Pre-fill the captured fields too in case the
      // user backs out and re-enters.
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _ackNameDone = true;
      _toneAskDone = true;
      _toneChosen = true;
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
      // Partial returning state: name set, tone not. Skip the name
      // capture beat and jump to tone-asking.
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

  void _onToneTap(_ToneChoice choice) {
    if (!mounted || _toneChosen) return;
    AppHaptics.success();
    ref.read(wizardProvider.notifier).setCoachingTone(choice.token);
    setState(() {
      _capturedToneToken = choice.token;
      _capturedToneBubble = choice.userBubble;
      _toneChosen = true;
    });
    _scrollToEnd();
  }

  void _onAckToneDone() {
    if (!mounted || _ackToneDone) return;
    setState(() => _ackToneDone = true);
    AppHaptics.success();
    // Closing dwell — let the user read the personalized line, then
    // advance.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
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

  CoachMood _currentMood() {
    if (!_userNamePosted) return CoachMood.listening;
    if (!_ackNameDone) return CoachMood.proud;
    if (!_toneChosen) return CoachMood.listening;
    return CoachMood.proud;
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050410)),
        // Phase 131 atmosphere · slow radial breath behind the chat.
        // Same language as CinematicAiPresence but lighter (smaller
        // alpha range, no second-color stop) so the chat surface
        // never starts competing with the bubbles for focus.
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
                      AppColors.neon.withValues(alpha: 0.14 + 0.06 * t),
                      AppColors.neonAccent.withValues(alpha: 0.04 + 0.03 * t),
                      const Color(0xFF050410),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
        const AmbientParticles(
          count: 8,
          color: AppColors.neon,
          minAlpha: 0.06,
          maxAlpha: 0.20,
          minRadius: 1.0,
          maxRadius: 2.0,
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
                        CoachChatBubble(
                          text: _toneAckText(
                            _capturedToneToken ?? '',
                            _capturedName,
                          ),
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          startDelay: const Duration(milliseconds: 400),
                          onTypingComplete: _onAckToneDone,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _BottomComposer(
                showInput: !_userNamePosted,
                showChips: _toneAskDone && !_toneChosen,
                textCtrl: _textCtrl,
                focusNode: _focusNode,
                inputEnabled: _msg2Done && !_userNamePosted,
                canSubmit: ctaEnabled,
                onSubmit: _submitName,
                tones: _tones,
                onToneTap: _onToneTap,
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
    required this.tones,
    required this.onToneTap,
  });

  final bool showInput;
  final bool showChips;
  final TextEditingController textCtrl;
  final FocusNode focusNode;
  final bool inputEnabled;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final List<_ToneChoice> tones;
  final void Function(_ToneChoice) onToneTap;

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
      child = _ToneChips(
        key: const ValueKey('chips'),
        tones: tones,
        onTap: onToneTap,
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

class _ToneChoice {
  const _ToneChoice({
    required this.token,
    required this.label,
    required this.userBubble,
  });
  final String token;
  final String label;
  final String userBubble;
}

/// Three-row coaching-tone chip selector. Each chip is a soft neon-
/// bordered pill with a subtle glow — same visual language as the
/// input pill so the bottom of the chat reads as one consistent
/// surface that just changes contents.
class _ToneChips extends StatelessWidget {
  const _ToneChips({
    super.key,
    required this.tones,
    required this.onTap,
  });

  final List<_ToneChoice> tones;
  final void Function(_ToneChoice) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tones.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ToneChipButton(choice: tones[i], onTap: () => onTap(tones[i])),
          ],
        ],
      ),
    );
  }
}

class _ToneChipButton extends StatelessWidget {
  const _ToneChipButton({required this.choice, required this.onTap});
  final _ToneChoice choice;
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
