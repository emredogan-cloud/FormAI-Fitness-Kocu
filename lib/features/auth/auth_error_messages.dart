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
String authErrorMessage(AppLocalizations l10n, AuthException e) {
  final m = e.message.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return l10n.authErrorInvalidCredentials;
  }
  if (m.contains('email not confirmed')) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (m.contains('already registered') ||
      m.contains('already been registered')) {
    return l10n.authErrorAlreadyRegistered;
  }
  if (m.contains('rate limit') || m.contains('security purposes')) {
    return l10n.authErrorRateLimited;
  }
  if (m.contains('at least 6 characters') || m.contains('weak password')) {
    return l10n.authErrorWeakPassword;
  }
  return l10n.authErrorGeneric;
}
