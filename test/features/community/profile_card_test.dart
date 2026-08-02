import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/core/widgets/share_templates.dart';
import 'package:sixpack_ai/features/community/domain/models/community_models.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 12 (C21) · the shareable profile card.
///
/// The rule worth testing is which stats may leave the device as an
/// image. An image is the one surface where a privacy choice cannot be
/// taken back afterwards, so the filter is a pure function and this is
/// the file that pins it.
void main() {
  group('what a card may carry', () {
    test('stats off keeps every number off the card', () {
      const visibility = ProfileVisibility(
        isPublic: true,
        showBadges: true,
        showStats: false,
      );
      expect(profileCardStats(visibility), [ProfileCardStat.badges]);
    });

    test('badges off keeps the badge count off the card', () {
      const visibility = ProfileVisibility(
        isPublic: true,
        showBadges: false,
        showStats: true,
      );
      expect(
        profileCardStats(visibility),
        isNot(contains(ProfileCardStat.badges)),
      );
    });

    test('both off leaves a card with no stats at all', () {
      const visibility = ProfileVisibility(
        isPublic: true,
        showBadges: false,
        showStats: false,
      );
      // Not an error state: name, handle and branding is still a card,
      // and somebody who shares one has chosen exactly that.
      expect(profileCardStats(visibility), isEmpty);
    });

    test('a private profile still governs its own card', () {
      // Visibility scopes what *other people* are served. A share is an
      // act by the owner, so `isPublic` does not gate the card — but the
      // two content flags still do, because they are about the numbers
      // rather than about who may look.
      const visibility = ProfileVisibility(
        isPublic: false,
        showBadges: true,
        showStats: true,
      );
      expect(profileCardStats(visibility).length, 4);
    });
  });

  group('the rendered card', () {
    // The templates render at a fixed pixel size (1080x1920) and carry a
    // localized footer, so the harness has to give them both. Nothing in
    // the suite had pumped a share template before this — they were only
    // ever exercised through the off-screen capture path.
    Future<void> pump(WidgetTester tester, List<(String, String)> lines) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShareProfileTemplate(
            displayName: 'Emre',
            handle: 'emre',
            lines: lines,
          ),
        ),
      );
    }

    testWidgets('shows the name and the handle with its @', (tester) async {
      await pump(tester, const [('Level', '7')]);
      expect(find.text('Emre'), findsOneWidget);
      // The '@' belongs to the template, not to the stored handle.
      expect(find.text('@emre'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders with no lines at all', (tester) async {
      await pump(tester, const []);
      expect(find.text('Emre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
