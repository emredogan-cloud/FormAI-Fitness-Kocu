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
const String _kWeighInKey = 'sixpack.weigh_in_reminder_enabled';

/// The switch inside the toggle tile whose title is [title].
///
/// Roadmap Phase 9 added a second toggle to this screen, so
/// `find.byType(Switch)` is no longer unique. Locating by the tile's own
/// title rather than by index means a third toggle cannot silently make
/// these assertions about the wrong row.
Switch _switchTitled(WidgetTester tester, String title) {
  return tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    ),
  );
}

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
    expect(find.text('Haftalık tartılma hatırlatıcısı'), findsOneWidget);
    expect(find.text('TEHLİKELİ BÖLGE'), findsOneWidget);

    // Both reminders default to off — neither is scheduled without an
    // explicit opt-in.
    expect(_switchTitled(tester, 'Bildirimler').value, isFalse);
    expect(
      _switchTitled(tester, 'Haftalık tartılma hatırlatıcısı').value,
      isFalse,
    );
  });

  testWidgets('reminder switch reflects the persisted enabled state',
      (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues({_kReminderKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    expect(_switchTitled(tester, 'Bildirimler').value, isTrue);
  });

  testWidgets(
      'the weigh-in nudge is its own consent — enabling the training '
      'reminder does not turn it on', (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues({_kReminderKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    expect(_switchTitled(tester, 'Bildirimler').value, isTrue);
    expect(
      _switchTitled(tester, 'Haftalık tartılma hatırlatıcısı').value,
      isFalse,
      reason: 'wanting a training reminder is not asking to be prompted '
          'about body weight',
    );
  });

  testWidgets('the weigh-in switch reflects its own persisted state',
      (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues({_kWeighInKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    expect(
      _switchTitled(tester, 'Haftalık tartılma hatırlatıcısı').value,
      isTrue,
    );
    expect(_switchTitled(tester, 'Bildirimler').value, isFalse);
  });
}
