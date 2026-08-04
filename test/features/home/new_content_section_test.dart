import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/core/services/content_sync_service.dart';
import 'package:sixpack_ai/features/home/presentation/widgets/new_content_section.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 14 (C6) · the "Yenilikler" section.
///
/// The targeting rules themselves are covered by
/// `content_freshness_test.dart`. What is pinned here is the part only a
/// widget tree can answer: that an untargeted drop reaches the screen,
/// a targeted one that does not match is absent, and the "New" badge
/// clears once it has been in front of the user.
/// No client, and no `Supabase.instance` either — `ContentSyncService`
/// resolves its client lazily so a cache read never needs a backend.
/// Constructing a real `SupabaseClient` here instead would leave the
/// realtime heartbeat running and every test would fail on a pending
/// timer, which is how that design decision got made.
class _StubSync extends ContentSyncService {
  _StubSync(super.prefs);

  @override
  Future<void> refreshIfStale() async {}

  @override
  Future<void> refresh() async {}
}

Map<String, dynamic> _drop({
  String slug = 'august-recipes',
  String kind = 'recipes',
  String? route = '/nutrition/discover',
  List<String>? goals,
  bool? equipment,
  String published = '2026-01-01T00:00:00Z',
  String? expires,
  Map<String, dynamic>? copy,
}) =>
    {
      'id': slug,
      'slug': slug,
      'kind': kind,
      'copy': copy ??
          {
            'en': {'title': 'Twenty new recipes', 'body': 'Summer cooking.'},
          },
      'route': route,
      'published_at': published,
      'expires_at': expires,
      'target_goals': goals,
      'target_levels': null,
      'target_locales': null,
      'requires_equipment': equipment,
    };

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> rows, {
  Set<String> alreadySeen = const {},
  String goal = 'sixpack',
  bool? hasEquipment,
}) async {
  SharedPreferences.setMockInitialValues({
    'sixpack.content_drops_v1': jsonEncode(rows),
    'sixpack.content_drops_seen_v1': alreadySeen.toList(),
    'sixpack.user_metrics': jsonEncode({'targetPhysique': goal}),
    if (hasEquipment != null) 'sixpack.has_equipment': hasEquipment,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentSyncServiceProvider.overrideWithValue(_StubSync(prefs)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: NewContentSection())),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('an untargeted drop reaches everybody', (tester) async {
    await _pump(tester, [_drop()]);
    expect(find.text('Twenty new recipes'), findsOneWidget);
    expect(find.text('Summer cooking.'), findsOneWidget);
  });

  testWidgets('nothing new renders NOTHING, not an empty state',
      (tester) async {
    // This section sits inside a hub with its own content. "There is
    // nothing new" on every visit is noise, and the roadmap's rule is
    // that discovery must not feel like advertising.
    await _pump(tester, const []);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
        find.text(l10n.discoveryNewContentTitle.toUpperCase()), findsNothing);
  });

  testWidgets('a drop for another goal does not appear', (tester) async {
    await _pump(
        tester,
        [
          _drop(goals: ['bulk'])
        ],
        goal: 'tone');
    expect(find.text('Twenty new recipes'), findsNothing);
  });

  testWidgets('an expired drop does not appear', (tester) async {
    await _pump(tester, [
      _drop(published: '2020-01-01T00:00:00Z', expires: '2020-02-01T00:00:00Z'),
    ]);
    expect(find.text('Twenty new recipes'), findsNothing);
  });

  testWidgets('a drop with no readable copy is skipped, not shown blank',
      (tester) async {
    await _pump(tester, [_drop(copy: const {})]);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
        find.text(l10n.discoveryNewContentTitle.toUpperCase()), findsNothing);
  });

  testWidgets('an unknown kind is dropped rather than guessed', (tester) async {
    await _pump(tester, [_drop(kind: 'hologram')]);
    expect(find.text('Twenty new recipes'), findsNothing);
  });

  group('the New badge', () {
    testWidgets('shows on an unseen drop and is recorded as seen',
        (tester) async {
      final container = await _pump(tester, [_drop()]);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.discoveryNewBadge), findsOneWidget);

      // Marking happens on BUILD: having the list in front of you is
      // what "seen" means. Requiring a tap would leave a permanent dot
      // beside content somebody decided they did not want.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(appPreferencesProvider).seenContentDrops,
        contains('august-recipes'),
      );
    });

    testWidgets('the badge survives the frame that records it', (tester) async {
      // The preference write and the render race. If the section read
      // `seenContentDrops` on every rebuild, the badge would vanish
      // before the first paint finished and nobody would ever see it.
      await _pump(tester, [_drop()]);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(l10n.discoveryNewBadge), findsOneWidget);
    });

    testWidgets('is absent on a drop already seen', (tester) async {
      await _pump(tester, [_drop()], alreadySeen: {'august-recipes'});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Twenty new recipes'), findsOneWidget);
      expect(find.text(l10n.discoveryNewBadge), findsNothing);
    });
  });

  testWidgets('a drop with no route renders without a tap target',
      (tester) async {
    // An announcement rather than a destination. A chevron that goes
    // nowhere is worse than no chevron.
    await _pump(tester, [_drop(route: null)]);
    expect(find.text('Twenty new recipes'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('equipment targeting reaches the right half', (tester) async {
    await _pump(tester, [_drop(equipment: false)], hasEquipment: true);
    expect(find.text('Twenty new recipes'), findsNothing);

    await _pump(tester, [_drop(equipment: false)], hasEquipment: false);
    expect(find.text('Twenty new recipes'), findsOneWidget);
  });

  testWidgets('newest first', (tester) async {
    await _pump(tester, [
      _drop(slug: 'older', published: '2026-01-01T00:00:00Z', copy: const {
        'en': {'title': 'Older drop'}
      }),
      _drop(slug: 'newer', published: '2026-06-01T00:00:00Z', copy: const {
        'en': {'title': 'Newer drop'}
      }),
    ]);
    final newer = tester.getTopLeft(find.text('Newer drop'));
    final older = tester.getTopLeft(find.text('Older drop'));
    expect(newer.dy, lessThan(older.dy));
  });
}
