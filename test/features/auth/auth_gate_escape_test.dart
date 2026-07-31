import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/auth/presentation/auth_modal_bottom_sheet.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Guest-trap regression (P0). The paywall's forced auth gate must never
/// be a dead-end: an anonymous user (guest, or a store reviewer picking
/// "guest") has to be able to leave it. The gate is non-dismissible by
/// back/scrim/swipe BY DESIGN (so anonymous purchases stay impossible),
/// so the ONLY escapes are the on-screen affordances. This test pins
/// that the "Şimdilik değil" dashboard escape renders alongside the
/// sign-in options — if it regresses, guests are trapped again.
void main() {
  testWidgets(
    'auth gate renders the "Şimdilik değil" dashboard escape so guests '
    'are never trapped',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            // Roadmap Phase 5 · localized strings need the
            // delegates; assertions stay unchanged because the
            // Turkish ARB values are the same literals.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('tr')],
            home: Scaffold(body: AuthModalBottomSheet()),
          ),
        ),
      );
      await tester.pump();

      // The two sign-in escapes...
      expect(find.text('Google ile Devam Et'), findsOneWidget);
      expect(find.text('E-posta ile Giriş Sayfasına Git'), findsOneWidget);
      // ...and the dashboard escape that breaks the trap.
      expect(find.text('Şimdilik değil'), findsOneWidget);
    },
  );
}
