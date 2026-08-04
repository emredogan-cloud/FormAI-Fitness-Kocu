import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/coach/presentation/coach_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/feedback/presentation/help_center_screen.dart';
import '../../features/home/presentation/account_settings_screen.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/home/domain/content_freshness.dart';
import '../../features/home/presentation/discovery_hub_screen.dart';
import '../../features/home/presentation/whats_new_screen.dart';
import '../../features/workout/presentation/program_continuation_screen.dart';
import '../../features/monetization/presentation/paywall_screen.dart';
import '../../features/nutrition/domain/models/recipe.dart';
import '../../features/nutrition/presentation/category_recipes_screen.dart';
import '../../features/nutrition/presentation/discover_recipes_screen.dart';
import '../../features/nutrition/presentation/favorites_screen.dart';
import '../../features/nutrition/presentation/recipe_detail_screen.dart';
import '../../features/onboarding/presentation/age_gate_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/feature_showcase_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/prediction_screen.dart';
import '../../features/progress/presentation/badges_screen.dart';
import '../../features/progress/presentation/body_metrics_screen.dart';
import '../../features/progress/presentation/outcome_report_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/friends_screen.dart';
import '../../features/community/presentation/challenges_screen.dart';
import '../../features/community/presentation/leaderboard_screen.dart';
import '../../features/community/presentation/squad_screen.dart';
import '../../features/progress/presentation/photo_gallery_screen.dart';
import '../../features/progress/presentation/calendar_screen.dart';
import '../../features/progress/presentation/suggestions_screen.dart';
import '../../features/progress/providers/badge_unlocks_provider.dart';
import '../../features/referral/presentation/referral_landing_screen.dart';
import '../../features/workout/domain/workout_mode.dart';
import '../../features/workout/models/workout_plan_model.dart';
import '../../features/workout/presentation/camera_tutorial_screen.dart';
import '../../features/workout/presentation/manual_workout_screen.dart';
import '../../features/workout/presentation/plan_detail_screen.dart';
import '../../features/workout/presentation/workout_camera_screen.dart';
import '../../l10n/app_localizations.dart';
import '../services/app_preferences.dart';

class AppRoutes {
  const AppRoutes._();
  static const String dashboard = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';

  /// Phase 138 · B-4. 18+ verification gate. The router routes a fresh
  /// install here BEFORE `/onboarding` whenever
  /// [AppPreferences.ageVerified] is false; once the user picks a
  /// birth year that yields age ≥ 18 the flag flips and subsequent
  /// loads bypass the gate. Sub-18 entries see a non-dismissable
  /// block screen and `SystemNavigator.pop()` returns them to the
  /// launcher. Legacy installs that already completed onboarding
  /// (`isFirstTime=false`) skip the gate entirely.
  static const String ageGate = '/age-gate';

  /// Phase 138 · H-2. KVKK / GDPR consent screen. Sits between
  /// `/age-gate` and `/onboarding` so the user explicitly opts into
  /// (or out of) anonymous analytics and crash reporting BEFORE any
  /// PostHog event fires or Sentry forwards a crash.
  static const String consent = '/consent';
  static const String workout = '/workout';
  static const String paywall = '/paywall';
  static const String prediction = '/prediction';
  static const String planDetail = '/plan-detail';
  static const String accountSettings = '/account-settings';
  static const String coach = '/coach';

  /// `/recipe` — full recipe detail view. Callers push with
  /// `context.push('/recipe', extra: recipe)`; the route unpacks
  /// `state.extra as Recipe`.
  static const String recipeDetail = '/recipe';

  // Phase 47A · dedicated screens that Phase 40 temporarily hid
  // because their destination didn't yet exist.
  static const String progressCalendar = '/progress/calendar';
  static const String progressSuggestions = '/progress/suggestions';
  static const String progressBadges = '/progress/badges';

  /// Roadmap Phase 9 (C1) · weight and tape measurements over time.
  static const String progressBody = '/progress/body';

  /// Roadmap Phase 10 (C4, C39) · the 30-day outcome report.
  static const String progressReport = '/progress/report';

