import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/feedback/domain/survey.dart';
import 'package:sixpack_ai/features/feedback/domain/survey_definitions.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

// Copy in a SurveyDefinition is a lookup, not a string (the catalogue is
// `const` and built before any locale exists). These fixtures exercise
// scheduling, which never reads the copy — so they return the same
// placeholders the assertions below always used.
String _q(AppLocalizations l) => 'q';
String _q2(AppLocalizations l) => 'q2';
String _a(AppLocalizations l) => 'A';

/// Roadmap Phase 1 (C8 · P4) · survey scheduling policy + NPS bucketing.
void main() {
  const cooldown = Duration(days: 30);
  final now = DateTime(2026, 7, 30, 12);

  const npsSurvey = SurveyDefinition(
    id: 'test_nps',
    kind: SurveyKind.nps,
    question: _q,
    minCompletedDays: 3,
    minDaysSinceInstall: 14,
  );
  const laterSurvey = SurveyDefinition(
    id: 'test_later',
    kind: SurveyKind.choice,
    question: _q2,
    minCompletedDays: 5,
    minDaysSinceInstall: 21,
    options: [SurveyOption(token: 'a', label: _a)],
  );

  SurveyDefinition? select({
    required SurveyContext context,
    List<SurveyDefinition> catalog = const [npsSurvey, laterSurvey],
    Set<String> answered = const <String>{},
    DateTime? lastShownAt,
  }) {
    return selectSurvey(
      catalog: catalog,
      context: context,
      answeredIds: answered,
      lastShownAt: lastShownAt,
      now: now,
      cooldown: cooldown,
    );
  }

  group('eligibility gates', () {
    test('both the behavioural AND the wall-clock gate must pass', () {
      // Enough time, not enough training — no informed opinion to give.
      expect(
        select(
          context: const SurveyContext(completedDays: 0, daysSinceInstall: 30),
        ),
        isNull,
      );
      // Enough training, not enough time.
      expect(
        select(
          context: const SurveyContext(completedDays: 10, daysSinceInstall: 2),
        ),
        isNull,
      );
      // Both satisfied.
      expect(
        select(
          context: const SurveyContext(completedDays: 3, daysSinceInstall: 14),
        ),
        npsSurvey,
      );
    });

    test('gates are inclusive at the boundary', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 3, daysSinceInstall: 14),
        ),
        isNotNull,
      );
      expect(
        select(
          context: const SurveyContext(completedDays: 2, daysSinceInstall: 14),
        ),
        isNull,
      );
    });
  });

  group('one-per-survey ledger', () {
    test('an answered survey is never re-asked', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 30, daysSinceInstall: 60),
          answered: {npsSurvey.id},
        ),
        laterSurvey,
      );
    });

    test('when everything is answered, nothing is shown', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 30, daysSinceInstall: 60),
          answered: {npsSurvey.id, laterSurvey.id},
        ),
        isNull,
      );
    });
  });

  group('cooldown', () {
    test('two surveys can never stack inside the cooldown window', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 30, daysSinceInstall: 60),
          answered: {npsSurvey.id},
          lastShownAt: now.subtract(const Duration(days: 3)),
        ),
        isNull,
      );
    });

    test('past the cooldown the next survey is allowed', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 30, daysSinceInstall: 60),
          answered: {npsSurvey.id},
          lastShownAt: now.subtract(const Duration(days: 31)),
        ),
        laterSurvey,
      );
    });
  });

  group('priority', () {
    test('catalogue order is priority order', () {
      expect(
        select(
          context: const SurveyContext(completedDays: 30, daysSinceInstall: 60),
        ),
        npsSurvey,
      );
    });
  });

  group('NPS bucketing', () {
    test('9-10 are promoters, 7-8 passives, 0-6 detractors', () {
      String? bucket(int score) =>
          SurveyAnswer(surveyId: 'x', score: score).npsBucket;
      expect(bucket(10), 'promoter');
      expect(bucket(9), 'promoter');
      expect(bucket(8), 'passive');
      expect(bucket(7), 'passive');
      expect(bucket(6), 'detractor');
      expect(bucket(0), 'detractor');
    });

    test('a choice answer has no NPS bucket', () {
      const answer = SurveyAnswer(surveyId: 'x', optionToken: 'a');
      expect(answer.npsBucket, isNull);
    });
  });

  group('shipped catalogue', () {
    test('survey ids are unique — they are the ledger keys', () {
      final ids = kSurveyCatalog.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every choice survey actually offers options', () {
      for (final survey in kSurveyCatalog) {
        if (survey.kind == SurveyKind.choice) {
          expect(
            survey.options,
            isNotEmpty,
            reason: '${survey.id} is a choice survey with no options',
          );
        }
      }
    });

    test(
        'no survey fires before the user has real experience — an NPS '
        'answered on day 1 measures the onboarding, not the product', () {
      for (final survey in kSurveyCatalog) {
        expect(survey.minDaysSinceInstall, greaterThanOrEqualTo(14));
        expect(survey.minCompletedDays, greaterThanOrEqualTo(1));
      }
    });
  });
}
