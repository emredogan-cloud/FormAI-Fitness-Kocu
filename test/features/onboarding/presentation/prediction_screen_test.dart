import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixpack_ai/core/routing/app_router.dart';
import 'package:sixpack_ai/features/onboarding/presentation/prediction_screen.dart';
import 'package:sixpack_ai/features/onboarding/providers/wizard_provider.dart';

/// The post-onboarding "future self" hook — last step of the funnel
/// before the paywall. Two things must hold:
///
///   • the hero facts reflect the wizard's captured goal + activity
///     level (the screen maps the enums to Turkish labels);
///   • the primary CTA routes to the paywall (the conversion moment).
///
/// The screen runs an infinitely-repeating pulse [AnimationController],
/// so the tests pump fixed durations rather than `pumpAndSettle` (which
/// would time out waiting for an animation that never ends).

/// Seeds [wizardProvider] with a fixed state so the label mapping is
/// deterministic under test.
class _SeededWizard extends WizardController {
  _SeededWizard(this._seed);
  final WizardState _seed;
  @override
  WizardState build() => _seed;
}

Widget _hostPrediction({WizardState? seed}) {
  final router = GoRouter(
    initialLocation: AppRoutes.prediction,
    routes: [
      GoRoute(
        path: AppRoutes.prediction,
        builder: (_, __) => const PredictionScreen(),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        builder: (_, __) => const Scaffold(body: Text('PAYWALL_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (seed != null) wizardProvider.overrideWith(() => _SeededWizard(seed)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
    'renders the plan hero, target-date card and paywall CTA',
    (tester) async {
      await tester.pumpWidget(_hostPrediction());
      await tester.pump();

      expect(find.text('FormAI için Özel Plan'), findsOneWidget);
      expect(find.text('HEDEF TARİHİN'), findsOneWidget);
      expect(find.text('Planımı Göster'), findsOneWidget);
      // No wizard answers seeded → the fallback labels render.
      expect(find.text('Kişisel Hedef'), findsOneWidget);
      expect(find.text('Kişiye Özel'), findsOneWidget);
    },
  );

  testWidgets(
    'hero facts reflect the seeded wizard goal + activity level',
    (tester) async {
      await tester.pumpWidget(
        _hostPrediction(
          seed: const WizardState(
            targetPhysique: GoalPhysique.sixpack,
            activityLevel: ActivityLevel.active,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Six-Pack'), findsOneWidget);
      expect(find.text('İleri'), findsOneWidget);
      expect(find.text('Kişisel Hedef'), findsNothing);
    },
  );

  testWidgets('tapping the CTA routes to the paywall', (tester) async {
    await tester.pumpWidget(_hostPrediction());
    await tester.pump();

    await tester.tap(find.text('Planımı Göster'));
    // Explicit pumps (not pumpAndSettle) — the source screen's pulse
    // animation never ends; a fixed duration lets the go_router
    // transition to the paywall stub complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('PAYWALL_ROUTE'), findsOneWidget);
    expect(find.text('Planımı Göster'), findsNothing);
  });
}
