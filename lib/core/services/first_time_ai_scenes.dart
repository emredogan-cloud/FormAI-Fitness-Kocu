import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/widgets/coach_mood.dart';
import '../utils/app_haptics.dart';
import '../utils/app_logger.dart';
import '../widgets/cinematic_ai_presence.dart';
import 'app_preferences.dart';

/// Phase 126 · gate + present the three first-time cinematic
/// AI-presence scenes.
///
/// Three trigger points across the product:
///
///   1. [FirstTimeAiScene.dashboardWelcome] — first time the user
///      lands on the dashboard after the paywall. Welcomes them
///      into the transformation journey.
///   2. [FirstTimeAiScene.nutritionIntro] — first time the user
///      taps the nutrition tab. Sets up nutrition as a core part
///      of the journey, mentally preparing them before the
///      deferred nutrition wizard.
///   3. [FirstTimeAiScene.workoutCompleteCelebration] — after the
///      first workout completes and the session-complete overlay
///      surfaces. Rewards the first-rep moment with an emotional
///      acknowledgment — "you actually started."
///
/// Gating is shared_preferences-backed via [AppPreferences] flags
/// — same pattern as the existing `hasCompletedNutritionPrefs` /
/// `isFirstTime` flags so the persistence semantics are consistent.
/// Each scene fires exactly once per install.
///
/// Call from any context that wants the scene:
///
///   await FirstTimeAiScenes.showIfNeeded(
///     context, ref, FirstTimeAiScene.dashboardWelcome,
///   );
///
/// Safe to call multiple times — `seen*` checks short-circuit when
/// already shown. Safe to call before/after Navigator state changes
/// — uses `rootNavigator: true` so it routes above any tab/nested
/// navigator.
///
/// Mark-seen ordering: the seen flag is written *before* the route
/// push. This guarantees that if the user backgrounds the app mid-
/// scene, the scene doesn't replay on resume. The cost is that a
/// scene that crashes during render is treated as "shown" — but the
/// CinematicAiPresence widget is fully tested at this point, so the
/// idempotency trade-off favors no-replay.
enum FirstTimeAiScene {
  dashboardWelcome,
  nutritionIntro,
  workoutCompleteCelebration,
}

class FirstTimeAiScenes {
  const FirstTimeAiScenes._();

  /// How long past a scene's own `autoCloseAfter` the watchdog waits
  /// before removing the route itself. Generous enough that it never
  /// races the intended close (which also has to run a 500 ms reverse
  /// transition), short enough that a stuck scene is a blip rather than
  /// a dead end.
  static const Duration _watchdogGrace = Duration(seconds: 3);

