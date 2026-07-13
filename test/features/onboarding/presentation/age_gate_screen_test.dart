import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/routing/app_router.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/age_gate_screen.dart';

/// The 18+ age gate is a store-compliance surface (Play Console
/// "Target audience: 18+"). Two behaviours must never regress:
///
///   • an adult passes → [AppPreferences.setAgeVerified] is stamped and
///     the user is routed on to `/onboarding`;
///   • a minor is stopped → a non-dismissible block screen appears, the
///     verification flag is NOT written, and no PII-collecting route is
///     reached.
///
/// The age math reads `DateTime.now().year`, so the wheel's default
/// (year 2000 ≈ 26 in 2026) is comfortably adult and the drag target
/// (~2025) is comfortably a minor — both bands are wide enough that the
/// exact wall-clock year the suite runs on doesn't matter.

Widget _hostAgeGate(SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: AppRoutes.ageGate,
    routes: [
      GoRoute(
        path: AppRoutes.ageGate,
        builder: (_, __) => const AgeGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const Scaffold(body: Text('ONBOARDING_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  // A phone-tall viewport so the picker column (title + description +
  // Expanded wheel + CTA + caption) lays out without overflowing the
  // default 800×600 test surface. Reset after each test.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the year-picker prompt and CTA, no block screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_hostAgeGate(prefs));
    await tester.pump();

    expect(find.text('Doğum yılını seç'), findsOneWidget);
    expect(find.text('Devam Et'), findsOneWidget);
    expect(
      find.text('Bilgilerin telefonunda kalır. Hesabınla ilişkilendirilmez.'),
      findsOneWidget,
    );
    // The under-18 block view must not be showing on first render.
    expect(find.text('Üzgünüz'), findsNothing);
  });

  testWidgets(
    'adult default year passes: stamps ageVerified and routes to onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostAgeGate(prefs));
      await tester.pump();

      // Do NOT touch the wheel — it defaults to year 2000 (adult).
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();

      expect(
        AppPreferences(prefs).ageVerified,
        isTrue,
        reason: 'passing the gate must persist the 18+ attestation',
      );
      expect(
        find.text('ONBOARDING_ROUTE'),
        findsOneWidget,
        reason: 'an adult must be routed on to the onboarding wizard',
      );
    },
  );

  testWidgets(
    'minor selection reveals the block screen, does not persist or route',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostAgeGate(prefs));
      await tester.pump();

      // Scroll the wheel toward the most-recent years. Item extent is
      // 64 px; dragging up ~25 items from the year-2000 default lands
      // deep in minor territory (~2025). The exact landing year doesn't
      // matter — anything ≥ 2009 is under 18, and the wheel clamps at
      // the current year, so over-scroll can't escape the band.
      await tester.drag(
        find.byType(ListWheelScrollView),
        const Offset(0, -25 * 64.0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Devam Et'));
      await tester.pump();

      expect(find.text('Üzgünüz'), findsOneWidget);
      expect(find.text('Uygulamayı Kapat'), findsOneWidget);
      expect(
        AppPreferences(prefs).ageVerified,
        isFalse,
        reason: 'a minor must never stamp the 18+ attestation',
      );
      expect(
        find.text('ONBOARDING_ROUTE'),
        findsNothing,
        reason: 'a minor must never reach the PII-collecting onboarding',
      );
    },
  );
}
