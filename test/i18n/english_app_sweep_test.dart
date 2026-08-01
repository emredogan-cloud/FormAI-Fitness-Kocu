import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/disclosure_providers.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/home/presentation/account_settings_screen.dart';
import 'package:sixpack_ai/features/home/presentation/discovery_hub_screen.dart';
import 'package:sixpack_ai/features/progress/presentation/badges_screen.dart';
import 'package:sixpack_ai/features/progress/presentation/calendar_screen.dart';
import 'package:sixpack_ai/features/progress/presentation/suggestions_screen.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';

import '../support/layout_probe.dart' show Viewports, scrollThrough;
import '../support/locale_probe.dart';

/// Roadmap Phase 6 · the English sweep, past onboarding.
///
/// The pseudo and RTL suites both stop at the paywall — every surface
/// either of them has ever rendered is part of the funnel. So the
/// screens a user spends the *rest* of their time in had never been
/// checked in any locale by any automated pass, which is the wrong half
/// of the app to leave uncovered.
///
/// These need provider stubs where the funnel screens did not, which is
/// why each test assembles its own scope instead of sharing one.
class _StubWorkoutSession extends WorkoutSessionNotifier {
  _StubWorkoutSession(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(const {});
  return SharedPreferences.getInstance();
}

Future<void> _sweep(
  WidgetTester tester,
  String describe,
  Widget scope,
) async {
  for (final scale in const [1.0, 1.3]) {
    await tester.pumpWidget(const SizedBox.shrink());
    while (tester.takeException() != null) {}

    await pumpInLocale(tester, scope, size: Viewports.phone, textScale: scale);

    final errors = <Object>[];
    for (var e = tester.takeException();
        e != null;
        e = tester.takeException()) {
      errors.add(e);
    }
    await scrollThrough(tester, errors);
    expect(
      errors,
      isEmpty,
      reason: '$describe overflowed in English at ${scale}x:\n'
          '${errors.join('\n')}',
    );
    expectNoTurkish(tester, describe, allow: kNeverTranslated);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
  while (tester.takeException() != null) {}
}

void main() {
  testWidgets('badges', (tester) async {
    final prefs = await _prefs();
    await _sweep(
      tester,
      'Badges screen',
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          workoutSessionProvider.overrideWith(
            () => _StubWorkoutSession(const WorkoutSessionState()),
          ),
        ],
        child: const BadgesScreen(),
      ),
    );
  });

  testWidgets('calendar', (tester) async {
    final prefs = await _prefs();
    await _sweep(
      tester,
      'Calendar screen',
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          workoutSessionProvider.overrideWith(
            () => _StubWorkoutSession(const WorkoutSessionState()),
          ),
        ],
        child: const CalendarScreen(),
      ),
    );
  });

  testWidgets('suggestions', (tester) async {
    final prefs = await _prefs();
    await _sweep(
      tester,
      'Suggestions screen',
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          workoutSessionProvider.overrideWith(
            () => _StubWorkoutSession(const WorkoutSessionState()),
          ),
        ],
        child: const SuggestionsScreen(),
      ),
    );
  });

  testWidgets('discovery hub', (tester) async {
    final prefs = await _prefs();
    await _sweep(
      tester,
      'Discovery hub',
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          completedSessionCountProvider.overrideWithValue(3),
        ],
        child: const DiscoveryHubScreen(),
      ),
    );
  });

  testWidgets('account settings', (tester) async {
    final prefs = await _prefs();
    await _sweep(
      tester,
      'Account settings',
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const AccountSettingsScreen(),
      ),
    );
  });
}
