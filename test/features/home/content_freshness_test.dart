import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/home/domain/content_freshness.dart';

/// Roadmap Phase 14 (C5, C6, R5) · release notes and content drops.
///
/// Every parse case here is "the server is newer than the client",
/// because that is the whole trade of authoring content as data.
void main() {
  Map<String, dynamic> releaseJson({
    int build = 36,
    String version = '1.0.0',
    Object? copy,
  }) =>
      {
        'id': 'r-$build',
        'version': version,
        'build_number': build,
        'copy': copy ??
            {
              'en': {
                'headline': 'What is new',
                'items': [
                  {'title': 'Challenges', 'body': 'Join one from Community.'},
                ],
              },
            },
      };

  group('ContentRelease parsing', () {
    test('a row missing any identity field is dropped', () {
      for (final key in ['id', 'version', 'build_number']) {
        final json = releaseJson()..remove(key);
        expect(ContentRelease.fromJson(json), isNull, reason: 'missing $key');
      }
    });

    test('copy that is not a map costs the copy, not the row', () {
      final release = ContentRelease.fromJson(releaseJson(copy: 'oops'));
      expect(release, isNotNull);
      expect(release!.items('en'), isEmpty);
      expect(release.hasContentFor('en'), isFalse);
    });

    test('an item with no title is skipped, one with no body is kept', () {
      final release = ContentRelease.fromJson(releaseJson(copy: {
        'en': {
          'items': [
            {'body': 'orphan body'},
            {'title': 'Title only'},
          ],
        },
      }))!;
      final items = release.items('en');
      expect(items, hasLength(1));
      expect(items.single.title, 'Title only');
      expect(items.single.body, isNull);
    });

    test('at most three items survive, however many are authored', () {
      // The roadmap's cap: never a wall of release notes.
      final release = ContentRelease.fromJson(releaseJson(copy: {
        'en': {
          'items': [
            for (var i = 0; i < 9; i++) {'title': 'Item $i'},
          ],
        },
      }))!;
      expect(release.items('en'), hasLength(ContentRelease.maxItems));
      expect(release.items('en').first.title, 'Item 0');
    });

    test('a region tag reads the language document', () {
      final release = ContentRelease.fromJson(releaseJson(copy: {
        'tr': {
          'headline': 'Yenilikler',
          'items': [
            {'title': 'Meydan okumalar'}
          ],
        },
      }))!;
      expect(release.headline('tr-TR'), 'Yenilikler');
      expect(release.items('tr-TR').single.title, 'Meydan okumalar');
    });

    test('the item list falls back as a WHOLE list, never item by item', () {
      // Phase 7 decided this for recipes: one row, one language. A
      // Turkish headline over English bullets is what a half-finished
      // translation pass leaves behind, and it reads as a bug.
      final release = ContentRelease.fromJson(releaseJson(copy: {
        'en': {
          'headline': 'What is new',
          'items': [
            {'title': 'English one'},
            {'title': 'English two'},
          ],
        },
        'tr': {
          'headline': 'Yenilikler',
          'items': [
            {'title': 'Sadece bir madde'},
          ],
        },
      }))!;
      final items = release.items('tr');
      expect(items, hasLength(1));
      expect(items.single.title, 'Sadece bir madde',
          reason: 'the Turkish list must not be topped up from English');
      expect(release.headline('tr'), 'Yenilikler');
    });

    test('a locale with no document at all falls through to English', () {
      final release = ContentRelease.fromJson(releaseJson())!;
      expect(release.items('de').single.title, 'Challenges');
      expect(release.headline('de'), 'What is new');
    });
  });

  group('which release a client shows', () {
    List<ContentRelease> releases(List<int> builds) => [
          for (final b in builds)
            ContentRelease.fromJson(releaseJson(build: b, version: '1.$b.0'))!,
        ];

    ContentRelease? pick(List<int> builds, int build, int seen) =>
        ContentRelease.newestFor(
          releases(builds),
          build: build,
          lastSeenBuild: seen,
          locale: 'en',
        );

    test('never a note for a build the user does not have', () {
      // Play rolls a release out over days, so on release day both
      // populations exist and this is not a hypothetical.
      expect(pick([36, 40], 36, 30)!.buildNumber, 36);
    });

    test('the newest of several unseen notes, not the oldest', () {
      expect(pick([34, 35, 36], 36, 30)!.buildNumber, 36);
    });

    test('a note already seen is not shown again', () {
      expect(pick([36], 36, 36), isNull);
    });

    test('a fresh install passing its own build sees nothing', () {
      // Their whole app is new; a changelog for a version they never ran
      // is a list of things they have no memory of missing.
      expect(pick([30, 34, 36], 36, 36), isNull);
    });

    test('an update skipping versions shows only the newest note', () {
      final chosen = pick([32, 34, 36], 36, 31);
      expect(chosen!.buildNumber, 36);
    });

    test('a note with no readable copy is skipped, not shown blank', () {
      final withEmpty = [
        ContentRelease.fromJson(releaseJson(build: 36, copy: const {}))!,
        ContentRelease.fromJson(releaseJson(build: 34))!,
      ];
      final chosen = ContentRelease.newestFor(withEmpty,
          build: 36, lastSeenBuild: 30, locale: 'en');
      expect(chosen!.buildNumber, 34);
    });

    test('no releases at all is null, not a throw', () {
      expect(pick(const [], 36, 0), isNull);
    });
  });

  group('ContentDrop', () {
    Map<String, dynamic> dropJson({
      String kind = 'recipes',
      Object? goals,
      Object? levels,
      Object? locales,
      Object? equipment,
      String? expires,
    }) =>
        {
          'id': 'd1',
          'slug': 'august-recipes',
          'kind': kind,
          'copy': {
            'en': {'title': 'New recipes', 'body': '20 of them.'},
          },
          'published_at': '2026-08-01T00:00:00Z',
          'expires_at': expires,
          'route': '/nutrition',
          'target_goals': goals,
          'target_levels': levels,
          'target_locales': locales,
          'requires_equipment': equipment,
        };

    test('an unknown kind drops the row', () {
      // A newer server's drop. The client would not know which screen it
      // belongs to, and guessing sends somebody to the wrong tab.
      expect(ContentDrop.fromJson(dropJson(kind: 'hologram')), isNull);
      expect(ContentDrop.fromJson(dropJson(kind: 'seasonal')), isNotNull);
    });

    test('an untargeted drop reaches everybody, including unknown users', () {
      final drop = ContentDrop.fromJson(dropJson())!;
      expect(drop.matches(const ContentAudience()), isTrue);
      expect(
        drop.matches(const ContentAudience(
            goal: 'bulk', level: 'advanced', hasEquipment: true)),
        isTrue,
      );
    });

    test('a targeted drop does not reach a user the app knows nothing about',
        () {
      // Guessing somebody into a targeted audience is how a person with
      // no equipment is sent a barbell program.
      final drop = ContentDrop.fromJson(dropJson(goals: ['bulk']))!;
      expect(drop.matches(const ContentAudience()), isFalse);
      expect(drop.matches(const ContentAudience(goal: 'bulk')), isTrue);
      expect(drop.matches(const ContentAudience(goal: 'tone')), isFalse);
    });

    test('an empty target array means everybody, exactly like null', () {
      // This is what a form submits when nobody picked anything, and a
      // drop that silently reaches nobody is the worst failure here.
      final drop = ContentDrop.fromJson(dropJson(goals: const []))!;
      expect(drop.matches(const ContentAudience(goal: 'tone')), isTrue);
      expect(drop.matches(const ContentAudience()), isTrue);
    });

    test('equipment is tri-state', () {
      final needs = ContentDrop.fromJson(dropJson(equipment: true))!;
      final needsNone = ContentDrop.fromJson(dropJson(equipment: false))!;
      final agnostic = ContentDrop.fromJson(dropJson())!;

      expect(needs.matches(const ContentAudience(hasEquipment: true)), isTrue);
      expect(
          needs.matches(const ContentAudience(hasEquipment: false)), isFalse);
      expect(needsNone.matches(const ContentAudience(hasEquipment: false)),
          isTrue);
      expect(
          agnostic.matches(const ContentAudience(hasEquipment: false)), isTrue);
      // Unknown equipment state passes: the field is old and many
      // profiles predate it, and withholding a bodyweight program from
      // them helps nobody.
      expect(needs.matches(const ContentAudience()), isTrue);
    });

    test('a locale target widens to the region', () {
      final drop = ContentDrop.fromJson(dropJson(locales: ['tr']))!;
      expect(drop.matches(const ContentAudience(locale: 'tr-TR')), isTrue);
      expect(drop.matches(const ContentAudience(locale: 'en')), isFalse);
      expect(drop.matches(const ContentAudience()), isFalse);
    });

    test('a region target does not widen to the language', () {
      // The widening runs one way only. Targeting `tr-TR` is how content
      // ops says "Turkey", and matching every `tr` speaker would undo it.
      final drop = ContentDrop.fromJson(dropJson(locales: ['tr-TR']))!;
      expect(drop.matches(const ContentAudience(locale: 'tr-TR')), isTrue);
      expect(drop.matches(const ContentAudience(locale: 'tr')), isFalse);
    });

    test('liveness spans published_at to expires_at', () {
      final seasonal =
          ContentDrop.fromJson(dropJson(expires: '2026-09-01T00:00:00Z'))!;
      expect(seasonal.isLive(DateTime.utc(2026, 7, 20)), isFalse);
      expect(seasonal.isLive(DateTime.utc(2026, 8, 15)), isTrue);
      expect(seasonal.isLive(DateTime.utc(2026, 9, 2)), isFalse);
    });

    test('no expiry never expires', () {
      final permanent = ContentDrop.fromJson(dropJson())!;
      expect(permanent.isLive(DateTime.utc(2030)), isTrue);
    });

    test('a malformed target array is read entry by entry', () {
      final drop = ContentDrop.fromJson(dropJson(goals: ['bulk', 7, '']))!;
      expect(drop.targetGoals, ['bulk']);
    });

    test('copy falls back and then gives up rather than showing the slug', () {
      final drop = ContentDrop.fromJson(dropJson())!;
      expect(drop.title('tr'), 'New recipes');
      final noCopy = ContentDrop.fromJson({...dropJson(), 'copy': {}})!;
      expect(noCopy.title('en'), isNull,
          reason: 'null so the caller drops the card; the slug is an '
              'identifier and showing one looks broken');
    });
  });
}
