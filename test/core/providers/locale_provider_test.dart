import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';

/// Roadmap Phase 6 (R3.2) · the language preference and its default.
Future<ProviderContainer> _container(
    [Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('default', () {
    test('a fresh install has no choice, which is what follows the device',
        () async {
      final container = await _container();
      expect(container.read(localeProvider), isNull);
    });

    test('never-chosen and chose-Turkish are different states', () async {
      // The distinction is load-bearing: a user who has never been asked
      // tracks a device whose language may change tomorrow; a user who
      // picked Türkçe does not.
      final fresh = await _container();
      expect(fresh.read(localeProvider), isNull);

      final chose = await _container({LocaleNotifier.storageKey: 'tr'});
      expect(chose.read(localeProvider), const Locale('tr'));
    });
  });

  group('persistence', () {
    test('a choice survives a rebuild of the container', () async {
      SharedPreferences.setMockInitialValues({});
      final raw = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
      );
      await first.read(localeProvider.notifier).set(const Locale('en'));
      expect(first.read(localeProvider), const Locale('en'));
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(raw)],
      );
      addTearDown(second.dispose);
      expect(second.read(localeProvider), const Locale('en'));
    });

    test('following the device is stored, not cleared', () async {
      // A cleared key reads as "never asked", which would let the
      // account copy overwrite the user's explicit reset on next launch.
      final container = await _container({LocaleNotifier.storageKey: 'en'});
      await container.read(localeProvider.notifier).set(null);

      expect(container.read(localeProvider), isNull);
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString(LocaleNotifier.storageKey), 'system');
    });
  });

  group('decode', () {
    test('a language this build no longer ships falls back to the device',
        () async {
      final container = await _container({LocaleNotifier.storageKey: 'de'});
      expect(container.read(localeProvider), isNull);
    });

    test('so does a corrupted value', () async {
      final container = await _container({LocaleNotifier.storageKey: '{}'});
      expect(container.read(localeProvider), isNull);
    });

    test('every shipped locale round-trips', () async {
      for (final locale in kSupportedLocales) {
        final container =
            await _container({LocaleNotifier.storageKey: locale.languageCode});
        expect(container.read(localeProvider), locale);
      }
    });
  });

  group('deviceLocale', () {
    // Found on a device: with English selected on a Turkish phone, the
    // settings sheet's "Device language" row read "Currently English"
    // — describing the choice it exists to undo. `Localizations.localeOf`
    // returns the ACTIVE locale, which is the override when there is one.
    testWidgets('reports the phone, not the app', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      expect(deviceLocale(), const Locale('tr'));

      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      expect(deviceLocale(), const Locale('en'));
    });

    testWidgets('an unshipped phone language falls back to English',
        (tester) async {
      // Deliberately asserted against `kFallbackLocale` and NOT against
      // `kSupportedLocales.first`, which is Turkish. The two used to be
      // the same constant; splitting them is the point of the change.
      tester.platformDispatcher.localesTestValue = [const Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      expect(deviceLocale(), kFallbackLocale);
      expect(deviceLocale(), const Locale('en'));
    });

    testWidgets('a later preferred locale wins over an unshipped first',
        (tester) async {
      // Android hands over an ordered list, and the walk down it has to
      // actually happen. Deliberately [de, tr] rather than [de, en]:
      // English is now the fallback, so a phone whose second choice is
      // English returns English whether the walk works or not, and the
      // test would pass on a build that had lost it entirely. Turkish
      // second can only be reached by matching.
      tester.platformDispatcher.localesTestValue = const [
        Locale('de'),
        Locale('tr')
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      expect(deviceLocale(), const Locale('tr'));
    });
  });

  group('endonyms', () {
    test('each shipped locale names itself in its own language', () {
      expect(localeEndonym(const Locale('tr')), 'Türkçe');
      expect(localeEndonym(const Locale('en')), 'English');
    });

    test('every shipped locale has one, and they are distinct', () {
      final names = kSupportedLocales.map(localeEndonym).toList();
      expect(names.where((n) => n.trim().isEmpty), isEmpty);
      expect(names.toSet().length, names.length);
    });
  });

  test('re-selecting the active locale is a no-op', () async {
    // Same guard as the theme notifier: a picker firing onSelected for
    // the already-active value must not push a notification through a
    // tree that is mid-rebuild.
    final container = await _container({LocaleNotifier.storageKey: 'en'});
    var notifications = 0;
    container.listen(localeProvider, (_, __) => notifications++);

    await container.read(localeProvider.notifier).set(const Locale('en'));
    expect(notifications, 0);

    await container.read(localeProvider.notifier).set(const Locale('tr'));
    expect(notifications, 1);
  });
}
