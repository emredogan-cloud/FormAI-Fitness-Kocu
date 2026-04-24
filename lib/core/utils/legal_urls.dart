import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';

/// Production URLs for the Kullanım Şartları (Terms of Use) and Gizlilik
/// Politikası (Privacy Policy) pages. Surfaced from the paywall footer,
/// the onboarding welcome disclaimer, and the in-app Gizlilik sheet —
/// satisfies App Store guideline 3.1.2 + 5.1.1(i), and Play Store Data
/// Safety link-out.
///
/// Phase 41: promoted from placeholder to canonical. Hosting lives on
/// `formai.app` (marketing static site); any URL change here must be
/// accompanied by a matching update in App Store Connect and Play
/// Console listing metadata.
class LegalUrls {
  const LegalUrls._();
  static const String terms = 'https://formai.app/terms';
  static const String privacy = 'https://formai.app/privacy';

  /// Phase 47B · canonical destek (support) inbox. Reachable via the
  /// profile-tab's "Destek" tile (`openSupportMail`) and referenced in
  /// the account-settings error toast when a delete fails.
  static const String supportEmail = 'support@formai.app';
  static const String supportSubject = 'SixPack AI Destek';
}

/// Opens [url] in the external browser. Returns true on success; logs and
/// returns false on failure so UI callers can show a fallback toast.
Future<bool> openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    AppLogger.error(
      'openLegalUrl failed',
      e,
      stackTrace: st,
      category: 'legal',
      data: {'url': url},
    );
    return false;
  }
}

/// Phase 47B · triggers the user's default mail client with a
/// pre-filled subject line pointing at [LegalUrls.supportEmail].
///
/// The `mailto:` URI is built via [Uri]'s `queryParameters` so the
/// subject is percent-encoded correctly (spaces become `%20`, Turkish
/// characters are kept valid per RFC 6068). Returns true on success;
/// failures are logged and swallowed so the UI can show a toast.
Future<bool> openSupportMail({
  String email = LegalUrls.supportEmail,
  String subject = LegalUrls.supportSubject,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    query: 'subject=${Uri.encodeQueryComponent(subject)}',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    AppLogger.error(
      'openSupportMail failed',
      e,
      stackTrace: st,
      category: 'legal',
      data: {'email': email, 'subject': subject},
    );
    return false;
  }
}
