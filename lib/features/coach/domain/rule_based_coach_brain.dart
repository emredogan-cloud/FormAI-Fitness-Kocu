import '../../../l10n/app_localizations.dart';
import 'coach_brain.dart';
import 'coach_context.dart';

/// The current coach brain. It is genuinely context-aware — every answer is
/// derived from the real [CoachContext] (today's day, streak, goal, BMI,
/// progress) — but it does NOT pretend to be a general AI: unmatched input
/// gets an honest "here's what I can help with" reply, never fabricated
/// free-form text. This is the intelligence we can truthfully ship today;
/// the LLM brain slots in behind the same [CoachBrain] interface later.
class RuleBasedCoachBrain implements CoachBrain {
  const RuleBasedCoachBrain();

  @override
  String greeting(AppLocalizations l10n, CoachContext ctx) {
    final hi = ctx.hour < 12
        ? l10n.coachGreetMorning
        : (ctx.hour < 18 ? l10n.coachGreetDay : l10n.coachGreetEvening);
    final who = ctx.firstName.isNotEmpty ? ' ${ctx.firstName}' : '';
    final b = StringBuffer(l10n.coachGreetIntro(hi, who));
    if (ctx.todayDayNumber != null && !ctx.todayIsCompleted) {
      b.write(l10n.coachGreetTodayPending(
        ctx.todayDayNumber!,
        ctx.todayExerciseCount,
      ));
    } else if (ctx.todayIsCompleted) {
      b.write(l10n.coachGreetTodayDone);
    }
    b.write(l10n.coachGreetPrompt);
    return b.toString();
  }

  @override
  List<CoachSuggestion> suggestions(AppLocalizations l10n, CoachContext ctx) =>
      [
        CoachSuggestion(l10n.coachSuggestToday, 'today'),
        CoachSuggestion(l10n.coachSuggestProgress, 'progress'),
        CoachSuggestion(l10n.coachSuggestNutrition, 'nutrition'),
        CoachSuggestion(l10n.coachSuggestMotivate, 'motivate'),
      ];

  @override
  Future<String> respond(
    AppLocalizations l10n,
    CoachContext ctx,
    List<CoachTurn> history,
    String message,
  ) async {
    final m = message.toLowerCase().trim();
    if (_hits(m, l10n.coachKeywordsToday)) {
      return _today(l10n, ctx);
    }
    if (_hits(m, l10n.coachKeywordsProgress)) {
      return _progress(l10n, ctx);
    }
    if (_hits(m, l10n.coachKeywordsNutrition)) {
      return _nutrition(l10n, ctx);
    }
    if (_hits(m, l10n.coachKeywordsMotivate)) {
      return _motivate(l10n, ctx);
    }
    if (_hits(m, l10n.coachKeywordsStreak)) {
      return ctx.streakDays > 0
          ? l10n.coachStreakAlive(ctx.streakDays)
          : l10n.coachStreakNone;
    }
    if (_hits(m, l10n.coachKeywordsInjury)) {
      return l10n.coachInjuryReply;
    }
    if (_hits(m, l10n.coachKeywordsGreeting)) {
      return greeting(l10n, ctx);
    }
    if (_hits(m, l10n.coachKeywordsThanks)) {
      return l10n.coachThanksReply;
    }
    // Honest fallback — no fabricated intelligence.
    return l10n.coachFallbackReply;
  }

  /// Keyword sets arrive as one comma-separated ARB value rather than a
  /// Dart list, because they are TRANSLATOR-OWNED: what an English
  /// speaker types to ask "how am I doing" is not a translation of the
  /// Turkish, it is a different set of substrings. A single string keeps
  /// the whole set in one editable place, and blank entries are dropped
  /// so a trailing comma cannot match everything.
  bool _hits(String m, String csv) => csv
      .split(',')
      .map((k) => k.trim().toLowerCase())
      .where((k) => k.isNotEmpty)
      .any(m.contains);

  String _today(AppLocalizations l10n, CoachContext ctx) {
    if (ctx.todayDayNumber == null) {
      return l10n.coachTodayPlanPending;
    }
    if (ctx.todayIsCompleted) {
      return l10n.coachTodayDone;
    }
    final eq = ctx.hasEquipment == true ? l10n.coachTodayEquipmentNote : '';
    return l10n.coachTodayPlan(
      ctx.todayDayNumber!,
      ctx.todayExerciseCount,
      eq,
    );
  }

  String _progress(AppLocalizations l10n, CoachContext ctx) {
    final pct = ctx.totalDays > 0
        ? (100 * ctx.completedDays / ctx.totalDays).round()
        : 0;
    final streak = ctx.streakDays > 0
        ? l10n.coachStreakContinuing(ctx.streakDays)
        : l10n.coachStreakRestart;
    return l10n.coachProgressReply(
      ctx.completedDays,
      ctx.totalDays,
      pct,
      streak,
      ctx.level,
      ctx.xp,
      ctx.badgeCount,
    );
  }

  String _nutrition(AppLocalizations l10n, CoachContext ctx) {
    final bmi = ctx.bmi;
    final bmiLine =
        bmi != null ? l10n.coachBmiFragment(bmi.toStringAsFixed(1)) : '';
    final goal =
        ctx.goalLabel != null ? l10n.coachGoalFragment(ctx.goalLabel!) : '';
    return l10n.coachNutritionReply(bmiLine, goal);
  }

  String _motivate(AppLocalizations l10n, CoachContext ctx) {
    final who = ctx.firstName.isNotEmpty ? '${ctx.firstName}, ' : '';
    if (ctx.streakDays >= 3) {
      return l10n.coachMotivateStreak(who, ctx.streakDays);
    }
    if (ctx.completedDays == 0) {
      return l10n.coachMotivateStart(who);
    }
    return l10n.coachMotivateKeepGoing(who);
  }
}
