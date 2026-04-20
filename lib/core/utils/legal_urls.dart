import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Placeholder URLs for the Kullanım Şartları and Gizlilik Politikası pages.
/// These get surfaced from both the paywall footer and onboarding disclaimer
/// (App Store guideline 3.1.2 + Play Store developer policy). Swap to real
/// URLs once legal approves the hosted copy.
class LegalUrls {
  const LegalUrls._();
  static const String terms = 'https://formai.app/terms';
  static const String privacy = 'https://formai.app/privacy';
}

/// Opens [url] in the external browser. Returns true on success; logs and
/// returns false on failure so UI callers can show a fallback toast.
Future<bool> openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    debugPrint('openLegalUrl failed for $url: $e\n$st');
    return false;
  }
}
