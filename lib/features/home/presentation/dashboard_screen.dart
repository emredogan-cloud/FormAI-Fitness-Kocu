import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/content_sync_service.dart';
import '../../../core/utils/app_logger.dart';
import 'whats_new_screen.dart';
import '../../../core/services/disclosure_providers.dart';
import '../../../core/services/feature_flags.dart';
import '../../../core/services/progressive_disclosure.dart';
import '../../../core/services/first_time_ai_scenes.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/services/tour_targets.dart';
import '../../community/presentation/community_screen.dart';
import '../../../core/services/unlock_announcer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extension.dart';
import '../../../core/services/analytics_service.dart';
import '../../feedback/domain/survey.dart';
import '../../feedback/presentation/survey_sheet.dart';
import '../../feedback/services/survey_service.dart';
import '../../monetization/domain/rating_trigger.dart';
import '../../monetization/providers/monetization_provider.dart';
import '../../monetization/services/conversion_moment_service.dart';
import '../../monetization/services/rating_moment_service.dart';
import '../../nutrition/domain/models/planned_meal.dart';
import '../../nutrition/presentation/nutrition_tab.dart';
import '../../nutrition/presentation/widgets/nutrition_onboarding_sheet.dart';
import '../../nutrition/providers/daily_menu_provider.dart';
import '../../progress/data/level_titles.dart';
import '../../progress/presentation/widgets/badge_unlock_dialog.dart';
import '../../progress/presentation/widgets/level_up_screen.dart';
import '../../progress/providers/badge_unlocks_provider.dart';
import '../../progress/providers/streak_provider.dart';
import '../../progress/providers/xp_award_listener.dart';
import '../../progress/providers/xp_provider.dart';
import '../../workout/domain/workout_mode.dart';
import '../../workout/providers/workout_provider.dart';
import 'dashboard_logic.dart';
import '../domain/discovery_tips.dart';
import 'widgets/antrenman_tab.dart';
import 'widgets/discovery_tip_card.dart';
import 'widgets/gelisim_tab.dart';
import 'widgets/profile_tab.dart';
import '../../../l10n/app_localizations.dart';

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

/// Roadmap Phase 2 · a request channel for switching dashboard tabs from
/// outside the dashboard's own State.
///
/// The Profil tab's "Uygulama Turu" row needs to put the user back on
/// Antrenman before replaying the tour (the tour's targets live there,
/// and an `IndexedStack` branch that isn't showing resolves to stale
/// rects). Rather than lift `_index` out of State — which every celebration
/// / nutrition-prompt / badge path reads — this exposes a one-way request
/// that the dashboard listens to and applies.
///
/// A monotonically-bumped sequence rides along with the index so two
/// consecutive requests for the *same* tab still notify. Without it, a
/// second "go to Antrenman" while already on Antrenman would be
/// swallowed by equality.
class DashboardTabRequest {
  const DashboardTabRequest({required this.index, required this.seq});

  final int index;
  final int seq;
}

class DashboardTabRequestNotifier extends Notifier<DashboardTabRequest?> {
  @override
  DashboardTabRequest? build() => null;

  int _seq = 0;

  void request(int index) {
    _seq++;
    state = DashboardTabRequest(index: index, seq: _seq);
  }
}

