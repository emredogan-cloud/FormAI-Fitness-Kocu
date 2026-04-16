import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/monetization/presentation/paywall_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/workout/presentation/workout_camera_screen.dart';
import '../services/app_preferences.dart';

class AppRoutes {
  const AppRoutes._();
  static const String dashboard = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String workout = '/workout';
  static const String paywall = '/paywall';
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
    if (path == AppRoutes.auth || path == AppRoutes.onboarding) {
      return AppRoutes.dashboard;
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
    ],
  );
});
