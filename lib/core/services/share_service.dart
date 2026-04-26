import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_logger.dart';
import '../widgets/share_templates.dart';
import 'analytics_service.dart';

/// Phase 54 · centralised viral-loop share engine.
///
/// Why a service rather than calling `Share.share*` from button handlers:
///
///   1. The share path involves five steps (compose template widget →
///      mount off-screen → wait for layout → capture RepaintBoundary →
///      encode + persist + dispatch share intent). Doing that inline
///      every share-button press would duplicate ~80 lines per call
///      site and make the analytics wiring (`share_initiated` /
///      `share_completed`) easy to forget.
///   2. Keeping the off-screen mount logic in one place lets us swap
///      the rendering strategy (currently `Overlay` + `RepaintBoundary`)
///      without a tour of the codebase.
///   3. Templates become typed: callers ask for "a progress share" or
///      "a badge share" with strongly-typed parameters, never compose
///      the share copy themselves.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  static const String _brandHashtagSuffix = '\n\n#FormAI #30GündeDeğişim';

  /// Renders the "Progress" template (program completion %) and hands
  /// it to the OS share-sheet. Fires `share_initiated` immediately and
  /// `share_completed` only when the user actually picks a destination
  /// from the system sheet (vs. dismissing it). Errors are reported to
  /// the logger but never thrown — sharing is best-effort.
  Future<void> shareProgress({
    required BuildContext context,
    required int percent,
    required int completedDays,
    required int totalDays,
    required int streak,
    String? referralCode,
    ShareFormat format = ShareFormat.story,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'progress'));
    try {
      final widget = ShareProgressTemplate(
        percent: percent,
        completedDays: completedDays,
        totalDays: totalDays,
        streak: streak,
        format: format,
      );
      final bytes = await _captureWidget(
        context: context,
        widget: widget,
        format: format,
      );
      if (!context.mounted) return;
      final file = await _persistTemp(bytes, prefix: 'formai_progress');
      final text = _composeProgressText(percent, referralCode);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: text,
          subject: 'FormAI ile %$percent tamamladım!',
        ),
      );
      if (result.status == ShareResultStatus.success) {
        unawaited(analytics.shareCompleted(surface: 'progress'));
      }
    } catch (e, st) {
      AppLogger.error(
        'shareProgress failed',
        e,
        stackTrace: st,
        category: 'share',
      );
    }
  }

  /// Renders the "Badge" template and hands it to the OS share-sheet.
  /// Same analytics + error-handling contract as [shareProgress].
  Future<void> shareBadge({
    required BuildContext context,
    required String badgeName,
    required String badgeSubtitle,
    required String badgeEmoji,
    String? referralCode,
    ShareFormat format = ShareFormat.story,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'badge'));
    try {
      final widget = ShareBadgeTemplate(
        badgeName: badgeName,
        badgeSubtitle: badgeSubtitle,
        badgeEmoji: badgeEmoji,
        format: format,
      );
      final bytes = await _captureWidget(
        context: context,
        widget: widget,
        format: format,
      );
      if (!context.mounted) return;
      final file = await _persistTemp(bytes, prefix: 'formai_badge');
      final text = _composeBadgeText(badgeName, referralCode);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: text,
          subject: "FormAI'da $badgeName rozetini kazandım!",
        ),
      );
      if (result.status == ShareResultStatus.success) {
        unawaited(analytics.shareCompleted(surface: 'badge'));
      }
    } catch (e, st) {
      AppLogger.error(
        'shareBadge failed',
        e,
        stackTrace: st,
        category: 'share',
      );
    }
  }

  /// Plain-text share for the referral code itself (no PNG asset). Used
  /// by the Profile-tab "Davet Et" CTA where the user is sharing a code
  /// rather than a celebration image.
  Future<void> shareReferralCode({
    required String code,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'referral'));
    try {
      final text =
          "FormAI'a katıl ve ilk ayını birlikte Pro yapalım! Davet kodum: "
          '$code\n\nformai://r/$code$_brandHashtagSuffix';
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'FormAI davet kodum',
        ),
      );
      if (result.status == ShareResultStatus.success) {
        unawaited(analytics.shareCompleted(surface: 'referral'));
      }
    } catch (e, st) {
      AppLogger.error(
        'shareReferralCode failed',
        e,
        stackTrace: st,
        category: 'share',
      );
    }
  }

  /// Mounts [widget] in a positioned-off-screen overlay layer, pumps a
  /// frame so layout + paint can settle, then captures the wrapping
  /// RepaintBoundary to PNG bytes. The overlay entry is removed in a
  /// `finally` so a thrown encode never leaks render objects.
  ///
  /// `pixelRatio: 1.0` is intentional: the templates already declare
  /// their target pixel size (1080×1920 / 1080×1080) as logical pixels
  /// in [storySize] / [squareSize], so a 1:1 capture lands the PNG at
  /// the expected resolution without over-sampling text.
  Future<Uint8List> _captureWidget({
    required BuildContext context,
    required Widget widget,
    required ShareFormat format,
  }) async {
    final logicalSize = format == ShareFormat.story ? storySize : squareSize;
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        // Positioned far off-screen + IgnorePointer so the live
        // overlay never intercepts taps while the share is in flight.
        return Positioned(
          left: -logicalSize.width - 200,
          top: -logicalSize.height - 200,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: logicalSize.width,
                  height: logicalSize.height,
                  child: widget,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    try {
      // Two frames: one for layout, one for paint settling. The 32 ms
      // sleep is belt-and-braces for slower devices (Redmi Note 11R
      // etc.) where the second `endOfFrame` occasionally returned
      // before the gradient orbs had fully rasterised.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 32));
      await WidgetsBinding.instance.endOfFrame;

      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('RepaintBoundary not yet mounted');
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('PNG encode returned null');
      }
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  /// Drops PNG bytes into the platform temp directory. Naming is
  /// `<prefix>_<epoch>.png` so successive shares don't clobber each
  /// other while the system share sheet is still resolving the URI.
  Future<File> _persistTemp(Uint8List bytes, {required String prefix}) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${prefix}_$ts.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _composeProgressText(int percent, String? referralCode) {
    final referral = referralCode == null
        ? ''
        : '\n\nSen de katıl, ilk ayın Pro: formai://r/$referralCode';
    return 'FormAI ile programımın %$percent\'ini tamamladım! 💪'
        '$referral$_brandHashtagSuffix';
  }

  String _composeBadgeText(String badgeName, String? referralCode) {
    final referral = referralCode == null
        ? ''
        : '\n\nSen de başlat, ilk ayın Pro: formai://r/$referralCode';
    return "FormAI'da '$badgeName' rozetini kazandım! 🏆"
        '$referral$_brandHashtagSuffix';
  }
}
