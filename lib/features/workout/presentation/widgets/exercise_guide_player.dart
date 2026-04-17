import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Looping, muted, offline asset video preview for an exercise demo.
/// Falls back to a neon placeholder tile when the asset is missing or the
/// controller fails to initialize — safe to point at a path before the
/// video file has been added to `assets/videos/`.
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
  bool _failed = false;
  bool _ready = false;

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
    debugPrint('🎥 VIDEO DEBUG: Trying to load asset: $path');
    if (path == null || path.isEmpty) {
      debugPrint(
        '🎥 VIDEO ERROR: assetPath is null or empty for '
        '"${widget.exerciseName}" — showing fallback tile.',
      );
      setState(() {
        _failed = true;
        _ready = false;
      });
      return;
    }

    setState(() {
      _failed = false;
      _ready = false;
    });

    final controller = VideoPlayerController.asset(path);
    _controller = controller;
    try {
      await controller.initialize();
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
      setState(() => _failed = true);
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !_ready) {
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
            exerciseName ?? 'Video Yükleniyor...',
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