final dashboardTabRequestProvider =
    NotifierProvider<DashboardTabRequestNotifier, DashboardTabRequest?>(
  DashboardTabRequestNotifier.new,
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  /// Asks the mounted dashboard to switch to [index]. No-op if no
  /// dashboard is listening.
  static void requestTab(WidgetRef ref, int index) {
    ref.read(dashboardTabRequestProvider.notifier).request(index);
  }

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

  // Tier 2-A · meal-image cache warming. One-shot flag prevents the
  // post-frame callback and the dailyMenuProvider listener from both
  // firing the prefetch on cold start.
  bool _didPrefetchMeals = false;
  ProviderSubscription<AsyncValue<List<PlannedMeal>>>? _menuSub;
  ProviderSubscription<DashboardTabRequest?>? _tabRequestSub;

  // Roadmap Phase 2 (C37 · P3) · tabs the user has opened at least once.
  // Drives the discovery dot on the bottom nav. Seeded in initState from
  // prefs so a returning user never sees dots on tabs they know.
  Set<int> _visitedTabs = const <int>{};

  // Roadmap Phase 2 (C28) · the currently-surfaced dashboard tip, or
  // null. Recomputed after the tour, after a first tab visit, and after
  // a dismissal.
  DiscoveryTip? _tip;

  @override
  void initState() {
    super.initState();
    // Warm today's meal images so the nutrition tab doesn't paint
    // LQIP-only on first navigation. Disk-only warm (no in-memory
    // bitmap decode — same `flutter_cache_manager` pattern as
    // antrenman_tab.dart's Phase 51 `_warmDefaults`). The post-frame
    // callback covers the common case where the provider has already
    // resolved; the listener covers the cold-start race where the
    // first frame paints before the recipe catalogue is fetched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybePrefetchTodaysMeals();
    });
    _menuSub = ref.listenManual<AsyncValue<List<PlannedMeal>>>(
      dailyMenuProvider,
      (_, next) {
        if (next.value != null) _maybePrefetchTodaysMeals();
      },
    );
    // Roadmap Phase 2 · seed the visited-tab set + the tip slot from
    // persisted state, so a returning user gets no stale dots and sees a
    // relevant tip on the very first frame rather than after a rebuild.
    final prefs = ref.read(appPreferencesProvider);
    _visitedTabs = prefs.visitedTabs;
    // Tab 0 is where every user lands, so record it here rather than
    // waiting for a tab *change* that may never come.
    unawaited(_recordTabVisit(0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshTip();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_maybeShowWhatsNew());
    });
    // Roadmap Phase 2 · honour external tab requests (currently the
    // Profil tab's tour-replay row). listenManual, not a build-time
    // ref.listen, so applying a request never happens during build.
    _tabRequestSub = ref.listenManual<DashboardTabRequest?>(
      dashboardTabRequestProvider,
      (_, next) {
        if (next == null || !mounted) return;
        if (next.index == _index) return;
        _onTabChanged(next.index);
      },
    );
  }

  /// Roadmap Phase 14 (C5) · the changelog, once per release.
  ///
  /// The sync runs first and the decision is made after it, so the very
  /// first launch on a new build shows the note for that build rather
  /// than one launch later. `refreshIfStale` makes that cheap: a user
  /// who opens the app six times an hour issues one request.
  ///
  /// **Everything here is allowed to do nothing.** No release table, no
  /// connectivity, no unread note and no locale with copy in it all end
  /// the same way — silently. A changelog is the least important thing
  /// on this screen and it must never be the reason it fails.
  Future<void> _maybeShowWhatsNew() async {
    try {
      await ref.read(contentSyncServiceProvider).refreshIfStale();
      if (!mounted) return;
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber);
      if (build == null || !mounted) return;
      final locale = Localizations.localeOf(context).toLanguageTag();
      final release = ref.read(
        pendingReleaseNoteProvider((build: build, locale: locale)),
      );
      if (release == null || !mounted) return;
      await context.push(AppRoutes.whatsNew, extra: release);
    } catch (e, st) {
      // package_info_plus fails on test stubs, and a wedged link throws
      // past the sync service's own guard. Neither is worth a broken
      // dashboard.
      AppLogger.warning('whats-new check skipped: $e',
          category: 'content', data: {'stack': st.toString()});
    }
  }

  void _maybePrefetchTodaysMeals() {
    if (_didPrefetchMeals) return;
    final plan = ref.read(dailyMenuProvider).value;
    if (plan == null) return;
    _didPrefetchMeals = true;
    final cacheManager = DefaultCacheManager();
    for (final url
        in DashboardLogic.prefetchUrls(plan.map((pm) => pm.recipe.imageUrl))) {
      unawaited(() async {
        try {
          await cacheManager.downloadFile(url);
        } catch (_) {
          // Best-effort. CachedNetworkImage will retry on first render.
        }
      }());
    }
  }

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

  /// Guards the one-shot first-run chain (tour then welcome scene).
  ///
  /// Not redundant with the two `seen*` flags: those are written before
  /// presentation, so they cannot stop a second `didPush` that arrives
  /// while the first chain is still awaiting.
  bool _firstRunFlowStarted = false;

  @override
  void dispose() {
    _menuSub?.close();
    _tabRequestSub?.close();
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
    // The first-run sequence, in the order the founder specified:
    //
    //   1. the spotlight tour — the functional layer, "where things are"
    //   2. it finishes
    //   3. the Form welcome scene — the emotional beat
    //
    // This is a reversal. The scene used to run first, on the reasoning
    // that the emotional beat should land before the mechanics. In
    // practice the two were arriving on top of each other, and the tour
    // is the one that has to own the screen: it points at real widgets,
    // so anything drawn over it makes it point at nothing.
    //
    // `_firstRunFlowStarted` is the guard. Both steps are individually
    // one-shot and each is gated on its own `seen*` flag, which is why
    // this looked safe — but the flags are written BEFORE presentation
    // (the idempotency contract both services share), so a second
    // `didPush` arriving while this chain is still awaiting would sail
    // through both gates and start a second, concurrent chain. That is
    // an overlap no amount of awaiting inside the chain can prevent.
    if (_firstRunFlowStarted) return;
    _firstRunFlowStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // One frame so the dashboard has certainly laid out — the tour
      // resolves target rects from live RenderBoxes, and an unresolved
      // step is silently dropped rather than retried.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      await ref.read(tourServiceProvider).maybeStartDashboardTour(context);
      if (!mounted) return;
      // Let the tour's exit transition finish before the scene's own
      // 600 ms fade-in starts, so the two never cross-dissolve.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      await FirstTimeAiScenes.showIfNeeded(
        context,
        ref,
        FirstTimeAiScene.dashboardWelcome,
      );
      if (!mounted) return;
      // Roadmap Phase 4 (R1.3) · everything open on day 0 is the
      // starting position, not an achievement. Recording it as
      // announced here is what stops a first-run user being handed a
      // stack of "yeni bir şey açıldı" cinematics for capabilities they
      // have not earned yet.
      await UnlockAnnouncer.markCurrentStateAnnounced(ref);
      if (!mounted) return;
      _refreshTip();
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

  /// Phase 135 + 136, extended in roadmap Phase 1 · sequenced
  /// post-return flow. Order matters for emotional beat sequencing:
  ///
  ///   1. Badge / level-up celebrations — "I unlocked something"
  ///   2. First-workout Pro invitation (non-pro only, 1+ workouts)
  ///   3. Contextual rating moment (ALL users — see [RatingTrigger])
  ///   4. Micro-survey, only if nothing above interrupted the user
  ///
  /// Each step is gated by its own persisted state so the sequence is
  /// idempotent and re-running the flow on a subsequent dashboard
  /// return doesn't replay anything the user already saw.
  ///
  /// Step 4's ordering is the important one: a survey never stacks on
  /// top of a rating ask or a celebration. At most ONE interruption per
  /// return to the dashboard, which is what keeps a growing set of
  /// prompts from degrading into nagging.
  Future<void> _runDashboardReturnFlow() async {
    final badgeJustUnlocked = await _maybeCelebrate();
    if (!mounted) return;

    // Roadmap Phase 4 (R1.3) · a capability arriving is a reward, and
    // rewards go before asks. If one fired, it is this visit's single
    // interruption: the Pro invitation, the rating ask and the survey
    // all wait for the next return. Handing someone a new capability
    // and immediately asking them to pay or rate would spend the
    // goodwill the moment just created.
    final announced = await UnlockAnnouncer.announceIfNeeded(
      context,
      ref,
      firstName:
          (ref.read(appPreferencesProvider).userMetrics?['name'] as String?)
              ?.trim(),
      streakDays: ref.read(currentStreakProvider),
    );
    if (!mounted || announced) return;

    final session = ref.read(workoutSessionProvider).value;
    if (session == null) return;
    final completed = session.days.where((d) => d.isCompleted).length;
    final isPro = ref.read(isProProvider);
    await ref.read(conversionMomentProvider).maybeShowFirstWorkoutProInvitation(
          context,
          completedDays: completed,
          isPro: isPro,
        );
    if (!mounted) return;

    final firedTrigger = await ref.read(ratingMomentProvider).maybeShow(
          context,
          ratingContext: RatingContext(
            completedDays: completed,
            currentStreak: ref.read(currentStreakProvider),
            badgeJustUnlocked: badgeJustUnlocked,
          ),
        );
    if (!mounted) return;
    if (firedTrigger != null || badgeJustUnlocked) return;

    await _maybeShowSurvey(completedDays: completed);
  }

  /// Roadmap Phase 1 (C8) · surface the next eligible micro-survey.
  /// Called only from the tail of [_runDashboardReturnFlow], so a
  /// survey can never appear on top of another prompt.
  Future<void> _maybeShowSurvey({required int completedDays}) async {
    final service = ref.read(surveyServiceProvider);
    final survey = service.pending(
      SurveyContext(
        completedDays: completedDays,
        daysSinceInstall: ref.read(appPreferencesProvider).daysSinceInstall,
      ),
    );
    if (survey == null) return;
    // Stamp before presenting — same idempotency contract as the
    // rating moment and the first-time AI scenes.
    await service.markShown(survey);
    if (!mounted) return;
    await showSurveySheet(context, survey: survey);
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
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [
                    AntrenmanTab(),
                    NutritionTab(),
                    GelisimTab(),
                    // Phase 14 · Community is index 3 so Profile stays
                    // last, which is where every app puts the account
                    // tab. Capability.tabIndex only names 1 and 2, so
                    // nothing in progressive disclosure moved; the
                    // tour's Profile step followed to slot 4.
                    CommunityScreen(embedded: true),
                    ProfileTab(),
                  ],
                ),
              ),
              // Roadmap Phase 2 (C28) · the tip slot. Sits between the
              // tab content and the nav so it reads as a system message
              // rather than part of whichever tab is showing, and never
              // covers content — it takes its own space or none at all.
              if (_tip != null)
                DiscoveryTipCard(
                  tip: _tip!,
                  onDismiss: () => _dismissTip(_tip!),
                  onAction: () {
                    final tip = _tip!;
                    AnalyticsService.instance.tipActioned(tipId: tip.id);
                    final route = tip.route;
                    if (route != null) context.push(route);
                  },
                ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomNav(
          index: _index,
          onChanged: _onTabChanged,
          targets: ref.read(tourTargetsProvider),
          visitedTabs: _visitedTabs,
          lockedTabs: _lockedTabs(),
        ),
      ),
    );
  }

  /// Returns `true` when at least one badge celebration was actually
  /// shown in this call. Roadmap Phase 1 uses that as the
  /// `badgeJustUnlocked` signal for [RatingTrigger.badgeUnlocked] — a
  /// rating ask that rides an existing celebration lands far better
  /// than one that arrives cold.
  Future<bool> _maybeCelebrate() async {
    if (!mounted || !_routeIsCurrent || _celebrating) return false;
    // Phase 57 · the PM specifically asked that badge unlocks ONLY
    // surface on the Gelişim (progress) tab. Holding the celebration
    // until the user lands there mirrors the rest of the badge UI
    // (badges grid + AI coach copy) which all live on Gelişim. If the
    // unlock happened off-tab, it stays in `unlockedBadgesProvider \
    // celebratedBadgesProvider` — the diff that drives this method
    // re-runs the moment the user switches to Gelişim (see
    // `_onTabChanged`).
    if (_index != _gelisimTabIndex) return false;
    final unlocked = ref.read(unlockedBadgesProvider);
    final pending = DashboardLogic.pendingBadgeCelebrations(
      unlocked,
      ref.read(celebratedBadgesProvider),
    );
    if (pending.isEmpty) {
      // Initialise celebrated set if it was null but no unlocks pending.
      if (ref.read(celebratedBadgesProvider) == null) {
        ref.read(celebratedBadgesProvider.notifier).setAll(unlocked);
      }
      return false;
    }
    var celebratedAny = false;
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
        celebratedAny = true;
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
    return celebratedAny;
  }

  void _onTabChanged(int newIndex) {
    final previous = _index;
    // Roadmap Phase 2 (C37 · P3) · retire the "new" dot and record the
    // first visit. Fire-and-forget: the write is a single prefs entry
    // and the dot is cosmetic, so a lost race just means one extra
    // frame with the dot still showing.
    unawaited(_recordTabVisit(newIndex));
    // Freemium (post-beta) · nutrition is no longer walled off at the tab.
    // Tapping Beslenme now opens a genuine free experience — the intro
    // scene + onboarding, the day's calorie/macro target, and the full
    // recipe library to browse. The premium wall appears *inside* the tab
    // on the high-value surfaces (the personalised daily plan + meal
    // tracking), which convert far better than a hard door does. Those
    // in-tab gates live in `nutrition_tab.dart` / `recipe_detail_screen.dart`.
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

  /// Roadmap Phase 4 (R1.3) · tab indices whose capability hasn't been
  /// introduced yet.
  ///
  /// A tab is only dimmed while EVERY capability living in it is still
  /// locked — Gelişim hosts three, and dimming it once the first has
  /// arrived would misrepresent a tab that now has real content.
  Set<int> _lockedTabs() {
    final state = ref.watch(disclosureStateProvider);
    final locked = <int>{};
    final unlockedTabs = <int>{};
    for (final capability in Capability.values) {
      final tab = capability.tabIndex;
      if (tab == null) continue;
      if (isUnlocked(capability, state)) {
        unlockedTabs.add(tab);
      } else {
        locked.add(tab);
      }
    }
    return locked.difference(unlockedTabs);
  }

  /// Roadmap Phase 2 · marks [index] visited and rebuilds the nav so the
  /// discovery dot disappears. No-op after the first visit.
  Future<void> _recordTabVisit(int index) async {
    final isFirst =
        await ref.read(appPreferencesProvider).markTabVisited(index);
    if (!isFirst || !mounted) return;
    AnalyticsService.instance.tabFirstVisit(tabIndex: index);
    setState(() => _visitedTabs = ref.read(appPreferencesProvider).visitedTabs);
    // A newly-visited tab can satisfy (or invalidate) a tip condition.
    _refreshTip();
  }

  /// Roadmap Phase 2 (C28) · recompute the dashboard tip slot.
  ///
  /// Suppressed while the one-shot tour is still pending, so the tip and
  /// the tour never compete for the user's attention on first run.
  void _refreshTip() {
    if (!mounted) return;
    final prefs = ref.read(appPreferencesProvider);
    // Roadmap Phase 4 (C7) · the tips engine is kill-switchable.
    if (!ref.read(featureFlagsProvider).isEnabled(FeatureFlag.contextualTips)) {
      if (_tip != null) setState(() => _tip = null);
      return;
    }
    if (!prefs.seenDashboardTour) {
      if (_tip != null) setState(() => _tip = null);
      return;
    }
    final session = ref.read(workoutSessionProvider).value;
    final completed = session?.days.where((d) => d.isCompleted).length ?? 0;
    final next = selectTip(
      context: TipContext(
        completedDays: completed,
        currentStreak: ref.read(currentStreakProvider),
        visitedTabs: prefs.visitedTabs,
        hasUsedCoach: prefs.hasChattedWithCoach,
        nutritionOnboarded: prefs.hasCompletedNutritionPrefs,
        daysSinceInstall: prefs.daysSinceInstall,
        // Roadmap Phase 4 · a session that exists but isn't complete is
        // one the user walked away from.
        pausedMidWorkout: session != null &&
            !session.isSessionComplete &&
            session.currentReps > 0,
        manualModeUser: prefs.preferredWorkoutMode == WorkoutMode.manual,
      ),
      dismissedIds: prefs.dismissedTipIds,
      lastShownAt: prefs.lastTipShownAt,
      now: DateTime.now(),
      currentTipId: _tip?.id,
    );
    if (next?.id == _tip?.id) return;
    setState(() => _tip = next);
    if (next != null) {
      AnalyticsService.instance.tipShown(tipId: next.id);
      // Stamped only when a NEW tip actually surfaces, so the cap
      // measures gaps between tips rather than time since the last
      // rebuild.
      unawaited(prefs.markTipShownNow());
    }
  }

  Future<void> _dismissTip(DiscoveryTip tip) async {
    AnalyticsService.instance.tipDismissed(tipId: tip.id);
    await ref.read(appPreferencesProvider).markTipDismissed(tip.id);
    if (!mounted) return;
    setState(() => _tip = null);
    // Another tip may now be the best match.
    _refreshTip();
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
  const _BottomNav({
    required this.index,
    required this.onChanged,
    required this.targets,
    required this.visitedTabs,
    required this.lockedTabs,
  });

  final int index;
  final ValueChanged<int> onChanged;

  /// Roadmap Phase 2 (C27) · carries [TourTargets.navBar], the single key
  /// the spotlight tour resolves nav-item rects from.
  final TourTargets targets;

  /// Tabs already opened at least once. Anything absent gets a dot.
  final Set<int> visitedTabs;

  /// Roadmap Phase 4 (R1.3) · tabs whose capability hasn't been
  /// introduced yet.
  ///
  /// These render at reduced opacity and **remain fully tappable**. The
  /// roadmap is explicit that locked never means blocked — that pattern
  /// is reserved for Pro. A dimmed-but-working tab says "there's
  /// something here you haven't met"; a disabled one says "you may not",
  /// and only one of those is true.
  final Set<int> lockedTabs;

  @override
  Widget build(BuildContext context) {
    // Phase 14 · rebuilt as a custom bar when Community made it five
    // items.
    //
    // WHY NOT JUST ADD A FIFTH `BottomNavigationBarItem`
    //
    // `BottomNavigationBarType.fixed` shows every label all the time.
    // Four items on a 360 dp phone give each 90 dp, which "Antrenman"
    // fits at 12 px. Five give 72 dp, which it does not — and the
    // pseudo-locale sweep pushes it further. The options were to shrink
    // the type until it stopped looking premium, or to stop showing
    // five labels at once.
    //
    // So the label belongs to the selected item only, inside a tinted
    // pill that grows into place. One label at a time cannot crowd, the
    // selected tab reads at a glance, and the bar gets quieter rather
    // than busier as it gains a destination.
    //
    // WHAT IS PRESERVED ON PURPOSE
    //
    //   * Colours still come from `bottomNavigationBarTheme`, so light
    //     mode keeps working without a second palette.
    //   * Every slot is an `Expanded`, so the equal-slice arithmetic in
    //     `TourTargets.navItemRect` is still correct — the tour would
    //     silently spotlight the wrong tab otherwise.
    //   * The discovery dot and the reduced-opacity locked state are
    //     unchanged, including that a locked tab stays tappable.
    //   * The label is hidden visually, never semantically: each slot
    //     carries a `Semantics` label at all times, so a screen reader
    //     announces "Community, tab 4 of 5" whether or not the pill is
    //     showing.
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final items = <({IconData icon, IconData active, String label})>[
      (
        icon: Icons.fitness_center_outlined,
        active: Icons.fitness_center,
        label: l10n.navWorkout,
      ),
      (
        icon: Icons.restaurant_outlined,
        active: Icons.restaurant,
        label: l10n.navNutrition,
      ),
      (
        icon: Icons.insights_outlined,
        active: Icons.insights,
        label: l10n.navProgress,
      ),
      (
        icon: Icons.groups_outlined,
        active: Icons.groups,
        label: l10n.navCommunity,
      ),
      (
        icon: Icons.person_outline,
        active: Icons.person,
        label: l10n.navProfile,
      ),
    ];
    assert(
      items.length == kBottomNavItemCount,
      'the tour slices the bar into $kBottomNavItemCount slots',
    );

    return DecoratedBox(
      key: targets.navBar,
      // Hairline border above the nav so the strip reads as a distinct
      // surface even when its background and the scaffold both land on
      // near-white tones in light mode.
      decoration: BoxDecoration(
        color: navTheme.backgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Padding(
            // So the first and last pills do not kiss the screen edge.
            // Without it the selected pill on slot 0 renders flush to
            // x=0, which the device walk caught immediately.
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavSlot(
                      icon: items[i].icon,
                      activeIcon: items[i].active,
                      label: items[i].label,
                      position: i + 1,
                      total: items.length,
                      selected: i == index,
                      locked: lockedTabs.contains(i),
                      unvisited:
                          !visitedTabs.contains(i) && !lockedTabs.contains(i),
                      selectedColor:
                          navTheme.selectedItemColor ?? AppColors.neon,
                      unselectedColor:
                          navTheme.unselectedItemColor ?? scheme.outline,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One slot in the bottom navigation.
///
/// Collapsed to an icon until it is selected, at which point the label
/// slides out beside it inside a tinted pill. The animation is driven by
/// `AnimatedSize` + `AnimatedOpacity` rather than a controller because
/// there is no state to own beyond "is this the current tab", and both
/// honour `MediaQuery.disableAnimations` through the app's global
/// motion settings.
class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.position,
    required this.total,
    required this.selected,
    required this.locked,
    required this.unvisited,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int position;
  final int total;
  final bool selected;
  final bool locked;
  final bool unvisited;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    // A locked tab is dimmed and still tappable — the roadmap is
    // explicit that locked never means blocked, which is reserved for
    // Pro.
    final opacity = locked ? 0.45 : 1.0;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    // A locked tab deliberately gets no dot: the dot means "new, go
    // look", which is the opposite of what disclosure is saying about
    // it. `unvisited` is computed with that already excluded.
    Widget glyph = Icon(selected ? activeIcon : icon, color: color, size: 24);
    if (unvisited) {
      glyph = Badge(
        backgroundColor: AppColors.neon,
        smallSize: 8,
        child: glyph,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      value: MaterialLocalizations.of(context).tabLabel(
        tabIndex: position,
        tabCount: total,
      ),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Opacity(
              opacity: opacity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The capsule sits behind the icon rather than around
                  // icon-and-label, because a pill wide enough to hold
                  // both does not fit one fifth of a 411 dp screen — the
                  // device walk proved that by truncating "Training" to
                  // "Trai". Highlighting the icon alone gives the same
                  // "this one is selected" read in the width available.
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: 46,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? selectedColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: glyph,
                  ),
                  const SizedBox(height: 3),
                  // FittedBox rather than a smaller hardcoded size: the
                  // longest label decides, and it is different in every
                  // locale. Scaling down beats an ellipsis on a word
                  // that is the only text identifying the tab.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
