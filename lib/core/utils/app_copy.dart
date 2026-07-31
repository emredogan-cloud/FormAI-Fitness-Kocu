import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Roadmap Phase 5 (C11) · localized copy for code that runs nowhere
/// near a `BuildContext`.
///
/// Most of the app reads copy through `AppLocalizations.of(context)`,
/// which is the right thing to do wherever a widget tree exists. Several
/// surfaces have no tree to read from:
///
///   * scheduled notifications, composed in the workout repository and
///     the smart-reminder scheduler;
///   * the Android home-screen widget, pushed from a Riverpod listener;
///   * the text-to-speech smoke test, which runs from a settings action
///     but speaks through a platform channel with no element attached.
///
/// Each of those could keep its own `static Locale` — the notification
/// service originally did. That does not scale: every additional one is
/// another thing `main.dart` has to remember to assign, and the failure
/// mode when it forgets is silent (one surface keeps speaking the
/// previous language). So there is exactly one locale here, assigned in
/// exactly one place: `main.dart`'s `localeResolutionCallback`, which is
/// where the app decides what language it speaks.
///
/// A [Locale] rather than a live [AppLocalizations], deliberately. This
/// copy is composed at one moment and consumed at another — a
/// notification is scheduled today and fired tomorrow with no app
/// process running; the home widget keeps rendering after the app is
/// killed. Holding an [AppLocalizations] would imply a liveness the
/// platform does not offer. A locale change takes effect on the next
/// compose, not retroactively on copy already handed to the OS.
abstract final class AppCopy {
  /// The locale non-widget copy is written in. Assigned by `main.dart`
  /// when the app resolves its locale; the default keeps everything
  /// working before the first frame and in tests.
  static Locale locale = const Locale('tr');

  /// Loads copy with no widget tree.
  ///
  /// [AppLocalizations.delegate] resolves synchronously in practice (its
  /// `load` returns a `SynchronousFuture`), so awaiting this does not
  /// cost a frame — but it is typed as a future and must be awaited.
  static Future<AppLocalizations> load() =>
      AppLocalizations.delegate.load(locale);
}
