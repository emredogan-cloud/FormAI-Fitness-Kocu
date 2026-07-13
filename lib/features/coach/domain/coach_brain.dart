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

/// The swappable "brain" behind the coach. Today the only implementation is
/// [RuleBasedCoachBrain] — genuinely contextual (it reads the real
/// [CoachContext]) but honest: it never invents free-form intelligence it
/// doesn't have. A future `LlmCoachBrain` implements the SAME interface,
/// sending [CoachContext.toPromptContext] as the system prompt and [history]
/// + the message as the conversation. Because the UI and providers depend
/// only on this interface, that swap changes no call sites.
///
/// LLM production design (documented, not yet built — no fake intelligence):
///   • Never call the model directly from the client (the API key must not
///     ship). Route through a Supabase Edge Function (`coach-chat`) that
///     holds the provider key server-side, injects [toPromptContext], and
///     streams the reply. See docs when implemented.
///   • Persist a rolling summary per user for long-term memory.
///   • Keep a hard "not medical advice" guardrail in the system prompt.
abstract class CoachBrain {
  /// The proactive opener shown when the coach screen is first opened.
  String greeting(CoachContext ctx);

  /// The quick-reply chips offered alongside the greeting.
  List<CoachSuggestion> suggestions(CoachContext ctx);

  /// Answer [message] given the full context and prior [history].
  String respond(CoachContext ctx, List<CoachTurn> history, String message);
}
