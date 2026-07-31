import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/auth/providers/auth_provider.dart';
import 'package:sixpack_ai/features/home/presentation/widgets/profile_tab.dart';
import 'package:sixpack_ai/features/monetization/providers/monetization_provider.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 1 (R2.1 · C30) · the AYARLAR section of the Profile tab.
///
/// The Testers Community observation this pins down, verbatim:
///
///   "There is no option to rate the app under the settings menu,
///    making it harder for users to provide feedback or leave reviews."
///
/// These tests assert the row now exists, is present for *every* user
/// class (the Phase 136 rating scene was Pro-only — that inversion is
/// exactly what C10 fixed), and that the help-centre row sits alongside
/// it. `currentUserProvider` is overridden so the build never reaches
/// `Supabase.instance`.
class _StubWorkoutSessionNotifier extends WorkoutSessionNotifier {
  @override
  Future<WorkoutSessionState> build() async => const WorkoutSessionState();
}

Widget _host(SharedPreferences prefs, {required bool isPro}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(null),
      isProProvider.overrideWithValue(isPro),
      workoutSessionProvider.overrideWith(_StubWorkoutSessionNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('tr')],
      home: const Scaffold(body: ProfileTab()),
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// A tall viewport so the whole ListView is mounted — off-screen
/// ListView children aren't in the element tree, which would make
/// `find.text` on the AYARLAR rows a false negative.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, {required bool isPro}) async {
  _tallViewport(tester);
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(_host(prefs, isPro: isPro));
  await tester.pump();
}

void main() {
  testWidgets(
      'R2.1 · the "Uygulamayı Değerlendir" row exists in the settings menu',
      (tester) async {
    await _pump(tester, isPro: false);

    expect(tester.takeException(), isNull);
    expect(find.text('Uygulamayı Değerlendir'), findsOneWidget);
    expect(find.text('Play Store\'da bizi değerlendir.'), findsOneWidget);
  });

  testWidgets(
      'C10 · the rate row is present for a FREE user — the population '
      'whose reviews build a new listing was previously never asked',
      (tester) async {
    await _pump(tester, isPro: false);
    expect(find.text('Uygulamayı Değerlendir'), findsOneWidget);
  });

  testWidgets('the rate row is present for a Pro user too', (tester) async {
    await _pump(tester, isPro: true);
    expect(find.text('Uygulamayı Değerlendir'), findsOneWidget);
  });

  testWidgets('C30 · the help-centre row exists above the feedback row',
      (tester) async {
    await _pump(tester, isPro: false);

    expect(find.text('Yardım Merkezi'), findsOneWidget);
    expect(find.text('Destek & Geri Bildirim'), findsOneWidget);

    // Ordering matters: help sits above feedback so a user finds the
    // answer before writing a ticket.
    final helpY = tester.getTopLeft(find.text('Yardım Merkezi')).dy;
    final feedbackY = tester.getTopLeft(find.text('Destek & Geri Bildirim')).dy;
    expect(helpY, lessThan(feedbackY));
  });

  testWidgets('the rate row is tappable without throwing', (tester) async {
    await _pump(tester, isPro: false);

    // The handler reaches in_app_review / url_launcher, both of which
    // are unavailable in a test binding. The service swallows those
    // failures by design (a rating tap must never crash a session), so
    // this asserts the graceful path.
    await tester.tap(find.text('Uygulamayı Değerlendir'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the settings rows survive a 1.3 text scale', (tester) async {
    _tallViewport(tester);
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
          isProProvider.overrideWithValue(false),
          workoutSessionProvider.overrideWith(_StubWorkoutSessionNotifier.new),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('tr')],
            home: const Scaffold(body: ProfileTab()),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Uygulamayı Değerlendir'), findsOneWidget);
  });
}
