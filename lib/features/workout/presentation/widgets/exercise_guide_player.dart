import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/app_logger.dart';

/// Adaptive exercise guide preview.
///
///   • `http://` or `https://` paths play through Phase 51's disk cache:
///     a hit on `flutter_cache_manager` short-circuits to
///     [VideoPlayerController.file]; a miss falls back to
///     [VideoPlayerController.networkUrl] so playback starts immediately
///     while a fire-and-forget background download warms the cache for
///     the next set / launch. Result: each unique URL hits the network
///     at most once per device.
///   • Local `.mp4`/`.mov`/`.webm` asset paths still work via
///     [VideoPlayerController.asset] so tests and any future offline
///     packs keep rendering without code changes.
///   • Image extensions (`.jpg`/`.jpeg`/`.png`/`.webp`/`.gif`) render as
///     a static [Image.asset] inside the same rounded container.
///   • Null/empty paths, or any renderer error, fall through to the neon
///     `_FallbackTile` so the PIP panel never goes blank.
///
/// On web the cache layer is bypassed: [VideoPlayerController.file]
/// has no plugin implementation in the browser, and the browser's own
/// HTTP cache plus the CDN edge already deliver the bandwidth win.
///
/// While the video is buffering (network branch, `!controller.value.isInitialized`)
/// a small centered [CircularProgressIndicator] overlays the fallback so
/// the PIP slot reads "loading" instead of "broken".
class ExerciseGuidePlayer extends StatefulWidget {
  const ExerciseGuidePlayer({
    super.key,
    required this.assetPath,
    this.exerciseName,
  });

  final String? assetPath;
  final String? exerciseName;

  @override
  State<ExerciseGuidePlayer> createState() => _ExerciseGuidePlayerState();
}

class _ExerciseGuidePlayerState extends State<ExerciseGuidePlayer> {
  VideoPlayerController? _controller;
  bool _hasError = false;
  bool _ready = false;
  bool _isImage = false;
  VoidCallback? _errorListener;

