import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/cinematic_ai_presence.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';

/// Act 3 · Strategic interlude #1 (post-goal predictive empathy).
///
/// Lives between the goal step and the experience step. Form reads
/// the user's goal selection and reflects back a short observation
/// that sounds like understanding rather than acknowledgment. The
/// audit calls this *predictive empathy*: not "great choice!", but
/// "people who pick this struggle with X — I won't do that to you."
///
/// Phase 129 · migrated from the legacy [InterludeScene] widget onto
/// the shared [CinematicAiPresence] system so every AI-presence beat
/// in the product reads as one continuous cinematic register. The
/// per-goal body text is preserved verbatim in the subtitle slot;
/// the title carries a presence header ("Anlıyorum...") and the chat
/// bar carries the "Form is writing" illusion.
class InterludeAfterGoalStep extends ConsumerWidget {
  const InterludeAfterGoalStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    return CinematicAiPresence(
      title: 'Anlıyorum...',
      subtitle: _composeSubtitle(wizard),
      subtitleTypewriter: true,
      composingPlaceholder: 'Düşüncelerimi topluyorum...',
      // Form is reassuring the user about their goal — warmer halo,
      // slower breath, slight inward settle. Reads as "I hear you."
      mood: CoachMood.reassuring,
      autoCloseAfter: const Duration(milliseconds: 6500),
      onComplete: onContinue,
    );
  }

  String _composeSubtitle(WizardState s) {
    final name = _capitaliseFirst(s.name);
    final prefix = name != null ? '$name, ' : '';
    final body = switch (s.goal) {
      'belly_burn' => 'yağ kaybı çoğu zaman süreklilikle zorlanır.\n'
          'Sana ağır başlayan bir plan kurmayacağım.',
      'muscle_gain' => 'kas büyütmek sabır işidir.\n'
          'Acelesi olmayan ama kararlı bir program kuracağım.',
      'fitness_look' => "'fit görünmek' aslında "
          "'kendinde rahat hissetmek' demek.\nPlana onu yansıtacağım.",
      'strength' => 'güç temeli yavaş atılır.\n'
          'Aceleye getirmeyen bir program kurarım.',
      _ => 'hedefini gördüm.\nBuna göre planı şekillendireceğim.',
    };
    return prefix + body;
  }

  String? _capitaliseFirst(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
