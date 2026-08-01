import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/onboarding/presentation/steps/language_step.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 6 (R3.2, C29) · onboarding step 0.
///
/// The behaviour worth protecting is not "two rows render". It is that
/// tapping a row changes the language of the screen the row is on —
/// which is the only feedback a user who cannot read the current
/// language gets.
Future<SharedPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

/// Mirrors `main.dart`: the user's choice drives `locale`, and the
/// callback resolves whatever Flutter hands it — the explicit choice
/// when there is one, the platform locale when there is not.
///
/// Getting this wrong is easy and quiet. An earlier version of this
/// harness ignored the callback's first argument and matched the device
/// every time, so the screen never changed language and the test looked
/// like an app bug.
Widget _host(SharedPreferences prefs, {VoidCallback? onContinue}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        localeResolutionCallback: (requested, supported) {
          for (final l in supported) {
            if (l.languageCode == requested?.languageCode) return l;
          }
          return supported.first;
        },
        home: Scaffold(
          body: LanguageStep(onContinue: onContinue ?? () {}),
        ),
      ),
    ),
  );
}

/// The language the phone is set to, which is what a fresh install
/// follows. Tests default to `en_US` otherwise.
void _device(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  // The redesigned screen is a full phone screen tall. The 800x600
  // default surface puts the second language row below the fold, where
  // a tap silently lands on the scroll view instead of the row.
  tester.view.physicalSize = const Size(393, 851);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Scrolls a row into view before tapping it.
Future<void> _tapLanguage(WidgetTester tester, String endonym) async {
  final target = find.text(endonym).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every shipped language is offered, named in itself',
      (tester) async {
    _device(tester, const Locale('tr'));
    await tester.pumpWidget(_host(await _prefs()));
    await tester.pump();

    // Each row carries the endonym AND the English name, per the
    // reference design — so the English row legitimately says "English"
    // twice and 'Turkish' appears beside 'Türkçe'.
    expect(find.text('Türkçe'), findsOneWidget);
    expect(find.text('Turkish'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2));
  });

  testWidgets('the device language is pre-selected without being stored',
      (tester) async {
    _device(tester, const Locale('en'));
    final prefs = await _prefs();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    // Rendering English proves the pre-selection; an empty store proves
    // it was not mistaken for a choice.
    expect(find.text('Choose your language'), findsOneWidget);
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
  });

  testWidgets('tapping a language re-renders this screen in it',
      (tester) async {
    _device(tester, const Locale('tr'));
    final prefs = await _prefs();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();
    expect(find.text('Dilini seç'), findsOneWidget);

    await _tapLanguage(tester, 'English');

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Dilini seç'), findsNothing);
    // And the CTA came with it — the whole subtree re-rendered, not
    // just the heading.
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('the tap is what persists the choice', (tester) async {
    _device(tester, const Locale('tr'));
    final prefs = await _prefs();
    await tester.pumpWidget(_host(prefs));
    await tester.pump();

    await _tapLanguage(tester, 'English');

    expect(prefs.getString(LocaleNotifier.storageKey), 'en');
  });

  testWidgets('the selected row is marked, and only that row', (tester) async {
    _device(tester, const Locale('tr'));
    await tester.pumpWidget(_host(await _prefs()));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);

    await _tapLanguage(tester, 'English');

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('continuing without tapping leaves the device in charge',
      (tester) async {
    _device(tester, const Locale('tr'));
    var continued = false;
    final prefs = await _prefs();
    await tester.pumpWidget(_host(prefs, onContinue: () => continued = true));
    await tester.pump();

    await tester.tap(find.text('Devam'));
    await tester.pump();

    expect(continued, isTrue);
    // Accepting a default is not the same act as choosing one. Storing
    // it here would pin a language against a phone whose own language
    // may change tomorrow.
    expect(prefs.getString(LocaleNotifier.storageKey), isNull);
  });
}
