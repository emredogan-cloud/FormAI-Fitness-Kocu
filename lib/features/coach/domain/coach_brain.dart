import 'coach_context.dart';

/// One line in a coach conversation.
class CoachTurn {
  const CoachTurn({required this.fromCoach, required this.text});
  final bool fromCoach;
  final String text;
}

/// A suggested quick-reply the UI can render as a tappable chip. `intent`
/// is what gets sent to the brain when tapped.
class CoachSuggestion {
  const CoachSuggestion(this.label, this.intent);
  final String label;
  final String intent;
}

/// The swappable "brain" behind the coach. Two implementations ship:
///   • [RuleBasedCoachBrain] — genuinely contextual (reads the real
///     [CoachContext]) and honest; it never invents free-form intelligence.
///     Used offline and as the fallback.
///   • `LlmCoachBrain` — sends [CoachContext.toPromptContext] + the recent
///     [history] to a real Claude model and returns its reply, falling back
///     to the rule brain on any error. Because the UI and providers depend
///     only on this interface, swapping between them changes no call sites.
///
/// LLM production design (now built):
///   • The model is NEVER called from the client — the API key must not ship
///     in the `.env` asset. `LlmCoachBrain` calls a Supabase Edge Function
///     (`coach-chat`) that holds `ANTHROPIC_API_KEY` server-side, prepends the
///     coaching persona + [toPromptContext], and returns the reply.
///   • History is compressed (only the recent turns are sent) and the static
///     persona is marked cacheable, so a typical turn is a few hundred tokens
///     on the cheapest model tier.
///   • A hard "not medical advice / defer to a professional" guardrail lives
///     in the system prompt, mirrored by the rule brain's injury path.
abstract class CoachBrain {
  /// The proactive opener shown when the coach screen is first opened. Kept
  /// synchronous and rule-based even for the LLM brain: it's instant, free,
  /// and personalised from local state, so the user never waits to be greeted.
  String greeting(CoachContext ctx);

  /// The quick-reply chips offered alongside the greeting.
  List<CoachSuggestion> suggestions(CoachContext ctx);

  /// Answer [message] given the full context and prior [history]. Async because
  /// the LLM brain performs a network round-trip; the rule brain returns an
  /// already-completed future.
  Future<String> respond(
    CoachContext ctx,
    List<CoachTurn> history,
    String message,
  );
}
