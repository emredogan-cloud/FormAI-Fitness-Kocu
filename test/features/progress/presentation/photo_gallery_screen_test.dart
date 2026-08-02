import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/data/progress_photo_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/progress_photo.dart';
import 'package:sixpack_ai/features/progress/presentation/photo_gallery_screen.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 10 (C2) · the photo gallery.
///
/// The assertions are about what the screen says when it cannot do the
/// thing the user came for — which on this screen is most of the states,
/// because a comparison needs two photos of one pose and a new user has
/// neither.
void main() {
  late Directory sandbox;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sandbox = await Directory.systemTemp.createTemp('formai_gallery_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => sandbox.path,
    );
    SharedPreferences.setMockInitialValues(const {});
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester,
    List<ProgressPhoto> photos, {
    Locale locale = const Locale('tr'),
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          progressPhotosProvider.overrideWith((ref) async => photos),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: locale,
          home: const PhotoGalleryScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    // Bounded pumps, never `pumpAndSettle`: the loading branch is a
    // CircularProgressIndicator, which never settles.
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  ProgressPhoto photo(PhotoPose pose, int day) => ProgressPhoto(
        recordedAt: DateTime(2026, 8, day),
        pose: pose,
        fileName: 'formai_${pose.token}_$day.jpg',
      );

  testWidgets(
      'the empty state leads with the privacy position, not an '
      'instruction', (tester) async {
    await pump(tester, const []);

    expect(find.text('Henüz fotoğraf yok'), findsOneWidget);
    expect(find.textContaining('Bu telefonda kalırlar'), findsOneWidget);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
  });

  testWidgets(
      'photos are grouped by pose, because only a pose compares '
      'against itself', (tester) async {
    await pump(tester, [
      photo(PhotoPose.front, 3),
      photo(PhotoPose.front, 1),
      photo(PhotoPose.side, 2),
    ]);

    expect(find.text('Ön'), findsOneWidget);
    expect(find.text('Yan'), findsOneWidget);
    expect(find.text('Arka'), findsNothing,
        reason: 'a pose with no photos gets no row');
    expect(find.text('2 fotoğraf'), findsOneWidget);
    expect(find.text('1 fotoğraf'), findsOneWidget);
  });

  testWidgets(
      'compare is offered only on a pose with two, and is absent '
      'rather than disabled below that', (tester) async {
    await pump(tester, [photo(PhotoPose.front, 1)]);
    expect(find.text('Karşılaştır'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, [photo(PhotoPose.front, 1), photo(PhotoPose.front, 8)]);
    expect(find.text('Karşılaştır'), findsOneWidget);
  });

  testWidgets(
      'when nothing can be compared yet, the screen says why — a missing '
      'button with no explanation reads as a bug', (tester) async {
    await pump(tester, [photo(PhotoPose.front, 1), photo(PhotoPose.side, 2)]);

    expect(find.textContaining('Aynı duruştan iki fotoğraf'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, [photo(PhotoPose.front, 1), photo(PhotoPose.front, 8)]);
    expect(find.textContaining('Aynı duruştan iki fotoğraf'), findsNothing);
  });

  testWidgets(
      'deletion is confirmed, and the confirmation says why it is '
      'final', (tester) async {
    await pump(tester, [photo(PhotoPose.front, 1)]);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }

    expect(find.text('Bu fotoğraf silinsin mi?'), findsOneWidget);
    // The privacy promise, stated as its consequence.
    expect(find.textContaining('geri getirilecek bir kopyası yok'),
        findsOneWidget);
  });

  testWidgets('resolves in English with no Turkish left in it', (tester) async {
    await pump(tester, const [], locale: const Locale('en'));

    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.textContaining('Fotoğraf'), findsNothing);
  });
}
