import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/feature_showcase_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 2 (R1.1) · the post-paywall capability showcase.
///
/// A minimal GoRouter is supplied because the screen finishes with
/// `context.go('/')`; without a router the finish path would throw
/// instead of navigating.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: '/showcase',
    routes: [
      GoRoute(
        path: '/showcase',
        builder: (_, __) => const FeatureShowcaseScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('DASHBOARD')),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr')],
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('opens on the form-analysis card with its proof point',
      (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);
    expect(find.text('Her tekrarını izliyorum.'), findsOneWidget);
    // Every card carries a verifiable claim, not an adjective.
    expect(
      find.textContaining('Tamamen cihazında çalışır'),
      findsOneWidget,
    );
    expect(find.text('DEVAM'), findsOneWidget);
  });

  testWidgets('Atla is available on the FIRST card', (tester) async {
    await _pump(tester);
    expect(find.text('Atla'), findsOneWidget);
  });

  testWidgets('walks all four cards and swaps the CTA on the last',
      (tester) async {
    await _pump(tester);

    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('KİŞİSEL AI KOÇ'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('SANA ÖZEL PROGRAM'), findsOneWidget);

    await tester.tap(find.text('DEVAM'));
    await tester.pumpAndSettle();
    expect(find.text('BESLENME'), findsOneWidget);
    expect(find.text('BAŞLAYALIM'), findsOneWidget);
    expect(find.text('DEVAM'), findsNothing);
  });

  testWidgets('finishing marks the flag and routes to the dashboard',
      (tester) async {
    final container = await _pump(tester);
    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isFalse);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('BAŞLAYALIM'));
    await tester.pumpAndSettle();

    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isTrue);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets(
      'skipping ALSO marks the flag — a skipped showcase must not '
      'reappear on the next dashboard visit', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(container.read(appPreferencesProvider).seenFeatureShowcase, isTrue);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('renders at a 1.3 text scale without overflow', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('CANLI FORM ANALİZİ'), findsOneWidget);
  });

  testWidgets('renders on a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester);
    expect(tester.takeException(), isNull);
  });
}