  /// Roadmap Phase 10 (C2) · progress photos. The images never leave the
  /// device; see `ProgressPhotoRepository`.
  static const String progressPhotos = '/progress/photos';

  /// Roadmap Phase 12 (R6, C24) · identity, friends and squads. Opt-in
  /// throughout; renders "not switched on yet" until `019` is applied.
  static const String community = '/community';

  /// Roadmap Phase 12 (C22) · friends, and the block/report controls.
  static const String communityFriends = '/community/friends';

  /// Roadmap Phase 12 (C22) · squads and their activity feeds.
  static const String communitySquads = '/community/squads';

  /// Roadmap Phase 13 · under `/community` because a leaderboard is a
  /// comparison between people and belongs with the identity layer that
  /// makes those people nameable.
  static const String communityLeaderboard = '/community/leaderboard';
  static const String communityChallenges = '/community/challenges';
  static const String nutritionDiscover = '/nutrition/discover';

  /// Phase 14 · the post-update changelog. Pushed automatically by the
  /// dashboard when there is an unread note, and reachable directly so
  /// somebody who dismissed it can go back and look — Phase 13 learned
  /// that a route nothing links to is not a route.
  static const String whatsNew = '/whats-new';

  /// Phase 14 · day 31. Reached from the program-complete card on the
  /// Progress tab, which is the only place the app knows a program just
  /// ended.
  static const String programContinuation = '/program/continue';

  /// Phase 50B · internal admin panel. Gated by [isAdminProvider]; the
  /// router redirects non-admins to [dashboard] before the screen is
  /// ever instantiated, so this path is invisible to regular users.
  static const String admin = '/admin';

  /// Phase 54 · landing screen for incoming referral deep-links.
  /// `formai://r/<code>` and `https://formai.app/r/<code>` both resolve
  /// here via [DeepLinkService]. The screen reads `?code=` from
  /// `state.uri.queryParameters` so the redirect rule below can pass
  /// the code through without losing it.
  static const String referralLanding = '/referral';

  /// Phase 56 Lite · "Favorilerim" — saved recipes hub with
  /// shopping-list export. Reached from a Profile-tab tile.
  static const String nutritionFavorites = '/nutrition/favorites';

  /// Roadmap Phase 1 (C30) · searchable FAQ / help centre. Reached from
  /// the AYARLAR section of the Profile tab, directly above the
  /// feedback row so it deflects tickets rather than competing with
  /// them.
  static const String helpCenter = '/help';

  /// Roadmap Phase 2 (R1.1) · one-shot post-paywall capability showcase.
  /// Not navigated to directly by any widget — the router's redirect
  /// interposes it between the paywall decision and the dashboard.
  static const String featureShowcase = '/showcase';

  /// Roadmap Phase 3 (R1.2 · C26) · guided camera setup + calibration.
  /// Interposed before the FIRST `/workout`; skipped forever after.
  static const String cameraTutorial = '/workout/tutorial';

  /// Roadmap Phase 3 feature 6 · the same guide, reopened on purpose from
  /// the workout overflow menu. `push`ed (not `go`ne to) so it returns
  /// the user to the session they left.
  static const String cameraTutorialReplay = '$cameraTutorial?replay=1';

  /// Roadmap Phase 3 (C21) · the camera-free workout surface.
  static const String manualWorkout = '/workout/manual';

  /// Roadmap Phase 4 (C28 · R1.3) · the capability map. Every feature
  /// FormAI has, with its locked/unlocked state and a one-tap override.
  static const String discoveryHub = '/discover';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final refreshListenable = ref.watch(authRefreshListenableProvider);
  // Phase 48.1 · register the global RouteObserver so DashboardScreen
  // can become RouteAware and learn when a pushed route (e.g. the
  // workout camera) pops back. The observer is owned by Riverpod so a
  // single instance is shared across the app's lifetime.
  final routeObserver = ref.watch(routeObserverProvider);

