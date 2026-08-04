/// The locale-fallback chain for copy authored as data.
///
/// Phase 11's `content_localization_schema`, Phase 13's `challenges` and
/// Phase 14's `content_releases` / `content_drops` all key their copy by
/// locale tag in jsonb, so that content ops ships without an app
/// release. They all need the same lookup, and it has three steps that
/// are easy to get subtly wrong:
///
///   1. the exact tag — `tr-TR`;
///   2. the language alone — `tr`, because a document authored for a
///      language should reach every region of it;
///   3. `en`, the authoring language.
///
/// **Then null, never the key.** A missing title returns null so the
/// caller can drop the row. Rendering the slug instead is the same
/// mistake as showing a user a badge token: an identifier is not copy,
/// and a screen that displays one looks broken rather than untranslated.
///
/// This lives in `core/utils` rather than beside any one feature because
/// the third caller is what makes a shared rule worth extracting — and
/// because a fallback chain that differs between two content types is a
/// bug nobody would think to look for.
library;

/// Reads a `{locale: {field: value}}` document out of decoded jsonb,
/// discarding anything that is not a string-to-string map.
///
/// Defensive because the server can be newer than the client: a copy
/// document that grows a nested object should cost that one field, not
/// the whole row.
Map<String, Map<String, String>> parseLocalizedCopy(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, Map<String, String>>{};
  raw.forEach((locale, fields) {
    if (locale is! String || fields is! Map) return;
    final entry = <String, String>{};
    fields.forEach((key, value) {
      if (key is String && value is String) entry[key] = value;
    });
    if (entry.isNotEmpty) out[locale] = entry;
  });
  return out;
}

/// [field] of [copy] in [locale], falling back to the language, then to
/// English, then to null.
///
/// An empty string is treated as absent at every step. Content ops
/// clearing a field to blank means "there is no copy here", and falling
/// through to English is a better answer than rendering nothing.
String? pickLocalized(
  Map<String, Map<String, String>> copy,
  String locale,
  String field,
) {
  final exact = copy[locale]?[field];
  if (exact != null && exact.isNotEmpty) return exact;
  final short = locale.split('-').first;
  final byLanguage = copy[short]?[field];
  if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
  final english = copy['en']?[field];
  return (english != null && english.isNotEmpty) ? english : null;
}
