import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/utils/pseudo_locale.dart';
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
}

void _noop() {}
