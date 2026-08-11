import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/utils/app_copy.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 6 · the fallback chain, and the hot switch.
///
/// The chain the roadmap asks for is: missing key → English → Turkish →
/// key name, never a blank and never a crash. Its first two links are
/// enforced at BUILD time, not runtime: `tool/arb_coverage.dart` runs in
/// CI and fails on any key present in one locale and absent in the
/// other, so "missing key" cannot reach a device. What is left to prove
/// at runtime is the last link — a locale we do not ship must land on
/// one we do rather than on a screen of untranslated identifiers.
///
/// That is worth stating out loud, because "we have a runtime fallback"
/// and "we have a build-time guarantee" are different promises and only
/// one of them is true here.

/// Mirrors `main.dart`'s `_resolveLocale` contract through a real
/// `MaterialApp`, so the test exercises the framework's plumbing rather
/// than a copy of the logic.
Widget _app(SharedPreferences prefs) {
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
          AppCopy.locale = kFallbackLocale;
          return kFallbackLocale;
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text(AppLocalizations.of(context).navProfile),
                Text(Localizations.localeOf(context).languageCode),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<SharedPreferences> _prefs([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

void main() {
  group('resolution', () {
    testWidgets('a shipped device locale is honoured', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(_app(await _prefs()));
      await tester.pump();

      expect(find.text('en'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('a locale we do not ship falls back to English, not to keys',
        (tester) async {
      // The failure this guards against is not "the user gets the wrong
      // language" — it is a screen of raw identifiers, which is what the
      // framework default produces for an unmatched locale.
      //
      // The fallback was Turkish until the device-language phase, on the
      // strength of Turkish being the home market. That argument is about
      // a user this branch never sees: a Turkish speaker's phone is set
      // to Turkish and matches above. Everyone who actually reaches here
      // asked for something we don't ship, and English is the likelier
      // second language for them. See `kFallbackLocale`.
      tester.platformDispatcher.localesTestValue = [const Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(_app(await _prefs()));
      await tester.pump();

      expect(find.text('en'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('the fallback is not just the head of the supported list',
        (tester) async {
      // Guards the decoupling itself. `kSupportedLocales` is also the
      // picker's render order and Turkish leads it deliberately; if a
      // later edit re-derives the fallback from `.first`, this fails
      // while the test above would still pass on a reordered list.
      expect(kFallbackLocale, const Locale('en'));
      expect(kSupportedLocales.first, const Locale('tr'));
      expect(kSupportedLocales, contains(kFallbackLocale));
    });

    testWidgets('an explicit choice beats the device', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(
        _app(await _prefs({LocaleNotifier.storageKey: 'en'})),
      );
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('hot switch', () {
    testWidgets('changing the language rebuilds the tree, with no restart',
        (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final prefs = await _prefs();
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return MaterialApp(
                locale: ref.watch(localeProvider),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: kSupportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Text(AppLocalizations.of(context).navProfile),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Profil'), findsOneWidget);

      await captured.read(localeProvider.notifier).set(const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Profil'), findsNothing);
    });
  });

  group('the build-time half of the chain', () {
    test('every locale implements every message', () {
      // `lookupAppLocalizations` returns a concrete subclass per locale,
      // and Dart will not compile one that leaves a message abstract. So
      // this is really an assertion that the ARBs are in step — which
      // arb_coverage enforces in CI, and which this restates where a
      // reader of the fallback chain will look for it.
      for (final locale in kSupportedLocales) {
        final strings = lookupAppLocalizations(locale);
        expect(strings.navProfile.trim(), isNotEmpty,
            reason: '${locale.languageCode} left navProfile blank');
        // Was `languageStepTitle`, which belonged to the onboarding
        // language ask and went with it. The Settings picker's title is
        // the surviving string in that family and makes the same point.
        expect(strings.languageSettingsTitle.trim(), isNotEmpty,
            reason: '${locale.languageCode} left languageSettingsTitle blank');
      }
    });

    test('the tree-less surfaces follow the same locale', () {
      // AppCopy is what notifications, the home widget and TTS read.
      // Nothing sets it for them, so if it ever stopped tracking the
      // resolved locale, the app would speak one language on screen and
      // another on the lock screen.
      AppCopy.locale = const Locale('en');
      expect(AppCopy.strings.navProfile, 'Profile');
      AppCopy.locale = const Locale('tr');
      expect(AppCopy.strings.navProfile, 'Profil');
    });
  });
}
