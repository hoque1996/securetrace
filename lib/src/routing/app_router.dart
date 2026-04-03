import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/register_screen.dart';
import 'scaffold_with_nav_bar.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import '../features/control_panel/presentation/control_panel_screen.dart';
import '../features/device_connect/presentation/qr_generate_screen.dart';
import '../features/device_connect/presentation/qr_scan_screen.dart';
import '../features/permissions/presentation/permissions_rationale_screen.dart';
import '../features/backup/presentation/backup_screen.dart';
import '../features/activity/presentation/activity_feed_screen.dart';
import '../features/geofencing/presentation/geofence_settings_screen.dart';
import '../features/cctv/presentation/cctv_streamer_screen.dart';
import '../features/cctv/presentation/cctv_viewer_screen.dart';
import '../features/ai_analysis/presentation/ai_scanner_screen.dart';
import '../features/intruder_detection/presentation/intruder_overlay_screen.dart';
import '../features/intruder_detection/presentation/face_enrollment_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/setup/permissions',
    redirect: (context, state) {
      if (authState.isLoading || authState.hasError) return null;
      
      final user = authState.value;
      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/register';

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute) {
        return '/setup/permissions';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/setup/permissions',
        builder: (context, state) => const PermissionsRationaleScreen(),
      ),
      GoRoute(
        path: '/connect/scan',
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/connect/generate',
        builder: (context, state) => const QrGenerateScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const TrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/control',
                builder: (context, state) => const ControlPanelScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/backup',
                builder: (context, state) => const BackupScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/geofence',
        builder: (context, state) => const GeofenceSettingsScreen(),
      ),
      GoRoute(
        path: '/cctv-broadcast',
        builder: (context, state) => const CCTVStreamerScreen(),
      ),
      GoRoute(
        path: '/cctv-view',
        builder: (context, state) => const CCTVViewerScreen(),
      ),
      GoRoute(
        path: '/ai-vision',
        builder: (context, state) => const AIScannerScreen(),
      ),
      GoRoute(
        path: '/intruder-capture',
        builder: (context, state) => const IntruderOverlayScreen(),
      ),
      GoRoute(
        path: '/enroll-face',
        builder: (context, state) => const FaceEnrollmentScreen(),
      ),
    ],
  );
});
