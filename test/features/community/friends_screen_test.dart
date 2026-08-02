import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/community/data/community_repository.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';
import 'package:sixpack_ai/features/community/presentation/friends_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 12 (C22) · the friends screen.
///
/// The assertions are mostly about which row lands in which list, and
/// about the two places this screen deliberately says less than it
/// knows.
void main() {
  const me = 'user-me';
  const them = 'user-them';

  Friendship friendship({
    String other = them,
    String requester = me,
    FriendshipStatus status = FriendshipStatus.pending,
  }) =>
      Friendship(
        userA: me,
        userB: other,
        requesterId: requester,
        status: status,
      );

  Future<void> pump(
    WidgetTester tester,
    List<Friendship> rows, {
    String? signedInAs,
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
          myFriendshipsProvider.overrideWith((ref) async => rows),
          currentCommunityUserIdProvider.overrideWithValue(signedInAs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: locale,
          home: const FriendsScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  testWidgets('the empty state says the other person decides', (tester) async {
    await pump(tester, const []);

    expect(find.text('Henüz arkadaşın yok'), findsOneWidget);
    // The consent half is the point of the sentence.
    expect(find.textContaining('kararı kendisi verir'), findsOneWidget);
  });

  testWidgets(
      'a screen with no signed-in user shows the empty state '
      'rather than a broken list', (tester) async {
    // `currentUserId` is null under test — there is no Supabase session —
    // so every row is unattributable. Showing them anonymously would be
    // worse than showing none.
    await pump(tester, [friendship(status: FriendshipStatus.accepted)]);

    expect(find.text('Henüz arkadaşın yok'), findsOneWidget);
    // 'Arkadaşlar' is the app-bar title too, so one is the correct count.
    expect(find.text('Arkadaşlar'), findsOneWidget);
  });

  testWidgets('the add action is always offered, even with no friends',
      (tester) async {
    await pump(tester, const []);
    expect(find.text('Arkadaş ekle'), findsOneWidget);
  });

  testWidgets('resolves in English with no Turkish left in it', (tester) async {
    await pump(tester, const [], locale: const Locale('en'));

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('Add a friend'), findsOneWidget);
    expect(find.textContaining('Arkadaş'), findsNothing);
  });
}
