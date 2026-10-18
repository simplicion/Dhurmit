import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/auth_state.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/auth_callback_screen.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/committees/presentation/create_committee_screen.dart';
import '../../features/committees/presentation/committee_dashboard_screen.dart';
import '../../features/members/presentation/member_statement_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

import 'startup_splash_screen.dart';

GoRouter createRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (BuildContext context, GoRouterState state) {
      // While initial AuthState is loading from local storage, keep user on StartupSplashScreen
      if (authState.isLoading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final isLoggingIn = state.matchedLocation == '/login';
      final isCallback = state.matchedLocation == '/auth/callback';
      final isSplash = state.matchedLocation == '/';
      final isLoggedIn = authState.isAuthenticated;
      final authCode = state.uri.queryParameters['code'];

      // If an authorization code is present in query parameters (e.g. from 180 OAuth redirect),
      // forward directly to callback handler
      if (authCode != null && authCode.isNotEmpty && !isCallback && !isLoggedIn) {
        return '/auth/callback?code=$authCode';
      }

      if (isSplash) {
        return isLoggedIn ? '/home' : '/login';
      }

      if (!isLoggedIn && !isLoggingIn && !isCallback) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    errorBuilder: (context, state) => const HomeDashboardScreen(),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const StartupSplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return AuthCallbackScreen(code: code);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeDashboardScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            redirect: (context, state) => '/settings',
          ),
          GoRoute(
            path: 'reports',
            redirect: (context, state) => '/reports',
          ),
        ],
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
