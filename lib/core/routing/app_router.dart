import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/workout/presentation/workout_camera_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const String dashboard = '/';
  static const String workout = '/workout';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.workout,
        name: 'workout',
        builder: (context, state) => const WorkoutCameraScreen(),
      ),
    ],
  );
});
