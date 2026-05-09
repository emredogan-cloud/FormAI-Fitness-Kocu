import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wizard_provider.dart';
import '../widgets/interlude_scene.dart';

/// Act 3 · Strategic interlude #1 (post-goal predictive empathy).
///
/// Lives between the goal step and the experience step. Form reads
/// the user's goal selection and reflects back a short observation
/// that sounds like understanding rather than acknowledgment. The
/// audit calls this *predictive empathy*: not "great choice!", but
/// "people who pick this struggle with X — I won't do that to you."
///
/// Copy is goal-aware, name-aware. Soft fallback when either is null
/// (returning user, edge cases) so the screen never reads as broken.
class InterludeAfterGoalStep extends ConsumerWidget {
  const InterludeAfterGoalStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    return InterludeScene(
      text: _composeText(wizard),
      onContinue: onContinue,
    );
  }

  String _composeText(WizardState s) {
    final name = _capitaliseFirst(s.name);
    final prefix = name != null ? '$name, ' : '';
    final body = switch (s.goal) {
      'belly_burn' =>
        'yağ kaybı çoğu zaman süreklilikle zorlanır.\n'
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
