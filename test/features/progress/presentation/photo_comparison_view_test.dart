import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/core/services/app_preferences.dart';
import 'package:sixpack_ai/features/progress/domain/models/progress_photo.dart';
import 'package:sixpack_ai/features/progress/presentation/photo_comparison_view.dart';
import 'package:sixpack_ai/l10n/app_localizations.dart';

/// Roadmap Phase 10 (C2) · the before/after wipe.
void main() {
  late Directory sandbox;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sandbox = await Directory.systemTemp.createTemp('formai_compare_test');
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

  Future<void> pump(WidgetTester tester, List<ProgressPhoto> photos) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('tr'), Locale('en')],
          locale: const Locale('en'),
          home: PhotoComparisonView(photos: photos),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  ProgressPhoto photo(DateTime at) => ProgressPhoto(
        recordedAt: at,
        pose: PhotoPose.front,
        fileName: 'formai_front_${at.millisecondsSinceEpoch}.jpg',
      );

  testWidgets('both ends are labelled, and the pose is named', (tester) async {
    await pump(tester, [
      photo(DateTime(2026, 8, 2, 9)),
      photo(DateTime(2026, 7, 5, 9)),
    ]);

    expect(find.text('Earlier'), findsNWidgets(2),
        reason: 'once on the frame, once on the picker');
    expect(find.text('Later'), findsNWidgets(2));
    expect(find.text('Front'), findsOneWidget);
  });

  // Found on the device. Two photos taken the same day rendered two
  // chips reading "Aug 2, 2026" and there was no way to tell them apart.
  // `recordedAt` is a moment; the formatter was throwing that away.
  testWidgets('two photos from one day are told apart by their time',
      (tester) async {
    await pump(tester, [
      photo(DateTime(2026, 8, 2, 20, 33)),
      photo(DateTime(2026, 8, 2, 20, 31)),
    ]);

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => t.contains('Aug 2'))
        .toSet();
    expect(labels.length, 2,
        reason: 'two same-day chips must not render identical text');
    expect(labels.every((l) => l.contains(':')), isTrue,
        reason: 'the time is what distinguishes them');
  });

  testWidgets(
      'distinct days stay on the plain date — a time on every '
      'chip would be noise', (tester) async {
    await pump(tester, [
      photo(DateTime(2026, 8, 2, 9)),
      photo(DateTime(2026, 7, 5, 9)),
    ]);

    // Twice each: the Earlier picker and the Later picker both list
    // every photo, so either end can be moved to any of them.
    expect(find.text('Aug 2, 2026'), findsNWidgets(2));
    expect(find.text('Jul 5, 2026'), findsNWidgets(2));
  });
}
