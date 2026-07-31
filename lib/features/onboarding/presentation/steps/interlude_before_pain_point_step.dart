import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/cinematic_ai_presence.dart';
import '../../providers/wizard_provider.dart';
import '../widgets/coach_mood.dart';
import '../../../../l10n/app_localizations.dart';

/// Act 3 · Strategic interlude #2 (vulnerability setup before
/// pain-point).
///
/// Lives between physical_data and pain_point. Pain-point is the
/// most emotionally loaded answer in the wizard — Form sets up the
/// vulnerability before asking. Frames the question as collaborative
/// ("birlikte çözmek için"), not interrogative ("yargılamak için
/// değil"). Removes the shame layer the audit (§3.6) flagged.
///
/// Phase 129 · migrated from the legacy [InterludeScene] widget onto
/// the shared [CinematicAiPresence] system. The title carries a
/// pause word ("Bir an...") that sets the emotional gravity before
/// the subtitle's collaborative-framing message types in.
class InterludeBeforePainPointStep extends ConsumerWidget {
  const InterludeBeforePainPointStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(wizardProvider);
    final name = _capitaliseFirst(wizard.name);
    final opener = name != null
        ? AppLocalizations.of(context).interludePainOpener(name)
        : AppLocalizations.of(context).interludePainPointTitle;
    return CinematicAiPresence(
      title: AppLocalizations.of(context).interludePainPointBeat,
      subtitle: AppLocalizations.of(context).interludePainBody(opener),
      subtitleTypewriter: true,
      composingPlaceholder:
          AppLocalizations.of(context).interludePainPointComposing,
      // Form is preparing the user for the most vulnerable answer —
      // dimmer, slower, deepest tone in the palette. Reads as
      // "this matters and I'm holding space for it."
      mood: CoachMood.reflective,
      autoCloseAfter: const Duration(milliseconds: 6800),
      onComplete: onContinue,
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
