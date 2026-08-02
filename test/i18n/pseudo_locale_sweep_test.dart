import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/utils/pseudo_locale.dart';
import 'package:sixpack_ai/features/progress/data/body_metrics_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/body_metric.dart';
import 'package:sixpack_ai/features/progress/presentation/body_metrics_screen.dart';
import 'package:sixpack_ai/features/progress/providers/target_weight_provider.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_3_buildup_steps.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_1_hook_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/consent_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/feature_showcase_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/prediction_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_4_revelation_steps.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_5_commitment_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/name_capture_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/social_proof_step.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

import '../support/layout_probe.dart';
import '../support/pseudo_localizations.dart';

/// Roadmap Phase 5 (C11) · the pseudo-locale sweep.
///
/// Every string in these screens comes back bracketed and ~40% longer,
/// which is roughly what German does to Turkish. The app has shipped a
/// clipped primary CTA three separate times (RC-17 paywall, RC-18 Başla,
/// the Phase-3b report) and every one of them was found on a device,
/// late. This suite turns that class of bug into a CI failure.
///
/// The assertion is deliberately "no overflow", not "these pixels":
/// pinning geometry against a machine-generated pseudo string would
/// break on every copy edit and teach the team to regenerate goldens
/// without reading them.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('the pseudo wrapper itself', () {
    testWidgets('covers every generated message', (tester) async {
      // If someone adds an ARB key and forgets to regenerate the
      // wrapper, that string would quietly render un-inflated and this
      // whole suite would stop testing it.
      late AppLocalizations l10n;
      await pumpPseudo(
        tester,
        Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(l10n, isA<PseudoAppLocalizations>());
      expect(isPseudoLocalized(l10n.act1Cta), isTrue);
      // A parameterised message must survive ICU intact — the value is
      // substituted first, and only the finished sentence is inflated.
      final plural = l10n.predictionDurationWeeks(12);
      expect(isPseudoLocalized(plural), isTrue);
      expect(plural, contains('12'));
    });

    test('the wrapper is in step with the generated class', () {
      // The generator records how many members it covered; the count is
      // asserted here so a stale wrapper fails a normal test run rather
      // than only the CI freshness step.
      expect(PseudoAppLocalizations.coveredMembers, greaterThan(1000));
    });
  });

  group('onboarding funnel survives a 40% longer language', () {
    testWidgets('act 1 · the hook screen', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Act 1 hook',
        () => const ProviderScope(child: WelcomeStep(onStart: _noop)),
      );
    });

    testWidgets('act 3 · gender', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Gender step',
        () => const ProviderScope(child: GenderStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · goal', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Goal step',
        () => const ProviderScope(child: GoalStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · experience', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Experience step',
        () => const ProviderScope(child: ExperienceStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · daily minutes', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Daily-minutes step',
        () => const ProviderScope(child: DailyMinutesStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · activity', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Activity step',
        () => const ProviderScope(child: ActivityStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · physical data', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Physical-data step',
        () => const ProviderScope(child: PhysicalDataStep(onContinue: _noop)),
      );
    });

    testWidgets('act 3 · pain point', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Pain-point step',
        () => const ProviderScope(child: PainPointStep(onCommitted: _noop)),
      );
    });

    testWidgets('social proof', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Social-proof step',
        () => const ProviderScope(child: SocialProofStep(onContinue: _noop)),
      );
    });

    testWidgets('act 2.5 · name capture chat', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Name-capture step',
        () => const ProviderScope(child: NameCaptureStep(onContinue: _noop)),
      );
    });

    testWidgets('act 4 · the analysis illusion', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Analysis-illusion step',
        () => const ProviderScope(
          child: AnalysisIllusionStep(onComplete: _noop),
        ),
      );
    });

    testWidgets('act 4 · the AI report', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Dynamic-report step',
        () => const ProviderScope(child: DynamicReportStep(onComplete: _noop)),
      );
    });

    testWidgets('act 5 · the pre-paywall summary', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Pre-paywall summary',
        () => const ProviderScope(
          child: PrePaywallSummaryStep(onComplete: _noop),
        ),
      );
    });
  });

  group('the surfaces around the funnel', () {
    testWidgets('the consent screen', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Consent screen',
        () => const ProviderScope(child: ConsentScreen()),
      );
    });

    testWidgets('the prediction screen', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Prediction screen',
        () => const ProviderScope(child: PredictionScreen()),
      );
    });

    testWidgets('the post-paywall showcase', (tester) async {
      await sweepPseudoLayouts(
        tester,
        'Feature showcase',
        () => const ProviderScope(child: FeatureShowcaseScreen()),
      );
    });
  });

  // ─── Roadmap Phase 9 · body metrics ─────────────────────────────────
  //
  // The densest surface this phase adds: a four-up segmented control, a
  // horizontally-scrolling measure selector and three cards of full
  // sentences with numbers substituted in. Pseudo-localisation inflates
  // every one of those ~40 %, which is roughly what German does, and the
  // 320-wide case is where a four-segment control gives up.
  group('body metrics', () {
    testWidgets('populated', (tester) async {
      SharedPreferences.setMockInitialValues({
        TargetWeightNotifier.storageKey: 75.0,
        'sixpack.max_streak': 11,
      });
      final prefs = await SharedPreferences.getInstance();
      await sweepPseudoLayouts(
        tester,
        'Body metrics',
        () => ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            bodyMetricsProvider.overrideWith((ref) async => _bodyEntries()),
          ],
          child: const BodyMetricsScreen(),
        ),
      );
    });

    testWidgets('empty', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await sweepPseudoLayouts(
        tester,
        'Body metrics (empty)',
        () => ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            bodyMetricsProvider.overrideWith((ref) async => const []),
          ],
          child: const BodyMetricsScreen(),
        ),
      );
    });
  });
}

/// Five weekly weigh-ins and a waist series, so every card on the screen
/// has real content to overflow with.
List<BodyMetric> _bodyEntries() {
  final today = BodyMetric.dayOf(DateTime.now());
  return [
    for (var week = 4; week >= 0; week--)
      BodyMetric(
        recordedOn: today.subtract(Duration(days: week * 7)),
        weightKg: 84 - (4 - week) * 1.0,
        waistCm: week.isEven ? 92 - (4 - week) * 0.5 : null,
      ),
  ];
}

void _noop() {}
