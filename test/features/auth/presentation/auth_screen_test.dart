import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/auth/presentation/auth_screen.dart';

/// The auth screen's build is pure `_mode`-driven UI — Supabase is only
/// touched inside the submit / social handlers, and `_submit` runs the
/// form validator (returning early on failure) before it ever reaches
/// `_client`. So the mode toggle and client-side field validation are
/// fully testable without booting Supabase.

Widget _host(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MaterialApp(
      home: AuthScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('defaults to sign-in and toggles to sign-up', (tester) async {
    _tallViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    // Sign-in mode.
    expect(find.text('Tekrar hoşgeldin.'), findsOneWidget);
    expect(find.text('GİRİŞ YAP'), findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsOneWidget);

    // Flip to sign-up.
    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pump();

    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.text('KAYIT OL'), findsOneWidget);
    // Forgot-password is a sign-in-only affordance.
    expect(find.text('Şifremi unuttum'), findsNothing);
  });

  testWidgets('submitting empty fields surfaces required-field errors',
      (tester) async {
    _tallViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    await tester.tap(find.text('GİRİŞ YAP'));
    await tester.pump();

    // Validator fails → errors render, Supabase is never reached.
    expect(find.text('E-posta gerekli'), findsOneWidget);
    expect(find.text('Şifre gerekli'), findsOneWidget);
  });

  testWidgets('rejects a malformed email and a too-short password',
      (tester) async {
    _tallViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'notanemail');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text('GİRİŞ YAP'));
    await tester.pump();

    expect(find.text('Geçersiz e-posta'), findsOneWidget);
    expect(find.text('En az 6 karakter'), findsOneWidget);
  });
}
