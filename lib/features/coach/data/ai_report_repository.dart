import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';

/// Why a coach reply is being reported.
///
/// Tokens, never labels — the value goes into a `check` constraint in
/// `027_ai_content_reports.sql` and is read by a human triaging in a
/// language that is not necessarily the reporter's. The labels live in
/// ARB beside every other piece of copy.
///
/// These are not `019`'s `user_reports` reasons and deliberately so.
/// Those describe how a *person* misbehaves; a language model in a
/// fitness app fails differently, and [harmfulAdvice] is the one that
/// matters most — this app talks to people about training and eating,
/// and a model that tells somebody to push through chest pain is a
/// materially worse event than one that is merely rude.
enum AiReportReason {
  harmfulAdvice('harmful_advice'),
  offensive('offensive'),
  inaccurate('inaccurate'),
  other('other');

  const AiReportReason(this.token);
  final String token;
}

/// Which AI surface produced the reported text.
enum AiReportSurface {
  coachChat('coach_chat'),
  onboardingChat('onboarding_chat');

  const AiReportSurface(this.token);
  final String token;
}

/// Files a report about a piece of AI-generated content.
///
/// Required by Google Play's AI-Generated Content policy, which asks for
/// an in-app affordance to flag offensive AI output "without needing to
/// exit the app". That last clause is why this writes to Supabase rather
/// than reusing [FeedbackService]'s mailto fallback: a mail client is
/// exiting the app, and a report that only works when a mail client is
/// configured is not an in-app mechanism.
///
/// A failure is therefore surfaced as "try again" rather than routed
/// somewhere else. The report is one row and the user can re-file it in
/// two taps; queueing it would mean holding reported content on the
/// device indefinitely, which is the opposite of what a person reporting
/// something wants.
class AiReportRepository {
  AiReportRepository({SupabaseClient? client}) : _client = client;

  /// Resolved lazily rather than in the constructor. `ContentSyncService`
  /// learned this the hard way in Phase 14: the eager
  /// `Supabase.instance` form breaks every widget test that mounts a
  /// screen holding one, because the plugin is not initialised there.
  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const String _table = 'ai_content_reports';

  /// Column cap in `027`. Above `MAX_TOKENS` for a coach reply, so a real
  /// one is never truncated — the clamp exists so a pathological input
  /// cannot make the insert fail a `check` constraint instead of
  /// reporting.
  static const int maxMessageLength = 4000;

  /// True when the row landed.
  ///
  /// Guests count: an anonymous Supabase session has a real `auth.uid()`
  /// and the insert policy keys on it, so somebody who never signed in
  /// can still report. Guest mode is a first-class path in this app and
  /// the policy requirement is not conditional on having an account.
  Future<bool> report({
    required String messageText,
    required AiReportReason reason,
    required AiReportSurface surface,
    String? locale,
  }) async {
    final text = messageText.trim();
    if (text.isEmpty) return false;
    final user = _db.auth.currentUser;
    if (user == null) {
      AppLogger.warning(
        'ai report skipped: no session',
        category: 'coach',
      );
      return false;
    }
    try {
      await _db.from(_table).insert({
        'reporter_id': user.id,
        'message_text': text.length > maxMessageLength
            ? text.substring(0, maxMessageLength)
            : text,
        'reason': reason.token,
        'surface': surface.token,
        if (locale != null && locale.isNotEmpty) 'locale': locale,
      });
      return true;
    } catch (e, st) {
      AppLogger.error(
        'ai report failed',
        e,
        stackTrace: st,
        category: 'coach',
      );
      return false;
    }
  }
}

final aiReportRepositoryProvider =
    Provider<AiReportRepository>((ref) => AiReportRepository());
