import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/ambient_particles.dart';
import '../../../../core/motion/glow_pulse.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coach/providers/coach_providers.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_chat_bubble.dart';
import '../widgets/coach_mood.dart';
import '../widgets/composing_dots.dart';
import '../widgets/living_coach_avatar.dart';

/// Act 2.5 · Name capture + emotional-reframe micro-conversation
/// (chat-format).
///
/// Two beats:
///
///   1. **Name** — Form asks the user's name. Captured as
///      `wizardProvider.name`.
///
///   2. **Emotional reframe** — Form asks what's tiring the user
///      right now. Three chips: `dongu` (stuck in the same loop),
///      `gormek` (can't see results), `yalniz` (loneliness). Captured
///      as `wizardProvider.coachingTone` (field name preserved for
///      schema continuity — semantics shifted from coaching-style to
///      emotional-burden in the May 2026 redesign).
///
/// After the user picks a chip, Form delivers a five-message
/// sequential cascade — acknowledge → confirm understanding →
/// companion offer → future-self pull → transition — then
/// auto-advances. The messages branch on the chip token so the
/// language reads as a real coach reacting to the specific pain the
/// user named, not a generic motivation script.
///
/// Mood progression:
///
///   • Phase A (asking name)        → CoachMood.listening
///   • Phase B (name acknowledged)  → CoachMood.proud (briefly)
///   • Phase C (asking reframe)     → CoachMood.listening
///   • Phase D (cascade running)    → CoachMood.proud
///
/// Re-entry: when both `name` and `coachingTone` already exist
/// (back-nav), the cascade collapses to its final state — all
/// bubbles pre-rendered, input/chips hidden, ready for
/// `onContinue`.

class NameCaptureStep extends ConsumerStatefulWidget {
  const NameCaptureStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<NameCaptureStep> createState() => _NameCaptureStepState();
}