  String? redirect(path) {
    // Phase 54 · referral landing is the one surface that survives
    // both the first-time-install gate AND the auth gate. A fresh
    // install that arrives via a deep link has to see the invite copy
    // (and store the code) before being punted into onboarding;
    // similarly, an existing-but-signed-out user redeeming on a new
    // device should see the landing first so they know what they're
    // signing in for.
    if (path == AppRoutes.referralLanding) return null;
    if (prefs.isFirstTime) {
      // Phase 138 · B-4. Block PII-collecting onboarding until the user
      // has confirmed 18+. The age gate is its own route so the
      // wizard's step-counter math stays untouched and so a tester
      // can deep-link past it via `prefs.setAgeVerified` from devtools.
      if (!prefs.ageVerified) {
        return path == AppRoutes.ageGate ? null : AppRoutes.ageGate;
      }
      // Phase 138 · H-2. Once age is verified but consent has not
      // yet been decided, route to /consent. PostHog has been
      // disabled at boot when consent was missing, and Sentry's
      // beforeSend is dropping events — onboarding analytics can
      // resume cleanly the moment the user opts in.
      if (!prefs.consentDecisionMade) {
        return path == AppRoutes.consent ? null : AppRoutes.consent;
      }
      return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }
    // Phase 88 · gate on `currentSession`, not `currentUser`. Both are
    // sourced from the same persisted Hive box, but `currentSession`
    // also covers the "access token expired and refresh failed (network
    // down)" edge — Supabase keeps the session row in cache so the
    // redirect doesn't bounce an offline user to /auth just because the
    // /auth/v1/token round-trip failed. `session.user` is then the same
    // identity object the rest of this redirect needs (anonymous flag,
    // app_metadata claim, etc.).
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return path == AppRoutes.auth ? null : AppRoutes.auth;
    }
    final user = session.user;
    // First-time anon sign-in lands users at /onboarding momentarily before
    // we punt them to the prediction hook. A *registered* user who hits
    // /auth has nothing to do there and gets forwarded to the paywall;
    // an *anonymous* user hitting /auth is explicitly trying to upgrade
    // (e.g. via the profile tab's "Üye Ol / Giriş Yap" tile), so we must
    // let them through.
    if (path == AppRoutes.onboarding) {
      return AppRoutes.prediction;
    }
    if (path == AppRoutes.auth) {
      return user.isAnonymous ? null : AppRoutes.paywall;
    }
    // Phase 50B · admin panel. Reads `app_metadata.role` directly off the
    // current Supabase user (not via Riverpod) because this redirect runs
    // before the widget tree is even mounted. Any non-admin (anonymous,
    // regular signed-in user, missing claim) is silently bounced to the
    // dashboard — the path stays invisible to the rest of the app.
    if (path == AppRoutes.admin) {
      final role = user.appMetadata['role'];
      final isAdmin = role is String && role == 'admin';
      return isAdmin ? null : AppRoutes.dashboard;
    }
    // Roadmap Phase 3 (R1.2 · C21) · route the workout entry point.
    //
    // Two interceptions, both here rather than at the ~6 widgets that
    // push `/workout`:
    //   1. First ever workout → the guided camera setup, so nobody meets
    //      pose detection by failing at it.
    //   2. A user who chose the camera-free path → the manual surface.
    // Both are skipped once the tutorial is done and the mode is camera.
    if (path == AppRoutes.workout) {
      if (!prefs.cameraTutorialCompleted) return AppRoutes.cameraTutorial;
      if (prefs.preferredWorkoutMode == WorkoutMode.manual) {
        return AppRoutes.manualWorkout;
      }
      return null;
    }

