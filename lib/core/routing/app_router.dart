import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/workout/presentation/workout_camera_screen.dart';
import '../services/app_preferences.dart';

class AppRoutes {
  const AppRoutes._();
  static const String dashboard = '/';
  static const String onboarding = '/onboarding';
  static const String workout = '/workout';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return GoRouter(
    initialLocation:
        prefs.isFirstTime ? AppRoutes.onboarding : AppRoutes.dashboard,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final onboarded = !prefs.isFirstTime;
      if (!onboarded && path != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (onboarded && path == AppRoutes.onboarding) {
        return AppRoutes.dashboard;
      }
      return null;
    },
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
        path: AppRoutes.workout,
        name: 'workout',
        builder: (context, state) => const WorkoutCameraScreen(),
      ),
    ],
  );
});
