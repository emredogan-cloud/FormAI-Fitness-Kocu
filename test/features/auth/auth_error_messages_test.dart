import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/auth/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Store-submission AC3 · the mapper must (a) never return English for a
/// known Supabase error, and (b) always return Turkish, even for an
/// unmapped message. A regression here leaks English into a TR-only
/// review screenshot.
void main() {
  String tr(String message) => authErrorToTr(AuthException(message));

  test('invalid credentials -> Turkish', () {
    expect(tr('Invalid login credentials'), 'E-posta veya şifre hatalı.');
  });

  test('email not confirmed -> Turkish (doğrulama)', () {
    expect(tr('Email not confirmed'), contains('doğrulaman'));
  });

  test('already registered -> Turkish (zaten kayıtlı)', () {
    expect(tr('User already registered'), contains('zaten kayıtlı'));
    expect(
      tr('A user with this email address has already been registered'),
      contains('zaten kayıtlı'),
    );
  });

  test('rate limit -> Turkish (çok fazla deneme)', () {
    expect(tr('Email rate limit exceeded'), contains('Çok fazla deneme'));
    expect(
      tr('For security purposes, you can only request this after 60 seconds'),
      contains('Çok fazla deneme'),
    );
  });

  test('weak password -> Turkish (6 karakter)', () {
    expect(
      tr('Password should be at least 6 characters'),
      contains('6 karakter'),
    );
  });

  test('case-insensitive matching', () {
    expect(tr('INVALID LOGIN CREDENTIALS'), 'E-posta veya şifre hatalı.');
  });

  test('unmapped message still returns Turkish (no English leak)', () {
    final out = tr('Some brand new server error nobody mapped yet');
    expect(out, 'Giriş başarısız oldu. Lütfen tekrar dene.');
    // Sanity: the fallback must not echo the raw English back.
    expect(out.toLowerCase(), isNot(contains('server error')));
  });
}
