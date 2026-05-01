import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/account_settings_screen.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/monetization/presentation/paywall_screen.dart';
import '../../features/nutrition/domain/models/recipe.dart';
import '../../features/nutrition/presentation/category_recipes_screen.dart';
import '../../features/nutrition/presentation/discover_recipes_screen.dart';
import '../../features/nutrition/presentation/favorites_screen.dart';
import '../../features/nutrition/presentation/recipe_detail_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/prediction_screen.dart';
import '../../features/progress/presentation/badges_screen.dart';
import '../../features/progress/presentation/calendar_screen.dart';
import '../../features/progress/presentation/suggestions_screen.dart';
import '../../features/progress/providers/badge_unlocks_provider.dart';
import '../../features/referral/presentation/referral_landing_screen.dart';
import '../../features/workout/models/workout_plan_model.dart';
import '../../features/workout/presentation/plan_detail_screen.dart';
import '../../features/workout/presentation/workout_camera_screen.dart';
import '../services/app_preferences.dart';

class AppRoutes {
  const AppRoutes._();
  static const String dashboard = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String workout = '/workout';
  static const String paywall = '/paywall';
  static const String prediction = '/prediction';
  static const String planDetail = '/plan-detail';
  static const String accountSettings = '/account-settings';

  /// `/recipe` — full recipe detail view. Callers push with
  /// `context.push('/recipe', extra: recipe)`; the route unpacks
  /// `state.extra as Recipe`.
  static const String recipeDetail = '/recipe';

  // Phase 47A · dedicated screens that Phase 40 temporarily hid
  // because their destination didn't yet exist.
  static const String progressCalendar = '/progress/calendar';
  static const String progressSuggestions = '/progress/suggestions';
  static const String progressBadges = '/progress/badges';
  static const String nutritionDiscover = '/nutrition/discover';

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
      return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return path == AppRoutes.auth ? null : AppRoutes.auth;
    }
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
      GoRoute(
        path: AppRoutes.paywall,
        name: 'paywall',
        builder: (context, state) => const PaywallScreen(),
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
          'FormAI',
          style: TextStyle(
            color: Color(0xFF00F0FF),
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(blurRadius: 24, color: Color(0xFF00F0FF))],
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
                'Davet bağlantısı eksik.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Ana ekrana dön'),
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
              const Text(
                'Tarif bulunamadı.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Ana ekrana dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