  static Future<void> showIfNeeded(
    BuildContext context,
    WidgetRef ref,
    FirstTimeAiScene scene,
  ) async {
    final prefs = ref.read(appPreferencesProvider);
    if (_hasSeen(prefs, scene)) return;

    // Mark seen first so we never replay even if the route push
    // fails or the user backgrounds the app mid-scene.
    await _markSeen(prefs, scene);

    // Soft arrival haptic — "Form is here." Same intensity as other
    // secondary CTAs so it reads as a presence ping, not a button
    // press. Closing haptic is handled by CinematicAiPresence itself.
    AppHaptics.lightImpact();

    if (!context.mounted) return;

    final config = _configs[scene]!;
    final navigator = Navigator.of(context, rootNavigator: true);

    late final PageRouteBuilder<void> route;
    route = PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) {
        return Builder(
          builder: (innerContext) => CinematicAiPresence(
            title: config.title,
            subtitle: config.subtitle,
            subtitleTypewriter: true,
            composingPlaceholder: config.composingPlaceholder,
            mood: config.mood,
            autoCloseAfter: config.autoCloseAfter,
            onComplete: () {
              if (innerContext.mounted) {
                Navigator.of(innerContext, rootNavigator: true).pop();
              }
            },
          ),
        );
      },
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: child,
      ),
    );

    final pushed = navigator.push<void>(route);

    // Watchdog. The scene is a full-screen, non-dismissible route with no
    // visible exit: if its internal auto-close doesn't fire, the user is
    // stranded on a cinematic with nothing to tap. Device QA reproduced
    // exactly that on a clean first run — the welcome scene sat past 22 s
    // against an 8 s `autoCloseAfter`, and only the system back button
    // got out of it.
    //
    // This does NOT replace the scene's own timer; it is the second one.
    // `removeRoute` targets this exact route, so it cannot pop something
    // the user navigated to in the meantime, and it no-ops entirely on
    // the normal path because the route is no longer active by then.
    // The log line is deliberate: it makes a failure that is currently
    // invisible show up in diagnostics instead of only in a bug report.
    var closed = false;
    unawaited(pushed.whenComplete(() => closed = true));
    unawaited(
      Future<void>.delayed(config.autoCloseAfter + _watchdogGrace, () {
        if (closed || !route.isActive) return;
        AppLogger.warning(
          'FirstTimeAiScene ${scene.name} did not auto-close; '
          'watchdog removed it',
          category: 'onboarding',
        );
        navigator.removeRoute(route);
      }),
    );

    await pushed;
  }

  static bool _hasSeen(AppPreferences prefs, FirstTimeAiScene scene) {
    switch (scene) {
      case FirstTimeAiScene.dashboardWelcome:
        return prefs.seenFirstDashboardAi;
      case FirstTimeAiScene.nutritionIntro:
        return prefs.seenFirstNutritionAi;
      case FirstTimeAiScene.workoutCompleteCelebration:
        return prefs.seenFirstWorkoutCompleteAi;
    }
  }

  static Future<void> _markSeen(
    AppPreferences prefs,
    FirstTimeAiScene scene,
  ) async {
    switch (scene) {
      case FirstTimeAiScene.dashboardWelcome:
        await prefs.markSeenFirstDashboardAi();
      case FirstTimeAiScene.nutritionIntro:
        await prefs.markSeenFirstNutritionAi();
      case FirstTimeAiScene.workoutCompleteCelebration:
        await prefs.markSeenFirstWorkoutCompleteAi();
    }
  }
}

class _SceneConfig {
  const _SceneConfig({
    required this.title,
    required this.subtitle,
    required this.composingPlaceholder,
    required this.mood,
    required this.autoCloseAfter,
  });

  final String title;
  final String subtitle;
  final String composingPlaceholder;
  final CoachMood mood;
  final Duration autoCloseAfter;
}

const Map<FirstTimeAiScene, _SceneConfig> _configs = {
  // Dashboard welcome — landing here for the first time after the
  // paywall. Tone: calm motivation, not hype. RC-1 P12 · Form appears
  // ONCE: the first-day line, a one-breath tour of the surfaces, and
  // where to find Form again — then disappears for good (seen-flag).
  FirstTimeAiScene.dashboardWelcome: _SceneConfig(
    title: 'Bugün dönüşümünün ilk günü.',
    subtitle: 'Antrenmanın burada. Beslenme, Gelişim ve Profil '
        'aşağıdaki sekmelerde.\n'
        'Bana ihtiyacın olduğunda üstteki avatarımdan yaz — '
        'her zaman buradayım. 💜',
    composingPlaceholder: 'Sana özel bir şey hazırlıyorum...',
    mood: CoachMood.proud,
    autoCloseAfter: Duration(milliseconds: 8000),
  ),

  // Nutrition intro — first tap on the nutrition tab. Tone: smart,
  // supportive, guiding. Surfaces *before* the existing deferred
  // nutrition wizard so the user feels prepared, not interrogated.
  FirstTimeAiScene.nutritionIntro: _SceneConfig(
    title: 'Beslenme...',
    subtitle: 'Dönüşümünün en güçlü parçalarından biri.\n'
        'Sana doğru bir yol haritası çizeceğim.',
    composingPlaceholder: 'Beslenmeni öğreniyorum...',
    mood: CoachMood.thinking,
    autoCloseAfter: Duration(milliseconds: 6500),
  ),

  // First workout completion — post-session, the moment the user
  // confirms they actually showed up. Tone: proud + emotionally
  // rewarding. NOT gamified celebration spam — calm
  // acknowledgment of the identity shift.
  FirstTimeAiScene.workoutCompleteCelebration: _SceneConfig(
    title: 'Harika iş çıkardın.',
    subtitle: 'İlk adımı attın. Şimdi gerçekten başladın.\n'
        'Bu hissi unutma.',
    composingPlaceholder: 'Seninle gurur duyuyorum...',
    mood: CoachMood.celebratory,
    autoCloseAfter: Duration(milliseconds: 7000),
  ),
};
