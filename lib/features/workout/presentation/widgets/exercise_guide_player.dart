import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Adaptive exercise guide preview.
///
///   • If [assetPath] ends in a video extension (`.mp4`/`.mov`/`.webm`)
///     the widget spins up [VideoPlayerController.asset] and shows a
///     looping muted demo, exactly like the original implementation.
///   • If [assetPath] ends in an image extension (`.jpg`/`.jpeg`/`.png`/
///     `.webp`/`.gif`) the widget skips the video pipeline entirely and
///     renders a static [Image.asset] inside the same rounded container.
///   • If [assetPath] is null/empty, or either renderer throws, the
///     stylish neon "fallback tile" takes over so the surrounding PIP
///     panel never goes blank.
///
/// Phase 27 baked .jpg stills into `assets/videos/` for ~26 exercises
/// because the upstream RapidAPI tier no longer ships GIF URLs; this
/// widget makes those land cleanly in the existing PIP slot.
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
    debugPrint('🎥 GUIDE DEBUG: Trying to load asset: $path');
    if (path == null || path.isEmpty) {
      debugPrint(
        '🎥 GUIDE ERROR: assetPath is null/empty for '
        '"${widget.exerciseName}" — showing fallback tile.',
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
      debugPrint('🎥 GUIDE DEBUG: Image branch active for $path');
      if (mounted) setState(() => _ready = true);
      return;
    }

    final controller = VideoPlayerController.asset(path);
    _controller = controller;
    try {
      await controller.initialize();

      // Catch decoder errors that surface AFTER initialize() returns,
      // so the widget gracefully degrades to the fallback tile instead
      // of freezing on a broken frame.
      _errorListener = () {
        if (!mounted) return;
        if (controller.value.hasError && !_hasError) {
          debugPrint(
            '🎥 VIDEO ERROR: runtime failure on $path — '
            '${controller.value.errorDescription}',
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
      debugPrint('🎥 VIDEO DEBUG: Successfully loaded $path');
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('🎥 VIDEO ERROR: Failed to load $path. Error: $e\n$st');
      if (!mounted) return;
      setState(() => _hasError = true);
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
    if (_hasError || !_ready) {
      return _FallbackTile(exerciseName: widget.exerciseName);
    }

    if (_isImage) {
      // Same rounded container as the video branch so the PIP slot looks
      // identical regardless of asset format.
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          widget.assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _FallbackTile(exerciseName: widget.exerciseName),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return _FallbackTile(exerciseName: widget.exerciseName);
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
  const _FallbackTile({this.exerciseName});
  final String? exerciseName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fitness_center,
            color: Color(0xFF00F0FF),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            exerciseName ?? 'Yükleniyor...',
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
        ],
      ),
    );
  }
}