    // Roadmap Phase 2 (R1.1) · one-shot capability showcase between the
    // paywall decision and the dashboard.
    //
    // Intercepted HERE rather than at the paywall's three `context.go('/')`
    // exits, for two reasons: (1) those exits sit inside RevenueCat
    // purchase / entitlement-listener code that earlier phases
    // deliberately keep byte-untouched, and (2) one redirect covers every
    // path to the dashboard — purchase success, explicit dismiss, and the
    // Pro self-redirect — without three chances to get it wrong.
    //
    // Only fires for a user who has finished onboarding and is signed in
    // (both already true at this point in the function), so a returning
    // user with the flag set never sees it, and a guest reaching the
    // dashboard via the auth-gate escape gets it exactly once.
    if (path == AppRoutes.dashboard && !prefs.seenFeatureShowcase) {
      return AppRoutes.featureShowcase;
    }
    // Never bounce off the showcase once it's the target; the screen
    // itself flips the flag and `go`s to the dashboard.
    if (path == AppRoutes.featureShowcase) return null;
    return null;
  }

  return GoRouter(
    initialLocation: redirect(AppRoutes.dashboard) ?? AppRoutes.dashboard,
    refreshListenable: refreshListenable,
    observers: [routeObserver],
    redirect: (context, state) => redirect(state.matchedLocation),
    // Phase 57 · branded splash instead of the default
    // "Page Not Found" black-on-white error screen. A widget tap
    // can race the router on cold start and briefly land on an
    // unmatched route while DeepLinkService is still resolving the
    // initial link; this builder makes that intermediate frame look
    // like a deliberate splash rather than a 404, and self-recovers
    // by punting the user to the dashboard after a short beat.
    errorBuilder: (context, state) => const _DeepLinkSplashScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Phase 138 · B-4 18+ verification gate. Routed to by the
      // redirect above whenever a first-time install hasn't yet
      // confirmed age. The screen owns its own block-and-exit copy
      // for under-18 entries; the redirect never bounces a user off
      // this path until the flag flips.
      GoRoute(
        path: AppRoutes.ageGate,
        name: 'ageGate',
        builder: (context, state) => const AgeGateScreen(),
      ),
      // Phase 138 · H-2 consent screen.
      GoRoute(
        path: AppRoutes.consent,
        name: 'consent',
        builder: (context, state) => const ConsentScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.workout,
        name: 'workout',
        builder: (context, state) => const WorkoutCameraScreen(),
      ),
      // Phase 57 · path alias for the Phase 55 widget / Live-Activity
      // deep link `formai://workout/today`. When Flutter's
      // platform-side routeInformation channel feeds GoRouter directly
      // (as it does on Android cold-start before our `app_links`
      // listener has a chance to intercept), the path arrives as
      // `/workout/today` — unmatched, GoRouter previously rendered its
      // default error page for ~500 ms. Registering the alias makes it
      // resolve cleanly on first paint; the DeepLinkService listener
      // is now belt-and-braces.
      GoRoute(
        path: '/workout/today',
        name: 'workoutToday',
        redirect: (_, __) => AppRoutes.workout,
      ),
      // Phase 142 · explicit fade transition for the paywall route.
      //
      // The default MaterialPage transition is a slide animation that
      // exposes whatever the new screen paints on its first frame.
      // PaywallScreen's first frame is heavy (cinematic backdrop with
      // 5 image layers + gradients + an animation controller), so the
      // slide visibly stutters as it waits on that first paint. Swap
      // to a 280 ms fade — the eye reads a fade as a deliberate
      // "settling-in" gesture instead of a janky slide, and the fade's
      // alpha ramp visually masks the first-frame paint cost. No
      // routing logic touched; only the transition's visual style.
      GoRoute(
        path: AppRoutes.paywall,
        name: 'paywall',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const PaywallScreen(),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.prediction,
        name: 'prediction',
        builder: (context, state) => const PredictionScreen(),
      ),
      GoRoute(
        path: AppRoutes.planDetail,
        name: 'planDetail',
        builder: (context, state) {
          // The dashboard's regional plan tiles push us with a WorkoutPlan
          // attached as `extra`; the daily-challenge hero card pushes us
          // with no extra and falls through to the legacy 30-day program
          // view. Anything else goes to the program view too.
          final extra = state.extra;
          return PlanDetailScreen(
            plan: extra is WorkoutPlan ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        name: 'accountSettings',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.coach,
        name: 'coach',
        builder: (context, state) => const CoachScreen(),
      ),
      GoRoute(
        path: AppRoutes.recipeDetail,
        name: 'recipeDetail',
        builder: (context, state) {
          // Callers push the full Recipe object via `extra:` so the
          // detail screen doesn't need a second round-trip to the
          // catalogue to render. Unexpected `extra` types fall back to
          // the dashboard rather than crashing.
          final extra = state.extra;
          if (extra is Recipe) {
            return RecipeDetailScreen(recipe: extra);
          }
          return const _MissingRecipe();
        },
      ),
      GoRoute(
        path: '/nutrition/category/:type',
        name: 'nutritionCategory',
        builder: (context, state) {
          // `type` is the English meal-type token (breakfast / lunch /
          // dinner / snack / dessert) or the Phase 83 `'budget'`
          // sentinel. The screen itself is tolerant of unknown values
          // and shows an empty state rather than crashing.
          //
          // Phase 83 dashboard expansion · the optional `?meal=<token>`
          // query parameter narrows the budget bucket to a single
          // meal_type. Only consulted by the screen when `type` is
          // `'budget'`; ignored for the five canonical categories
          // (where meal_type is already the primary filter).
          final type = state.pathParameters['type'] ?? 'breakfast';
          final subFilter = state.uri.queryParameters['meal'];
          return CategoryRecipesScreen(
            categoryType: type,
            mealTypeSubFilter: subFilter,
          );
        },
      ),
      // Phase 47A · progress + discovery surfaces.
      GoRoute(
        path: AppRoutes.progressCalendar,
        name: 'progressCalendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressSuggestions,
        name: 'progressSuggestions',
        builder: (context, state) => const SuggestionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressBadges,
        name: 'progressBadges',
        builder: (context, state) => const BadgesScreen(),
      ),
      // Roadmap Phase 9 (C1, C3) · body metrics and trends.
      GoRoute(
        path: AppRoutes.progressBody,
        name: 'progressBody',
        builder: (context, state) => const BodyMetricsScreen(),
      ),
      // Roadmap Phase 10 (C4, C39) · the 30-day outcome report.
      GoRoute(
        path: AppRoutes.progressReport,
        name: 'progressReport',
        builder: (context, state) => const OutcomeReportScreen(),
      ),
      // Roadmap Phase 10 (C2) · progress photos.
      GoRoute(
        path: AppRoutes.progressPhotos,
        name: 'progressPhotos',
        builder: (context, state) => const PhotoGalleryScreen(),
      ),
      // Roadmap Phase 12 (R6, C24) · community.
      GoRoute(
        path: AppRoutes.community,
        name: 'community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityFriends,
        name: 'communityFriends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: AppRoutes.communitySquads,
        name: 'communitySquads',
        builder: (context, state) => const SquadScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityLeaderboard,
        name: 'communityLeaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityChallenges,
        name: 'communityChallenges',
        builder: (context, state) => const ChallengesScreen(),
      ),
      GoRoute(
        path: AppRoutes.programContinuation,
        name: 'programContinuation',
        builder: (context, state) => const ProgramContinuationScreen(),
      ),
      GoRoute(
        path: AppRoutes.whatsNew,
        name: 'whatsNew',
        // `extra` is the release the dashboard already resolved. Null
        // when the route is opened directly, which the screen renders as
        // "nothing new right now" rather than treating as an error.
        builder: (context, state) =>
            WhatsNewScreen(release: state.extra as ContentRelease?),
      ),
      GoRoute(
        path: AppRoutes.nutritionDiscover,
        name: 'nutritionDiscover',
        builder: (context, state) => const DiscoverRecipesScreen(),
      ),
      // Phase 56 Lite · favourites hub.
      GoRoute(
        path: AppRoutes.nutritionFavorites,
        name: 'nutritionFavorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      // Roadmap Phase 1 (C30) · help centre / FAQ.
      GoRoute(
        path: AppRoutes.helpCenter,
        name: 'helpCenter',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      // Roadmap Phase 2 (R1.1) · post-paywall capability showcase.
      GoRoute(
        path: AppRoutes.featureShowcase,
        name: 'featureShowcase',
        builder: (context, state) => const FeatureShowcaseScreen(),
      ),
      // Roadmap Phase 3 (R1.2) · guided camera setup.
      //
      // Declared as a sibling of `/workout`, not a child. GoRouter
      // matches full paths for non-nested routes, so `/workout` does not
      // shadow `/workout/tutorial` regardless of declaration order — the
      // same way the existing `/workout/today` alias already coexists.
      GoRoute(
        path: AppRoutes.cameraTutorial,
        name: 'cameraTutorial',
        // Roadmap Phase 3 feature 6 · `?replay=1` marks a visit from the
        // workout overflow menu. A replay returns the user where they
        // came from instead of launching a workout, and skips the
        // practice rep they have already done.
        builder: (context, state) => CameraTutorialScreen(
          replay: state.uri.queryParameters['replay'] == '1',
        ),
      ),
      // Roadmap Phase 3 (C21) · camera-free workout.
      GoRoute(
        path: AppRoutes.manualWorkout,
        name: 'manualWorkout',
        builder: (context, state) => const ManualWorkoutScreen(),
      ),
      // Roadmap Phase 4 (C28) · the capability map.
      //
      // Deliberately NOT gated on `FeatureFlag.discoveryHub`: the flag
      // hides the *entry points*, but a route that 404s when a flag
      // flips would break any deep link or back-stack entry created
      // while it was on.
      GoRoute(
        path: AppRoutes.discoveryHub,
        name: 'discoveryHub',
        builder: (context, state) => const DiscoveryHubScreen(),
      ),
      // Phase 50B · admin panel. The redirect above already forces
      // non-admins to /, so the builder can render unconditionally.
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      // Phase 54 · referral landing. Reachable via deep link
      // (`formai://r/<code>`) or in-app navigation. Code arrives as
      // `?code=ABCDEF`; missing code falls back to the dashboard so a
      // malformed link never strands the user on a blank screen.
      GoRoute(
        path: AppRoutes.referralLanding,
        name: 'referralLanding',
        builder: (context, state) {
          final code = state.uri.queryParameters['code']?.toUpperCase();
          if (code == null || code.isEmpty) {
            return const _MissingReferralCode();
          }
          return ReferralLandingScreen(code: code);
        },
      ),
    ],
  );
});

/// Phase 57 · neutral splash rendered as the GoRouter `errorBuilder`.
///
/// Reached when:
///   • A deep-link path arrives that doesn't match any registered
///     route (e.g. a future widget version pushes a path the current
///     build doesn't yet know about).
///   • The platform feeds an unmatched URI to Flutter's route
///     information provider on cold start, before our app_links
///     listener has had a chance to intercept it.
///
/// Self-recovers by deferring a `context.go(dashboard)` until the
/// next frame so the user never gets stuck on this screen — the
/// brief paint reads as a launch splash rather than a 404.
class _DeepLinkSplashScreen extends StatefulWidget {
  const _DeepLinkSplashScreen();

  @override
  State<_DeepLinkSplashScreen> createState() => _DeepLinkSplashScreenState();
}

class _DeepLinkSplashScreenState extends State<_DeepLinkSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Two frames of buffer — one for layout, one to give the
    // app_links listener a chance to land its route(s) before we
    // overrule with a dashboard fallback. If the listener resolved
    // first the route changes, this widget tears down and the
    // post-frame callback's `go` becomes a no-op against the active
    // location. 200 ms is deliberately short so the user never
    // *waits* on this splash.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B12),
      body: Center(
        child: Text(
          'FormAI', // i18n-ignore — brand wordmark
          // Store-submission U7 · brand purple (matches the boot-splash
          // wordmark); this screen previously kept the retired cyan.
          style: TextStyle(
            color: Color(0xFF8E5BFF),
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 24, color: Color(0xFF8E5BFF))],
          ),
        ),
      ),
    );
  }
}

/// Phase 54 · fallback for `/referral` without `?code=...`. Surfaces a
/// polite "your link is broken" rather than letting the user land on
/// an empty screen — the share text always carries the code, so
/// hitting this means the link was truncated or hand-edited.
class _MissingReferralCode extends StatelessWidget {
  const _MissingReferralCode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.link_off,
                size: 56,
                color: Colors.white38,
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).routeInviteLinkMissing,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: Text(AppLocalizations.of(context).routeBackToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny fallback shown when someone navigates to `/recipe` without
/// actually attaching a [Recipe] to `state.extra`. Keeps the app from
/// crashing on a bad deep link without pulling in a whole error screen.
class _MissingRecipe extends StatelessWidget {
  const _MissingRecipe();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, color: Colors.white38, size: 56),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).routeRecipeNotFound,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: Text(AppLocalizations.of(context).routeBackToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
