import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';

/// Helpers for rendering ONE localised sentence with parts of it styled
/// or tappable.
///
/// The alternative — building the sentence from several `TextSpan`s,
/// one per fragment — hardcodes clause order in the widget tree. Turkish
/// puts the accented noun in the middle of "Vücudunu **Yapay Zeka** ile
/// Şekillendir"; English does not. Keeping the sentence whole in ARB and
/// splitting it at render time leaves the translator in charge of both
/// the wording and where the emphasis lands.
///
/// Both helpers fail soft. A fragment a translation dropped simply isn't
/// found, so it isn't styled or linked — the sentence still renders
/// correctly, which is the right failure mode for something cosmetic,
/// and (for links) leaves the reader with the same documents reachable
/// from Settings.

/// Splits [sentence] around [fragment] and applies [style] to that one
/// occurrence.
List<TextSpan> splitHighlighted(
  String sentence,
  String fragment,
  TextStyle style,
) {
  final index = fragment.isEmpty ? -1 : sentence.indexOf(fragment);
  if (index < 0) return [TextSpan(text: sentence)];
  return [
    if (index > 0) TextSpan(text: sentence.substring(0, index)),
    TextSpan(text: fragment, style: style),
    if (index + fragment.length < sentence.length)
      TextSpan(text: sentence.substring(index + fragment.length)),
  ];
}

/// Splits [sentence] around each key of [links] and attaches that key's
/// recogniser — plus [linkStyle] — to the matching fragment.
List<TextSpan> splitLinked(
  String sentence,
  Map<String, GestureRecognizer> links,
  TextStyle linkStyle,
) {
  var spans = <TextSpan>[TextSpan(text: sentence)];
  links.forEach((fragment, recognizer) {
    if (fragment.isEmpty) return;
    final next = <TextSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || span.recognizer != null || !text.contains(fragment)) {
        next.add(span);
        continue;
      }
      final index = text.indexOf(fragment);
      if (index > 0) next.add(TextSpan(text: text.substring(0, index)));
      next.add(
        TextSpan(text: fragment, style: linkStyle, recognizer: recognizer),
      );
      final rest = text.substring(index + fragment.length);
      if (rest.isNotEmpty) next.add(TextSpan(text: rest));
    }
    spans = next;
  });
  return spans;
}
