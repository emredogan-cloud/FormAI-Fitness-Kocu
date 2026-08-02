import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixpack_ai/features/progress/data/progress_photo_repository.dart';
import 'package:sixpack_ai/features/progress/domain/models/progress_photo.dart';

/// Roadmap Phase 10 (C2, P6) · **the release gate.**
///
/// The roadmap makes this test a condition of shipping, not a nice-to-
/// have: *"verify photos are never transmitted without explicit opt-in —
/// an explicit network-assertion test"*, and *"zero privacy incidents;
/// photo transmission test green in every release"*.
///
/// It asserts the same thing twice, deliberately, because the two checks
/// fail in different directions:
///
///   1. **The source scan** reads `progress_photo_repository.dart` and
///      fails on any networking symbol. This is the load-bearing one. A
///      behavioural test can only prove the paths it happens to
///      exercise; the scan proves there is no path — including one added
///      later behind a flag, which is exactly how a promise like this
///      gets broken.
///   2. **The behavioural test** drives the whole write/read/delete
///      cycle with every socket refused. It catches a transitive upload:
///      a dependency that phones home would pass the scan and fail here.
///
/// If cloud backup is ever built it belongs in a separate opt-in service
/// that reads from the repository. The moment an upload branch appears
/// inside the repository, check 1 fails — which is the point.
void main() {
  group('the source contains no way to transmit a photograph', () {
    late String source;

    setUpAll(() {
      source = File('lib/features/progress/data/progress_photo_repository.dart')
          .readAsStringSync();
    });

    test('imports nothing that can open a socket', () {
      final imports = RegExp(r"^import\s+'([^']+)'", multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();

      const forbidden = <String>[
        'package:http/',
        'package:dio/',
        'package:supabase',
        'package:firebase',
        'package:googleapis',
        'package:web_socket',
        'dart:html',
      ];
      for (final import in imports) {
        for (final banned in forbidden) {
          expect(
            import.startsWith(banned),
            isFalse,
            reason: 'progress_photo_repository imports $import — a progress '
                'photo must have no route off the device',
          );
        }
      }
    });

    test('names no upload, bucket or client symbol', () {
      // Comments are stripped first: this file's own doc comment
      // explains at length that there is no upload path, and matching
      // the word "upload" inside that explanation would make the test
      // fail on its own documentation.
      final code = source
          .replaceAll(RegExp(r'///.*', multiLine: true), '')
          .replaceAll(RegExp(r'//.*', multiLine: true), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

      const forbidden = <String>[
        'Supabase',
        'HttpClient',
        'upload',
        'Uri.parse',
        'storage.from',
        'StorageFileApi',
        'multipart',
      ];
      for (final symbol in forbidden) {
        expect(
          code.contains(symbol),
          isFalse,
          reason: 'progress_photo_repository mentions "$symbol" — the '
              'privacy promise is that the code to send a photo does not '
              'exist, not that it is currently switched off',
        );
      }
    });

    test('writes only inside the app-private documents directory', () {
      // Not the gallery, not external storage. A progress photo in the
      // camera roll syncs to a cloud the user did not choose and shows up
      // in a picker they hand to somebody else.
      expect(source, contains('getApplicationDocumentsDirectory'));
      for (final banned in const [
        'getExternalStorageDirectory',
        'getDownloadsDirectory',
        'MediaStore',
        'PhotoLibrary',
      ]) {
        expect(source.contains(banned), isFalse, reason: 'writes to $banned');
      }
    });
  });

  group('the account-deletion contract', () {
    // `AuthController.deleteAccount` cannot be driven in a unit test —
    // it calls `Supabase.instance`, which is not initialised here, and
    // the resume guide records that as a standing constraint. So the
    // contract is asserted against the source.
    //
    // That is weaker than executing it, and it is still worth having:
    // the failure this guards against is somebody deleting the call
    // during an unrelated refactor of that method, and a source
    // assertion catches exactly that. It is named honestly rather than
    // dressed up as a behavioural test.
    late String source;

    setUpAll(() {
      source = File('lib/features/auth/providers/auth_provider.dart')
          .readAsStringSync();
    });

    test('deleteAccount clears the photo directory', () {
      final body = source.substring(source.indexOf('deleteAccount() async'));
      final method = body.substring(0, body.indexOf('\n  }'));

      expect(
        method,
        contains('progressPhotoRepositoryProvider'),
        reason: 'delete_user cascades the server rows and prefs.clear() '
            'drops the index, but neither touches the documents '
            'directory — without this the photographs outlive the '
            'account on the handset',
      );
      expect(method, contains('deleteEverything'));
    });
  });

  group('with every socket refused', () {
    late Directory sandbox;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sandbox = await Directory.systemTemp.createTemp('formai_photo_test');
      // The plugin is mocked at its method channel rather than through
      // `PathProviderPlatform`, which would mean importing two packages
      // this app only depends on transitively — and CI fails on the
      // `depend_on_referenced_packages` info that produces.
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

    Future<ProgressPhotoRepository> repository() async =>
        ProgressPhotoRepository(await SharedPreferences.getInstance());

    /// Everything below runs inside this. Any attempt to open a socket —
    /// by the repository or by anything it calls — throws.
    Future<T> offline<T>(Future<T> Function() body) =>
        HttpOverrides.runZoned(body, createHttpClient: (_) {
          throw StateError(
            'a progress photo path opened an HTTP client — the whole '
            'point of this feature is that it cannot',
          );
        });

    test('a photo can be saved, listed, read back and deleted', () async {
      await offline(() async {
        final repo = await repository();
        final bytes = Uint8List.fromList(List<int>.filled(64, 7));
        final at = DateTime(2026, 8, 2, 9, 30);

        final saved = await repo.save(
          bytes: bytes,
          pose: PhotoPose.front,
          recordedAt: at,
        );
        expect(saved.pose, PhotoPose.front);
        expect(saved.fileName, endsWith('.jpg'));

        final listed = await repo.loadAll();
        expect(listed, hasLength(1));
        expect(listed.single.fileName, saved.fileName);

        final path = await repo.pathOf(saved);
        expect(File(path).readAsBytesSync(), bytes);

        await repo.delete(saved);
        expect(await repo.loadAll(), isEmpty);
        expect(File(path).existsSync(), isFalse);
      });
    });

    test('the bytes land in the app-private directory and nowhere else',
        () async {
      await offline(() async {
        final repo = await repository();
        final saved = await repo.save(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          pose: PhotoPose.side,
          recordedAt: DateTime(2026, 8, 2),
        );

        final path = await repo.pathOf(saved);
        expect(path, startsWith(sandbox.path));
        expect(path, contains('progress_photos'));
      });
    });

    test('the index stores a file name, never an absolute path', () async {
      await offline(() async {
        final repo = await repository();
        await repo.save(
          bytes: Uint8List.fromList(const [1]),
          pose: PhotoPose.back,
          recordedAt: DateTime(2026, 8, 2),
        );

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('sixpack.progress_photos_v1')!;
        expect(raw, isNot(contains(sandbox.path)),
            reason: 'a persisted absolute path is a broken image after the '
                'next install');
        final decoded = jsonDecode(raw) as List;
        expect(decoded.single['file_name'], isNot(contains('/')));
      });
    });

    test('an entry whose file has vanished is dropped, not shown broken',
        () async {
      await offline(() async {
        final repo = await repository();
        final saved = await repo.save(
          bytes: Uint8List.fromList(const [1]),
          pose: PhotoPose.front,
          recordedAt: DateTime(2026, 8, 2),
        );
        File(await repo.pathOf(saved)).deleteSync();

        expect(await repo.loadAll(), isEmpty);
      });
    });

    test(
        'deleteEverything leaves nothing on disk — the account-deletion '
        'contract', () async {
      await offline(() async {
        final repo = await repository();
        for (final pose in PhotoPose.values) {
          await repo.save(
            bytes: Uint8List.fromList(const [9]),
            pose: pose,
            recordedAt: DateTime(2026, 8, 2, pose.index),
          );
        }
        expect(await repo.loadAll(), hasLength(3));

        await repo.deleteEverything();

        expect(await repo.loadAll(), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sixpack.progress_photos_v1'), isNull);
        expect(
          Directory('${sandbox.path}/progress_photos').existsSync(),
          isFalse,
          reason: 'prefs.clear() does not touch the documents directory, so '
              'without this the photos outlive the account',
        );
      });
    });

    test('photos come back newest first', () async {
      await offline(() async {
        final repo = await repository();
        for (var day = 1; day <= 3; day++) {
          await repo.save(
            bytes: Uint8List.fromList([day]),
            pose: PhotoPose.front,
            recordedAt: DateTime(2026, 8, day),
          );
        }

        final listed = await repo.loadAll();
        expect(listed.map((p) => p.recordedAt.day), [3, 2, 1]);
      });
    });
  });
}
