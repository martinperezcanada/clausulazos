import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/activity/activity_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/clauses/confirm_clause_screen.dart';
import '../../screens/clauses/select_player_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/main_shell.dart';
import '../../screens/players/players_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../models/user.dart';

class AppRouter {
  AppRouter._();

  static GoRouter build(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final status = authProvider.status;
        final loggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/welcome';
        final onSplash = state.matchedLocation == '/splash';

        if (status == AuthStatus.unknown) {
          return onSplash ? null : '/splash';
        }
        if (status == AuthStatus.unauthenticated) {
          return loggingIn ? null : '/welcome';
        }
        // authenticated
        if (onSplash || loggingIn) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
        GoRoute(
          path: '/select-player',
          builder: (context, state) => const SelectPlayerScreen(),
        ),
        GoRoute(
          path: '/confirm-clause',
          builder: (context, state) => ConfirmClauseScreen(
            player: state.extra as AppUser,
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
            GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
            GoRoute(path: '/players', builder: (context, state) => const PlayersScreen()),
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ],
        ),
      ],
    );
  }
}

/// Convenience so screens can grab the AuthProvider without importing
/// `provider` boilerplate everywhere.
extension AuthProviderReader on BuildContext {
  AuthProvider get auth => read<AuthProvider>();
}
