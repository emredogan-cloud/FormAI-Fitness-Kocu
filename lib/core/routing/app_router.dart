import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/account_settings_screen.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/monetization/presentation/paywall_screen.dart';
import '../../features/nutrition/presentation/recipe_detail_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/prediction_screen.dart';
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

  /// `/recipe/:id` — full recipe detail view. Pass the recipe's primary
  /// key from Supabase as the `id` path param.
  static const String recipeDetail = '/recipe';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  final refreshListenable = ref.watch(authRefreshListenableProvider);

  String? redirect(path) {
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
    return null;
  }

  return GoRouter(
    initialLocation: redirect(AppRoutes.dashboard) ?? AppRoutes.dashboard,
    refreshListenable: refreshListenable,
    redirect: (context, state) => redirect(state.matchedLocation),
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
        path: '/recipe/:id',
        name: 'recipeDetail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RecipeDetailScreen(recipeId: id);
        },
      ),
    ],
  );
});
