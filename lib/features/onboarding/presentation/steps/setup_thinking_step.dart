import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/cinematic_ai_presence.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';

/// Act 2.7 · Form's thinking moment.
///
/// Phase 110 first version: ambient particles + composing-dots bubble
/// + kinetic-text reveal of a personalized setup line. Worked, but
/// the visual mechanics were a single bubble — no AI-presence ring,
/// no chat-input illusion.
///
/// Phase 125 refactor: this step is now a thin call-site over
/// [CinematicAiPresence] — the reusable cinematic AI-presence
/// system. Visual mechanics (neon ring stack, atmosphere breath,
/// glassmorphism chat-input bar, blinking cursor) come from the
/// shared widget; this file just maps wizard state → scene props:
///
///   • title         = "Düşünüyorum..." (universal AI status)
///   • subtitle      = the personalized setup line, type-writer'd
///   • placeholder   = "Sana bir şey yazıyor..." (chat bar illusion)
///   • mood          = thinking (cool accent, faster pulse)
///   • autoClose     = 6.5 s (settles after the ~2.8 s subtitle type)
///   • onComplete    = success haptic → advance
///
/// Name personalization preserved from Phase 110.
class SetupThinkingStep extends ConsumerStatefulWidget {
  const SetupThinkingStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  ConsumerState<SetupThinkingStep> createState() =>
      _SetupThinkingStepState();
}

class _SetupThinkingStepState extends ConsumerState<SetupThinkingStep> {
  bool _advanced = false;

  void _onAutoClose() {
    if (!mounted || _advanced) return;
    _advanced = true;
    AppHaptics.success();
    widget.onContinue();
  }

  String _composeSubtitle(WizardState s) {
    final name = _capitaliseFirst(s.name);
    if (name != null) {
      return '$name, senden birkaç şey öğrenmem gerekiyor. '
          'Plan tamamen sana özel olacak.';
    }
    return 'Senden birkaç şey öğrenmem gerekiyor. '
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
    return CinematicAiPresence(
      title: 'Düşünüyorum...',
      subtitle: _composeSubtitle(wizard),
      subtitleTypewriter: true,
      composingPlaceholder: 'Sana bir şey yazıyor...',
      mood: CoachMood.thinking,
      autoCloseAfter: const Duration(milliseconds: 6500),
      onComplete: _onAutoClose,
    );
  }
}
