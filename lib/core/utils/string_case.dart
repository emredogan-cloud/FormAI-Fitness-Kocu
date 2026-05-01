/// String-case conversion helpers.
///
/// Phase 75 · added [snakeToPascal] so we can map snake_case exercise
/// `slug` values to the PascalCase filenames Supabase Storage actually
/// hosts (Storage is case-sensitive; `decline_push_up.mp4` 404s while
/// `DeclinePushUp.mp4` works).
class StringCase {
  const StringCase._();

  /// Converts `snake_case` to `PascalCase`.
  ///
  ///   snakeToPascal('decline_push_up') == 'DeclinePushUp'
  ///   snakeToPascal('crunch')          == 'Crunch'
  ///   snakeToPascal('')                == ''
  ///
  /// Empty input returns an empty string. Empty path components
  /// (e.g. leading/trailing/double underscores) are dropped so
  /// `'__push__up__'` collapses to `'PushUp'` rather than producing
  /// stray empty segments.
  static String snakeToPascal(String input) {
    if (input.isEmpty) return input;
    final parts = input.split('_').where((p) => p.isNotEmpty);
    final buf = StringBuffer();
    for (final p in parts) {
      buf.write(p[0].toUpperCase());
      if (p.length > 1) buf.write(p.substring(1));
    }
    return buf.toString();
  }
}
