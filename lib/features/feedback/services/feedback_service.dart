import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/legal_urls.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 56 Lite · in-app feedback transport.
///
/// Tries Supabase first (table `feedback`, columns `user_id`,
/// `subject`, `message`, `app_version`, `platform`); on any failure
/// falls back to opening the user's mail client with the same body
/// pre-filled. Both transports surface the message to the team — the
/// fallback exists so an offline user / a user whose row doesn't pass
/// RLS still has a path forward.
///
/// Returns the [FeedbackTransport] that ultimately succeeded so the
/// UI can word the success toast precisely (`Mesajın iletildi.` vs
/// `Mail uygulaman açıldı.`).
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const String _table = 'feedback';

  Future<FeedbackTransport> submit({
    required AppLocalizations l10n,
    required FeedbackSubject subject,
    required String message,
  }) async {
    final body = message.trim();
    if (body.isEmpty) {
      throw ArgumentError('Feedback message must not be empty.');
    }
    final ctx = await _DeviceContext.collect();
    final transport = await _trySupabase(subject, body, ctx) ??
        await _tryMailto(l10n, subject, body, ctx);

    if (transport != null) {
      AnalyticsService.instance.feedbackSubmitted(
        subject: subject.token,
        transport: transport.name,
      );
      return transport;
    }
    throw const FeedbackException();
  }

  Future<FeedbackTransport?> _trySupabase(
    FeedbackSubject subject,
    String body,
    _DeviceContext ctx,
  ) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      // Anonymous-only users can still submit — RLS on the `feedback`
      // table allows authenticated insert with `user_id = auth.uid()`.
      // If the user truly isn't signed in (rare given the redirect
      // gate), skip the Supabase path so we don't 401-noise the logs.
      if (user == null) return null;
      await client.from(_table).insert(<String, dynamic>{
        'user_id': user.id,
        'subject': subject.token,
        'message': body,
        'app_version': ctx.appVersion,
        'platform': ctx.platform,
        'os_version': ctx.osVersion,
      });
      return FeedbackTransport.supabase;
    } catch (e, st) {
      AppLogger.warning(
        'feedback supabase write failed: $e',
        category: 'feedback',
        data: {'stack': st.toString()},
      );
      return null;
    }
  }

  Future<FeedbackTransport?> _tryMailto(
    AppLocalizations l10n,
    FeedbackSubject subject,
    String body,
    _DeviceContext ctx,
  ) async {
    final composed = '$body\n\n— Cihaz —\n'
        'Uygulama: ${ctx.appVersion}\n'
        'Platform: ${ctx.platform} ${ctx.osVersion}';
    final uri = Uri(
      scheme: 'mailto',
      path: LegalUrls.supportEmail,
      query: 'subject=${Uri.encodeQueryComponent(subject.label(l10n))}'
          '&body=${Uri.encodeQueryComponent(composed)}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok ? FeedbackTransport.mailto : null;
    } catch (e, st) {
      AppLogger.warning(
        'feedback mailto fallback failed: $e',
        category: 'feedback',
        data: {'stack': st.toString()},
      );
      return null;
    }
  }
}

enum FeedbackTransport { supabase, mailto }

enum FeedbackSubject {
  bug('bug'),
  suggestion('suggestion'),
  question('question');

  const FeedbackSubject(this.token);

  /// Stable English identifier used in analytics + DB. Never localised —
  /// it is also the value the `feedback_subject_check` constraint in
  /// migration 008 enforces.
  final String token;

  /// UI label surfaced by the dropdown.
  String label(AppLocalizations l10n) => switch (this) {
        FeedbackSubject.bug => l10n.feedbackSubjectBug,
        FeedbackSubject.suggestion => l10n.feedbackSubjectSuggestion,
        FeedbackSubject.question => l10n.feedbackSubjectQuestion,
      };
}

/// Raised when BOTH transports failed.
///
/// Deliberately carries no user-facing copy. It used to hold a Turkish
/// sentence that the sheet rendered verbatim, which put presentation
/// text in a service that has no locale. The sheet maps this to
/// `feedbackSendFailed`; [toString] is a diagnostic for logs, not copy.
class FeedbackException implements Exception {
  const FeedbackException();

  @override
  String toString() => 'FeedbackException: all transports failed';
}

class _DeviceContext {
  const _DeviceContext({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
  });

  final String appVersion;
  final String platform;
  final String osVersion;

  static Future<_DeviceContext> collect() async {
    String version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // package_info_plus can fail on web/desktop test stubs — degrade
      // gracefully rather than blocking the submit flow.
    }
    final platform = Platform.isIOS
        ? 'iOS'
        : (Platform.isAndroid ? 'Android' : Platform.operatingSystem);
    return _DeviceContext(
      appVersion: version,
      platform: platform,
      osVersion: Platform.operatingSystemVersion,
    );
  }
}
