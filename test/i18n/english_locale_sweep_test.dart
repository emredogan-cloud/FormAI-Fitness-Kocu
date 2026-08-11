import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/consent_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/feature_showcase_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/prediction_screen.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_1_hook_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_3_buildup_steps.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_4_revelation_steps.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/act_5_commitment_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/body_feelings_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/name_capture_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/social_proof_step.dart';

import '../support/layout_probe.dart' show Viewports, scrollThrough;
import '../support/locale_probe.dart';

/// Roadmap Phase 6 · "zero untranslated strings in an English-locale
/// sweep", asserted rather than eyeballed.
///
/// The pseudo-locale suite next door proves these screens survive a
/// longer language. This one proves they are actually *in* the language
/// the user chose — a different failure, and the one that ships when a
/// literal never made it to ARB.
///
/// Each surface is rendered twice: at the reference phone and at 1.3
/// text scale, because English is shorter than Turkish and a layout that
/// was tuned for Turkish can leave English looking sparse rather than
/// broken. Overflow is still checked, so a regression in either
/// direction fails here.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> sweepEnglish(
    WidgetTester tester,
    String describe,
    Widget Function() build,
  ) async {
    for (final scale in const [1.0, 1.3]) {
      await tester.pumpWidget(const SizedBox.shrink());
      while (tester.takeException() != null) {}

      await pumpInLocale(
        tester,
        build(),
        size: Viewports.phone,
        textScale: scale,
      );

      final errors = <Object>[];
      for (var e = tester.takeException();
          e != null;
          e = tester.takeException()) {
        errors.add(e);
      }
      // Paint what is below the fold before believing the screen is
      // clean — see scrollThrough for the 32-px badge this missed.
      await scrollThrough(tester, errors);
      expect(
        errors,
        isEmpty,
        reason: '$describe overflowed in English at ${scale}x:\n'
            '${errors.join('\n')}',
      );
      expectNoTurkish(tester, describe, allow: kNeverTranslated);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    while (tester.takeException() != null) {}
  }

  group('the funnel speaks English', () {
    // The language picker used to be swept here as step 0. The step is
    // gone — the app follows the device locale instead of asking — so
    // the funnel now opens on the hook screen. The picker's English is
    // still covered: it lives in Settings, and profile_tab is swept by
    // this file's sibling cases.

    testWidgets('act 1 · the hook screen', (tester) async {
      await sweepEnglish(
        tester,
        'Act 1 hook',
        () => const ProviderScope(child: WelcomeStep(onStart: _noop)),
      );
    });

    testWidgets('act 2.5 · name capture chat', (tester) async {
      await sweepEnglish(
        tester,
        'Name-capture step',
        () => const ProviderScope(child: NameCaptureStep(onContinue: _noop)),
      );
    });

    testWidgets('act 3 · body feelings', (tester) async {
      await sweepEnglish(
        tester,
        'Body-feelings step',
        () => const ProviderScope(child: BodyFeelingsStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · gender', (tester) async {
      await sweepEnglish(
        tester,
        'Gender step',
        () => const ProviderScope(child: GenderStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · goal', (tester) async {
      await sweepEnglish(
        tester,
        'Goal step',
        () => const ProviderScope(child: GoalStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · experience', (tester) async {
      await sweepEnglish(
        tester,
        'Experience step',
        () => const ProviderScope(child: ExperienceStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · daily minutes', (tester) async {
      await sweepEnglish(
        tester,
        'Daily-minutes step',
        () => const ProviderScope(child: DailyMinutesStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · activity', (tester) async {
      await sweepEnglish(
        tester,
        'Activity step',
        () => const ProviderScope(child: ActivityStep(onCommitted: _noop)),
      );
    });

    testWidgets('act 3 · physical data', (tester) async {
      await sweepEnglish(
        tester,
        'Physical-data step',
        () => const ProviderScope(child: PhysicalDataStep(onContinue: _noop)),
      );
    });

    testWidgets('act 3 · pain point', (tester) async {
      await sweepEnglish(
        tester,
        'Pain-point step',
        () => const ProviderScope(child: PainPointStep(onCommitted: _noop)),
      );
    });

    testWidgets('social proof', (tester) async {
      await sweepEnglish(
        tester,
        'Social-proof step',
        () => const ProviderScope(child: SocialProofStep(onContinue: _noop)),
      );
    });

    testWidgets('act 4 · the AI report', (tester) async {
      await sweepEnglish(
        tester,
        'Dynamic-report step',
        () => const ProviderScope(child: DynamicReportStep(onComplete: _noop)),
      );
    });

    testWidgets('act 5 · the pre-paywall summary', (tester) async {
      await sweepEnglish(
        tester,
        'Pre-paywall summary',
        () => const ProviderScope(
          child: PrePaywallSummaryStep(onComplete: _noop),
        ),
      );
    });
  });

  group('the surfaces around the funnel speak English', () {
    testWidgets('the consent screen', (tester) async {
      await sweepEnglish(
        tester,
        'Consent screen',
        () => const ProviderScope(child: ConsentScreen()),
      );
    });

    testWidgets('the prediction screen', (tester) async {
      await sweepEnglish(
        tester,
        'Prediction screen',
        () => const ProviderScope(child: PredictionScreen()),
      );
    });

    testWidgets('the post-paywall showcase', (tester) async {
      await sweepEnglish(
        tester,
        'Feature showcase',
        () => const ProviderScope(child: FeatureShowcaseScreen()),
      );
    });
  });
}

void _noop() {}
