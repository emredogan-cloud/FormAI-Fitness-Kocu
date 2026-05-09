import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wizard_provider.dart';
import '../widgets/multi_select_question_step.dart';

/// Phase 111 · emotional self-recognition step.
///
/// Reference timestamp: ~0:35–0:50 (Unrot's "feelings after scrolling"
/// multi-select). Adapted for fitness self-image — the user picks
/// every feeling that resonates, claiming the emotional starting
/// point of their journey before goal declaration.
///
/// Sits between gender (demographic) and goal (intent). The order is
/// deliberate: the user identifies *how they feel about themselves*
/// before being asked *what they want to change*. Goal declaration
/// then carries the emotional weight of the feelings that preceded
/// it.
///
/// Eight options covering the most emotionally loaded fitness
/// self-statements. Multi-select with min 1 selection — the user
/// has to acknowledge at least one feeling for the CTA to enable.
/// Empty selections fall back gracefully (the engine treats an empty
/// `bodyFeelings` as "no signal" and doesn't branch on it).
class BodyFeelingsStep extends ConsumerWidget {
  const BodyFeelingsStep({super.key, required this.onCommitted});
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = ref.watch(wizardProvider).bodyFeelings;
    return MultiSelectQuestionStep(
      title: 'Şu sıralar kendinle ilgili neler hissediyorsun?',
      subtitle: 'Sana tanıdık gelenleri seç. Birden fazla seçebilirsin.',
      initialSelected: initial,
      options: const [
        MultiSelectOption(
          value: 'tired',
          label: 'Yorgunum',
          emoji: '😟',
        ),
        MultiSelectOption(
          value: 'lost_form',
          label: 'Form bende kayboldu',
          emoji: '💔',
        ),
        MultiSelectOption(
          value: 'low_discipline',
          label: 'Disiplinim tutmuyor',
          emoji: '😤',
        ),
        MultiSelectOption(
          value: 'low_energy',
          label: 'Enerjim düşük',
          emoji: '😴',
        ),
        MultiSelectOption(
          value: 'mirror_avoid',
          label: 'Aynaya bakmak zor geliyor',
          emoji: '🪞',
        ),
        MultiSelectOption(
          value: 'dont_know_start',
          label: 'Nereden başlayacağımı bilmiyorum',
          emoji: '🤷',
        ),
        MultiSelectOption(
          value: 'want_old_self',
          label: 'Eski hâlimi geri istiyorum',
          emoji: '💪',
        ),
        MultiSelectOption(
          value: 'want_better',
          label: 'Daha iyi hissetmek istiyorum',
          emoji: '🌱',
        ),
      ],
      onCommitted: (selected) {
        ref.read(wizardProvider.notifier).setBodyFeelings(selected);
        onCommitted();
      },
    );
  }
}
