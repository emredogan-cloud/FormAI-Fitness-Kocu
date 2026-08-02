import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/data/community_repository.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';
import 'package:sixpack_ai/features/community/presentation/community_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 12 (R6, C24) · the community entry point.
///
/// Two of the three states this screen has are states most users will
/// actually be in — `019` is unapplied, and a profile is opt-in — so
/// most of this file is about what it says when it has nothing to show.
/// The roadmap's rule is that a user who never touches community sees no
/// change, and an error tile would be a very visible change.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool available,
    CommunityProfile? profile,
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityAvailableProvider.overrideWith((ref) async => available),
          myProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: locale,
          home: const CommunityScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    // Bounded pumps, never `pumpAndSettle`: both loading branches are
    // CircularProgressIndicators, which never settle.
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  CommunityProfile profile({
    String name = 'Emre',
    String handle = 'emre_d',
    ProfileVisibility visibility = ProfileVisibility.private,
    bool approved = true,
  }) =>
      CommunityProfile(
        userId: 'user-a',
        displayName: name,
        handle: handle,
        visibility: visibility,
        moderationApproved: approved,
      );

  group('when the schema is not applied', () {
    testWidgets('it says the feature is off, not that something broke',
        (tester) async {
      await pump(tester, available: false);

      expect(find.text('Topluluk henüz açık değil.'), findsOneWidget);
      // The second sentence is the one that matters: an unapplied
      // migration must not read as a broken app.
      expect(
          find.textContaining('aynen çalışmaya devam ediyor'), findsOneWidget);
    });

    testWidgets('it does not offer to create a profile it cannot store',
        (tester) async {
      await pump(tester, available: false);
      expect(find.text('Profil oluştur'), findsNothing);
    });
  });

  group('when there is no profile', () {
    testWidgets('the empty state leads with the privacy position',
        (tester) async {
      await pump(tester, available: true);

      expect(find.text('Henüz profilin yok'), findsOneWidget);
      expect(find.textContaining('Sen açmadıkça hiçbir bilgisi görünmez'),
          findsOneWidget);
      expect(find.text('Profil oluştur'), findsOneWidget);
    });
  });

  group('when a profile exists', () {
    testWidgets('it shows the name and the handle', (tester) async {
      await pump(tester, available: true, profile: profile());

      expect(find.text('Emre'), findsOneWidget);
      expect(find.text('@emre_d'), findsOneWidget);
    });

    testWidgets('a fresh profile reports every field as hidden',
        (tester) async {
      await pump(tester, available: true, profile: profile());

      // Three visibility lines, all off. If any of them ever renders as
      // on for a default profile, creating one has published it.
      expect(find.byIcon(Icons.remove_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    });

    testWidgets('switched-on fields are shown as on, one at a time',
        (tester) async {
      await pump(
        tester,
        available: true,
        profile: profile(
          visibility: const ProfileVisibility(isPublic: true, showBadges: true),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget,
          reason: 'stats were never switched on');
    });

    testWidgets(
        'a profile awaiting moderation says so — otherwise somebody '
        'wonders why their friend cannot find them', (tester) async {
      await pump(tester, available: true, profile: profile(approved: false));

      expect(find.textContaining('kontrol ediliyor'), findsOneWidget);
    });

    testWidgets('an approved profile carries no review notice', (tester) async {
      await pump(tester, available: true, profile: profile());
      expect(find.textContaining('kontrol ediliyor'), findsNothing);
    });
  });

  testWidgets('resolves in English with no Turkish left in it', (tester) async {
    await pump(tester, available: false, locale: const Locale('en'));

    expect(find.text('Community'), findsOneWidget);
    expect(find.text("Community isn't switched on yet."), findsOneWidget);
    expect(find.textContaining('Topluluk'), findsNothing);
  });
}
