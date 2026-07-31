import 'package:flutter/widgets.dart';
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
import 'package:sixpack_ai/features/onboarding/presentation/steps/name_capture_step.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/social_proof_step.dart';

import '../support/layout_probe.dart';

/// Roadmap Phase 5 (C11) · RTL readiness.
///
/// FormAI ships Turkish today, so nothing here is about supporting
/// Arabic tomorrow. It is about the decisions that are cheap to make
/// correctly while the code is being touched anyway and expensive to
/// find later: a hardcoded `left:` padding, a `TextAlign.right`, an
/// `Alignment.centerLeft` where `AlignmentDirectional.centerStart` was
/// meant.
///
/// Rendering these screens right-to-left does not prove they read well
/// in Arabic — that needs a translator and a native reader. It proves
/// the widget tree does not assume a direction in a way translation
/// alone can never repair.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final surfaces = <String, Widget Function()>{
    'Act 1 hook': () => const ProviderScope(child: WelcomeStep(onStart: _noop)),
    'Name capture': () =>
        const ProviderScope(child: NameCaptureStep(onContinue: _noop)),
    'Gender step': () =>
        const ProviderScope(child: GenderStep(onCommitted: _noop)),
    'Goal step': () => const ProviderScope(child: GoalStep(onCommitted: _noop)),
    'Experience step': () =>
        const ProviderScope(child: ExperienceStep(onCommitted: _noop)),
    'Daily-minutes step': () =>
        const ProviderScope(child: DailyMinutesStep(onCommitted: _noop)),
    'Activity step': () =>
        const ProviderScope(child: ActivityStep(onCommitted: _noop)),
    'Physical-data step': () =>
        const ProviderScope(child: PhysicalDataStep(onContinue: _noop)),
    'Pain-point step': () =>
        const ProviderScope(child: PainPointStep(onCommitted: _noop)),
    'Analysis illusion': () =>
        const ProviderScope(child: AnalysisIllusionStep(onComplete: _noop)),
    'AI report': () =>
        const ProviderScope(child: DynamicReportStep(onComplete: _noop)),
    'Social proof': () =>
        const ProviderScope(child: SocialProofStep(onContinue: _noop)),
    'Pre-paywall summary': () =>
        const ProviderScope(child: PrePaywallSummaryStep(onComplete: _noop)),
    'Consent screen': () => const ProviderScope(child: ConsentScreen()),
    'Prediction screen': () => const ProviderScope(child: PredictionScreen()),
    'Feature showcase': () =>
        const ProviderScope(child: FeatureShowcaseScreen()),
  };

  surfaces.forEach((name, build) {
    testWidgets('$name lays out right-to-left', (tester) async {
      await sweepRtlLayout(tester, name, build);
    });
  });
}

void _noop() {}
