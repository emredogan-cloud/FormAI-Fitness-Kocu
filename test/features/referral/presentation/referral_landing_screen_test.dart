import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixpack_ai/core/routing/app_router.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/referral/presentation/referral_landing_screen.dart';

/// The `formai://r/<code>` deep-link landing. The common entry is a
/// signed-out friend arriving from a share, so these tests cover that
/// pre-auth path (currentUserProvider = null): the invite pitch, the
/// upper-cased code card, the "create account" CTA and its route, and
/// the copy-to-clipboard affordance. The authed redeem path calls the
/// referral service (Supabase) and is left to service-level tests.

Widget _host(String code) {
  final router = GoRouter(
    initialLocation: '/r',
    routes: [
      GoRoute(
          path: '/r', builder: (_, __) => ReferralLandingScreen(code: code)),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, __) => const Scaffold(body: Text('AUTH_ROUTE')),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const Scaffold(body: Text('DASHBOARD_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets(
    'anonymous entry shows the invite pitch, upper-cased code and sign-up CTA',
    (tester) async {
      await tester.pumpWidget(_host('abc123'));
      await tester.pump();

      expect(find.text('Bir arkadaşın seni davet etti! 🎉'), findsOneWidget);
      expect(find.text('DAVET KODU'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget); // upper-cased
      expect(find.text('Hesap Oluştur'), findsOneWidget);
      // The authed "redeem now" CTA must not show for a signed-out user.
      expect(find.text('Daveti Kabul Et'), findsNothing);
    },
  );

  testWidgets('the sign-up CTA routes to auth', (tester) async {
    await tester.pumpWidget(_host('abc123'));
    await tester.pump();

    await tester.tap(find.text('Hesap Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('AUTH_ROUTE'), findsOneWidget);
  });

  testWidgets('the copy button copies the code and confirms with a snackbar',
      (tester) async {
    await tester.pumpWidget(_host('abc123'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump(); // let the SnackBar animate in

    expect(find.text('Kod kopyalandı'), findsOneWidget);
  });
}
