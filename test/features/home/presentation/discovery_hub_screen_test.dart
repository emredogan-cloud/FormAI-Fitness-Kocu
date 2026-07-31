import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/disclosure_providers.dart';
import 'package:sixpack_ai/core/services/progressive_disclosure.dart';
import 'package:sixpack_ai/features/home/presentation/discovery_hub_screen.dart';
import 'package:sixpack_ai/features/home/presentation/unlock_hint_copy.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 4 (C28 · R1.3) · the capability map.
///
/// This screen is what makes staged disclosure an introduction rather
/// than a restriction. The properties it must hold are exactly that
/// claim: everything is listed whether or not it is open, a locked row
/// says when it arrives, and any locked row can be opened right now.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int days = 0,
  int sessions = 0,
  Map<String, Object> seed = const {},
  // Tall by default so the lazily-built list renders every row: these
  // tests are about which capabilities exist and what state they are
  // in, not about scrolling. The small-phone layout gets its own test.
  Size surface = const Size(393, 2400),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  SharedPreferences.setMockInitialValues({
    // `installedAt` drives daysSinceInstall.
    'sixpack.installed_at':
        DateTime.now().subtract(Duration(days: days)).toIso8601String(),
    ...seed,
  });
  final raw = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(raw),
      completedSessionCountProvider.overrideWithValue(sessions),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('tr')],
        home: const DiscoveryHubScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

late AppLocalizations l10n;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('nothing is hidden', () {
    testWidgets('every capability is listed on a brand-new install', (t) async {
      await _pump(t);
      for (final capability in Capability.values) {
        expect(
          find.text(capability.title(l10n)),
          findsOneWidget,
          reason: '${capability.key} missing from the hub',
        );
      }
    });

    testWidgets('each pillar with capabilities gets a heading', (t) async {
      await _pump(t);
      final pillars = Capability.values.map((c) => c.pillar).toSet();
      for (final pillar in pillars) {
        expect(find.text(pillar.label(l10n).toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('the header counts what is open out of the total', (t) async {
      await _pump(t);
      expect(find.text('0 / ${Capability.values.length}'), findsOneWidget);
    });
  });

  group('locked rows explain themselves', () {
    testWidgets('a locked row shows an unlock hint, not a bare lock',
        (t) async {
      await _pump(t);
      // On day 0 every capability is closer by training than by
      // waiting, so every hint points at the workout — which turns the
      // lock into a nudge toward the thing the app wants the user to do.
      expect(find.textContaining('antrenman sonra açılıyor'), findsWidgets);
    });

    testWidgets('the hint switches to days once training is the longer road',
        (t) async {
      // Day 6, no sessions: the calendar is one day away but five
      // workouts away.
      await _pump(t, days: 6);
      expect(find.text('Yarın açılıyor'), findsWidgets);
    });

    testWidgets('every locked row offers an immediate override', (t) async {
      await _pump(t);
      // Disclosure is a default, never a restriction — so the escape
      // hatch is on every locked row, not buried in settings.
      expect(
        find.text('Şimdi aç'),
        findsNWidgets(Capability.values.length),
      );
    });

    testWidgets('an unlocked row offers "Aç" instead', (t) async {
      await _pump(t, days: 365);
      expect(find.text('Şimdi aç'), findsNothing);
      expect(find.text('Aç'), findsNWidgets(Capability.values.length));
    });
  });

  group('manual unlock', () {
    testWidgets('tapping "Şimdi aç" opens that capability permanently',
        (t) async {
      final container = await _pump(t);
      await t.tap(find.text('Şimdi aç').first);
      await t.pumpAndSettle();

      final prefs = container.read(appPreferencesProvider);
      expect(prefs.manualUnlocks, contains(Capability.nutrition.key));
      expect(
        isUnlocked(
          Capability.nutrition,
          container.read(disclosureStateProvider),
        ),
        isTrue,
      );
    });

    testWidgets('it also counts as announced, so no celebration follows',
        (t) async {
      // The app taking credit for something the user did themselves
      // would read as tone-deaf.
      final container = await _pump(t);
      await t.tap(find.text('Şimdi aç').first);
      await t.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).announcedUnlocks,
        contains(Capability.nutrition.key),
      );
    });

    testWidgets('the row flips to unlocked without leaving the screen',
        (t) async {
      await _pump(t);
      final before = find.text('Şimdi aç').evaluate().length;
      await t.tap(find.text('Şimdi aç').first);
      await t.pumpAndSettle();
      expect(find.text('Şimdi aç').evaluate().length, before - 1);
    });
  });

  group('state reflects the schedule', () {
    testWidgets('a user several days in sees a mix', (t) async {
      await _pump(t, days: 3);
      expect(find.text('Aç'), findsWidgets);
      expect(find.text('Şimdi aç'), findsWidgets);
    });

    testWidgets('sessions unlock without waiting for days', (t) async {
      await _pump(t, days: 0, sessions: 10);
      expect(find.text('Şimdi aç'), findsNothing);
    });
  });

  group('resilience', () {
    testWidgets('lays out on a small phone without overflow', (t) async {
      await _pump(t, surface: const Size(360, 640));
      expect(t.takeException(), isNull);
    });

    testWidgets('screen-reader labels state the lock status', (t) async {
      await _pump(t);
      final handle = t.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('${Capability.nutrition.title(l10n)}\\.')),
        findsWidgets,
      );
      handle.dispose();
    });
  });
}
