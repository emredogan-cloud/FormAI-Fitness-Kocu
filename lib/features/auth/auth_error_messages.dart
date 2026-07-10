import 'package:supabase_flutter/supabase_flutter.dart';

/// Store-submission AC3 · Supabase raises English `AuthException` messages;
/// this maps the common ones to Turkish so raw English never reaches the
/// TR-only UI. Kept as a pure top-level function (not a private State
/// method) so the mapping is unit-testable — a wrong substring or a wrong
/// Turkish string would otherwise ship silently into review screenshots.
///
/// The caller is responsible for logging the raw [AuthException.message];
/// this returns only the user-facing Turkish copy.
String authErrorToTr(AuthException e) {
  final m = e.message.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return 'E-posta veya şifre hatalı.';
  }
  if (m.contains('email not confirmed')) {
    return 'Önce e-postanı doğrulaman gerekiyor — gelen kutunu kontrol et.';
  }
  if (m.contains('already registered') ||
      m.contains('already been registered')) {
    return 'Bu e-posta zaten kayıtlı. Giriş yapmayı dene.';
  }
  if (m.contains('rate limit') || m.contains('security purposes')) {
    return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar dene.';
  }
  if (m.contains('at least 6 characters') || m.contains('weak password')) {
    return 'Şifre en az 6 karakter olmalı.';
  }
  return 'Giriş başarısız oldu. Lütfen tekrar dene.';
}
