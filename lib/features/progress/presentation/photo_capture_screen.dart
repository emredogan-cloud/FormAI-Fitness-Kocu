import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../data/progress_photo_repository.dart';
import '../domain/models/progress_photo.dart';
import 'photo_copy.dart';

/// Roadmap Phase 10 (C2) · guided progress-photo capture.
///
/// Two things make a progress photo worth taking, and both of them are
/// about the *next* photo rather than this one:
///
///   * **The ghost overlay.** The previous photo of the same pose is
///     drawn over the viewfinder at low opacity. Without it, week two is
///     taken from a different distance at a different angle in different
///     light, and the comparison shows the photographer moving rather
///     than the person changing. This is the single feature that decides
///     whether the before/after screen is worth building.
///   * **Saying where the photo goes, at the moment it is taken.** The
///     roadmap is explicit that this belongs on the camera screen, not
///     in a policy. Somebody deciding whether to photograph their own
///     body is deciding *now*, and a promise they have to go and look
///     for is not a promise they have.
///
/// The camera is released in `dispose` and on the way out of every
/// branch. A progress photo screen that leaves the sensor open is a
/// green dot in the status bar on a screen about privacy.
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key, this.initialPose = PhotoPose.front});

  final PhotoPose initialPose;

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  CameraController? _controller;
  late PhotoPose _pose = widget.initialPose;
  bool _ghost = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Resolves the photo directory so `cachedPathOf` can answer during
    // layout; without it the ghost overlay is missing until some other
    // rebuild happens to follow the first read.
    ref.read(progressPhotoRepositoryProvider).warmUp().then((_) {
      if (mounted) setState(() {});
    });
    _start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _error = _Reason.denied.name);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = _Reason.failed.name);
        return;
      }
      // Front camera when there is one: a progress photo is taken by the
      // person in it, and a rear-camera self-portrait is a photo of a
      // mirror.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e, st) {
      AppLogger.error('photo capture start failed', e,
          stackTrace: st, category: 'progress');
      if (mounted) setState(() => _error = _Reason.failed.name);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final shot = await controller.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      await ref.read(progressPhotoRepositoryProvider).save(
            bytes: bytes,
            pose: _pose,
            recordedAt: DateTime.now(),
          );
      // `takePicture` writes to a cache directory the app does not own
      // the lifetime of. The photo now lives in the private documents
      // directory; leaving the cache copy behind would mean a second
      // image of the user's body in a location this feature makes no
      // promises about.
      try {
        await File(shot.path).delete();
      } catch (_) {}
      ref.invalidate(progressPhotosProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.photosSaved)));
      navigator.pop(true);
    } catch (e, st) {
      AppLogger.error('photo capture failed', e,
          stackTrace: st, category: 'progress');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.photosCameraFailed)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(l10n.photosTitle),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: l10n.photosGhostToggle,
              onPressed: () => setState(() => _ghost = !_ghost),
              icon: Icon(
                _ghost ? Icons.layers : Icons.layers_clear_outlined,
                color: _ghost ? AppColors.neon : Colors.white,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? _Message(
                text: _error == _Reason.denied.name
                    ? l10n.photosCameraDenied
                    : l10n.photosCameraFailed,
              )
            : controller == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neon))
                : Column(
                    children: [
                      Expanded(
                        child: _Viewfinder(
                          controller: controller,
                          ghost: _ghost ? _ghostFile() : null,
                        ),
                      ),
                      _PrivacyLine(text: l10n.photosPrivacyAtCapture),
                      _PoseSelector(
                        active: _pose,
                        onChanged: (pose) => setState(() => _pose = pose),
                      ),
                      const SizedBox(height: 8),
                      _Shutter(
                        label: l10n.photosCapture,
                        busy: _busy,
                        onTap: _capture,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
      ),
    );
  }

  /// The most recent photo of the pose being captured, if there is one.
  ///
  /// Same pose only. Overlaying a front photo while somebody lines up a
  /// side shot is worse than no guide — it tells them to stand wrong.
  File? _ghostFile() {
    final photos = ref.watch(progressPhotosProvider).value;
    if (photos == null) return null;
    for (final photo in photos) {
      if (photo.pose != _pose) continue;
      final path =
          ref.read(progressPhotoRepositoryProvider).cachedPathOf(photo);
      if (path == null) return null;
      final file = File(path);
      return file.existsSync() ? file : null;
    }
    return null;
  }
}

enum _Reason { denied, failed }

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.controller, required this.ghost});

  final CameraController controller;
  final File? ghost;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1080,
            height: controller.value.previewSize?.width ?? 1920,
            child: CameraPreview(controller),
          ),
        ),
        if (ghost != null)
          // 0.35, and it matters. Too faint and it does not guide; too
          // strong and the user frames the photograph rather than
          // themselves, which produces a comparison of two identical
          // compositions and no visible change.
          Opacity(
            opacity: 0.35,
            child: Image.file(
              ghost!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (ghost != null)
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.photosGhostHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// The promise, on the screen where the decision is made.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.neonGreen, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseSelector extends StatelessWidget {
  const _PoseSelector({required this.active, required this.onChanged});

  final PhotoPose active;
  final ValueChanged<PhotoPose> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final pose in PhotoPose.values) ...[
          if (pose != PhotoPose.values.first) const SizedBox(width: 10),
          Semantics(
            button: true,
            selected: pose == active,
            child: GestureDetector(
              onTap: () => onChanged(pose),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: pose == active
                      ? AppColors.neon.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: pose == active
                        ? AppColors.neon
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  poseLabel(l10n, pose),
                  style: TextStyle(
                    color: pose == active ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.camera_alt_rounded),
          label: Text(label),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }
}
