import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/routing/app_router.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/consent_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// The KVKK / GDPR consent screen. Two invariants matter for
/// compliance and must not regress:
///
///   • both data-collection toggles default OFF (KVKK Article 5 needs
///     explicit opt-in — a missing choice is denial), and the primary
///     CTA reflects "essential only" until the user flips something;
///   • the essential-only path persists BOTH channels as denied,
///     records that a decision was made, and routes forward.
///
/// The persist path also calls `AnalyticsService.setEnabled` (guarded +
/// try/caught when the SDK isn't initialised) and `Sentry.addBreadcrumb`
/// (a no-op when Sentry isn't initialised), so it runs cleanly under a
/// bare widget test without booting the analytics stack.

Widget _hostConsent(SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: AppRoutes.consent,
    routes: [
      GoRoute(
        path: AppRoutes.consent,
        builder: (_, __) => const ConsentScreen(),
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'renders both toggles OFF with the essential-only CTA and disclaimer',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostConsent(prefs));
      await tester.pump();

      expect(find.text('Gizlilik Tercihlerin'), findsOneWidget);
      expect(find.text('Anonim Kullanım Verileri'), findsOneWidget);
      expect(find.text('Anonim Çökme Raporları'), findsOneWidget);
      expect(find.text('Gizlilik Politikasını Oku'), findsOneWidget);
      // Both toggles must start OFF (explicit opt-in).
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      expect(switches.every((s) => s.value == false), isTrue);
      // With nothing flipped the CTA reads "essential only".
      expect(find.text('Sadece Zorunlu — Devam Et'), findsOneWidget);
      expect(find.text('Tercihlerimi Kaydet'), findsNothing);
    },
  );

  testWidgets(
    'flipping a toggle switches the primary CTA to save-preferences',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostConsent(prefs));
      await tester.pump();

      // Tapping the tile toggles its switch via the InkWell.
      await tester.tap(find.text('Anonim Kullanım Verileri'));
      await tester.pump();

      expect(find.text('Tercihlerimi Kaydet'), findsOneWidget);
      expect(find.text('Sadece Zorunlu — Devam Et'), findsNothing);
    },
  );

  testWidgets(
    'essential-only choice persists denial of both channels and routes on',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_hostConsent(prefs));
      await tester.pump();

      await tester.tap(find.text('Sadece Zorunlu — Devam Et'));
      await tester.pumpAndSettle();

      final saved = AppPreferences(prefs);
      expect(saved.consentDecisionMade, isTrue);
      expect(saved.analyticsConsentGranted, isFalse);
      expect(saved.crashReportingConsentGranted, isFalse);
      expect(find.text('ONBOARDING_ROUTE'), findsOneWidget);
    },
  );
}
