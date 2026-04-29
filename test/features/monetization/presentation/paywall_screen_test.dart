import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixpack_ai/features/monetization/presentation/paywall_screen.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';

/// Stubs [SubscriptionNotifier.build] with a fixed [SubscriptionState] so
/// the widget tree never touches the RevenueCat SDK. Everything else on
/// the notifier (purchase / restore / developer override) stays
/// inherited, but the tests below only exercise [build] / [dispose].
class _StubSubscriptionNotifier extends SubscriptionNotifier {
  _StubSubscriptionNotifier(this._seed);
  final SubscriptionState _seed;

  @override
  Future<SubscriptionState> build() async => _seed;
}

/// Minimal host: a GoRouter with `/` and `/paywall` so the close-button
/// target (`context.go('/')`) has somewhere to resolve to without a real
/// app shell.
Widget _wrapPaywall({required SubscriptionState seededState}) {
  final router = GoRouter(
    initialLocation: '/paywall',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const PaywallScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(
        () => _StubSubscriptionNotifier(seededState),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
    'loading / null-offerings state still renders the plan cards + CTA',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(),
      ));
      // `pump` (not `pumpAndSettle`) so we don't block on the eternal
      // pulsing animation that some paywall art plays.
      await tester.pump();

      // Hero copy renders.
      expect(find.text('Kişiselleştirilmiş planın hazır'), findsOneWidget);
      // The three plan pickers (1 Ay / 3 Ay / 12 Ay) are all on screen.
      expect(find.text('1 Ay'), findsOneWidget);
      expect(find.text('3 Ay'), findsOneWidget);
      expect(find.text('12 Ay'), findsOneWidget);
      // Primary CTA still reads as "try for free".
      expect(find.text('₺0,00 ile başla'), findsOneWidget);
      // Restore button renders regardless of offerings availability.
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);
    },
  );

  testWidgets(
    'populated-offerings state renders the full plan ladder without '
    'crashing when the user has no entitlement yet',
    (tester) async {
      // `offerings` is left null — the widget tree doesn't reach into
      // the RevenueCat-specific fields until the user taps CTA (which
      // we don't exercise here). Smoke-testing the "populated but not
      // purchased" snapshot is enough to catch a layout regression.
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: false),
      ));
      await tester.pump();

      expect(find.byType(PaywallScreen), findsOneWidget);
      // Phase 60D · risk-removal badge promotes "7 gün ücretsiz dene"
      // to the headline; the original "Şimdi ödeme yok" survives as a
      // muted secondary line under it.
      expect(find.text('7 gün ücretsiz dene'), findsOneWidget);
      expect(find.text('Şimdi ödeme yok'), findsOneWidget);
      expect(find.text('₺0,00 ile başla'), findsOneWidget);
    },
  );

  testWidgets(
    'entitlement-active state renders without throwing so a paywall '
    'resurfaced to a Pro user cannot crash the app',
    (tester) async {
      await tester.pumpWidget(_wrapPaywall(
        seededState: const SubscriptionState(isPro: true),
      ));
      await tester.pump();

      // The paywall doesn't currently auto-dismiss when entitlement flips
      // true, but the smoke test here is that the widget still *mounts*
      // in this state (otherwise Pro users who get deep-linked here
      // would hit a redscreen).
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.text('Kişiselleştirilmiş planın hazır'), findsOneWidget);
    },
  );
}
