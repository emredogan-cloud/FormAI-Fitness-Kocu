import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/nutrition/domain/models/recipe.dart';
import '../../features/nutrition/domain/recipe_ingredient_lines.dart';
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

  /// Two blank lines then the brand hashtags. `#FormAI` is the brand
  /// tag and never changes; the campaign tag beside it is copy, so it
  /// comes from ARB.
  static String _brandHashtagSuffix(AppLocalizations l10n) =>
      '\n\n${l10n.shareBrandHashtags}';

  /// Roadmap Phase 10 (C4) · shares the 30-day outcome report.
  ///
  /// Everything on the card arrives already formatted and already
  /// filtered — see [ShareOutcomeTemplate]. This method's only two jobs
  /// are precaching the photograph, if there is one, and telling the
  /// truth in the failure branch.
  ///
  /// **The precache is not an optimisation.** `_captureWidget` gives the
  /// off-screen tree two frames and 32 ms; an undecoded image would
  /// simply be absent from the PNG, and a share card that silently drops
  /// the photograph the user deliberately opted in to is worse than one
  /// that fails.
  Future<bool> shareOutcomeReport({
    required BuildContext context,
    required String headline,
    required String subline,
    required List<(String, String)> lines,
    Uint8List? photoBytes,
    ShareFormat format = ShareFormat.story,
  }) async {
    final analytics = AnalyticsService.instance;
    final l10n = AppLocalizations.of(context);
    unawaited(analytics.shareInitiated(surface: 'outcome_report'));
    try {
      if (photoBytes != null) {
        await precacheImage(MemoryImage(photoBytes), context);
        if (!context.mounted) return false;
      }
      final bytes = await _captureWidget(
        context: context,
        widget: ShareOutcomeTemplate(
          headline: headline,
          subline: subline,
          lines: lines,
          photoBytes: photoBytes,
          format: format,
        ),
        format: format,
      );
      if (!context.mounted) return false;
      final file = await _persistTemp(bytes, prefix: 'formai_report');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '$headline${_brandHashtagSuffix(l10n)}',
        ),
      );
      if (result.status == ShareResultStatus.success) {
        unawaited(analytics.shareCompleted(surface: 'outcome_report'));
      }
      return true;
    } catch (e, st) {
      AppLogger.error('shareOutcomeReport failed', e,
          stackTrace: st, category: 'share');
      return false;
    }
  }

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
          '\n\nformai://r/$code${_brandHashtagSuffix(l10n)}';
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
  /// Malzemeler block (the structured `recipe_ingredients` rows when
  /// present, otherwise the legacy blob — see
  /// [recipeIngredientLines]) and the
  /// Yapılışı block. The referral CTA stays at the tail so the link
  /// remains the prominent call-to-action.
  Future<void> shareRecipe({
    required AppLocalizations l10n,
    required Recipe recipe,
    String? userCode,
  }) async {
    final analytics = AnalyticsService.instance;
    unawaited(analytics.shareInitiated(surface: 'recipe'));
    try {
      final referralLine =
          userCode == null ? '' : l10n.shareRecipeReferralLine(userCode);
      final ingredients = recipeIngredientLines(recipe);
      final method = _methodFor(recipe);
      final sections = <String>[
        l10n.shareRecipeIntro(recipe.title),
        l10n.shareRecipeMacros(recipe.calories, recipe.protein),
        if (ingredients.isNotEmpty)
          '${l10n.shareRecipeIngredientsHeading}\n'
              '${ingredients.map((e) => '- $e').join('\n')}',
        if (method.isNotEmpty) '${l10n.shareRecipeMethodHeading}\n$method',
        if (referralLine.isNotEmpty) referralLine,
      ];
      final text = sections.join('\n\n') + _brandHashtagSuffix(l10n);
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: l10n.shareRecipeSubject(recipe.title),
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
        '$referral${_brandHashtagSuffix(l10n)}';
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
        '$referral${_brandHashtagSuffix(l10n)}';
  }
}
