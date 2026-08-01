import 'coach_brain.dart';
import 'coach_context.dart';
import 'rule_based_coach_brain.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/coach_providers.dart' show coachLocale;

/// Transport for one coach turn. Returns the model's reply, or `null` on ANY
/// failure (offline, timeout, function not deployed, model error) so the brain
/// can fall back cleanly. The concrete implementation (a Supabase Edge Function
/// call) is injected by the provider, which keeps this class free of any
/// Supabase import and trivially unit-testable.
typedef CoachChatTransport = Future<String?> Function(
  String contextPrompt,
  List<CoachTurn> recentTurns,
  String message,
);

/// The production coach brain. The actual "intelligence" is a real Claude model
/// reached through the `coach-chat` Supabase Edge Function (the API key never
/// ships in the app). It degrades to the honest [RuleBasedCoachBrain] on any
/// failure, so the coach is never blank, never hangs forever, and never crashes
/// — offline it simply becomes the rule brain again.
///
/// Cost discipline is built in:
///   • the greeting + suggestion chips stay local (no model call to say hello);
///   • only the most recent [maxTurnsSent] turns are sent — the full user state
///     already rides in the context prompt, so old small-talk is dropped;
///   • the server caps output tokens and marks the static persona cacheable.
class LlmCoachBrain implements CoachBrain {
  const LlmCoachBrain({
    required this.transport,
    this.fallback = const RuleBasedCoachBrain(),
    this.timeout = const Duration(seconds: 15),
    this.maxTurnsSent = 8,
  });

  final CoachChatTransport transport;
  final RuleBasedCoachBrain fallback;
  final Duration timeout;
  final int maxTurnsSent;

  @override
  String greeting(AppLocalizations l10n, CoachContext ctx) =>
      fallback.greeting(l10n, ctx);

  @override
  List<CoachSuggestion> suggestions(AppLocalizations l10n, CoachContext ctx) =>
      fallback.suggestions(l10n, ctx);

  @override
  Future<String> respond(
    AppLocalizations l10n,
    CoachContext ctx,
    List<CoachTurn> history,
    String message,
  ) async {
    final recent = history.length > maxTurnsSent
        ? history.sublist(history.length - maxTurnsSent)
        : history;
    try {
      // The context block follows the app's language, not the device's,
      // for the same reason the persona does: an English persona handed
      // a Turkish profile block makes the model pick a language per turn.
      final reply = await transport(
        ctx.toPromptContext(locale: coachLocale),
        recent,
        message,
      ).timeout(timeout);
      final trimmed = reply?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    } catch (_) {
      // Any failure (offline, timeout, function 404, model error) drops to the
      // honest rule brain below — the user always gets a real answer.
    }
    return fallback.respond(l10n, ctx, history, message);
  }
}
