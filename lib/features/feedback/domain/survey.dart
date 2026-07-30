/// Roadmap Phase 1 (C8 · P4) · the micro-survey model.
///
/// The Production Access Questionnaire tells Google that feedback is
/// collected "through surveys and direct communication". Direct
/// communication already exists (the feedback sheet); this is the
/// survey half.
///
/// Design constraints, all deliberate:
///
///   * **One question.** A survey that takes more than a single tap
///     does not get answered inside a fitness app, and a long form
///     interrupts the session the user actually opened the app for.
///   * **Declarative.** Surveys are data, not widgets, so adding one is
///     a list entry — and so the same definitions can later move to the
///     remote-config layer (roadmap Phase 4) without a rewrite.
///   * **Always dismissible.** No survey blocks a user. Dismissal is
///     recorded as an answer for scheduling purposes so a declined
///     survey is never re-asked.
library;

/// How a survey renders its answer affordance.
enum SurveyKind {
  /// 0–10 scale, Net Promoter Score semantics.
  nps,

  /// A small set of mutually exclusive choices.
  choice,
}

class SurveyOption {
  const SurveyOption({required this.token, required this.label});

  /// Stable English identifier persisted and sent to analytics.
  final String token;

  /// Turkish UI label.
  final String label;
}

class SurveyDefinition {
  const SurveyDefinition({
    required this.id,
    required this.kind,
    required this.question,
    this.subtitle,
    this.options = const <SurveyOption>[],
    this.minCompletedDays = 0,
    this.minDaysSinceInstall = 0,
  });

  /// Stable identifier. Also the ledger key in
  /// [AppPreferences.answeredSurveyIds] — never reuse or rename one.
  final String id;

  final SurveyKind kind;
  final String question;
  final String? subtitle;

  /// Only meaningful for [SurveyKind.choice].
  final List<SurveyOption> options;

  /// Eligibility gates. Both must be satisfied. Behavioural and
  /// wall-clock gates are combined deliberately: a user who installed
  /// three weeks ago but has never trained has no informed opinion to
  /// give, and asking them produces noise rather than signal.
  final int minCompletedDays;
  final int minDaysSinceInstall;

  bool matches(SurveyContext ctx) {
    if (ctx.completedDays < minCompletedDays) return false;
    if (ctx.daysSinceInstall < minDaysSinceInstall) return false;
    return true;
  }
}

/// The signals a survey-scheduling decision is made from.
class SurveyContext {
  const SurveyContext({
    required this.completedDays,
    required this.daysSinceInstall,
  });

  final int completedDays;
  final int daysSinceInstall;
}

/// A submitted answer, normalised across survey kinds.
class SurveyAnswer {
  const SurveyAnswer({
    required this.surveyId,
    this.score,
    this.optionToken,
  });

  final String surveyId;

  /// Set for [SurveyKind.nps] — 0–10.
  final int? score;

  /// Set for [SurveyKind.choice].
  final String? optionToken;

  /// Standard NPS bucketing, used for analytics rollups. `null` for
  /// non-NPS answers.
  String? get npsBucket {
    final s = score;
    if (s == null) return null;
    if (s >= 9) return 'promoter';
    if (s >= 7) return 'passive';
    return 'detractor';
  }
}

/// Pure scheduling decision: which survey, if any, should be shown now?
///
/// Returns `null` when the user should not be asked. Extracted from the
/// service so the whole policy is unit-testable without a widget tree,
/// a clock, or SharedPreferences.
SurveyDefinition? selectSurvey({
  required List<SurveyDefinition> catalog,
  required SurveyContext context,
  required Set<String> answeredIds,
  required DateTime? lastShownAt,
  required DateTime now,
  required Duration cooldown,
}) {
  if (lastShownAt != null && now.difference(lastShownAt) < cooldown) {
    return null;
  }
  for (final survey in catalog) {
    if (answeredIds.contains(survey.id)) continue;
    if (survey.matches(context)) return survey;
  }
  return null;
}
