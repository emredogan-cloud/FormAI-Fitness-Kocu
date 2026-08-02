import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/data/community_repository.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';
import 'package:sixpack_ai/features/community/presentation/squad_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 12 (C22) · squads.
void main() {
  Squad squad({String name = 'Sabah ekibi', int members = 4}) => Squad(
        id: 'squad-1',
        name: name,
        ownerId: 'user-me',
        inviteCode: 'ABCD2345',
        memberCount: members,
      );

  Future<void> pump(
    WidgetTester tester,
    List<Squad> squads, {
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
          mySquadsProvider.overrideWith((ref) async => squads),
          currentCommunityUserIdProvider.overrideWithValue('user-me'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: locale,
          home: const SquadScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  testWidgets('the empty state says what a squad is and why it is small',
      (tester) async {
    await pump(tester, const []);

    expect(find.text('Henüz squad\'ın yok'), findsOneWidget);
    expect(find.textContaining('en fazla 12 kişi'), findsOneWidget);
    // Both ways in are offered from the empty state — creating and
    // joining are equally likely first moves.
    expect(find.text('Squad oluştur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
  });

  testWidgets(
      'a squad row states the cap alongside the count, so full '
      'is never a surprise', (tester) async {
    await pump(tester, [squad(members: 7)]);

    expect(find.text('Sabah ekibi'), findsOneWidget);
    expect(find.text('12 kişiden 7'), findsOneWidget);
  });

  testWidgets('a full squad still renders its count rather than hiding it',
      (tester) async {
    await pump(tester, [squad(members: 12)]);
    expect(find.text('12 kişiden 12'), findsOneWidget);
  });

  testWidgets(
      'every squad offers sharing its code, which is the whole '
      'joining flow', (tester) async {
    await pump(tester, [squad()]);
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
  });

  testWidgets('resolves in English with no Turkish left in it', (tester) async {
    await pump(tester, const [], locale: const Locale('en'));

    expect(find.text('Squads'), findsOneWidget);
    expect(find.text('No squad yet'), findsOneWidget);
    expect(find.text('Create a squad'), findsOneWidget);
    expect(find.textContaining('katıl'), findsNothing);
  });
}
