import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/providers/locale_provider.dart';
import 'package:sixpack_ai/core/utils/app_copy.dart';
import 'package:sixpack_ai/features/coach/providers/coach_providers.dart';

/// Roadmap Phase 6 (AI work) · the coach speaks the app's language.
///
/// The server owns persona selection, keyed on the `locale` this value
/// puts on the wire. If it ever went back to reading the device, a
/// Turkish user on an English handset would get an English coach inside
/// a Turkish app — the exact failure the parameter exists to prevent.
void main() {
  tearDown(() => AppCopy.locale = const Locale('tr'));

  test('follows the app, not the device', () {
    AppCopy.locale = const Locale('en');
    expect(coachLocale, 'en');

    AppCopy.locale = const Locale('tr');
    expect(coachLocale, 'tr');
  });

  test('every shipped locale produces a code the server can key on', () {
    for (final locale in kSupportedLocales) {
      AppCopy.locale = locale;
      expect(coachLocale, locale.languageCode);
      expect(coachLocale.length, 2,
          reason: 'the server slices the locale to 8 chars and matches on '
              'a prefix; a region-tagged code would still work, but the '
              'persona map is keyed on the language alone');
    }
  });
}
