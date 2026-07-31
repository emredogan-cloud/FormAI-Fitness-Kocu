import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/presentation/badges_screen.dart';
import 'package:sixpack_ai/features/progress/providers/badge_unlocks_provider.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 1 (R2.3) · the `voice_heard` badge.
///
/// Two things must hold together, and the second is easy to forget:
///   1. the unlock predicate fires off the feedback count, and
///   2. the badge is actually *findable* in the full gallery.
///
/// A badge that unlocks but appears in no gallery is worse than no badge
/// — the celebration fires and the user can never see it again. Device
/// QA on this phase caught exactly that, hence the second test.
class _StubWorkoutSessionNotifier extends WorkoutSessionNotifier {
  @override
  Future<WorkoutSessionState> build() async => const WorkoutSessionState();
}

Future<ProviderContainer> _container([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workoutSessionProvider.overrideWith(_StubWorkoutSessionNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('unlock predicate', () {
    test('locked with no feedback submitted', () async {
      final container = await _container();
      expect(
        container.read(unlockedBadgesProvider),
        isNot(contains('voice_heard')),
      );
    });

    test(
        'unlocks on the first submitted message — participation, '
        'not volume', () async {
      final container = await _container({
        'sixpack.feedback_submitted_count': 1,
      });
      expect(container.read(unlockedBadgesProvider), contains('voice_heard'));
    });

    test('stays unlocked as the count grows', () async {
      final container = await _container({
        'sixpack.feedback_submitted_count': 9,
      });
      expect(container.read(unlockedBadgesProvider), contains('voice_heard'));
    });
  });

  group('catalogue', () {
    test('the badge exists in kBadgeCatalog with an emoji', () {
      // Roadmap Phase 5 · label/subtitle moved to ARB; the copy half of
      // this assertion now lives in badge_copy_test.dart, which checks
      // every badge in every locale rather than this one in Turkish.
      final badge = badgeById('voice_heard');
      expect(badge, isNotNull);
      expect(badge!.emoji, isNotEmpty);
    });

    test('badge ids across the catalogue are unique', () {
      final ids = kBadgeCatalog.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test(
        'every badge the unlock provider can emit has catalogue copy — '
        'otherwise the celebration dialog has nothing to render', () async {
      // Seed every signal at once so the provider emits its full set.
      final container = await _container({
        'sixpack.feedback_submitted_count': 5,
        'sixpack.nutrition_streak': 40,
      });
      for (final id in container.read(unlockedBadgesProvider)) {
        expect(
          badgeById(id),
          isNotNull,
          reason: 'badge "$id" unlocks but has no kBadgeCatalog entry',
        );
      }
    });
  });

  group('gallery visibility', () {
    testWidgets('the badge is findable in the full gallery once unlocked',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 4600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'sixpack.feedback_submitted_count': 1,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            workoutSessionProvider
                .overrideWith(_StubWorkoutSessionNotifier.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('tr')],
            home: BadgesScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Sesini Duyduk'), findsOneWidget);
    });

    testWidgets('it renders in the gallery while still locked too',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 4600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            workoutSessionProvider
                .overrideWith(_StubWorkoutSessionNotifier.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('tr')],
            home: BadgesScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Sesini Duyduk'), findsOneWidget);
      expect(find.text('Geri bildirim gönder'), findsOneWidget);
    });
  });
}
