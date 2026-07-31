import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/services/progressive_disclosure.dart';
import 'package:sixpack_ai/features/home/presentation/unlock_hint_copy.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 5 · the words for the disclosure layer.
///
/// progressive_disclosure.dart decides what is locked and which road is
/// shorter; this file is the only place that says it. The copy checks
/// that used to live in progressive_disclosure_test moved here and now
/// run over every supported locale instead of the one that was compiled
/// into the enum.
void main() {
  late Map<Locale, AppLocalizations> loaded;

  setUpAll(() async {
    loaded = {
      for (final l in AppLocalizations.supportedLocales)
        l: await AppLocalizations.delegate.load(l),
    };
  });

  test('every capability has a title and a blurb in every locale', () {
    loaded.forEach((locale, l10n) {
      for (final c in Capability.values) {
        expect(c.title(l10n).trim(), isNotEmpty,
            reason: '${c.key} in ${locale.languageCode}');
        expect(c.blurb(l10n).trim(), isNotEmpty,
            reason: '${c.key} in ${locale.languageCode}');
      }
    });
  });

  test('every pillar has a heading in every locale', () {
    loaded.forEach((locale, l10n) {
      for (final p in CapabilityPillar.values) {
        expect(p.label(l10n).trim(), isNotEmpty,
            reason: '${p.name} in ${locale.languageCode}');
      }
    });
  });

  test('no two capabilities share a title', () {
    loaded.forEach((locale, l10n) {
      final titles = Capability.values.map((c) => c.title(l10n)).toList();
      expect(titles.toSet(), hasLength(titles.length),
          reason: 'duplicate capability title in ${locale.languageCode}');
    });
  });

  group('unlock hints', () {
    test('the one-day case names the day rather than counting it', () {
      // This is the whole reason the hint goes through ICU instead of
      // interpolation: "opens tomorrow" is not "opens in 1 day", and no
      // amount of "$n gün" produces it.
      final tr = loaded[const Locale('tr')]!;
      expect(const UnlockAfterDays(1).text(tr), 'Yarın açılıyor');
      expect(const UnlockAfterDays(3).text(tr), contains('3'));

      final en = loaded[const Locale('en')]!;
      expect(const UnlockAfterDays(1).text(en), 'Opens tomorrow');
      expect(const UnlockAfterDays(1).text(en), isNot(contains('1')));
      expect(const UnlockAfterDays(3).text(en), contains('3'));
    });

    test('the session hint pluralises where the language needs it', () {
      final en = loaded[const Locale('en')]!;
      expect(const UnlockAfterSessions(1).text(en), contains('workout'));
      expect(
          const UnlockAfterSessions(1).text(en), isNot(contains('workouts')));
      expect(const UnlockAfterSessions(4).text(en), contains('workouts'));
    });

    test('every hint shape renders non-empty in every locale', () {
      // A blank hint is a locked row that never explains itself.
      loaded.forEach((locale, l10n) {
        for (final hint in <UnlockHint>[
          const UnlockAfterSessions(1),
          const UnlockAfterSessions(7),
          const UnlockAfterDays(1),
          const UnlockAfterDays(12),
          const UnlockSoon(),
        ]) {
          expect(hint.text(l10n).trim(), isNotEmpty,
              reason: '$hint in ${locale.languageCode}');
        }
      });
    });
  });
}
