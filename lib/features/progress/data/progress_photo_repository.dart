import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/models/progress_photo.dart';

/// Roadmap Phase 10 (C2) · progress photos, stored on the device only.
///
/// # This file contains no network code, on purpose
///
/// There is no Supabase client here, no `http`, no storage bucket, no
/// upload path — not behind a flag, not behind a Pro gate, not in a
/// branch that is currently unreachable. **The absence is the privacy
/// guarantee.** A feature flag that could be flipped to upload a
/// photograph is a feature that uploads photographs; the only version of
/// "your photos stay on your phone" a user can actually verify is the
/// one where the code to send them does not exist.
///
/// `test/features/progress/data/progress_photo_privacy_test.dart` is the
/// gate the roadmap asks for. It reads this source file and fails on any
/// networking symbol, and it drives the whole read/write/delete cycle
/// under an `HttpOverrides` that throws on any request. The first check
/// is the load-bearing one: a mock can only prove the paths a test
/// happens to exercise, while the source scan proves there is no path.
///
/// If cloud backup is ever built, it belongs in a **separate** opt-in
/// service that reads from this one — never as a branch inside it.
///
/// # Why the bytes are files and the index is a preference
///
/// Photographs are megabytes and `SharedPreferences` is a synchronously
/// loaded XML/plist blob; putting images in it would make every app
/// launch slower forever. So the images are files in the app's private
/// documents directory and the index — dates, poses, filenames — is JSON
/// under a versioned key, exactly like `SessionLogRepository`.
///
/// The index stores a file NAME rather than a path. The documents
/// directory's absolute path is not stable across installs, and on iOS
/// it changes between launches; a persisted absolute path is a broken
/// image with a delay on it.
class ProgressPhotoRepository {
  ProgressPhotoRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Versioned, so a future schema change can leave v1 entries invisible
  /// rather than needing a destructive rewrite. Photos are advisory —
  /// losing the index does not lose the files.
  static const String _indexKey = 'sixpack.progress_photos_v1';

  /// Inside `getApplicationDocumentsDirectory()`, which is app-private on
  /// both platforms and is NOT the gallery. A progress photo does not
  /// belong in the camera roll where it syncs to a cloud the user did not
  /// choose and appears in a photo picker they hand to someone else.
  static const String _dirName = 'progress_photos';

  Directory? _cachedDir;

