import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// Store-submission AC3 · Supabase raises English `AuthException`
/// messages; this maps the common ones onto our own copy so a raw
/// provider string never reaches the UI. Kept as a pure top-level
/// function (not a private State method) so the mapping is
/// unit-testable — a wrong substring would otherwise ship silently into
/// review screenshots.
///
/// The MATCHING stays on the English provider text, which is correct:
/// Supabase emits those messages in English regardless of the app's
/// locale, so they are protocol, not copy. Only the returned string is
/// localized.
///
/// The caller is responsible for logging the raw [AuthException.message];
/// this returns only the user-facing copy.
/// The fragments of Supabase's wire text this file matches on.
///
/// Named rather than inlined so each one sits on a short line of its
/// own with a stable `// i18n-ignore`. Inline, the markers ride on
/// `if (...)` conditions, and `dart format` relocates a trailing comment
/// the moment a condition wraps or the marker follows an opening brace —
/// which silently un-marks the literal and reopens the file in the gate.
const _invalidCredentials = 'invalid login credentials'; // i18n-ignore
const _emailNotConfirmed = 'email not confirmed'; // i18n-ignore
const _alreadyRegistered = 'already registered'; // i18n-ignore
const _alreadyBeenRegistered = 'already been registered'; // i18n-ignore
const _rateLimit = 'rate limit'; // i18n-ignore
const _securityPurposes = 'security purposes'; // i18n-ignore
const _atLeastSixCharacters = 'at least 6 characters'; // i18n-ignore
const _weakPassword = 'weak password'; // i18n-ignore

String authErrorMessage(AppLocalizations l10n, AuthException e) {
  final m = e.message.toLowerCase();
  if (m.contains(_invalidCredentials)) {
    return l10n.authErrorInvalidCredentials;
  }
  if (m.contains(_emailNotConfirmed)) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (m.contains(_alreadyRegistered) || m.contains(_alreadyBeenRegistered)) {
    return l10n.authErrorAlreadyRegistered;
  }
  if (m.contains(_rateLimit) || m.contains(_securityPurposes)) {
    return l10n.authErrorRateLimited;
  }
  if (m.contains(_atLeastSixCharacters) || m.contains(_weakPassword)) {
    return l10n.authErrorWeakPassword;
  }
  return l10n.authErrorGeneric;
}
