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
    question: 'FormAI\'ı bir arkadaşına önerir miydin?',
    subtitle: '0 = kesinlikle hayır, 10 = kesinlikle evet',
    minCompletedDays: 3,
    minDaysSinceInstall: 14,
  ),

  // Fires for users who stayed but did not convert. Tells us which
  // pillar is actually carrying retention, which is the input the
  // roadmap's later phases need most.
  SurveyDefinition(
    id: 'value_driver_v1',
    kind: SurveyKind.choice,
    question: 'FormAI\'da en çok işine yarayan şey ne?',
    minCompletedDays: 5,
    minDaysSinceInstall: 21,
    options: [
      SurveyOption(
          token: 'form_analysis', label: 'Gerçek zamanlı form analizi'),
      SurveyOption(token: 'ai_coach', label: 'AI koç Form'),
      SurveyOption(token: 'plan', label: 'Kişisel antrenman planı'),
      SurveyOption(token: 'nutrition', label: 'Beslenme'),
      SurveyOption(token: 'progress', label: 'Gelişim takibi'),
    ],
  ),
];
