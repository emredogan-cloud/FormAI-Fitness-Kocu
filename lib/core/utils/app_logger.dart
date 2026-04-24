import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Phase 42: the single logging fasad for the app.
///
/// Every `debugPrint` site across the codebase was replaced with one of
/// the three methods below. Two rules:
///
///   1. `info` / `warning` add a Sentry `Breadcrumb`. Breadcrumbs never
///      trigger an issue on their own; they ride attached to the *next*
///      captured exception so we have narrative context leading up to
///      the crash (auth flow, workout state transitions, etc.).
///   2. `error` captures the exception in Sentry AND leaves a breadcrumb.
///      The exception is the thing that creates an issue in the Sentry
///      dashboard.
///
/// PII hygiene: never pass raw body weight, exact age, or raw Supabase
/// user-IDs through `data`. The app-level `beforeSend` hook (`main.dart`)
/// also scrubs the User context to a hashed placeholder as a second
/// line of defence.
class AppLogger {
  const AppLogger._();

  /// Informational breadcrumb — flow markers, feature-flag decisions,
  /// provider-lifecycle transitions. Cheap; call freely.
  static void info(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      debugPrint('[INFO] ${category ?? '-'}: $message');
    }
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          level: SentryLevel.info,
          data: data,
        ),
      ),
    );
  }

  /// Non-fatal anomaly — a best-effort path failed but the user is still
  /// fine (e.g. WakelockPlus didn't toggle, TTS lang list empty). Upgrade
  /// to `error` only if the user's session actually breaks.
  static void warning(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      debugPrint('[WARN] ${category ?? '-'}: $message');
    }
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          level: SentryLevel.warning,
          data: data,
        ),
      ),
    );
  }

  /// Actual exception — captured in Sentry + logged to debug console.
  /// Always include the real error object and stack trace; Sentry uses
  /// these to fingerprint the issue. The free-text [message] is the
  /// breadcrumb tag — keep it short and scannable.
  static void error(
    String message,
    Object error, {
    StackTrace? stackTrace,
    String? category,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      debugPrint('[ERROR] ${category ?? '-'}: $message → $error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
    // Breadcrumb first so the issue timeline includes our own tag, then
    // capture the exception so Sentry opens / updates an issue.
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          level: SentryLevel.error,
          data: data,
        ),
      ),
    );
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }

  /// Utility — fire-and-forget a Future without triggering the
  /// `unawaited_futures` lint. Sentry's calls all return `Future<void>`.
  static void unawaited(Future<void> future) {
    // ignore: discarded_futures
    future;
  }
}
