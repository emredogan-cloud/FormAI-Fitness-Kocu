import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../widgets/interlude_scene.dart';

/// Act 3 · Strategic interlude #2 (vulnerability setup before
/// pain-point).
///
/// Lives between physical_data and pain_point. Pain-point is the
/// most emotionally loaded answer in the wizard — Form sets up the
/// vulnerability before asking. Frames the question as collaborative
/// ("birlikte çözmek için"), not interrogative ("yargılamak için
/// değil"). Removes the shame layer the audit (§3.6) flagged.
class InterludeBeforePainPointStep extends ConsumerWidget {
  const InterludeBeforePainPointStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    final name = _capitaliseFirst(wizard.name);
    final opener = name != null
        ? '$name, şimdi en zorlandığın şeyi bilmem gerekiyor.'
        : 'Şimdi en zorlandığın şeyi bilmem gerekiyor.';
    return InterludeScene(
      text: '$opener\nYargılamak için değil — birlikte çözmek için.',
      onContinue: onContinue,
      // Form is preparing the user for the most vulnerable answer —
      // dimmer, slower, deepest tone in the palette. Reads as
      // "this matters and I'm holding space for it."
      mood: CoachMood.reflective,
    );
  }

  String? _capitaliseFirst(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
