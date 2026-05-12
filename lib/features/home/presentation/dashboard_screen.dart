import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/first_time_ai_scenes.dart';
import '../../../core/theme/theme_extension.dart';
import '../../monetization/models/locked_feature_type.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../monetization/services/conversion_moment_service.dart';
import '../../monetization/services/premium_gate_service.dart';
import '../../monetization/services/rating_moment_service.dart';
import '../../nutrition/presentation/nutrition_tab.dart';
import '../../nutrition/presentation/widgets/nutrition_onboarding_sheet.dart';
import '../../progress/data/level_titles.dart';
import '../../progress/presentation/widgets/badge_unlock_dialog.dart';
import '../../progress/presentation/widgets/level_up_screen.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../progress/providers/xp_award_listener.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/providers/workout_provider.dart';
import 'widgets/antrenman_tab.dart';
import 'widgets/gelisim_tab.dart';
import 'widgets/profile_tab.dart';

// Phase 53B · `_neon` no longer needed locally; the bottom nav now
// reads its accent colour from the centralised `BottomNavigationBarTheme`
// in AppTheme.dark/light, so the file-level constant is dead.
const int _nutritionTabIndex = 1;
// Phase 57 · the Gelişim tab is the only context where the badge
// celebration dialog should pop. Ad-hoc and program-day workouts
// finish on the /workout route, then surface the SessionCompleteOverlay
// on top before the user dismisses back to the dashboard. Even after
// pop, the user might land on the Antrenman tab (index 0) — popping a
// celebration there feels disconnected from the badge UI which lives
// inside the Gelişim tab. So we hold the dialog until the user is
// actually on Gelişim.
const int _gelisimTabIndex = 2;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with RouteAware {
  int _index = 0;
  // Phase 48.1 · whether the dashboard's PageRoute is currently the
  // topmost route in the navigator. Toggled from `didPush` /
  // `didPushNext` / `didPopNext`. We only fire badge celebrations when
  // this is true, so an unlock that resolves while the user is still
  // looking at the workout summary overlay (a route pushed on top)
  // gets queued and surfaced after they pop back.
  bool _routeIsCurrent = true;
  RouteObserver<PageRoute<dynamic>>? _routeObserver;
  // Tracks whether a celebration dialog is in flight so we don't stack
  // two on top of each other if the unlock set churns mid-celebration.
  bool _celebrating = false;

  // Progress Phase 3.E · the last level we've already shown a level-up
  // celebration for. Null until the first emission of
  // `currentLevelProvider` seeds it (the same pattern badges use to
  // avoid a celebration storm on cold start with backfilled XP).
  int? _celebratedLevel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = ref.read(routeObserverProvider);
      _routeObserver!.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _routeIsCurrent = true;
    // Right after first push, seed the celebration history with whatever
    // is already unlocked so we don't replay yesterday's wins on cold
    // start. The seed is null-checked inside `_maybeCelebrate`.
    _maybeCelebrate();
    // Phase 126 · first-time post-paywall welcome AI scene. The gate
    // inside [FirstTimeAiScenes] makes this a no-op on subsequent
    // dashboard pushes; on the first push it pushes a cinematic
    // welcome over the dashboard, then auto-pops back here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstTimeAiScenes.showIfNeeded(
        context,
        ref,
        FirstTimeAiScene.dashboardWelcome,
      );
    });
  }

  @override
  void didPopNext() {
    // Returned to the dashboard from a pushed route (e.g. /workout).
    // Now is the moment any badges that unlocked while we were
    // off-screen become safe to celebrate.
    _routeIsCurrent = true;
    _runDashboardReturnFlow();
  }

  /// Phase 135 + 136 · sequenced post-return flow. Order matters for
  /// emotional beat sequencing:
  ///
  ///   1. Badge / level-up celebrations — "I unlocked something"
  ///   2. First-workout Pro invitation (non-pro only, 1+ workouts)
  ///   3. 3rd-workout rating cinematic (pro only, 3+ workouts)
  ///
  /// Each step is gated by its own SharedPreferences flag so the
  /// sequence is idempotent and re-running the flow on a subsequent
  /// dashboard return doesn't replay anything the user already saw.
  Future<void> _runDashboardReturnFlow() async {
    await _maybeCelebrate();
    if (!mounted) return;
    final session = ref.read(workoutSessionProvider).value;
    if (session == null) return;
    final completed = session.days.where((d) => d.isCompleted).length;
    final isPro = ref.read(isProProvider);
    await ref
        .read(conversionMomentProvider)
        .maybeShowFirstWorkoutProInvitation(
          context,
          completedDays: completed,
          isPro: isPro,
        );
    if (!mounted) return;
    await ref.read(ratingMomentProvider).maybeShow(
          context,
          completedDays: completed,
          isPro: isPro,
        );
  }

  @override
  void didPushNext() {
    // Another route was pushed on top of the dashboard. Suppress
    // celebrations until we get a `didPopNext`.
    _routeIsCurrent = false;
  }

  @override
  Widget build(BuildContext context) {
    // Phase 48.1 · listen for unlock-set transitions. The dialog
    // itself is shown only when `_routeIsCurrent` is true; otherwise
    // the unlocked id is held in the celebrated provider's diff and
    // surfaced on the next `didPopNext`.
    ref.listen<Set<String>>(unlockedBadgesProvider, (previous, next) {
      // First emission seeds `celebratedBadgesProvider` so existing
      // unlocks don't trigger a celebration storm on cold start.
      final celebrated = ref.read(celebratedBadgesProvider);
      if (celebrated == null) {
        ref.read(celebratedBadgesProvider.notifier).setAll(next);
        return;
      }
      _maybeCelebrate();
    });

    // Progress Phase 3.C · mount the XP awarding listener. It owns its
    // own `ref.listen` chain over badges / sessionLogs / preferences,
    // so we just touch it once here to ensure it's instantiated for
    // the lifetime of the dashboard. Idempotent — re-watching is a
    // no-op after the first attach.
    ref.watch(xpAwardListenerProvider);

    // Progress Phase 3.E · level-up detection. Mirrors the badge
    // pattern: first emission seeds `_celebratedLevel` so backfilled
    // XP on Phase-3 boot doesn't replay every level the user already
    // has. Subsequent emissions trigger the queue.
    ref.listen<int>(currentLevelProvider, (previous, next) {
      if (_celebratedLevel == null) {
        _celebratedLevel = next;
        return;
      }
      if (next > _celebratedLevel!) {
        _maybeCelebrate();
      }
    });

    // Phase 4.F · status bar styling. Tints the system bars to match
    // the active theme — masterplan §9.7 calls this out as one of the
    // "subtle but persistent" Apple touches that compound to make the
    // app feel premium. AnnotatedRegion is theme-reactive: a mid-
    // session OS dark/light flip repaints the system chrome on the
    // next frame.
    final isDark = context.isDarkMode;
    final overlayStyle = isDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
      // Phase 53B · drop the explicit override and let the active
      // `ThemeData.scaffoldBackgroundColor` drive the canvas. In light
      // mode that's `AppColors.lightBg` (#F7F8FA, an off-white), which
      // gives cards painted with `surface` (#FFFFFF) the natural
      // contrast they were missing. The previous hotfix pinned the
      // scaffold to `surface` directly, which made cards melt into the
      // background — exactly the bug the PM screenshotted.
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            AntrenmanTab(),
            NutritionTab(),
            GelisimTab(),
            ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: _onTabChanged,
      ),
      ),
    );
  }

  Future<void> _maybeCelebrate() async {
    if (!mounted || !_routeIsCurrent || _celebrating) return;
    // Phase 57 · the PM specifically asked that badge unlocks ONLY
    // surface on the Gelişim (progress) tab. Holding the celebration
    // until the user lands there mirrors the rest of the badge UI
    // (badges grid + AI coach copy) which all live on Gelişim. If the
    // unlock happened off-tab, it stays in `unlockedBadgesProvider \
    // celebratedBadgesProvider` — the diff that drives this method
    // re-runs the moment the user switches to Gelişim (see
    // `_onTabChanged`).
    if (_index != _gelisimTabIndex) return;
    final unlocked = ref.read(unlockedBadgesProvider);
    final celebrated = ref.read(celebratedBadgesProvider) ?? unlocked;
    final pending = unlocked.difference(celebrated).toList();
    if (pending.isEmpty) {
      // Initialise celebrated set if it was null but no unlocks pending.
      if (ref.read(celebratedBadgesProvider) == null) {
        ref.read(celebratedBadgesProvider.notifier).setAll(unlocked);
      }
      return;
    }
    _celebrating = true;
    try {
      // ─── 1. Badge celebrations ─────────────────────────────────
      for (final id in pending) {
        if (!mounted || !_routeIsCurrent) break;
        final badge = badgeById(id);
        if (badge == null) {
          // Mark anyway so an unknown id doesn't loop forever.
          ref.read(celebratedBadgesProvider.notifier).add(id);
          continue;
        }
        await showBadgeUnlockedDialog(context, badge);
        if (!mounted) break;
        ref.read(celebratedBadgesProvider.notifier).add(id);
      }

      // ─── 2. Level-up celebrations (Progress Phase 3.E) ────────
      // Run *after* badges because levels are typically a consequence
      // of unlocking the badges that just fired. Walk every level the
      // user crossed since the last celebration so a multi-level jump
      // (rare, but possible on Phase-3-boot backfill) plays each one.
      if (mounted && _routeIsCurrent && _celebratedLevel != null) {
        final currentLevel = ref.read(currentLevelProvider);
        var lastSeen = _celebratedLevel!;
        while (lastSeen < currentLevel && mounted && _routeIsCurrent) {
          final next = lastSeen + 1;
          await LevelUpScreen.push(
            context,
            level: next,
            tier: tierForLevel(next),
          );
          lastSeen = next;
          _celebratedLevel = lastSeen;
        }
      }
    } finally {
      _celebrating = false;
    }
  }

  void _onTabChanged(int newIndex) {
    final previous = _index;
    // Phase 134 · nutrition is now a premium-gated section. When a
    // non-pro user taps Beslenme, intercept the tab switch and route
    // through PremiumGateService so the cinematic conversion scene
    // (Phase 135) — or, until C4 lands, the paywall — fires instead
    // of revealing nutrition content. Pro users fall through to the
    // normal tab-switch path including the deferred-onboarding hook.
    if (newIndex == _nutritionTabIndex &&
        previous != _nutritionTabIndex &&
        !ref.read(isProProvider)) {
      ref.read(premiumGateProvider).handleLockedTap(
            context,
            LockedFeatureType.nutritionTab,
          );
      return;
    }
    setState(() => _index = newIndex);
    // Phase 46 · deferred nutrition onboarding. First time the user
    // lands on the Beslenme tab, present the four nutrition
    // questions that used to live at the tail of primary
    // onboarding. `hasCompletedNutritionPrefs` gates the prompt so
    // it fires exactly once per install.
    if (newIndex == _nutritionTabIndex && previous != _nutritionTabIndex) {
      _maybePromptNutritionSheet();
    }
    // Phase 57 · drain pending badge celebrations the moment the user
    // switches into Gelişim. `_maybeCelebrate` is a no-op when the
    // unlock set hasn't grown since the last seed, so the cost is one
    // set-difference per tab change — cheap and correct.
    if (newIndex == _gelisimTabIndex && previous != _gelisimTabIndex) {
      _maybeCelebrate();
    }
  }

  void _maybePromptNutritionSheet() {
    // Phase 126 · the deferred nutrition wizard now chains through the
    // first-time AI intro scene. Both have their own seen-flags, so:
    //   • first ever nutrition-tab tap: AI scene → then the wizard
    //   • nutrition wizard already done, AI scene not yet: just AI
    //   • AI scene done, wizard not yet: just the wizard
    //   • both done: nothing
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await FirstTimeAiScenes.showIfNeeded(
        context,
        ref,
        FirstTimeAiScene.nutritionIntro,
      );
      if (!mounted) return;
      final prefs = ref.read(appPreferencesProvider);
      if (prefs.hasCompletedNutritionPrefs) return;
      showNutritionOnboardingSheet(context);
    });
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Phase 53B · the bottom nav now reads its colours from the
    // pre-resolved `Theme.of(context).bottomNavigationBarTheme` set up
    // in `AppTheme.dark()` / `AppTheme.light()`, so the widget flips
    // automatically with the user's theme choice. The previous
    // hotfix wrapped the BottomNavigationBar in a Container with its
    // own `decoration: BoxDecoration(color: ...)`, which was
    // double-painting and produced rendering surprises in some
    // builds — dropping the wrapper lets Material own the chrome
    // entirely.
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final scheme = context.colors;
    return DecoratedBox(
      // Hairline border above the nav so the strip reads as a distinct
      // surface even when its background and the scaffold both land on
      // near-white tones in light mode. The border colour pulls from
      // outlineVariant so it darkens cleanly on dark mode too.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: BottomNavigationBar(
        currentIndex: index,
        onTap: onChanged,
        // `backgroundColor` is left null on purpose — the
        // BottomNavigationBarThemeData on the active ThemeData paints
        // the Material so we don't fight it from two sides.
        backgroundColor: navTheme.backgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: navTheme.selectedItemColor,
        unselectedItemColor: navTheme.unselectedItemColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Antrenman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Beslenme',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Gelişim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