class _NameCaptureStepState extends ConsumerState<NameCaptureStep>
    with SingleTickerProviderStateMixin {
  // RC-1 P7 · Form introduces itself briefly, then asks the name. The
  // acknowledgment replies are REAL LLM turns (coach-chat) with these
  // scripted lines as instant offline fallbacks — onboarding never waits
  // on the network beyond one composing beat.
  String get _prompt1 => AppLocalizations.of(context).nameCaptureIntro;
  String get _prompt2 => AppLocalizations.of(context).nameCaptureAsk;
  String get _reframePrompt =>
      AppLocalizations.of(context).nameCaptureReframeAsk;

  /// 750 ms composing-dots beat between every user chip tap and
  /// Form's reply, and between each AI cascade message.
  static const Duration _composingBeat = Duration(milliseconds: 750);

  /// The three emotional-reframe tokens captured in beat 2.
  static List<_ChipChoice> _reframeChoicesFor(AppLocalizations l10n) => [
        _ChipChoice(
          token: 'dongu',
          label: l10n.nameCaptureChipLoop,
          userBubble: l10n.nameCaptureChipLoop,
        ),
        _ChipChoice(
          token: 'gormek',
          label: l10n.nameCaptureChipResults,
          userBubble: l10n.nameCaptureChipResults,
        ),
        _ChipChoice(
          token: 'yalniz',
          label: l10n.nameCaptureChipAlone,
          userBubble: l10n.nameCaptureChipAlone,
        ),
      ];

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  late final ScrollController _scrollCtrl;

  /// Breathing radial atmosphere behind the chat.
  late final AnimationController _atmosphereCtrl;

  /// True when name + reframe were already captured on a prior visit.
  late final bool _isReturning;

  bool _msg1Done = false;
  bool _msg2Done = false;
  bool _userNamePosted = false;
  bool _nameAckReady = false;
  bool _ackNameDone = false;
  bool _reframeAskDone = false;
  bool _reframeChosen = false;
  bool _ackReady = false;
  bool _ackDone = false;
  bool _transitionReady = false;
  bool _transitionDone = false;

  String _capturedName = '';
  String? _capturedReframeToken;

  /// Live Claude replies for the two acknowledgment beats — null means the
  /// scripted fallback line renders instead (offline / LLM off / slow).
  String? _llmNameAck;
  String? _llmReframeAck;

  @override
  void initState() {
    super.initState();
    final wizard = ref.read(wizardProvider);
    final existingName = wizard.name ?? '';
    final existingReframe = wizard.coachingTone;
    _isReturning = existingName.isNotEmpty && existingReframe != null;

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
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _nameAckReady = true;
      _ackNameDone = true;
      _reframeAskDone = true;
      _reframeChosen = true;
      _ackReady = true;
      _ackDone = true;
      _transitionReady = true;
      _transitionDone = true;
      _capturedName = existingName;
      _capturedReframeToken = existingReframe;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) widget.onContinue();
        });
      });
    } else if (existingName.isNotEmpty) {
      // Partial returning state: only name set. Jump to reframe-asking.
      _msg1Done = true;
      _msg2Done = true;
      _userNamePosted = true;
      _nameAckReady = true;
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
    // RC-1 P7 · the welcome is a REAL Form turn: ask the live coach for a
    // one-line personalised greeting while the composing dots show. The
    // beat lasts at least one composing cadence, at most the LLM timeout;
    // a null reply keeps the scripted fallback. Onboarding cannot stall.
    final llm = onboardingCoachReply(
      // Prompt scaffolding, not UI copy — never rendered. Per-locale
      // prompts are Phase 7's job; `onboardingCoachReply` already
      // threads the locale to the server-side persona registry.
      'Kullanıcı adını söyledi: "$name". Ona adıyla hitap ederek tek cümlelik '
      'sıcak bir hoş geldin ver. Soru sorma, uzatma — bir sonraki adıma ben ' // i18n-ignore
      'geçeceğim.', // i18n-ignore
    );
    Future.wait<dynamic>([llm, Future<void>.delayed(_composingBeat)])
        .then((results) {
      if (!mounted || _nameAckReady) return;
      setState(() {
        _llmNameAck = results.first as String?;
        _nameAckReady = true;
      });
      _scrollToEnd();
    });
  }

  void _onAckNameDone() {
    if (!mounted || _ackNameDone) return;
    setState(() => _ackNameDone = true);
    _scrollToEnd();
  }

  void _onReframeAskDone() {
    if (!mounted || _reframeAskDone) return;
    setState(() => _reframeAskDone = true);
    _scrollToEnd();
  }

  void _onReframeTap(_ChipChoice choice) {
    if (!mounted || _reframeChosen) return;
    AppHaptics.success();
    ref.read(wizardProvider.notifier).setCoachingTone(choice.token);
    setState(() {
      _capturedReframeToken = choice.token;
      _reframeChosen = true;
    });
    _scrollToEnd();
    // RC-1 P7 · empathetic acknowledgment is a live Form turn too —
    // referencing the user's name AND what they said tires them most.
    // Scripted _ackText stays as the instant fallback.
    final llm = onboardingCoachReply(
      // Prompt scaffolding, not UI copy — see above.
      'Kullanıcının adı: "$_capturedName". "Şu an seni en çok ne yoruyor?" '
      'sorusuna "${choice.userBubble}" diye cevap verdi. Bunu duyduğunu '
      'hissettiren, adıyla hitap eden, 1-2 cümlelik empatik ve umut veren ' // i18n-ignore
      'bir yanıt ver. Soru sorma.', // i18n-ignore
    );
    Future.wait<dynamic>([llm, Future<void>.delayed(_composingBeat)])
        .then((results) {
      if (!mounted || _ackReady) return;
      setState(() {
        _llmReframeAck = results.first as String?;
        _ackReady = true;
      });
      _scrollToEnd();
    });
  }

  void _onAckDone() {
    if (!mounted || _ackDone) return;
    setState(() => _ackDone = true);
    _scrollToEnd();
    // RC-1 P7 · the confirm/companion/future monologue beats are CUT —
    // the first conversation stays short. Straight to the transition line.
    _scheduleNext(
      () => _transitionReady,
      () => setState(() => _transitionReady = true),
    );
  }

  void _onTransitionDone() {
    if (!mounted || _transitionDone) return;
    setState(() => _transitionDone = true);
    AppHaptics.success();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onContinue();
    });
  }

  /// Composing-dots beat scheduler. On returning users we skip the
  /// beat entirely so the cascade collapses to its final state
  /// without re-pacing through the typewriter cadence.
  void _scheduleNext(bool Function() isReady, VoidCallback flip) {
    if (_isReturning) {
      if (!isReady()) flip();
      return;
    }
    Future<void>.delayed(_composingBeat, () {
      if (!mounted || isReady()) return;
      flip();
      _scrollToEnd();
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

  /// The user's own answer bubble, resolved from the stored token
  /// rather than remembered as text — a token survives a locale change,
  /// a captured sentence would not.
  String _reframeBubbleFor(String? token) {
    final choices = _reframeChoicesFor(AppLocalizations.of(context));
    return choices
        .firstWhere((c) => c.token == token, orElse: () => choices.first)
        .userBubble;
  }

  String _normalizeForGreeting(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Message 1 of the cascade — empathic acknowledgment that names
  /// the pain back to the user so they feel heard before Form
  /// reframes it.
  String _ackText(String token, String name) {
    final l10n = AppLocalizations.of(context);
    final n = _normalizeForGreeting(name);
    // Both entry points guard on a non-empty name, but the no-name
    // sentence exists so a future caller cannot open the line with a
    // stray comma.
    if (n.isEmpty) return l10n.nameCaptureAckGenericNoName;
    return switch (token) {
      'dongu' => l10n.nameCaptureAckLoop(n),
      'gormek' => l10n.nameCaptureAckResults(n),
      'yalniz' => l10n.nameCaptureAckAlone(n),
      _ => l10n.nameCaptureAckGeneric(n),
    };
  }

  /// to the next onboarding step ("now I'm building your plan").
  String _transitionText(String name) {
    final l10n = AppLocalizations.of(context);
    final n = _normalizeForGreeting(name);
    if (n.isEmpty) return l10n.nameCaptureTransitionNoName;
    return l10n.nameCaptureTransition(n);
  }

  CoachMood _currentMood() {
    if (!_userNamePosted) return CoachMood.listening;
    if (!_ackNameDone) return CoachMood.proud;
    if (!_reframeChosen) return CoachMood.listening;
    return CoachMood.proud;
  }

  @override
  Widget build(BuildContext context) {
    final ctaEnabled = _textCtrl.text.trim().isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF050410)),
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
                        if (!_nameAckReady)
                          const _ComposingBubble()
                        else
                          CoachChatBubble(
                            text: _llmNameAck ??
                                AppLocalizations.of(context).nameCaptureWelcome(
                                  _normalizeForGreeting(_capturedName),
                                ),
                            side: ChatBubbleSide.form,
                            typewriter: !_isReturning,
                            startDelay: const Duration(milliseconds: 200),
                            onTypingComplete: _onAckNameDone,
                          ),
                      ],
                      if (_ackNameDone) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _reframePrompt,
                          side: ChatBubbleSide.form,
                          typewriter: !_isReturning,
                          startDelay: const Duration(milliseconds: 650),
                          onTypingComplete: _onReframeAskDone,
                        ),
                      ],
                      if (_reframeChosen) ...[
                        const SizedBox(height: 8),
                        CoachChatBubble(
                          text: _reframeBubbleFor(_capturedReframeToken),
                          side: ChatBubbleSide.user,
                        ),
                        const SizedBox(height: 8),
                        if (!_ackReady)
                          const _ComposingBubble()
                        else
                          CoachChatBubble(
                            text: _llmReframeAck ??
                                _ackText(
                                  _capturedReframeToken ?? '',
                                  _capturedName,
                                ),
                            side: ChatBubbleSide.form,
                            typewriter: !_isReturning,
                            startDelay: const Duration(milliseconds: 200),
                            onTypingComplete: _onAckDone,
                          ),
                      ],
                      if (_ackDone) ...[
                        const SizedBox(height: 8),
                        if (!_transitionReady)
                          const _ComposingBubble()
                        else
                          CoachChatBubble(
                            text: _transitionText(_capturedName),
                            side: ChatBubbleSide.form,
                            typewriter: !_isReturning,
                            startDelay: const Duration(milliseconds: 200),
                            onTypingComplete: _onTransitionDone,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              _BottomComposer(
                showInput: !_userNamePosted,
                showChips: _reframeAskDone && !_reframeChosen,
                textCtrl: _textCtrl,
                focusNode: _focusNode,
                inputEnabled: _msg2Done && !_userNamePosted,
                canSubmit: ctaEnabled,
                onSubmit: _submitName,
                chips: _reframeChoicesFor(AppLocalizations.of(context)),
                onChipTap: _onReframeTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom anchor for the chat — either the name-input pill, the
/// reframe chip selector, or nothing (during the AI-cascade dwell
/// before auto-advance). AnimatedSwitcher cross-fades between them
/// so the bottom never visually pops.
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
/// "Form is composing a reply" beat between every chip tap / AI
/// message hand-off. Same shape language as a Form-side
/// [CoachChatBubble] so the bubble silhouette doesn't pop when the
/// real bubble swaps in.
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
/// changes contents.
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
/// input is non-empty.
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
                  hintText: AppLocalizations.of(context).nameCaptureHint,
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
