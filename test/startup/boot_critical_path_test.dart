import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two lines that decide how long a cold start takes.
///
/// These are source assertions, not behaviour assertions, and that is
/// deliberate. What went wrong was an *ordering* property of `main()` —
/// one platform-channel call was awaited before `runApp`, and awaiting it
/// cost ~1.9 s of the ~3.0 s to first frame on a Redmi Note 8. A widget
/// test cannot see that: `testWidgets` never runs `main()`, the platform
/// channel is mocked to answer instantly, and the whole cost is the real
/// Android main thread being busy building the activity. Every test that
/// could observe the bug is a test that cannot run on CI hardware.
///
/// So the guard is crude on purpose. It reads the two files and checks
/// the shape that made the app slow, because a regression here is
/// invisible until someone measures a physical device again — and the
/// last time nobody did, it shipped.
void main() {
  group('the boot critical path stays clear', () {
    test('main() does not await the orientation lock', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(
        source,
        contains('SystemChrome.setPreferredOrientations'),
        reason: 'the portrait lock is load-bearing on iOS — Info.plist '
            'still lists both landscapes. If it moved, move this test.',
      );
      expect(
        source,
        isNot(contains('await SystemChrome.setPreferredOrientations')),
        reason: 'awaiting this cost ~1.9 s of a ~3.0 s cold start on a '
            'Redmi Note 8. Nothing in main() needs its result: it '
            'configures the window and reports nothing back. Dispatch it '
            'with unawaited() and let Android enforce portrait from the '
            'manifest instead.',
      );
      expect(
        source,
        contains('unawaited(SystemChrome.setPreferredOrientations'),
        reason: 'the call must still be dispatched — iOS has no manifest '
            'to declare the lock in.',
      );
    });

    test('Android declares the portrait lock in the manifest', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(
        manifest,
        contains('android:screenOrientation="portrait"'),
        reason: 'this is what makes un-awaiting the Dart call safe. The OS '
            'applies it before the process starts, so there is no frame in '
            'which a landscape phone could catch the app unlocked. Without '
            'it, the un-awaited call leaves a real gap.',
      );
    });
  });
}