  static const _imageExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };

  static bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant ExerciseGuidePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    await _disposeController();
    if (!mounted) return;

    final path = widget.assetPath;
    AppLogger.info(
      'ExerciseGuide: loading asset',
      category: 'workout',
      data: {'path': path ?? '', 'exercise': widget.exerciseName},
    );
    if (path == null || path.isEmpty) {
      AppLogger.warning(
        'ExerciseGuide: assetPath is null/empty — fallback tile',
        category: 'workout',
        data: {'exercise': widget.exerciseName},
      );
      setState(() {
        _hasError = true;
        _ready = false;
        _isImage = false;
      });
      return;
    }

    final isImage = _isImagePath(path);
    setState(() {
      _hasError = false;
      _ready = false;
      _isImage = isImage;
    });

    if (isImage) {
      // Image.asset is synchronous and pulls from the bundle on build.
      // Mark ready immediately; if the file is missing, the build's
      // errorBuilder swaps in the fallback tile without an extra round-trip.
      AppLogger.info(
        'ExerciseGuide: image branch active',
        category: 'workout',
        data: {'path': path},
      );
      if (mounted) setState(() => _ready = true);
      return;
    }

    // Remote streaming branch (Phase 10 default) vs local asset branch.
    // startsWith('http') covers both http and https so we don't special-case
    // the scheme; Dart's Uri.parse will normalise either.
    final isRemote = path.startsWith('http');
    final controller = isRemote
        ? await _resolveRemoteController(path)
        : VideoPlayerController.asset(path);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    try {
      await controller.initialize();

      // Catch decoder errors that surface AFTER initialize() returns,
      // so the widget gracefully degrades to the fallback tile instead
      // of freezing on a broken frame.
      _errorListener = () {
        if (!mounted) return;
        if (controller.value.hasError && !_hasError) {
          AppLogger.warning(
            'ExerciseGuide: video runtime failure',
            category: 'workout',
            data: {
              'path': path,
              'error': controller.value.errorDescription ?? 'unknown',
            },
          );
          setState(() => _hasError = true);
        }
      };
      controller.addListener(_errorListener!);

      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      AppLogger.info(
        'ExerciseGuide: video loaded',
        category: 'workout',
        data: {'path': path},
      );
      setState(() => _ready = true);
    } catch (e, st) {
      AppLogger.error(
        'ExerciseGuide: video load failed',
        e,
        stackTrace: st,
        category: 'workout',
        data: {'path': path},
      );
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  /// Phase 51 · cache-aware controller factory for remote URLs. Cache
  /// hit → play from disk file (no network); miss → kick a background
  /// download to populate the cache for next time, return a network
  /// controller for immediate playback so the user never waits on the
  /// download.
  ///
  /// Web bypasses the disk cache entirely because
  /// [VideoPlayerController.file] is unimplemented in the browser
  /// plugin; the browser's own HTTP cache + the CDN edge cover the
  /// bandwidth case there.
  Future<VideoPlayerController> _resolveRemoteController(String path) async {
    if (kIsWeb) {
      return VideoPlayerController.networkUrl(Uri.parse(path));
    }

    final cacheManager = DefaultCacheManager();
    try {
      final fileInfo = await cacheManager.getFileFromCache(path);
      if (fileInfo != null) {
        AppLogger.info(
          'ExerciseGuide: video cache HIT — playing from disk',
          category: 'workout',
          data: {'path': path, 'cached_path': fileInfo.file.path},
        );
        return VideoPlayerController.file(fileInfo.file);
      }
    } catch (e, st) {
      // A cache lookup failure (corrupt index, locked DB) is non-fatal:
      // we still have the network fallback below, and the lookup error
      // is informational. Keep the warning quiet so it doesn't drown
      // out actual playback errors when the user is offline.
      AppLogger.warning(
        'ExerciseGuide: cache lookup threw; falling back to network',
        category: 'workout',
        data: {'path': path, 'error': e.toString(), 'stack': st.toString()},
      );
    }

    AppLogger.info(
      'ExerciseGuide: video cache MISS — streaming + warming cache',
      category: 'workout',
      data: {'path': path},
    );
    unawaited(_warmCache(cacheManager, path));
    return VideoPlayerController.networkUrl(Uri.parse(path));
  }

  /// Background fetch that populates the cache so future renders of the
  /// same URL hit the file branch above. Failures are swallowed because
  /// the user already saw playback start from the network — there's
  /// nothing to surface to them, but we log so a systemic issue
  /// (Storage 403, CDN misconfig) lands in the breadcrumb trail.
  Future<void> _warmCache(BaseCacheManager cacheManager, String path) async {
    try {
      await cacheManager.downloadFile(path);
      AppLogger.info(
        'ExerciseGuide: cache warmed',
        category: 'workout',
        data: {'path': path},
      );
    } catch (e, st) {
      AppLogger.warning(
        'ExerciseGuide: cache warm failed',
        category: 'workout',
        data: {'path': path, 'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    final listener = _errorListener;
    _controller = null;
    _errorListener = null;
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    await controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _FallbackTile(
        exerciseName: widget.exerciseName,
        errorMode: true,
      );
    }
    if (!_ready) {
      // Show the fallback chrome + a centered spinner while the network
      // video is still buffering. Keeps the PIP slot feeling "alive"
      // instead of static placeholder text.
      return Stack(
        fit: StackFit.expand,
        children: [
          _FallbackTile(exerciseName: widget.exerciseName),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00F0FF),
              ),
            ),
          ),
        ],
      );
    }

    if (_isImage) {
      // Same rounded container as the video branch so the PIP slot looks
      // identical regardless of asset format.
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          widget.assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackTile(
            exerciseName: widget.exerciseName,
            errorMode: true,
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return _FallbackTile(
        exerciseName: widget.exerciseName,
        errorMode: true,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _FallbackTile extends StatelessWidget {
  const _FallbackTile({this.exerciseName, this.errorMode = false});

  final String? exerciseName;

  /// Phase 75 · when true the tile reads as a permanent failure
  /// ("Video yüklenemedi" + alert icon) instead of a benign loading
  /// placeholder. The build() spinner overlay above only fires on the
  /// loading branch, so without this flag the user could not tell
  /// whether playback was still buffering or had silently failed.
  final bool errorMode;

  @override
  Widget build(BuildContext context) {
    final accent = errorMode
        ? const Color(0xFFFF6B6B) // soft red — visible against dark
        : const Color(0xFF00F0FF); // brand cyan
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            errorMode ? Icons.error_outline : Icons.fitness_center,
            color: accent,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            errorMode ? 'Video yüklenemedi' : (exerciseName ?? 'Yükleniyor...'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (errorMode && exerciseName != null) ...[
            const SizedBox(height: 2),
            Text(
              exerciseName!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
