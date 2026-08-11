import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../workout/services/camera_frame_converter.dart';
import '../domain/food_database.dart';
import '../providers/calorie_providers.dart';

/// Reads a barcode off a package and looks it up.
///
/// ------------------------------------------------------------
/// WHY THIS EXISTS ALONGSIDE THE VISION SCANNER
/// ------------------------------------------------------------
///
/// `docs/CALORIE_TRACKING_RESEARCH.md` §1.2: packaged food should never
/// go through the vision model. Vision on a nutrition label is strictly
/// worse than reading the barcode next to it — a barcode is an exact
/// identification against the manufacturer's own declared panel, where
/// the vision path is a documented 15–25% estimate.
///
/// It is also free in both senses: no model call, so no cost and no
/// scan-quota slot. A user out of AI scans can still log every packaged
/// thing they eat, which is what keeps the free tier usable rather than
/// merely limited.
///
/// ------------------------------------------------------------
/// WHY IT REUSES CameraFrameConverter
/// ------------------------------------------------------------
///
/// That class already carries the sensor-rotation compensation the pose
/// detector needed, and its own doc comment explains why duplicating it
/// is a bad idea: getting rotation wrong is invisible in review and only
/// shows up on hardware you don't own. Both ML Kit packages re-export the
/// same `google_mlkit_commons` types, so the converter works unchanged.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;

  // Only the 1D symbologies that appear on food packaging. Narrowing the
  // set is a real speed-up on a low-end device: ML Kit runs one detector
  // per enabled format, and QR/Aztec/PDF417 will never be on a yoghurt.
  final _scanner = BarcodeScanner(formats: const [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
  ]);

  bool _busy = false;
  bool _handled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    unawaited(_scanner.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded. Holding it means another app
    // cannot open the camera, and on some OEMs the controller comes back
    // in an unusable state after a resume.
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(c.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'no_camera');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        // Barcodes are high-contrast and small; medium is plenty and
        // costs far less per frame than high on a Redmi-class device.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.startImageStream(_onFrame);
      setState(() {
        _controller = controller;
        _camera = camera;
        _error = null;
      });
    } catch (e, st) {
      AppLogger.warning('Barcode camera failed to start: $e',
          category: 'calories', data: {'stack': st.toString()});
      if (mounted) setState(() => _error = 'camera_denied');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    // One frame at a time. Without this the stream queues detections
    // faster than ML Kit retires them and the isolate falls behind
    // permanently — the classic symptom is a scanner that works for two
    // seconds and then stops responding.
    if (_busy || _handled) return;
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return;

    _busy = true;
    try {
      final input = CameraFrameConverter.toInputImage(
        image,
        camera: camera,
        controller: controller,
      );
      if (input == null) return;

      final codes = await _scanner.processImage(input);
      final value = codes
          .map((b) => b.rawValue)
          .whereType<String>()
          .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
      if (value.isEmpty) return;

      _handled = true;
      await _lookup(value.trim());
    } catch (_) {
      // A frame that cannot be processed is skipped; the next arrives in
      // ~33 ms. Surfacing this would flash an error at the user for a
      // condition that resolves itself.
    } finally {
      _busy = false;
    }
  }

  Future<void> _lookup(String barcode) async {
    if (!mounted) return;
    await _controller?.stopImageStream();

    final db = ref.read(foodDatabaseProvider);
    FoodProduct? product;
    try {
      product = await db.lookupBarcode(barcode);
    } catch (e) {
      AppLogger.warning('Barcode lookup failed: $e', category: 'calories');
    }

    if (!mounted) return;
    if (product == null) {
      // A miss is ordinary — Open Food Facts coverage is uneven by
      // market — so hand back the barcode rather than a dead end. The
      // caller offers manual entry with it pre-filled.
      Navigator.of(context).pop(BarcodeScanOutcome.notFound(barcode));
      return;
    }
    Navigator.of(context).pop(BarcodeScanOutcome.found(product));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(l10n.calorieBarcodeTitle),
      ),
      extendBodyBehindAppBar: true,
      body: _error != null
          ? _BarcodeError(
              message: _error == 'no_camera'
                  ? l10n.calorieBarcodeNoCamera
                  : l10n.calorieCameraDenied,
            )
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    const _ReticleOverlay(),
                    PositionedDirectional(
                      start: 24,
                      end: 24,
                      bottom: 48,
                      child: Text(
                        l10n.calorieBarcodeHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// A framing guide. Deliberately just a rounded rectangle: ML Kit scans
/// the whole frame, so a reticle that implied the code must sit exactly
/// inside it would be making a promise the detector does not keep.
class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 260,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neon, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}

class _BarcodeError extends StatelessWidget {
  const _BarcodeError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
}

/// What the scanner hands back.
class BarcodeScanOutcome {
  const BarcodeScanOutcome.found(FoodProduct this.product) : barcode = null;
  const BarcodeScanOutcome.notFound(String this.barcode) : product = null;

  final FoodProduct? product;
  final String? barcode;

  bool get isFound => product != null;
}
