import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/coach_brain.dart';
import '../providers/coach_providers.dart';

const Color _neon = Color(0xFF8E5BFF);
const Color _bg = Color(0xFF0A0612);
const Color _coachBubble = Color(0xFF17131F);

/// The persistent, always-reachable AI coach. Renders the live conversation
/// from [coachChatProvider]; the "intelligence" is entirely in the brain
/// behind that provider, so this screen is unchanged when the rule-based
/// brain is replaced by an LLM.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    _scrollToBottomSoon();
    // Fire the async turn; scroll again when the reply (or fallback) lands.
    ref.read(coachChatProvider.notifier).send(text).then((_) {
      if (mounted) _scrollToBottomSoon();
    });
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Turns already revealed — the newest coach bubble beyond this count gets
  /// the typewriter entrance, then is marked revealed so it never replays.
  int _revealedCount = 0;

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(coachChatProvider);
    final turns = chat.turns;
    final suggestions = ref.read(coachChatProvider.notifier).suggestions;
    // Seed: the greeting (and any restored turns) render statically.
    if (_revealedCount == 0 && turns.isNotEmpty) _revealedCount = turns.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _neon.withValues(alpha: 0.6)),
              ),
              child: ClipOval(
                child: Image.asset('photos/PT_FORM.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.smart_toy, color: _neon, size: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 'Form' is the coach's name — a brand term, never
                // translated. See the Phase 5 glossary.
                const Text('Form', // i18n-ignore
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text(AppLocalizations.of(context).coachHeaderStatus,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              // A trailing typing bubble while the coach is thinking.
              itemCount: turns.length + (chat.sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= turns.length) return const _TypingBubble();
                final turn = turns[i];
                final animate =
                    turn.fromCoach && i >= _revealedCount && !chat.sending;
                return _Bubble(
                  key: ValueKey('turn-$i'),
                  turn: turn,
                  animate: animate,
                  onRevealed:
                      animate ? () => _revealedCount = turns.length : null,
                );
              },
            ),
          ),
          if (turns.length <= 1 && !chat.sending)
            _SuggestionRow(suggestions: suggestions, onTap: _send),
          _InputBar(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble(
      {super.key, required this.turn, this.animate = false, this.onRevealed});
  final CoachTurn turn;

  /// Typewriter-reveal the text (newest coach reply only).
  final bool animate;
  final VoidCallback? onRevealed;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    final coach = turn.fromCoach;
    final at = turn.at;
    final body = coach
        ? _RichCoachText(text: turn.text)
        : Text(turn.text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600));

    return Column(
      crossAxisAlignment:
          coach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Align(
          alignment: coach
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: coach ? _coachBubble : _neon,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(coach ? 4 : 16),
                bottomRight: Radius.circular(coach ? 16 : 4),
              ),
              border: coach
                  ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                  : null,
            ),
            child: widget.animate && !_done
                ? _TypewriterReveal(
                    text: turn.text,
                    builder: (visible) => _RichCoachText(text: visible),
                    onDone: () {
                      _done = true;
                      widget.onRevealed?.call();
                    },
                  )
                : body,
          ),
        ),
        if (at != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4).copyWith(bottom: 10),
            child: Text(
              '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          )
        else
          const SizedBox(height: 10),
      ],
    );
  }
}

/// ChatGPT-style entrance: the (already complete) reply types itself in over
/// ~a second. Purely visual — the text is final before the animation starts,
/// so nothing here can desync from the model output.
class _TypewriterReveal extends StatefulWidget {
  const _TypewriterReveal(
      {required this.text, required this.builder, required this.onDone});
  final String text;
  final Widget Function(String visible) builder;
  final VoidCallback onDone;

  @override
  State<_TypewriterReveal> createState() => _TypewriterRevealState();
}

class _TypewriterRevealState extends State<_TypewriterReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // ~8 ms/char, capped so long structured replies don't drag.
    duration: Duration(
        milliseconds: (widget.text.length * 8).clamp(300, 1400).toInt()),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final n = (widget.text.length * _c.value).round();
        return widget.builder(widget.text.substring(0, n));
      },
    );
  }
}

/// Lightweight rich renderer for coach replies. The persona instructs the
/// model to emit a constrained format — emoji-headed section lines, `•`
/// bullets, and `**bold**` — so a tiny deterministic parser covers it with no
/// markdown dependency. Anything unrecognised falls through as plain text,
/// which also keeps the rule-brain's plain replies rendering identically.
class _RichCoachText extends StatelessWidget {
  const _RichCoachText({required this.text});
  final String text;

  static const _base = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500);
  static const _header = TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w900);

  bool _isHeader(String line) {
    if (line.length > 48 || line.isEmpty) return false;
    final r = line.runes.first;
    return r >= 0x2190; // arrows/symbols/emoji block onward — never TR letters
  }

  /// `**bold**` → bold spans; everything else keeps [style].
  List<TextSpan> _inline(String line, TextStyle style) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var idx = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: line.substring(idx, m.start), style: style));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: style.copyWith(fontWeight: FontWeight.w800)));
      idx = m.end;
    }
    if (idx < line.length) {
      spans.add(TextSpan(text: line.substring(idx), style: style));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trimRight();
      final line = raw.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      if (_isHeader(line)) {
        children.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 2),
          child: Text.rich(TextSpan(children: _inline(line, _header))),
        ));
        continue;
      }
      if (line.startsWith('• ') || line.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•',
                  style: TextStyle(
                      color: _neon, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                    TextSpan(children: _inline(line.substring(2), _base))),
              ),
            ],
          ),
        ));
        continue;
      }
      children.add(Text.rich(TextSpan(children: _inline(line, _base))));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children);
  }
}

/// Three pulsing dots in a coach bubble while the model is thinking. Mirrors
/// the app's existing spinners (which also animate through reduce-motion) —
/// a chat affordance the user expects to see move.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _coachBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(3, (i) {
                final t = (_c.value + i * 0.2) % 1.0;
                final o =
                    (0.3 + 0.7 * (0.5 - (t - 0.5).abs()) * 2).clamp(0.3, 1.0);
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 5),
                  child: Opacity(
                    opacity: o,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _neon,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(AppLocalizations.of(context).coachTyping,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onTap});
  final List<CoachSuggestion> suggestions;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i].label),
          labelStyle: const TextStyle(color: _neon, fontSize: 13),
          backgroundColor: _neon.withValues(alpha: 0.12),
          side: BorderSide(color: _neon.withValues(alpha: 0.4)),
          // Send the human-readable label (not the terse intent) so the
          // user's own bubble reads naturally and the LLM gets real language.
          onPressed: () => onTap(suggestions[i].label),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).coachInputHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _coachBubble,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _neon,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSend(controller.text),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
