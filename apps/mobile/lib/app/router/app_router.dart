import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/auth_state.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/committees/presentation/create_committee_screen.dart';
import '../../features/committees/presentation/committee_dashboard_screen.dart';
import '../../features/members/presentation/member_statement_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

GoRouter createRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authState,
    redirect: (BuildContext context, GoRouterState state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isLoggedIn = authState.isAuthenticated;

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: '/committees/create',
        builder: (context, state) => const CreateCommitteeScreen(),
      ),
      GoRoute(
        path: '/committees/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CommitteeDashboardScreen(committeeId: id);
        },
      ),
      GoRoute(
        path: '/committees/:committeeId/members/:memberId/statement',
        builder: (context, state) {
          final committeeId = state.pathParameters['committeeId']!;
          final memberId = state.pathParameters['memberId']!;
          return MemberStatementScreen(
            committeeId: committeeId,
            memberId: memberId,
          );
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
