import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/presentation/suggestions_screen.dart';
import 'package:sixpack_ai/features/workout/providers/workout_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

class _StubWorkoutSessionNotifier extends WorkoutSessionNotifier {
  _StubWorkoutSessionNotifier(this._seed);
  final WorkoutSessionState _seed;

  @override
  Future<WorkoutSessionState> build() async => _seed;
}

Future<Widget> _host(WorkoutSessionState seed) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      workoutSessionProvider.overrideWith(
        () => _StubWorkoutSessionNotifier(seed),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      home: SuggestionsScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  testWidgets('renders the coach hero + 3 suggestion cards for a fresh user',
      (tester) async {
    final widget = await _host(const WorkoutSessionState());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Öneriler'), findsOneWidget);
    expect(find.text('BUGÜNÜN ÖNERİLERİ'), findsOneWidget);
    expect(find.text('AI Koçun diyor ki'), findsOneWidget);
    // Scroll the "Su içmeyi unutma" tip into view — it's the 3rd
    // card and sits past the default 600-px viewport on an empty
    // session state.
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -400));
    await tester.pump();
    expect(find.text('Su içmeyi unutma'), findsOneWidget);
  });
}
