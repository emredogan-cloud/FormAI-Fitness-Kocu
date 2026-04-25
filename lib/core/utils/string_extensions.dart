/// Phase 51 hotfix · admin Storage uploads were 400-ing with
/// `Invalid key` when admins entered Turkish-character titles
/// ("Tatlı Patates" → `tatlı_patates.webp`). Supabase Storage keys
/// are restricted to ASCII; the `sanitizeFileName` extension below
/// is the one place every upload path runs strings through before
/// constructing the final key.
///
/// Lives in `core/utils` (not in the admin feature folder) because
/// it's a generic string concern — the same pipeline could plug into
/// future user-uploaded avatars / progress photos / anything else
/// where the file name flows from human input to a Storage key.
extension StorageFilenameSanitizer on String {
  /// Returns a Supabase-Storage-safe filename derived from this string.
  ///
  /// Pipeline:
  ///   1. Transliterate Turkish characters first (both cases) so the
  ///      lowercase step doesn't have to deal with locale-specific
  ///      surprises like `'İ'.toLowerCase()` returning the multi-rune
  ///      `'i' + U+0307` sequence on some platforms. Mapping ı/ğ/ü/ş/
  ///      ö/ç + their uppercase forms covers every TR-locale glyph.
  ///   2. Lowercase so admin-typed `MIXED_Case.WebP` and `mixed_case.
  ///      webp` collide on the same Storage key (Supabase treats keys
  ///      case-sensitively, but mixed-case keys are a footgun for
  ///      anyone re-querying via Studio).
  ///   3. Replace anything outside `[a-z0-9._-]` with `_`, collapsing
  ///      runs to a single underscore. The dot is allowed so the
  ///      caller can pass a name that already includes the extension;
  ///      dash + underscore stay so `kahvaltı-tarifi` keeps reading
  ///      naturally as `kahvalti-tarifi`.
  ///   4. Trim leading / trailing underscores so keys never start or
  ///      end with `_` (cosmetic, but it makes Storage console listings
  ///      easier to scan).
  ///
  /// Returns [fallback] when the cleaned result is empty (e.g. the
  /// input was entirely non-ASCII punctuation that collapsed away).
  /// Truncates to [maxLength] characters so long titles don't blow
  /// past Storage's 1024-byte key limit when combined with the path
  /// prefix + timestamp.
  String sanitizeFileName({
    int maxLength = 80,
    String fallback = 'file',
  }) {
    final transliterated = replaceAll('İ', 'I')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'G')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'U')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 'S')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'O')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'C')
        .replaceAll('ç', 'c');
    final cleaned = transliterated
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }
}
