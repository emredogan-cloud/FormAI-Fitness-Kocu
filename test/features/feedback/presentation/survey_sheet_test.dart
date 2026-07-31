import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/feedback/domain/survey.dart';
import 'package:sixpack_ai/features/feedback/presentation/survey_sheet.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 1 (C8) · the micro-survey sheet.
const _nps = SurveyDefinition(
  id: 'test_nps',
  kind: SurveyKind.nps,
  question: 'Önerir miydin?',
  subtitle: '0 = hayır, 10 = evet',
);

const _choice = SurveyDefinition(
  id: 'test_choice',
  kind: SurveyKind.choice,
  question: 'En çok ne işine yarıyor?',
  options: [
    SurveyOption(token: 'coach', label: 'AI koç'),
    SurveyOption(token: 'plan', label: 'Plan'),
  ],
);

Future<void> _pumpSheet(
  WidgetTester tester,
  SurveyDefinition survey, {
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('tr')],
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSurveySheet(context, survey: survey),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an NPS survey renders all 11 values, 0 through 10',
      (tester) async {
    await _pumpSheet(tester, _nps);

    expect(tester.takeException(), isNull);
    expect(find.text('Önerir miydin?'), findsOneWidget);
    expect(find.text('0 = hayır, 10 = evet'), findsOneWidget);
    for (var i = 0; i <= 10; i++) {
      expect(
        find.text('$i'),
        findsOneWidget,
        reason: 'NPS value $i must be reachable — a hidden promoter end '
            'biases the score',
      );
    }
  });

  testWidgets('a choice survey renders every option', (tester) async {
    await _pumpSheet(tester, _choice);

    expect(tester.takeException(), isNull);
    expect(find.text('AI koç'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
  });

  testWidgets('answering shows the thank-you state then auto-closes',
      (tester) async {
    await _pumpSheet(tester, _nps);

    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Teşekkürler.'), findsOneWidget);

    // The thank-you beat is a `Future.delayed`, not a scheduled frame,
    // so pumpAndSettle alone would return before it fires. Advance past
    // the 1100ms hold explicitly, then settle the pop animation.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('Teşekkürler.'), findsNothing);
  });

  testWidgets('answering records the survey so it is never re-asked',
      (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('tr')],
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSurveySheet(context, survey: _nps),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    // Advance past the thank-you hold so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(
      container.read(appPreferencesProvider).answeredSurveyIds,
      contains(_nps.id),
    );
  });

  testWidgets(
      'dismissing records the survey as answered — a user who closed it '
      'has given their answer', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: [Locale('tr')],
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSurveySheet(context, survey: _nps),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(
      container.read(appPreferencesProvider).answeredSurveyIds,
      contains(_nps.id),
    );
  });

  testWidgets('the NPS scale survives a 1.3 text scale without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pumpSheet(tester, _nps, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
