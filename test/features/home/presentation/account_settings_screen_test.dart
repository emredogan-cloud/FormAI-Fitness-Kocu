import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/home/presentation/account_settings_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Account settings hosts the Phase-1 compliance surfaces (password
/// change gate, daily-reminder toggle, and the account-deletion danger
/// zone). Its destructive actions all live behind tap callbacks that
/// reach Supabase / RevenueCat, so these tests cover the render + the
/// persisted reminder-toggle state — the parts that don't need the
/// auth stack booted.
///
/// [currentUserProvider] is overridden with `null` (a guest / anon
/// session) so the build never touches `Supabase.instance`.

const String _kReminderKey = 'sixpack.daily_reminder_enabled';

Widget _host(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      home: const AccountSettingsScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// A tall viewport so the whole ListView (including the bottom "danger
/// zone") is mounted — off-screen ListView children aren't in the
/// element tree, which would make `find.text` on them a false negative.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('renders the account + danger sections for a guest user',
      (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    expect(find.text('Hesap Ayarları'), findsOneWidget);
    expect(find.text('HESAP'), findsOneWidget);
    expect(find.text('Profili Düzenle'), findsOneWidget);
    expect(find.text('Şifreyi Değiştir'), findsOneWidget);
    // Guest/anon → the change-password tile explains it's unavailable.
    expect(
      find.text('Önce bir hesap oluşturman gerekiyor.'),
      findsOneWidget,
    );
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('TEHLİKELİ BÖLGE'), findsOneWidget);

    // Reminder defaults to off.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('reminder switch reflects the persisted enabled state',
      (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues({_kReminderKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