  Future<Directory> _directory() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$_dirName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return _cachedDir = dir;
  }

  /// Every photo, newest first.
  ///
  /// An entry whose file has gone — cleared by the OS, restored from a
  /// backup that skipped it, deleted by a file manager — is dropped from
  /// the returned list rather than surfaced as a broken tile. The index
  /// is not rewritten by a read; [prune] is the explicit way to do that.
  Future<List<ProgressPhoto>> loadAll() async {
    final entries = _decodeIndex();
    if (entries.isEmpty) return const [];
    final dir = await _directory();
    final present = <ProgressPhoto>[];
    for (final photo in entries) {
      if (File('${dir.path}/${photo.fileName}').existsSync()) {
        present.add(photo);
      }
    }
    present.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return List.unmodifiable(present);
  }

  /// Absolute path for a photo, for handing to `Image.file`.
  Future<String> pathOf(ProgressPhoto photo) async =>
      '${(await _directory()).path}/${photo.fileName}';

  /// The same path, synchronously, or null before the directory has been
  /// resolved once.
  ///
  /// A `build` method cannot await, and the capture screen's ghost
  /// overlay needs a path during layout. Returning null rather than
  /// blocking means the first frame draws without the overlay and the
  /// next one has it — which is correct, because the alternative is a
  /// synchronous filesystem call on every rebuild of a camera preview.
  /// [warmUp] is how a caller makes that first frame the only one.
  String? cachedPathOf(ProgressPhoto photo) {
    final dir = _cachedDir;
    return dir == null ? null : '${dir.path}/${photo.fileName}';
  }

  /// Resolves the directory so [cachedPathOf] starts answering. Cheap,
  /// idempotent, and safe to call from `initState`.
  Future<void> warmUp() => _directory();

  /// Writes the bytes and records the entry.
  ///
  /// The filename is derived from the moment and the pose rather than
  /// being random, so the directory is legible to a person who goes
  /// looking — which is the point of storing it somewhere they own.
  Future<ProgressPhoto> save({
    required Uint8List bytes,
    required PhotoPose pose,
    required DateTime recordedAt,
  }) async {
    final dir = await _directory();
    final stamp = recordedAt.toUtc().millisecondsSinceEpoch;
    final photo = ProgressPhoto(
      recordedAt: recordedAt,
      pose: pose,
      fileName: 'formai_${pose.token}_$stamp.jpg',
    );
    await File('${dir.path}/${photo.fileName}')
        .writeAsBytes(bytes, flush: true);
    final entries = _decodeIndex()..add(photo);
    await _writeIndex(entries);
    return photo;
  }

  /// Removes one photo, file and entry together.
  ///
  /// The file goes first. If the process dies between the two, the index
  /// carries an entry whose file is gone — which [loadAll] already
  /// tolerates — rather than a file the user believes they deleted still
  /// sitting on disk with nothing pointing at it.
  Future<void> delete(ProgressPhoto photo) async {
    final dir = await _directory();
    final file = File('${dir.path}/${photo.fileName}');
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (e) {
        AppLogger.warning(
          'ProgressPhotoRepository · could not delete file: $e',
          category: 'progress',
        );
      }
    }
    final entries = _decodeIndex()
      ..removeWhere((entry) => entry.fileName == photo.fileName);
    await _writeIndex(entries);
  }

  /// Deletes every photo and the index.
  ///
  /// Roadmap Phase 10 · the account-deletion contract. `delete_user`
  /// removes the server rows and `prefs.clear()` removes the index, but
  /// neither touches the documents directory — so without this call,
  /// deleting an account would leave the photographs on the handset for
  /// whoever signs in next. Called from `AuthController.deleteAccount`.
  Future<void> deleteEverything() async {
    try {
      final dir = await _directory();
      if (dir.existsSync()) await dir.delete(recursive: true);
      _cachedDir = null;
    } catch (e) {
      AppLogger.warning(
        'ProgressPhotoRepository · could not clear photo directory: $e',
        category: 'progress',
      );
    }
    await _prefs.remove(_indexKey);
  }

  /// Drops index entries whose files are gone. Cheap, idempotent, and
  /// separate from [loadAll] so a read never mutates storage.
  Future<void> prune() async {
    final dir = await _directory();
    final kept = _decodeIndex()
        .where((p) => File('${dir.path}/${p.fileName}').existsSync())
        .toList(growable: false);
    await _writeIndex(kept);
  }

  List<ProgressPhoto> _decodeIndex() {
    final raw = _prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <ProgressPhoto>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ProgressPhoto>[];
      final photos = <ProgressPhoto>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          photos.add(ProgressPhoto.fromJson(entry));
        } catch (e) {
          AppLogger.warning(
            'ProgressPhotoRepository · dropping malformed entry: $e',
            category: 'progress',
          );
        }
      }
      return photos;
    } catch (e) {
      AppLogger.warning(
        'ProgressPhotoRepository · unreadable index: $e',
        category: 'progress',
      );
      return <ProgressPhoto>[];
    }
  }

  Future<void> _writeIndex(List<ProgressPhoto> photos) async {
    final sorted = photos.toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    await _prefs.setString(
      _indexKey,
      jsonEncode([for (final photo in sorted) photo.toJson()]),
    );
  }
}

final progressPhotoRepositoryProvider = Provider<ProgressPhotoRepository>(
  (ref) => ProgressPhotoRepository(ref.watch(sharedPreferencesProvider)),
);

/// The photo list, newest first. Invalidate after a capture or a delete.
final progressPhotosProvider = FutureProvider<List<ProgressPhoto>>(
  (ref) => ref.watch(progressPhotoRepositoryProvider).loadAll(),
);
