import 'package:go_router/go_router.dart';
import 'package:shorebird_console/data/auth_storage.dart';
import 'package:shorebird_console/features/apps/presentation/screens/app_detail_screen.dart';
import 'package:shorebird_console/features/apps/presentation/screens/dashboard_screen.dart';
import 'package:shorebird_console/features/auth/presentation/screens/login_screen.dart';
import 'package:shorebird_console/features/auth/presentation/screens/register_screen.dart';
import 'package:shorebird_console/features/organizations/presentation/screens/org_detail_screen.dart';
import 'package:shorebird_console/features/organizations/presentation/screens/organizations_screen.dart';
import 'package:shorebird_console/features/releases/presentation/screens/release_detail_screen.dart';
import 'package:shorebird_console/shared/widgets/shell_screen.dart';

GoRouter createRouter(IAuthStorage authStorage) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authStorage.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/';
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
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
            routes: [
              GoRoute(
                path: 'apps/:appId',
                builder: (context, state) => AppDetailScreen(
                  appId: state.pathParameters['appId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'releases/:releaseId',
                    builder: (context, state) => ReleaseDetailScreen(
                      appId: state.pathParameters['appId']!,
                      releaseId: int.parse(
                        state.pathParameters['releaseId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/organizations',
            builder: (context, state) => const OrganizationsScreen(),
            routes: [
              GoRoute(
                path: ':orgId',
                builder: (context, state) => OrgDetailScreen(
                  orgId: int.parse(state.pathParameters['orgId']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
