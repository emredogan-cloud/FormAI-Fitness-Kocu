import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/theme/theme_extension.dart';
import '../../nutrition/presentation/nutrition_tab.dart';
import '../../nutrition/presentation/widgets/nutrition_onboarding_sheet.dart';
import '../../progress/presentation/widgets/badge_unlock_dialog.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
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
  }

  @override
  void didPopNext() {
    // Returned to the dashboard from a pushed route (e.g. /workout).
    // Now is the moment any badges that unlocked while we were
    // off-screen become safe to celebrate.
    _routeIsCurrent = true;
    _maybeCelebrate();
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

    return Scaffold(
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
    } finally {
      _celebrating = false;
    }
  }

  void _onTabChanged(int newIndex) {
    final previous = _index;
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
    final prefs = ref.read(appPreferencesProvider);
    if (prefs.hasCompletedNutritionPrefs) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
