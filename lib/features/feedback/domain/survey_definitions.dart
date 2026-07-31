import '../../../l10n/app_localizations.dart';
import 'survey.dart';

/// Roadmap Phase 1 (C8) · the survey catalogue.
///
/// Ordering is priority order — [selectSurvey] returns the first
/// eligible, unanswered entry. Put the survey whose answer you most
/// need first.
///
/// Adding a survey is a list entry plus nothing else. When the
/// remote-config layer lands (roadmap Phase 4) this list becomes the
/// local default and the remote copy overrides it, so the shape here is
/// intentionally serialisable.
const List<SurveyDefinition> kSurveyCatalog = [
  // The headline metric. Gated on real experience: two weeks observed
  // AND three completed workouts, so the score reflects the product
  // rather than a first impression of the onboarding.
  SurveyDefinition(
    id: 'nps_v1',
    kind: SurveyKind.nps,
    question: _npsQuestion,
    subtitle: _npsSubtitle,
    minCompletedDays: 3,
    minDaysSinceInstall: 14,
  ),

  // Fires for users who stayed but did not convert. Tells us which
  // pillar is actually carrying retention, which is the input the
  // roadmap's later phases need most.
  SurveyDefinition(
    id: 'value_driver_v1',
    kind: SurveyKind.choice,
    question: _valueDriverQuestion,
    minCompletedDays: 5,
    minDaysSinceInstall: 21,
    options: [
      SurveyOption(token: 'form_analysis', label: _optionFormAnalysis),
      SurveyOption(token: 'ai_coach', label: _optionAiCoach),
      SurveyOption(token: 'plan', label: _optionPlan),
      SurveyOption(token: 'nutrition', label: _optionNutrition),
      SurveyOption(token: 'progress', label: _optionProgress),
    ],
  ),
];

// Copy is held as a lookup so the catalogue stays `const` and the
// analytics `token` stays decoupled from the words — the funnel joins
// on the token, so rewording an option must never move a number.
String _npsQuestion(AppLocalizations l) => l.surveyNpsQuestion;
String _npsSubtitle(AppLocalizations l) => l.surveyNpsSubtitle;
String _valueDriverQuestion(AppLocalizations l) => l.surveyValueDriverQuestion;
String _optionFormAnalysis(AppLocalizations l) =>
    l.surveyValueDriverFormAnalysis;
String _optionAiCoach(AppLocalizations l) => l.surveyValueDriverAiCoach;
String _optionPlan(AppLocalizations l) => l.surveyValueDriverPlan;
String _optionNutrition(AppLocalizations l) => l.surveyValueDriverNutrition;
String _optionProgress(AppLocalizations l) => l.surveyValueDriverProgress;
