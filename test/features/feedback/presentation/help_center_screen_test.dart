import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/feedback/data/faq_content.dart';
import 'package:sixpack_ai/features/feedback/presentation/help_center_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 1 (C30) · the help centre.
Future<Widget> _host() async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: [Locale('tr')],
      home: HelpCenterScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

void main() {
  // The catalogue is a function of AppLocalizations now (its search
  // index needs resolved text, not lookups). Loading tr here keeps every
  // assertion below on exactly the strings it always asserted.
  late AppLocalizations l10n;
  late List<FaqCategory> catalogue;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    catalogue = faqCategories(l10n);
  });

  group('search index', () {
    test('an empty query returns the full catalogue', () {
      // Compare shape, not identity: the catalogue is rebuilt per call
      // now, so `same instance` is no longer the right question.
      expect(searchFaq(l10n, '').map((c) => c.title),
          catalogue.map((c) => c.title));
      expect(searchFaq(l10n, '   ').map((c) => c.title),
          catalogue.map((c) => c.title));
    });

    test('search is case-insensitive and matches answer text too', () {
      final byQuestion = searchFaq(l10n, 'KAMERA');
      expect(byQuestion, isNotEmpty);
      // "google play" only appears in answer bodies, never in a question,
      // so a hit proves the answer text is indexed.
      final byAnswer = searchFaq(l10n, 'google play');
      expect(byAnswer, isNotEmpty);
    });

    test(
        'Turkish suffix mutation is a real constraint on this index — a '
        'substring search cannot match "aboneliğimi" from the stem '
        '"abonelik" (k→ğ), so queries are matched literally', () {
      // Documents the known limitation rather than pretending it away.
      // Roadmap Phase 5 (i18n) is where a proper locale-aware collation
      // would replace this substring match.
      expect(searchFaq(l10n, 'abonelik'), isEmpty);
      expect(searchFaq(l10n, 'abonel'), isNotEmpty);
    });

    test('matching categories are pruned to only their matching entries', () {
      final results = searchFaq(l10n, 'hesabımı nasıl silerim');
      expect(results, hasLength(1));
      expect(results.first.entries, hasLength(1));
    });

    test('a query with no matches returns an empty list', () {
      expect(searchFaq(l10n, 'zzzzz-not-a-real-question'), isEmpty);
    });
  });

  group('content quality', () {
    test('no duplicate questions across the whole catalogue', () {
      final questions =
          catalogue.expand((c) => c.entries).map((e) => e.question).toList();
      expect(questions.toSet().length, questions.length);
    });

    test('every entry has a substantive answer', () {
      for (final category in catalogue) {
        for (final entry in category.entries) {
          expect(
            entry.answer.length,
            greaterThan(40),
            reason: '"${entry.question}" has a stub answer',
          );
        }
      }
    });

    test(
        'the camera and subscription categories exist — they are the two '
        'highest-volume support topics for this product shape', () {
      final titles = catalogue.map((c) => c.title).toList();
      expect(titles, contains('ANTRENMAN & KAMERA'));
      expect(titles, contains('ABONELİK'));
    });
  });

  group('screen', () {
    testWidgets('renders the search field and the first category',
        (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Yardım Merkezi'), findsOneWidget);
      expect(find.text('Soru ara…'), findsOneWidget);
      expect(find.text('ANTRENMAN & KAMERA'), findsOneWidget);
    });

    testWidgets('typing a query filters the list down', (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'iptal');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('ABONELİK'), findsOneWidget);
      expect(find.text('ANTRENMAN & KAMERA'), findsNothing);
    });

    testWidgets('a query with no results shows the ask-us empty state',
        (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('sonuç yok'), findsOneWidget);
      expect(find.text('Soru Gönder'), findsOneWidget);
    });

    testWidgets(
        'the help centre never dead-ends — a route into feedback is always '
        'present', (tester) async {
      await tester.pumpWidget(await _host());
      await tester.pump();
      // Scroll to the bottom where the "still stuck?" card lives.
      await tester.dragUntilVisible(
        find.text('Cevabını bulamadın mı?'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('Cevabını bulamadın mı?'), findsOneWidget);
    });

    testWidgets('survives a 1.3 text scale without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 851 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: [Locale('tr')],
              home: HelpCenterScreen(),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
