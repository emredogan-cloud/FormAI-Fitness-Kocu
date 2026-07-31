import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/utils/text_span_split.dart';

/// These two helpers are what let a localised sentence stay ONE ARB
/// string while still carrying an accent colour or a tappable link.
/// Every caller depends on the same property: whatever the translator
/// writes, the full sentence reaches the screen.

const _accent = TextStyle(color: Color(0xFF8E5BFF));

String _plain(List<TextSpan> spans) => spans.map((s) => s.text ?? '').join();

void main() {
  group('splitHighlighted', () {
    test('splits a sentence into before / fragment / after', () {
      final spans = splitHighlighted(
        'Vücudunu Yapay Zeka ile Şekillendir',
        'Yapay Zeka',
        _accent,
      );

      expect(spans, hasLength(3));
      expect(spans[0].text, 'Vücudunu ');
      expect(spans[1].text, 'Yapay Zeka');
      expect(spans[1].style, _accent);
      expect(spans[2].text, ' ile Şekillendir');
    });

    test('handles a fragment at the start and at the end', () {
      expect(
        splitHighlighted('SESLİ FORM KOÇLUĞU', 'SESLİ', _accent)
            .map((s) => s.text),
        ['SESLİ', ' FORM KOÇLUĞU'],
      );
      expect(
        splitHighlighted('with your form coach', 'form coach', _accent)
            .map((s) => s.text),
        ['with your ', 'form coach'],
      );
    });

    test('a fragment the translation dropped leaves the sentence intact', () {
      // The realistic failure: a translator rewrites the sentence and
      // the highlight no longer appears verbatim. Losing the accent is
      // acceptable; losing the sentence is not.
      final spans = splitHighlighted(
        'Reshape your body with artificial intelligence',
        'Yapay Zeka',
        _accent,
      );

      expect(spans, hasLength(1));
      expect(_plain(spans), 'Reshape your body with artificial intelligence');
      expect(spans.single.style, isNull);
    });

    test('an empty fragment is not treated as a match at position zero', () {
      final spans = splitHighlighted('Bir cümle', '', _accent);
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Bir cümle');
    });

    test('only the first occurrence is highlighted', () {
      final spans = splitHighlighted('AI ve AI', 'AI', _accent);
      final accented = spans.where((s) => s.style == _accent);
      expect(accented, hasLength(1));
      expect(_plain(spans), 'AI ve AI');
    });
  });

  group('splitLinked', () {
    late TapGestureRecognizer terms;
    late TapGestureRecognizer privacy;

    setUp(() {
      terms = TapGestureRecognizer();
      privacy = TapGestureRecognizer();
    });

    tearDown(() {
      terms.dispose();
      privacy.dispose();
    });

    test('attaches each recogniser to its own fragment', () {
      final spans = splitLinked(
        'Devam ederek Kullanım Şartları ve Gizlilik Politikası’nı kabul '
        'edersin.',
        {'Kullanım Şartları': terms, 'Gizlilik Politikası': privacy},
        _accent,
      );

      final linked = spans.where((s) => s.recognizer != null).toList();
      expect(linked, hasLength(2));
      expect(linked.map((s) => s.text),
          containsAll(['Kullanım Şartları', 'Gizlilik Politikası']));
      expect(
        linked.singleWhere((s) => s.text == 'Kullanım Şartları').recognizer,
        same(terms),
      );
      expect(
        _plain(spans),
        'Devam ederek Kullanım Şartları ve Gizlilik Politikası’nı kabul '
        'edersin.',
      );
    });

    test('works when the translation reorders the links', () {
      final spans = splitLinked(
        'You accept the Privacy Policy and the Terms of Use by continuing.',
        {'Terms of Use': terms, 'Privacy Policy': privacy},
        _accent,
      );

      final linked = spans.where((s) => s.recognizer != null).toList();
      expect(linked, hasLength(2));
      // Order follows the sentence, not the map.
      expect(linked.first.text, 'Privacy Policy');
      expect(linked.last.text, 'Terms of Use');
    });

    test('a dropped link label costs the link, not the sentence', () {
      const sentence = 'By continuing you accept our terms.';
      final spans = splitLinked(
        sentence,
        {'Kullanım Şartları': terms, 'Gizlilik Politikası': privacy},
        _accent,
      );

      expect(spans.where((s) => s.recognizer != null), isEmpty);
      expect(_plain(spans), sentence);
    });

    test('a fragment is never linked twice', () {
      final spans = splitLinked(
        'Şartlar ve Şartlar',
        {'Şartlar': terms},
        _accent,
      );

      expect(spans.where((s) => s.recognizer != null), hasLength(1));
      expect(_plain(spans), 'Şartlar ve Şartlar');
    });
  });
}
