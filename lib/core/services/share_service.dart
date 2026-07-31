import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/nutrition/domain/models/recipe.dart';
import '../../l10n/app_localizations.dart';
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
    // Read before the first await: everything below crosses an async
    // gap, and reading localizations off a context after one is exactly
    // what `use_build_context_synchronously` is warning about.
    final l10n = AppLocalizations.of(context);
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
      final text = _composeProgressText(l10n, percent, referralCode);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: text,
          subject: l10n.shareProgressSubject(percent),
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
    final l10n = AppLocalizations.of(context);
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
      final text = _composeBadgeText(l10n, badgeName, referralCode);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: text,
          subject: l10n.shareBadgeSubject(badgeName),
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
  ///
  /// Phase 54B · marketing copy upgrade. The new wording leans on the
  /// "AI fitness coach" angle (the hook the PM saw landing in user
  /// interviews) instead of the bland "join FormAI" pitch. Two-line
  /// shape so the deep link sits on its own line — most chat clients
  /// auto-linkify the trailing URL when it isn't glued to copy.
  Future<void> shareReferralCode({
    required AppLocalizations l10n,
    required String code,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'referral'));
    try {
      final text = '${l10n.shareReferralText(code)}'
          '\n\nformai://r/$code$_brandHashtagSuffix';
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: l10n.shareReferralSubject,
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

  /// Phase 54B · plain-text share for a recipe. Triggered from the
  /// recipe detail screen's AppBar share icon. Optimised for organic
  /// chat distribution (WhatsApp / Telegram / iMessage) — no PNG to
  /// preview, just a punchy macro callout that doubles as a referral
  /// hook because every share carries the user's deep-link.
  ///
  /// Phase 57 · the share payload now carries the full recipe so the
  /// recipient can cook it without opening the app: macro line,
  /// Malzemeler block (structured `recipe.ingredients` when present;
  /// otherwise heuristic extraction from `instructions`) and the
  /// Yapılışı block. The referral CTA stays at the tail so the link
  /// remains the prominent call-to-action.
  Future<void> shareRecipe({
    required Recipe recipe,
    String? userCode,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'recipe'));
    try {
      final referralLine = userCode == null
          ? ''
          : 'Sen de uygulamayı indir, $userCode kodumla ilk ayını ücretsiz '
              'Pro yap: formai://r/$userCode';
      final ingredients = _ingredientsFor(recipe);
      final method = _methodFor(recipe);
      final sections = <String>[
        "FormAI'da harika bir tarif buldum: ${recipe.title}!",
        'Sadece ${recipe.calories} kcal ve ${recipe.protein}g protein içeriyor.',
        if (ingredients.isNotEmpty)
          'Malzemeler:\n${ingredients.map((e) => '- $e').join('\n')}',
        if (method.isNotEmpty) 'Yapılışı:\n$method',
        if (referralLine.isNotEmpty) referralLine,
      ];
      final text = sections.join('\n\n') + _brandHashtagSuffix;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: "FormAI'da harika bir tarif: ${recipe.title}",
        ),
      );
      if (result.status == ShareResultStatus.success) {
        unawaited(analytics.shareCompleted(surface: 'recipe'));
      }
    } catch (e, st) {
      AppLogger.error(
        'shareRecipe failed',
        e,
        stackTrace: st,
        category: 'share',
      );
    }
  }

  /// Phase 57 · shared ingredient extractor. Mirrors
  /// `FavoritesScreen._ingredientsFor` so the share payload and the
  /// shopping-list export agree on what counts as an ingredient line.
  /// Kept inline rather than extracted to a util because the two call
  /// sites are tiny — a third caller is the trigger to refactor.
  List<String> _ingredientsFor(Recipe recipe) {
    if (recipe.ingredients.isNotEmpty) return recipe.ingredients;
    final raw = (recipe.instructions ?? '').trim();
    if (raw.isEmpty) return const [];
    final lines = raw.split(RegExp(r'\r?\n'));
    final extracted = <String>[];
    var inBlock = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (inBlock) break;
        continue;
      }
      if (RegExp(r'^malzemeler\s*:?\s*$', caseSensitive: false)
          .hasMatch(trimmed)) {
        inBlock = true;
        continue;
      }
      if (RegExp(r'^(yapılışı|hazırlanışı|tarif)\s*:?\s*$',
              caseSensitive: false)
          .hasMatch(trimmed)) {
        if (inBlock) break;
      }
      if (inBlock) {
        extracted.add(_stripBullet(trimmed));
      }
    }
    return extracted;
  }

  /// Phase 57 · returns the cooking-method block from `instructions`.
  /// If the instructions text has a "Yapılışı:" / "Hazırlanışı:"
  /// header, returns everything after it; otherwise returns the whole
  /// instructions string (capped to 1000 chars so a runaway long
  /// recipe doesn't flood the recipient's chat).
  String _methodFor(Recipe recipe) {
    final raw = (recipe.instructions ?? '').trim();
    if (raw.isEmpty) return '';
    final headerMatch = RegExp(
      r'^\s*(?:yapılışı|hazırlanışı|tarif)\s*:?\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(raw);
    final body =
        headerMatch == null ? raw : raw.substring(headerMatch.end).trim();
    if (body.length <= 1000) return body;
    return '${body.substring(0, 1000).trimRight()}…';
  }

  String _stripBullet(String line) {
    return line.replaceFirst(RegExp(r'^[-•*•]\s*'), '').trim();
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

  /// Phase 54B · marketing copy upgrade. The lead now anchors on
  /// "yapay zeka fitness koçumla" (AI fitness coach) — the angle that
  /// the PM saw landing best in user interviews — and the referral
  /// line is rephrased so the deep link reads as a peer invitation
  /// rather than a coupon offer.
  String _composeProgressText(
    AppLocalizations l10n,
    int percent,
    String? referralCode,
  ) {
    final referral = referralCode == null
        ? ''
        : '\n\n${l10n.shareReferralTail}formai://r/$referralCode';
    return '${l10n.shareProgressText(percent)}'
        '$referral$_brandHashtagSuffix';
  }

  /// Phase 54B · same upgrade arc as `shareProgress`. The trailing
  /// referral line keeps the "1 ay birlikte Pro" phrasing because the
  /// PM tested it specifically against the badge surface and saw
  /// higher tap-through than the generic "katıl" copy.
  String _composeBadgeText(
    AppLocalizations l10n,
    String badgeName,
    String? referralCode,
  ) {
    final referral = referralCode == null
        ? ''
        : '\n\n${l10n.shareReferralTail}formai://r/$referralCode';
    return '${l10n.shareBadgeText(badgeName)}'
        '$referral$_brandHashtagSuffix';
  }
}
