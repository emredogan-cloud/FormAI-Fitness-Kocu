import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

import 'layout_probe.dart' show Viewports;

/// Roadmap Phase 6 · rendering a screen in a chosen locale, and asking
/// what language actually came out.
///
/// This is a second detector, not a duplicate of the hardcoded-string
/// gate. The gate reads source and guesses which literals are copy; this
/// reads the frame and sees what a user would. They fail differently: a
/// literal reachable only through a `switch` the gate can't evaluate is
/// invisible to it, and a string this probe never renders is invisible
/// here. Phase 6 found the gate wrong for the fourth time, so a check
/// that works from the other end is worth its weight.
Future<void> pumpInLocale(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = Viewports.phone,
  double textScale = 1.0,
  Duration settle = const Duration(milliseconds: 400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: Scaffold(body: child),
    ),
  );
  // Blind spot #6 — the same one `pumpPseudo` carried. A single
  // `pump(settle)` renders the frame where every async provider is still
  // `AsyncLoading`, so the sweep measures a spinner and reports "no
  // Turkish" about a screen that painted no copy at all. Each
  // zero-duration pump drains one round of microtasks; bounded rather
  // than `pumpAndSettle`, which never returns on the surfaces here that
  // run an infinite animation.
  for (var i = 0; i < 6; i++) {
    await tester.pump(Duration.zero);
  }
  await tester.pump(settle);
}

/// Every string the current frame is actually painting.
///
/// Reads `RichText` rather than `Text`: a plain `Text` builds one
/// internally, so this catches `Text`, `Text.rich`, and the spans that
/// `text_span_split.dart` produces — which is where a half-translated
/// sentence would hide.
List<String> renderedText(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((w) => w.text.toPlainText())
      .where((s) => s.trim().isNotEmpty)
      .toList();
}

/// Letters that exist in Turkish and not in English.
///
/// `ç`, `ö` and `ü` are deliberately excluded: they turn up in borrowed
/// proper nouns and would make this probe cry wolf. `ğ`, `ı`, `ş` and
/// their capitals do not appear in English at all.
final _turkishLetters = RegExp(r'[ğışĞİŞ]');

/// Turkish words with no English homograph.
///
/// The letter check alone is not enough — "Devam Et", "Tema" and "Kilo"
/// are pure ASCII, and that exact blind spot is what let 69 untranslated
/// strings sit in shipped screens until Phase 6 went looking.
///
/// The boundaries are `(?<![\w'’])` rather than `\b` because `\b` treats
/// an apostrophe as a word break: `\bve\b` matches the "ve" inside
/// "I've", and the first run of this probe reported "I've lost my shape"
/// as Turkish.
final _turkishWords = RegExp(
  r"(?<![\w'’])("
  r've|için|bir|bu|ile|sana|senin|daha|gün|hafta|antrenman|kalori|'
  r'tekrar|hedef|hedefin|seni|sen|ama|çok|yeni|şimdi|devam|tamam|'
  r'başla|geri|ileri|kaydet|ayarlar|profil|rozet|rozetler|seviye|'
  r'kilo|boy|dinlenme|öğün|tarif|beslenme|tema|koyu|sistem|kopyala|'
  r'kullan|detay|bekleyen|planlanan|tamamlanan|atla'
  r")(?![\w'’])",
  caseSensitive: false,
);

/// Fails if the frame is painting Turkish while the app is in English.
///
/// [allow] exempts strings that are legitimately not translated — the
/// FormAI wordmark, the coach's name, unit symbols, and the language
/// picker's own `Türkçe` endonym, which is the one Turkish word that
/// must survive an English build.
void expectNoTurkish(
  WidgetTester tester,
  String describe, {
  Set<String> allow = const {},
}) {
  final offenders = <String>[];
  for (final line in renderedText(tester)) {
    if (allow.contains(line.trim())) continue;
    if (_turkishLetters.hasMatch(line) || _turkishWords.hasMatch(line)) {
      offenders.add(line);
    }
  }
  expect(
    offenders,
    isEmpty,
    reason: '$describe rendered Turkish under the English locale:\n'
        '${offenders.map((o) => '  · $o').join('\n')}',
  );
}

/// The strings an English build is allowed to render in another script.
///
/// Each is in `GLOSSARY.md` as never-translated. `Türkçe` is here
/// because the language picker names every language in itself — an
/// English-locale user choosing Turkish looks for `Türkçe`, not
/// "Turkish".
const kNeverTranslated = <String>{
  'FormAI',
  'FormAI Pro',
  'Form',
  'Türkçe',
  'English',
  'AI',
  'XP',
  'Pro',
};
