import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    ref.read(coachChatProvider.notifier).send(text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final turns = ref.watch(coachChatProvider);
    final suggestions = ref.read(coachChatProvider.notifier).suggestions;

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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Form',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text('AI Koçun · çevrimiçi',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
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
              itemCount: turns.length,
              itemBuilder: (_, i) => _Bubble(turn: turns[i]),
            ),
          ),
          if (turns.length <= 1)
            _SuggestionRow(suggestions: suggestions, onTap: _send),
          _InputBar(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final CoachTurn turn;

  @override
  Widget build(BuildContext context) {
    final coach = turn.fromCoach;
    return Align(
      alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
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
        child: Text(turn.text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
                fontWeight: coach ? FontWeight.w500 : FontWeight.w600)),
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
          onPressed: () => onTap(suggestions[i].intent),
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
                  hintText: "Form'a bir şey sor…",
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
